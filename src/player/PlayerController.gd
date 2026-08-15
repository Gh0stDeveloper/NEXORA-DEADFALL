class_name DeadfallPlayerController
extends CharacterBody3D

signal local_command_generated(command: Dictionary)

enum Stance { STAND, CROUCH, PRONE }
enum ControlMode { OFFLINE_LOCAL, NETWORK_PREDICTED, SERVER_REMOTE, REMOTE_PROXY }

const PlayerCommandScript = preload("res://src/network/PlayerCommand.gd")

@export_category("Movement")
@export var walk_speed := 4.5
@export var sprint_speed := 7.5
@export var crouch_speed := 2.8
@export var prone_speed := 1.6
@export var jump_velocity := 5.2
@export var ground_acceleration := 22.0
@export var air_acceleration := 7.0
@export_category("Look")
@export var look_sensitivity := 0.0025
@export_category("Stance")
@export var standing_height := 1.80
@export var crouch_height := 1.25
@export var prone_height := 0.80
@export var standing_eye_height := 1.62
@export var crouch_eye_height := 1.08
@export var prone_eye_height := 0.58
@export_category("Networking")
@export var player_entity_id := 1
@export var control_mode: int = ControlMode.OFFLINE_LOCAL
@export var reconciliation_strength := 0.35
@export var hard_reconciliation_distance := 2.5

@onready var input_source: DeadfallPlayerInput = $PlayerInput
@onready var health: Node = $Health
@onready var life_state: Node = $LifeState
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visual_root: Node3D = $VisualRoot
@onready var visual_body: MeshInstance3D = $VisualRoot/Body
@onready var camera_rig: DeadfallCameraRig = $CameraRig

var stance: Stance = Stance.STAND
var _gravity := 9.8
var _command_sequence := 0
var _jump_serial := 0
var _crouch_serial := 0
var _prone_serial := 0
var _processed_jump_serial := 0
var _processed_crouch_serial := 0
var _processed_prone_serial := 0
var _last_server_sequence := -1
var _server_command: Dictionary = {}

func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	if collision_shape.shape != null:
		collision_shape.shape = collision_shape.shape.duplicate(true)
	camera_rig.camera_mode_changed.connect(_on_camera_mode_changed)
	if life_state != null and life_state.has_signal("state_changed"):
		life_state.connect("state_changed", Callable(self, "_on_life_state_changed"))
	_apply_stance_geometry(stance)
	configure_network_identity(player_entity_id, control_mode)

func configure_network_identity(entity_id: int, mode: int) -> void:
	player_entity_id = entity_id
	control_mode = mode
	var local_visual_control := control_mode in [ControlMode.OFFLINE_LOCAL, ControlMode.NETWORK_PREDICTED]
	if camera_rig != null:
		camera_rig.set_camera_enabled(local_visual_control)
	if input_source != null and not local_visual_control:
		input_source.set_process_unhandled_input(false)
	if life_state != null and life_state.has_method("configure_squad_mode"):
		life_state.call("configure_squad_mode", control_mode != ControlMode.OFFLINE_LOCAL)
	var weapon := get_node_or_null("PrimaryWeapon")
	if weapon != null and weapon.has_method("set_input_enabled"):
		weapon.call("set_input_enabled", local_visual_control)
	if local_visual_control:
		_on_camera_mode_changed(int(camera_rig.mode))
	else:
		visual_root.visible = true

func _physics_process(delta: float) -> void:
	if control_mode == ControlMode.REMOTE_PROXY:
		return
	if _life_is_dead():
		velocity = Vector3.ZERO
		return

	var command: Dictionary
	if control_mode == ControlMode.SERVER_REMOTE:
		command = _server_command
		if command.is_empty():
			_process_vertical_velocity(delta, false)
			_process_planar_velocity(delta, Vector2.ZERO, false, _life_move_multiplier())
			move_and_slide()
			return
		_apply_authoritative_orientation(command)
	else:
		command = _capture_local_command()
		_apply_local_look(Vector2(command.get("look_delta", Vector2.ZERO)))

	var downed := _life_is_downed()
	if downed and stance != Stance.PRONE:
		_apply_replica_stance(Stance.PRONE)
	_process_serial_actions(command, not downed)
	var jump_requested := _serial_triggered(command, "jump_serial", _processed_jump_serial, not downed)
	_process_vertical_velocity(delta, jump_requested)
	_process_planar_velocity(delta, Vector2(command.get("move", Vector2.ZERO)), bool(command.get("sprint", false)) and not downed, _life_move_multiplier())
	move_and_slide()

	if control_mode == ControlMode.NETWORK_PREDICTED:
		var wire := command.duplicate(true)
		wire.erase("look_delta")
		wire["yaw"] = rotation.y
		wire["pitch"] = camera_rig.get_pitch()
		local_command_generated.emit(wire)

