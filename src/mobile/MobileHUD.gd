class_name DeadfallMobileHUD
extends CanvasLayer

const SafeAreaScript = preload("res://src/mobile/SafeArea.gd")
const JoystickScript = preload("res://src/mobile/TouchJoystick.gd")
const LookAreaScript = preload("res://src/mobile/TouchLookArea.gd")
const ActionButtonScript = preload("res://src/mobile/TouchActionButton.gd")

@export var player_path := NodePath("../Player")
@export var show_on_desktop := false
var _safe_root: Control
var _input_target: Node

func _ready() -> void:
	bind_player(get_node_or_null(player_path))

func bind_player(player: Node) -> bool:
	if player == null:
		push_warning("MobileHUD could not resolve player")
		return false
	_input_target = player.get_node_or_null("PlayerInput")
	if _input_target == null:
		push_warning("MobileHUD could not resolve PlayerInput")
		return false
	if _safe_root != null and is_instance_valid(_safe_root):
		_safe_root.queue_free()
	_build_hud()
	visible = OS.has_feature("mobile") or show_on_desktop
	return true

func _build_hud() -> void:
	_safe_root = SafeAreaScript.new()
	_safe_root.name = "SafeArea"
	add_child(_safe_root)
	_safe_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var look_area := LookAreaScript.new()
	look_area.name = "LookArea"
	look_area.input_target = _input_target
	look_area.anchor_left = 0.40
	look_area.anchor_top = 0.0
	look_area.anchor_right = 1.0
	look_area.anchor_bottom = 1.0
	_safe_root.add_child(look_area)
	var joystick := JoystickScript.new()
	joystick.name = "MoveJoystick"
	joystick.input_target = _input_target
	joystick.anchor_left = 0.0
	joystick.anchor_top = 1.0
	joystick.anchor_right = 0.0
	joystick.anchor_bottom = 1.0
	joystick.offset_left = 42.0
	joystick.offset_top = -322.0
	joystick.offset_right = 322.0
	joystick.offset_bottom = -42.0
	_safe_root.add_child(joystick)
	_add_action_button("RUN", &"sprint", Rect2(-470, -145, 118, 62))
	_add_action_button("JUMP", &"jump", Rect2(-170, -145, 128, 62))
	_add_action_button("CROUCH", &"crouch", Rect2(-315, -145, 132, 62))
	_add_action_button("REVIVE", &"interact", Rect2(-470, -220, 132, 62))
	_add_action_button("PRONE", &"prone", Rect2(-315, -220, 132, 62))
	_add_action_button("CAM", &"camera_cycle", Rect2(-170, -220, 128, 62))
	_add_action_button("RELOAD", &"reload", Rect2(-315, -295, 132, 62))
	_add_action_button("FIRE", &"fire", Rect2(-170, -365, 128, 128), 22)

func _add_action_button(label_text: String, action: StringName, rect: Rect2, font_size: int = 18) -> void:
	var button := ActionButtonScript.new()
	button.name = "%sButton" % label_text.capitalize()
	button.text = label_text
	button.input_target = _input_target
	button.action_name = action
	button.anchor_left = 1.0
	button.anchor_top = 1.0
	button.anchor_right = 1.0
	button.anchor_bottom = 1.0
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", font_size)
	button.modulate = Color(1.0, 1.0, 1.0, 0.82)
	_safe_root.add_child(button)
