class_name DeadfallPlayerController
extends CharacterBody3D

enum Stance {
	STAND,
	CROUCH,
	PRONE,
}

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

@onready var input_source: DeadfallPlayerInput = $PlayerInput
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visual_root: Node3D = $VisualRoot
@onready var visual_body: MeshInstance3D = $VisualRoot/Body
@onready var camera_rig: DeadfallCameraRig = $CameraRig

var stance: Stance = Stance.STAND
var _gravity := 9.8

func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	if collision_shape.shape != null:
		collision_shape.shape = collision_shape.shape.duplicate(true)
	camera_rig.camera_mode_changed.connect(_on_camera_mode_changed)
	_apply_stance_geometry(stance)
	_on_camera_mode_changed(int(camera_rig.mode))

func _physics_process(delta: float) -> void:
	_process_look()
	_process_stance_actions()
	_process_vertical_velocity(delta)
	_process_planar_velocity(delta)
	move_and_slide()

func _process_look() -> void:
	var look_delta := input_source.consume_look_delta()
	if look_delta.is_zero_approx():
		return
	rotation.y -= look_delta.x * look_sensitivity
	camera_rig.add_pitch(-look_delta.y * look_sensitivity)

func _process_stance_actions() -> void:
	if input_source.consume_action_just_pressed("camera_cycle"):
		camera_rig.cycle_camera()

	if input_source.consume_action_just_pressed("crouch"):
		match stance:
			Stance.STAND:
				_try_set_stance(Stance.CROUCH)
			Stance.CROUCH:
				_try_set_stance(Stance.STAND)
			Stance.PRONE:
				_try_set_stance(Stance.CROUCH)

	if input_source.consume_action_just_pressed("prone"):
		if stance == Stance.PRONE:
			_try_set_stance(Stance.STAND)
		else:
			_try_set_stance(Stance.PRONE)

func _process_vertical_velocity(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -0.1
		if input_source.consume_action_just_pressed("jump") and stance != Stance.PRONE:
			velocity.y = jump_velocity
	else:
		velocity.y -= _gravity * delta

func _process_planar_velocity(delta: float) -> void:
	var move_input := input_source.get_move_vector()
	var local_direction := Vector3(move_input.x, 0.0, move_input.y)
	var world_direction := (global_transform.basis * local_direction).normalized()
	var target_speed := _get_target_speed()
	var target_velocity := world_direction * target_speed
	var acceleration := ground_acceleration if is_on_floor() else air_acceleration

	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

func _get_target_speed() -> float:
	match stance:
		Stance.CROUCH:
			return crouch_speed
		Stance.PRONE:
			return prone_speed
		_:
			return sprint_speed if input_source.is_action_pressed("sprint") else walk_speed

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
		Stance.CROUCH:
			return crouch_height
		Stance.PRONE:
			return prone_height
		_:
			return standing_height

func _eye_height_for_stance(value: Stance) -> float:
	match value:
		Stance.CROUCH:
			return crouch_eye_height
		Stance.PRONE:
			return prone_eye_height
		_:
			return standing_eye_height

func _on_camera_mode_changed(mode: int) -> void:
	visual_root.visible = mode != DeadfallCameraRig.CameraMode.FIRST_PERSON

func get_stance_name() -> String:
	return Stance.keys()[int(stance)]
