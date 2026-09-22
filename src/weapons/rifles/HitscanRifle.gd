class_name DeadfallHitscanRifle
extends Node3D

signal shot_intent_created(intent)
signal shot_fired(intent, hit_result)
signal ammo_changed(in_mag: int, reserve: int)
signal reload_started()
signal reload_completed()
signal dry_fired()

const DamageEventScript = preload("res://src/core/damage/DamageEvent.gd")
const RuntimeStateScript = preload("res://src/weapons/base/WeaponRuntimeState.gd")
const ShotIntentScript = preload("res://src/weapons/base/ShotIntent.gd")
const ProceduralWeapons = preload("res://src/assets/ProceduralWeaponModels.gd")

@export var weapon_data: Resource
@export var shooter_entity_id: int = 1
@export var input_path := NodePath("../PlayerInput")
@export var camera_rig_path := NodePath("../CameraRig")
@export_flags_3d_physics var hitscan_mask: int = 5
@export var input_enabled := true

var _input_source = null
var _camera_rig = null
var _state = RuntimeStateScript.new()
var _shot_sequence := 0
var _last_server_fire_sequence := 0
var _last_server_reload_sequence := 0
var _last_presented_sequence := 0
var _last_dry_usec := -1000000
var _view_model: Node3D
var _view_tween: Tween
var _base_view_position := Vector3(0.25, -0.22, -0.48)
var _base_view_rotation := Vector3(deg_to_rad(-1.0), deg_to_rad(-4.0), deg_to_rad(1.0))

func _ready() -> void:
	_input_source = get_node_or_null(input_path)
	_camera_rig = get_node_or_null(camera_rig_path)
	_state.configure(weapon_data)
	ammo_changed.emit(_state.ammo_in_mag, _state.reserve_ammo)
	if DisplayServer.get_name() != "headless" and not OS.has_feature("dedicated_server"):
		# Weapons precede CameraRig in Player.tscn; its @onready cameras must exist.
		call_deferred("_build_view_model")
	if _camera_rig != null and _camera_rig.has_signal("camera_mode_changed"):
		_camera_rig.connect("camera_mode_changed", Callable(self, "_on_camera_mode_changed"))
	shot_fired.connect(Callable(self, "_on_view_shot_fired"))
	reload_started.connect(func() -> void: _sound(&"reload"))
	dry_fired.connect(func() -> void: _sound(&"dry"))
	_refresh_view_visibility()

func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	_refresh_view_visibility()

func _process(_delta: float) -> void:
	if weapon_data == null:
		return
	var now_usec := Time.get_ticks_usec()
	if _state.update_reload(now_usec):
		reload_completed.emit()
		ammo_changed.emit(_state.ammo_in_mag, _state.reserve_ammo)
	if not _owner_can_use_weapon():
		if _state.reloading:
			_state.cancel_reload()
		return
	if not input_enabled or _input_source == null:
		return
	if _input_source.consume_action_just_pressed(&"reload") and _state.try_start_reload(now_usec):
		reload_started.emit()
	var wants_fire: bool = false
	if bool(weapon_data.get("automatic")):
		wants_fire = bool(_input_source.is_action_pressed(&"fire"))
	else:
		wants_fire = bool(_input_source.consume_action_just_pressed(&"fire"))
	if wants_fire:
		_try_fire(now_usec)

func _build_view_model() -> void:
	if is_instance_valid(_view_model):
		return
	if _camera_rig == null or not _camera_rig.has_method("get_aim_camera"):
		return
	var camera := _camera_rig.call("get_aim_camera") as Camera3D
	if camera == null:
		return
	var weapon_id: StringName = &"nxr_rifle_01"
	if weapon_data != null:
		weapon_id = weapon_data.weapon_id
	_view_model = ProceduralWeapons.create_view_model(weapon_id)
	_view_model.name = "ProceduralWeaponViewModel"
	_view_model.position = _base_view_position
	_view_model.rotation = _base_view_rotation
	ProceduralWeapons.add_first_person_hands(_view_model, weapon_id)
	camera.add_child(_view_model)
	_refresh_view_visibility()

func _on_camera_mode_changed(_mode: int) -> void:
	_refresh_view_visibility()

