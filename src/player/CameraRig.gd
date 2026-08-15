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

func _ready() -> void:
	_apply_mode()

func add_pitch(delta_radians: float) -> void:
	_pitch_radians = clampf(
		_pitch_radians + delta_radians,
		deg_to_rad(min_pitch_degrees),
		deg_to_rad(max_pitch_degrees)
	)
	pitch.rotation.x = _pitch_radians

func cycle_camera() -> void:
	mode = ((int(mode) + 1) % CameraMode.size()) as CameraMode
	_apply_mode()

func _apply_mode() -> void:
	first_person.current = mode == CameraMode.FIRST_PERSON
	third_person_rear.current = mode == CameraMode.THIRD_PERSON_REAR
	third_person_front.current = mode == CameraMode.THIRD_PERSON_FRONT
	camera_mode_changed.emit(int(mode))
