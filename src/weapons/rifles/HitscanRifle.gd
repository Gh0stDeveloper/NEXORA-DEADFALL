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

@export var weapon_data: Resource
@export var shooter_entity_id: int = 1
@export var input_path := NodePath("../PlayerInput")
@export var camera_rig_path := NodePath("../CameraRig")
@export_flags_3d_physics var hitscan_mask: int = 5

var _input_source = null
var _camera_rig = null
var _state = RuntimeStateScript.new()
var _shot_sequence := 0

func _ready() -> void:
	_input_source = get_node_or_null(input_path)
	_camera_rig = get_node_or_null(camera_rig_path)
	_state.configure(weapon_data)
	ammo_changed.emit(_state.ammo_in_mag, _state.reserve_ammo)

func _process(_delta: float) -> void:
	if weapon_data == null or _input_source == null:
		return
	var now_usec := Time.get_ticks_usec()
	if _state.update_reload(now_usec):
		reload_completed.emit()
		ammo_changed.emit(_state.ammo_in_mag, _state.reserve_ammo)

	if _input_source.consume_action_just_pressed(&"reload"):
		if _state.try_start_reload(now_usec):
			reload_started.emit()

	var wants_fire := _input_source.is_action_pressed(&"fire") if bool(weapon_data.get("automatic")) else _input_source.consume_action_just_pressed(&"fire")
	if wants_fire:
		_try_fire(now_usec)

func _try_fire(now_usec: int) -> bool:
	if _state.reloading:
		return false
	if _state.ammo_in_mag <= 0:
		dry_fired.emit()
		return false
	if not _state.try_consume_shot(now_usec):
		return false

	ammo_changed.emit(_state.ammo_in_mag, _state.reserve_ammo)
	var intent = _build_shot_intent()
	if intent == null:
		return false
	shot_intent_created.emit(intent)

	if _is_local_session():
		_resolve_local_hitscan(intent)
	return true

func _build_shot_intent():
	if _camera_rig == null or not _camera_rig.has_method("get_active_camera"):
		return null
	var camera = _camera_rig.get_active_camera() as Camera3D
	if camera == null:
		return null
	_shot_sequence += 1
	var intent = ShotIntentScript.new()
	intent.attacker_id = shooter_entity_id
	intent.weapon_id = StringName(weapon_data.get("weapon_id"))
	intent.origin = camera.global_position
	intent.direction = -camera.global_transform.basis.z.normalized()
	intent.max_distance = float(weapon_data.get("max_distance"))
	intent.simulation_tick = Engine.get_physics_frames()
	intent.sequence = _shot_sequence
	return intent

func _resolve_local_hitscan(intent) -> void:
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

	var game := get_tree().root.get_node_or_null("Game")
	if game == null:
		return
	var active_authority = game.get("authority")
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
	event.penetration = float(weapon_data.get("penetration"))
	event.simulation_tick = intent.simulation_tick
	active_authority.resolve_damage(event)

func _is_local_session() -> bool:
	if get_tree() == null:
		return false
	var game := get_tree().root.get_node_or_null("Game")
	return game != null and game.has_method("is_local_session") and bool(game.call("is_local_session"))

func get_ammo_in_mag() -> int:
	return _state.ammo_in_mag

func get_reserve_ammo() -> int:
	return _state.reserve_ammo

func is_reloading() -> bool:
	return _state.reloading