func _capture_local_command() -> Dictionary:
	_command_sequence += 1
	if input_source.consume_action_just_pressed(&"camera_cycle"):
		camera_rig.cycle_camera()
	if input_source.consume_action_just_pressed(&"jump"):
		_jump_serial += 1
	if input_source.consume_action_just_pressed(&"crouch"):
		_crouch_serial += 1
	if input_source.consume_action_just_pressed(&"prone"):
		_prone_serial += 1
	return {
		"sequence": _command_sequence,
		"client_tick": Engine.get_physics_frames(),
		"move": input_source.get_move_vector(),
		"look_delta": input_source.consume_look_delta(),
		"yaw": rotation.y,
		"pitch": camera_rig.get_pitch(),
		"sprint": input_source.is_action_pressed(&"sprint"),
		"interact": input_source.is_action_pressed(&"interact"),
		"jump_serial": _jump_serial,
		"crouch_serial": _crouch_serial,
		"prone_serial": _prone_serial,
	}

func push_server_command(raw_command: Dictionary) -> bool:
	if control_mode != ControlMode.SERVER_REMOTE:
		return false
	var command := PlayerCommandScript.sanitize(raw_command, _last_server_sequence)
	if command.is_empty():
		return false
	_last_server_sequence = int(command.get("sequence", -1))
	_server_command = command
	return true

func get_last_server_command() -> Dictionary:
	return _server_command.duplicate(true)

func can_use_weapon() -> bool:
	return life_state == null or not life_state.has_method("can_use_weapon") or bool(life_state.call("can_use_weapon"))

func is_recoverable() -> bool:
	return life_state == null or not life_state.has_method("is_recoverable") or bool(life_state.call("is_recoverable"))

func _apply_local_look(look_delta: Vector2) -> void:
	if look_delta.is_zero_approx():
		return
	rotation.y -= look_delta.x * look_sensitivity
	camera_rig.add_pitch(-look_delta.y * look_sensitivity)

func _apply_authoritative_orientation(command: Dictionary) -> void:
	rotation.y = float(command.get("yaw", rotation.y))
	camera_rig.set_pitch(float(command.get("pitch", camera_rig.get_pitch())))

func _process_serial_actions(command: Dictionary, allow_actions: bool) -> void:
	var crouch_serial := int(command.get("crouch_serial", 0))
	if crouch_serial != _processed_crouch_serial:
		_processed_crouch_serial = crouch_serial
		if allow_actions:
			match stance:
				Stance.STAND: _try_set_stance(Stance.CROUCH)
				Stance.CROUCH: _try_set_stance(Stance.STAND)
				Stance.PRONE: _try_set_stance(Stance.CROUCH)
	var prone_serial := int(command.get("prone_serial", 0))
	if prone_serial != _processed_prone_serial:
		_processed_prone_serial = prone_serial
		if allow_actions:
			_try_set_stance(Stance.STAND if stance == Stance.PRONE else Stance.PRONE)

func _serial_triggered(command: Dictionary, key: String, processed_value: int, allow_action: bool) -> bool:
	var serial := int(command.get(key, 0))
	if key == "jump_serial" and serial != processed_value:
		_processed_jump_serial = serial
		return allow_action
	return false

func _process_vertical_velocity(delta: float, jump_requested: bool) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -0.1
		if jump_requested and stance != Stance.PRONE:
			velocity.y = jump_velocity
	else:
		velocity.y -= _gravity * delta

func _process_planar_velocity(delta: float, move_input: Vector2, sprint: bool, movement_multiplier: float = 1.0) -> void:
	var local_direction := Vector3(move_input.x, 0.0, move_input.y)
	var world_direction := (global_transform.basis * local_direction).normalized()
	var target_speed := _get_target_speed(sprint) * clampf(movement_multiplier, 0.0, 1.0)
	var target_velocity := world_direction * target_speed
	var acceleration := ground_acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

func _get_target_speed(sprint: bool = false) -> float:
	match stance:
		Stance.CROUCH: return crouch_speed
		Stance.PRONE: return prone_speed
		_: return sprint_speed if sprint else walk_speed

func _try_set_stance(target: Stance) -> bool:
	if target == stance:
		return true
	var target_height := _height_for_stance(target)
	if target_height > _height_for_stance(stance) and not _can_fit_height(target_height):
		return false
	stance = target
	_apply_stance_geometry(target)
	return true