func _refresh_view_visibility() -> void:
	if _view_model == null or _camera_rig == null:
		return
	var mode_value = _camera_rig.get("mode")
	_view_model.visible = input_enabled and int(mode_value) == 0

func _sound(cue: StringName) -> void:
	AudioDirector.play_at(cue, global_position, 0, 1, get_instance_id())

func _on_view_shot_fired(_intent, _hit_result) -> void:
	_sound(&"pistol" if String(weapon_data.weapon_id).contains("pistol") else &"rifle")
	if _view_model == null or not is_instance_valid(_view_model):
		return
	if _view_tween != null and _view_tween.is_valid():
		_view_tween.kill()
	var flash := _view_model.get_node_or_null("MuzzleFlash") as Node3D
	if flash != null:
		flash.visible = true
		get_tree().create_timer(0.045).timeout.connect(func() -> void:
			if is_instance_valid(flash):
				flash.visible = false
		)
	_view_model.position = _base_view_position
	_view_model.rotation = _base_view_rotation
	_view_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_view_tween.tween_property(_view_model, "position", _base_view_position + Vector3(0.0, 0.018, 0.065), 0.055)
	_view_tween.parallel().tween_property(_view_model, "rotation", _base_view_rotation + Vector3(deg_to_rad(-4.0), deg_to_rad(1.5), deg_to_rad(2.0)), 0.055)
	_view_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_view_tween.tween_property(_view_model, "position", _base_view_position, 0.14)
	_view_tween.parallel().tween_property(_view_model, "rotation", _base_view_rotation, 0.14)

func _try_fire(now_usec: int) -> bool:
	if not _owner_can_use_weapon() or _state.reloading:
		return false
	if _state.ammo_in_mag <= 0:
		if now_usec - _last_dry_usec >= 500000:
			_last_dry_usec = now_usec
			dry_fired.emit()
		return false
	if not _state.try_consume_shot(now_usec):
		return false
	ammo_changed.emit(_state.ammo_in_mag, _state.reserve_ammo)
	_shot_sequence += 1
	_last_presented_sequence = maxi(_last_presented_sequence, _shot_sequence)
	var intent = _build_shot_intent(_shot_sequence, Engine.get_physics_frames())
	if intent == null:
		return false
	shot_intent_created.emit(intent)
	if _is_local_session():
		_resolve_authoritative_hitscan(intent)
	return true

func server_try_fire(request_sequence: int, client_tick: int = 0) -> bool:
	if not _is_simulation_authority() or not _owner_can_use_weapon() or request_sequence <= _last_server_fire_sequence:
		return false
	_last_server_fire_sequence = request_sequence
	var now_usec := Time.get_ticks_usec()
	_state.update_reload(now_usec)
	if not _state.try_consume_shot(now_usec):
		return false
	var intent = _build_shot_intent(request_sequence, client_tick)
	if intent == null:
		return false
	_last_presented_sequence = maxi(_last_presented_sequence, request_sequence)
	ammo_changed.emit(_state.ammo_in_mag, _state.reserve_ammo)
	shot_intent_created.emit(intent)
	_resolve_authoritative_hitscan(intent)
	return true

func server_try_reload(request_sequence: int) -> bool:
	if not _is_simulation_authority() or not _owner_can_use_weapon() or request_sequence <= _last_server_reload_sequence:
		return false
	_last_server_reload_sequence = request_sequence
	var started := _state.try_start_reload(Time.get_ticks_usec())
	if started:
		reload_started.emit()
	return started

func start_automatic_reload() -> bool:
	if not _is_simulation_authority() or not _owner_can_use_weapon():
		return false
	var started := _state.try_start_reload(Time.get_ticks_usec())
	if started:
		reload_started.emit()
	return started

func add_reserve_ammo(amount: int) -> int:
	if amount <= 0 or weapon_data == null or not _is_simulation_authority():
		return 0
	var configured_max: int = int(weapon_data.get("max_reserve_ammo")) if weapon_data.get("max_reserve_ammo") != null else int(weapon_data.get("starting_reserve_ammo")) * 3
	var maximum: int = maxi(0, configured_max)
	var before: int = int(_state.reserve_ammo)
	_state.reserve_ammo = mini(maximum, before + amount)
	var added: int = int(_state.reserve_ammo) - before
	if added > 0:
		ammo_changed.emit(_state.ammo_in_mag, _state.reserve_ammo)
	return added

