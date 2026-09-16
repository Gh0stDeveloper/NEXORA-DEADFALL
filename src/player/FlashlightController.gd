class_name DeadfallFlashlightController
extends Node

@export var input_path := NodePath("../PlayerInput")
@export var light_path := NodePath("../CameraRig/Pitch/FirstPerson/Flashlight")
@export var starts_enabled := false

var _input: Node
var _light: SpotLight3D

func _ready() -> void:
	_input = get_node_or_null(input_path)
	_light = get_node_or_null(light_path) as SpotLight3D
	if _light != null:
		_light.visible = starts_enabled

func _process(_delta: float) -> void:
	if _input == null or _light == null:
		return
	if _input.has_method("consume_action_just_pressed") and bool(_input.call("consume_action_just_pressed", &"flashlight")):
		_light.visible = not _light.visible

func set_enabled(value: bool) -> void:
	if _light != null:
		_light.visible = value

func is_enabled() -> bool:
	return _light != null and _light.visible
