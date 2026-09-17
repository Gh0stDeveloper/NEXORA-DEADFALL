class_name DeadfallCameraRig
extends Node3D

signal camera_mode_changed(mode: int)

enum CameraMode {
	FIRST_PERSON,
	THIRD_PERSON_REAR,
	THIRD_PERSON_FRONT,
}

@export_range(-89.0, -10.0, 1.0) var min_pitch_degrees := -80.0
@export_range(10.0, 89.0, 1.0) var max_pitch_degrees := 80.0

@onready var pitch: Node3D = $Pitch
@onready var first_person: Node3D = $Pitch/FirstPerson
@onready var third_person_rear: Camera3D = get_node_or_null("Pitch/ThirdPersonRear")
@onready var third_person_front: Camera3D = get_node_or_null("Pitch/ThirdPersonFront")

var mode: CameraMode = CameraMode.FIRST_PERSON
var _pitch_radians := 0.0
var _camera_enabled := true

func _enter_tree() -> void:
	if has_node("Pitch/FirstPerson"):
		return
	var pivot := get_node("Pitch")
	if not preload("res://src/core/PresentationRuntime.gd").enabled():
		var aim := Node3D.new()
		aim.name = "FirstPerson"
		pivot.add_child(aim)
		return
	for index in range(3):
		var camera := Camera3D.new()
		camera.name = ["FirstPerson", "ThirdPersonRear", "ThirdPersonFront"][index]
		camera.fov = 75.0
		camera.near = 0.05 if index == 0 else 0.08
		pivot.add_child(camera)
		if index == 1:
			camera.position = Vector3(0, 0.25, 3.2)
		elif index == 2:
			camera.position = Vector3(0, 0.2, -3.0)
			camera.rotation.y = PI
		else:
			var light := SpotLight3D.new()
			light.name = "Flashlight"
			light.visible = false
			light.position = Vector3(0.12, -0.10, -0.18)
			light.light_color = Color(0.84, 0.90, 1.0)
			light.light_energy = 4.2
			light.spot_range = 22.0
			light.spot_angle = 27.0
			light.shadow_enabled = true
			camera.add_child(light)

func _ready() -> void:
	_apply_mode()

func add_pitch(delta_radians: float) -> void:
	set_pitch(_pitch_radians + delta_radians)

func set_pitch(value: float) -> void:
	_pitch_radians = clampf(value, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
	pitch.rotation.x = _pitch_radians

func get_pitch() -> float:
	return _pitch_radians

func set_camera_enabled(enabled: bool) -> void:
	_camera_enabled = enabled
	_apply_mode()

func cycle_camera() -> void:
	mode = ((int(mode) + 1) % CameraMode.size()) as CameraMode
	_apply_mode()

func get_active_camera() -> Camera3D:
	match mode:
		CameraMode.THIRD_PERSON_REAR:
			return third_person_rear
		CameraMode.THIRD_PERSON_FRONT:
			return third_person_front
		_:
			return first_person as Camera3D

func get_aim_camera() -> Node3D:
	# Authoritative hitscan needs an origin and orientation, not a Camera3D.
	return first_person

func _apply_mode() -> void:
	if first_person is Camera3D:
		(first_person as Camera3D).current = _camera_enabled and mode == CameraMode.FIRST_PERSON
	if third_person_rear != null:
		third_person_rear.current = _camera_enabled and mode == CameraMode.THIRD_PERSON_REAR
	if third_person_front != null:
		third_person_front.current = _camera_enabled and mode == CameraMode.THIRD_PERSON_FRONT
	camera_mode_changed.emit(int(mode))