func _build_shot_intent(sequence: int, simulation_tick: int):
	if _camera_rig == null or not _camera_rig.has_method("get_aim_camera"):
		return null
	var aim_camera = _camera_rig.get_aim_camera() as Node3D
	if aim_camera == null:
		return null
	var intent = ShotIntentScript.new()
	intent.attacker_id = shooter_entity_id
	intent.weapon_id = StringName(weapon_data.get("weapon_id"))
	intent.origin = aim_camera.global_position
	intent.direction = -aim_camera.global_transform.basis.z.normalized()
	intent.max_distance = float(weapon_data.get("max_distance"))
	intent.simulation_tick = simulation_tick
	intent.sequence = sequence
	return intent

func _resolve_authoritative_hitscan(intent) -> void:
	if get_world_3d() == null or intent == null or not intent.is_valid():
		return
	var query := PhysicsRayQueryParameters3D.create(intent.origin, intent.origin + intent.direction * intent.max_distance, hitscan_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var shooter_body := get_parent() as CollisionObject3D
	if shooter_body != null:
		query.exclude = [shooter_body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	shot_fired.emit(intent, hit)
	if hit.is_empty():
		return
	var collider = hit.get("collider")
	if collider == null or not collider.has_method("get_victim_id") or not collider.has_method("get_body_part"):
		return
	var active_authority = Game.authority if get_tree() != null else null
	if active_authority == null or not active_authority.has_method("resolve_damage"):
		return
	var event = DamageEventScript.new()
	event.attacker_id = intent.attacker_id
	event.victim_id = int(collider.get_victim_id())
	event.weapon_id = intent.weapon_id
	event.amount = float(weapon_data.get("base_damage"))
	event.damage_type = DamageEventScript.DamageType.BULLET
	event.body_part = int(collider.get_body_part())
	event.hit_position = hit.get("position", intent.origin)
	event.hit_direction = intent.direction
	event.hit_normal = hit.get("normal", Vector3.ZERO)
	event.penetration = float(weapon_data.get("penetration"))
	event.simulation_tick = intent.simulation_tick
	active_authority.resolve_damage(event)

func get_authoritative_state() -> Dictionary:
	return {
		"ammo": _state.ammo_in_mag,
		"reserve": _state.reserve_ammo,
		"reloading": _state.reloading,
		"reload_remaining_usec": maxi(0, _state.reload_end_usec - Time.get_ticks_usec()) if _state.reloading else 0,
		"last_sequence": _last_presented_sequence,
	}

func apply_authoritative_state(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	var next_sequence := int(snapshot.get("last_sequence", _last_presented_sequence))
	if next_sequence > _last_presented_sequence and not input_enabled:
		_on_view_shot_fired(null, null)
	if bool(snapshot.get("reloading", false)) and not _state.reloading and not input_enabled:
		_sound(&"reload")
	_state.ammo_in_mag = maxi(0, int(snapshot.get("ammo", _state.ammo_in_mag)))
	_state.reserve_ammo = maxi(0, int(snapshot.get("reserve", _state.reserve_ammo)))
	_state.reloading = bool(snapshot.get("reloading", false))
	_state.reload_end_usec = Time.get_ticks_usec() + maxi(0, int(snapshot.get("reload_remaining_usec", 0))) if _state.reloading else 0
	_last_presented_sequence = maxi(_last_presented_sequence, int(snapshot.get("last_sequence", _last_presented_sequence)))
	ammo_changed.emit(_state.ammo_in_mag, _state.reserve_ammo)

func restore_authoritative_state(snapshot: Dictionary) -> void:
	apply_authoritative_state(snapshot)

func _owner_can_use_weapon() -> bool:
	var owner := get_parent()
	return owner == null or not owner.has_method("can_use_weapon") or bool(owner.call("can_use_weapon"))

func _is_local_session() -> bool:
	return Game.is_local_session() if get_tree() != null else false

func _is_simulation_authority() -> bool:
	return Game.is_simulation_authority() if get_tree() != null else false

func get_ammo_in_mag() -> int:
	return _state.ammo_in_mag

func get_reserve_ammo() -> int:
	return _state.reserve_ammo

func is_reloading() -> bool:
	return _state.reloading