func _can_fit_height(target_height: float) -> bool:
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule == null or not is_inside_tree():
		return true
	var test_shape := CapsuleShape3D.new()
	test_shape.radius = capsule.radius
	test_shape.height = target_height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = test_shape
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.margin = 0.01
	query.transform = Transform3D(global_basis, global_position + Vector3.UP * (target_height * 0.5 + 0.025))
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _apply_stance_geometry(target: Stance) -> void:
	var target_height := _height_for_stance(target)
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule != null:
		capsule.height = target_height
		collision_shape.position.y = target_height * 0.5
	visual_body.scale.y = target_height / standing_height
	visual_body.position.y = target_height * 0.5
	camera_rig.position.y = _eye_height_for_stance(target)

func _height_for_stance(value: Stance) -> float:
	match value:
		Stance.CROUCH: return crouch_height
		Stance.PRONE: return prone_height
		_: return standing_height

func _eye_height_for_stance(value: Stance) -> float:
	match value:
		Stance.CROUCH: return crouch_eye_height
		Stance.PRONE: return prone_eye_height
		_: return standing_eye_height

func _on_camera_mode_changed(mode: int) -> void:
	if control_mode in [ControlMode.OFFLINE_LOCAL, ControlMode.NETWORK_PREDICTED]:
		visual_root.visible = mode != DeadfallCameraRig.CameraMode.FIRST_PERSON
	else:
		visual_root.visible = true

func _on_life_state_changed(_previous: int, current: int, _reason: String) -> void:
	if current == 1:
		_apply_replica_stance(Stance.PRONE)
	elif current == 2:
		velocity = Vector3.ZERO

func get_stance_name() -> String:
	return Stance.keys()[int(stance)]

func get_network_snapshot() -> Dictionary:
	return {
		"entity_id": player_entity_id,
		"position": global_position,
		"yaw": rotation.y,
		"pitch": camera_rig.get_pitch(),
		"velocity": velocity,
		"stance": int(stance),
		"ack_sequence": _last_server_sequence if control_mode == ControlMode.SERVER_REMOTE else _command_sequence,
		"life": life_state.call("get_network_snapshot") if life_state != null and life_state.has_method("get_network_snapshot") else {},
	}

func apply_authoritative_snapshot(snapshot: Dictionary) -> void:
	if control_mode != ControlMode.NETWORK_PREDICTED:
		return
	if life_state != null and life_state.has_method("apply_network_snapshot"):
		life_state.call("apply_network_snapshot", Dictionary(snapshot.get("life", {})))
	var authoritative_position := Vector3(snapshot.get("position", global_position))
	var error := global_position.distance_to(authoritative_position)
	if error >= hard_reconciliation_distance:
		global_position = authoritative_position
		rotation.y = float(snapshot.get("yaw", rotation.y))
	else:
		global_position = global_position.lerp(authoritative_position, reconciliation_strength)
		rotation.y = lerp_angle(rotation.y, float(snapshot.get("yaw", rotation.y)), reconciliation_strength)
	velocity = Vector3(snapshot.get("velocity", velocity))
	camera_rig.set_pitch(lerpf(camera_rig.get_pitch(), float(snapshot.get("pitch", camera_rig.get_pitch())), reconciliation_strength))
	_apply_replica_stance(int(snapshot.get("stance", int(stance))))

func restore_authoritative_snapshot(snapshot: Dictionary) -> void:
	global_position = Vector3(snapshot.get("position", global_position))
	rotation.y = float(snapshot.get("yaw", rotation.y))
	velocity = Vector3(snapshot.get("velocity", Vector3.ZERO))
	camera_rig.set_pitch(float(snapshot.get("pitch", 0.0)))
	_apply_replica_stance(int(snapshot.get("stance", int(stance))))
	if life_state != null and life_state.has_method("restore_authoritative_snapshot"):
		life_state.call("restore_authoritative_snapshot", Dictionary(snapshot.get("life", {})))

func apply_replica_presentation(snapshot: Dictionary) -> void:
	_apply_replica_stance(int(snapshot.get("stance", int(stance))))
	camera_rig.set_pitch(float(snapshot.get("pitch", camera_rig.get_pitch())))
	if life_state != null and life_state.has_method("apply_network_snapshot"):
		life_state.call("apply_network_snapshot", Dictionary(snapshot.get("life", {})))

func _apply_replica_stance(value: int) -> void:
	var next := clampi(value, Stance.STAND, Stance.PRONE) as Stance
	if next != stance:
		stance = next
		_apply_stance_geometry(stance)

func _life_is_downed() -> bool:
	return life_state != null and life_state.has_method("is_downed") and bool(life_state.call("is_downed"))

func _life_is_dead() -> bool:
	return life_state != null and life_state.has_method("is_dead") and bool(life_state.call("is_dead"))

func _life_move_multiplier() -> float:
	return float(life_state.call("get_movement_multiplier")) if life_state != null and life_state.has_method("get_movement_multiplier") else 1.0
