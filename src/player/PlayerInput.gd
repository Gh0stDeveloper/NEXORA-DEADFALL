class_name DeadfallPlayerInput
extends Node

const KEY_BINDINGS := {
	"move_forward": KEY_W,
	"move_back": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"jump": KEY_SPACE,
	"sprint": KEY_SHIFT,
	"crouch": KEY_C,
	"prone": KEY_Z,
	"camera_cycle": KEY_V,
	"reload": KEY_R,
	"interact": KEY_E,
	"flashlight": KEY_F,
}

var _mobile_move := Vector2.ZERO
var _mobile_look := Vector2.ZERO
var _mobile_pressed: Dictionary = {}
var _mobile_just_pressed: Dictionary = {}
var _debug_move_logged := false
var _debug_look_logged := false
var _debug_actions_logged: Dictionary = {}

func _init() -> void:
	_ensure_input_map()

func _ready() -> void:
	if DisplayServer.get_name() != "headless" and not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mobile_look += event.relative
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func get_move_vector() -> Vector2:
	var desktop := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return _mobile_move if _mobile_move.length_squared() > desktop.length_squared() else desktop

func consume_look_delta() -> Vector2:
	var value := _mobile_look
	_mobile_look = Vector2.ZERO
	return value

func is_action_pressed(action: StringName) -> bool:
	return Input.is_action_pressed(action) or bool(_mobile_pressed.get(action, false))

func consume_action_just_pressed(action: StringName) -> bool:
	if Input.is_action_just_pressed(action):
		return true
	if bool(_mobile_just_pressed.get(action, false)):
		_mobile_just_pressed[action] = false
		return true
	return false

func set_mobile_move(value: Vector2) -> void:
	_mobile_move = value.limit_length(1.0)
	if _android_debug_enabled() and not _debug_move_logged and _mobile_move.length() >= 0.2:
		_debug_move_logged = true
		print("DEADFALL_TOUCH_JOYSTICK active")

func add_mobile_look(delta: Vector2) -> void:
	_mobile_look += delta
	if _android_debug_enabled() and not _debug_look_logged and delta.length_squared() > 0.0:
		_debug_look_logged = true
		print("DEADFALL_TOUCH_LOOK active")

func set_mobile_action(action: StringName, pressed: bool) -> void:
	var was_pressed := bool(_mobile_pressed.get(action, false))
	_mobile_pressed[action] = pressed
	if pressed and not was_pressed:
		_mobile_just_pressed[action] = true
		if _android_debug_enabled() and not bool(_debug_actions_logged.get(action, false)):
			_debug_actions_logged[action] = true
			print("DEADFALL_TOUCH_ACTION %s" % action)

func clear_mobile_actions() -> void:
	_mobile_move = Vector2.ZERO
	_mobile_look = Vector2.ZERO
	_mobile_pressed.clear()
	_mobile_just_pressed.clear()

func _android_debug_enabled() -> bool:
	return OS.has_feature("android") and OS.is_debug_build()

func _ensure_input_map() -> void:
	for action in KEY_BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		if InputMap.action_get_events(action).is_empty():
			var key_event := InputEventKey.new()
			key_event.physical_keycode = KEY_BINDINGS[action]
			InputMap.action_add_event(action, key_event)

	if not InputMap.has_action(&"fire"):
		InputMap.add_action(&"fire", 0.2)
	if InputMap.action_get_events(&"fire").is_empty():
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(&"fire", mouse_event)
