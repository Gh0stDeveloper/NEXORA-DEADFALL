class_name DeadfallMacheteWeapon
extends Node3D

signal attack_intent_created(sequence: int, simulation_tick: int)
signal attack_started()
signal attack_hit(victim_id: int, damage: float)

const DamageEventScript = preload("res://src/core/damage/DamageEvent.gd")
const ProceduralWeapons = preload("res://src/assets/ProceduralWeaponModels.gd")

@export var shooter_entity_id := 1
@export var input_path := NodePath("../PlayerInput")
@export var camera_rig_path := NodePath("../CameraRig")
@export_range(0.5, 5.0, 0.1) var range_meters := 2.55
@export_range(1.0, 200.0, 1.0) var base_damage := 55.0
@export_range(0.1, 2.0, 0.05) var attack_cooldown_seconds := 0.62
@export_flags_3d_physics var melee_mask := 5
@export var input_enabled := false

var _input_source: Node
var _camera_rig: Node
var _attack_sequence := 0
var _last_server_sequence := 0
var _last_presented_sequence := 0
var _next_attack_usec := 0
var _view_model: Node3D
var _view_tween: Tween
var _base_view_position := Vector3(0.40, -0.34, -0.72)
var _base_view_rotation := Vector3(deg_to_rad(18.0), deg_to_rad(-12.0), deg_to_rad(-24.0))

func _ready() -> void:
	_input_source = get_node_or_null(input_path)
	_camera_rig = get_node_or_null(camera_rig_path)
	if DisplayServer.get_name() != "headless" and not OS.has_feature("dedicated_server"):
		call_deferred("_build_view_model")
	if _camera_rig != null and _camera_rig.has_signal("camera_mode_changed"):
		_camera_rig.connect("camera_mode_changed", Callable(self, "_on_camera_mode_changed"))
	_refresh_view_visibility()
	attack_started.connect(func() -> void: AudioDirector.play_at(&"melee", global_position, 0, 1, get_instance_id()))
	attack_hit.connect(func(_victim: int, _damage: float) -> void: AudioDirector.play_at(&"impact", global_position, 0, 1, get_instance_id()))

func _process(_delta: float) -> void:
	if not input_enabled or _input_source == null or not _owner_can_use_weapon():
		return
	if bool(_input_source.call("consume_action_just_pressed", &"fire")):
		_try_attack(Engine.get_physics_frames())

func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	_refresh_view_visibility()

func server_try_attack(request_sequence: int, simulation_tick: int = 0) -> bool:
	if not _is_simulation_authority() or not _owner_can_use_weapon() or request_sequence <= _last_server_sequence:
		return false
	_last_server_sequence = request_sequence
	if not _consume_cooldown():
		return false
	_last_presented_sequence = maxi(_last_presented_sequence, request_sequence)
	attack_started.emit()
	_resolve_authoritative_melee(request_sequence, simulation_tick)
	return true

func get_authoritative_state() -> Dictionary:
	return {
		"weapon_id": "machete",
		"infinite": true,
		"last_sequence": _last_presented_sequence,
		"cooldown_remaining_usec": maxi(0, _next_attack_usec - Time.get_ticks_usec()),
	}

