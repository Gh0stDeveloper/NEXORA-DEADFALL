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
@onready var first_person: Camera3D = $Pitch/FirstPerson
@onready var third_person_rear: Camera3D = $Pitch/ThirdPersonRear
@onready var third_person_front: Camera3D = $Pitch/ThirdPersonFront

var mode: CameraMode = CameraMode.FIRST_PERSON
var _pitch_radians := 0.0
var _camera_enabled := true

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
			return first_person

func get_aim_camera() -> Camera3D:
	return first_person

func _apply_mode() -> void:
	first_person.current = _camera_enabled and mode == CameraMode.FIRST_PERSON
	third_person_rear.current = _camera_enabled and mode == CameraMode.THIRD_PERSON_REAR
	third_person_front.current = _camera_enabled and mode == CameraMode.THIRD_PERSON_FRONT
	camera_mode_changed.emit(int(mode))