func apply_authoritative_state(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	if int(snapshot.get("last_sequence", 0)) > _last_presented_sequence and not input_enabled:
		AudioDirector.play_at(&"melee", global_position, 0, 1, get_instance_id())
	var remaining := maxi(0, int(snapshot.get("cooldown_remaining_usec", 0)))
	if remaining > 0:
		_next_attack_usec = maxi(_next_attack_usec, Time.get_ticks_usec() + remaining)
	_last_presented_sequence = maxi(_last_presented_sequence, int(snapshot.get("last_sequence", _last_presented_sequence)))

func _try_attack(simulation_tick: int) -> bool:
	if not _consume_cooldown():
		return false
	_attack_sequence += 1
	_last_presented_sequence = maxi(_last_presented_sequence, _attack_sequence)
	attack_started.emit()
	_animate_swing()
	attack_intent_created.emit(_attack_sequence, simulation_tick)
	if Game != null and Game.is_local_session():
		_resolve_authoritative_melee(_attack_sequence, simulation_tick)
	return true

func _consume_cooldown() -> bool:
	var now := Time.get_ticks_usec()
	if now < _next_attack_usec:
		return false
	_next_attack_usec = now + int(attack_cooldown_seconds * 1_000_000.0)
	return true

func _resolve_authoritative_melee(sequence: int, simulation_tick: int) -> void:
	if not _is_simulation_authority() or _camera_rig == null or not _camera_rig.has_method("get_aim_camera"):
		return
	var camera := _camera_rig.call("get_aim_camera") as Camera3D
	if camera == null or camera.get_world_3d() == null:
		return
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z.normalized()
	var right := camera.global_transform.basis.x.normalized()
	var best_hit: Dictionary = {}
	var best_distance := INF
	for lateral in [-0.16, 0.0, 0.16]:
		var direction := (forward + right * float(lateral)).normalized()
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * range_meters, melee_mask)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		var owner_body := get_parent() as CollisionObject3D
		if owner_body != null:
			query.exclude = [owner_body.get_rid()]
		var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var collider = hit.get("collider")
		if collider == null or not collider.has_method("get_victim_id") or not collider.has_method("get_body_part"):
			continue
		var distance := origin.distance_to(Vector3(hit.get("position", origin)))
		if distance < best_distance:
			best_distance = distance
			best_hit = hit
	if best_hit.is_empty():
		return
	var collider = best_hit.get("collider")
	var authority = Game.authority
	if authority == null or not authority.has_method("resolve_damage"):
		return
	var event = DamageEventScript.new()
	event.attacker_id = shooter_entity_id
	event.victim_id = int(collider.call("get_victim_id"))
	event.weapon_id = &"machete"
	event.amount = base_damage
	event.damage_type = DamageEventScript.DamageType.MELEE
	event.body_part = int(collider.call("get_body_part"))
	event.hit_position = Vector3(best_hit.get("position", origin + forward * best_distance))
	event.hit_direction = forward
	event.hit_normal = Vector3(best_hit.get("normal", Vector3.ZERO))
	event.simulation_tick = simulation_tick
	if bool(authority.call("resolve_damage", event)):
		attack_hit.emit(event.victim_id, base_damage)
		print("DEADFALL_MACHETE_HIT seq=%d victim=%d" % [sequence, event.victim_id])

func _build_view_model() -> void:
	if is_instance_valid(_view_model):
		return
	if _camera_rig == null:
		return
	var camera := _camera_rig.call("get_aim_camera") as Camera3D if _camera_rig.has_method("get_aim_camera") else null
	if camera == null:
		return
	_view_model = ProceduralWeapons.create_view_model(&"machete")
	ProceduralWeapons.add_first_person_hands(_view_model, &"machete")
	_view_model.name = "ProceduralMacheteViewModel"
	_view_model.position = _base_view_position
	_view_model.rotation = _base_view_rotation
	camera.add_child(_view_model)
	_refresh_view_visibility()

func _animate_swing() -> void:
	if _view_model == null or not is_instance_valid(_view_model):
		return
	if _view_tween != null and _view_tween.is_valid():
		_view_tween.kill()
	_view_model.position = _base_view_position
	_view_model.rotation = _base_view_rotation
	_view_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_view_tween.tween_property(_view_model, "rotation", Vector3(deg_to_rad(38.0), deg_to_rad(-55.0), deg_to_rad(-112.0)), 0.11)
	_view_tween.parallel().tween_property(_view_model, "position", Vector3(0.12, -0.12, -0.55), 0.11)
	_view_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_view_tween.tween_property(_view_model, "rotation", _base_view_rotation, 0.22)
	_view_tween.parallel().tween_property(_view_model, "position", _base_view_position, 0.22)

func _on_camera_mode_changed(_mode: int) -> void:
	_refresh_view_visibility()

func _refresh_view_visibility() -> void:
	if _view_model == null or _camera_rig == null:
		return
	var mode_value = _camera_rig.get("mode")
	_view_model.visible = input_enabled and int(mode_value) == 0

func _owner_can_use_weapon() -> bool:
	var owner := get_parent()
	return owner == null or not owner.has_method("can_use_weapon") or bool(owner.call("can_use_weapon"))

func _is_simulation_authority() -> bool:
	return Game != null and Game.is_simulation_authority()
