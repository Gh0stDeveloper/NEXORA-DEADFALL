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
var _quick_settings_panel: PanelContainer
var _sensitivity_value_label: Label

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
	look_area.sensitivity_scale = 1.0
	look_area.anchor_left = 0.38
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

	# Thumb-first layout: locomotion helpers remain close to the left joystick,
	# while combat/camera actions form a spaced arc around the right thumb.
	_add_action_button(&"sprint", &"sprint", Rect2(326, -154, 92, 92), Vector2(0, 1), &"sprint")
	_add_action_button(&"interact", &"interact", Rect2(-492, -244, 88, 88), Vector2(1, 1), &"interact")
	_add_action_button(&"prone", &"prone", Rect2(-395, -278, 84, 84), Vector2(1, 1), &"prone")
	_add_action_button(&"crouch", &"crouch", Rect2(-397, -174, 90, 90), Vector2(1, 1), &"crouch")
	_add_action_button(&"camera", &"camera_cycle", Rect2(-287, -374, 82, 82), Vector2(1, 1), &"camera")
	_add_action_button(&"jump", &"jump", Rect2(-292, -272, 96, 96), Vector2(1, 1), &"jump")
	_add_action_button(&"reload", &"reload", Rect2(-176, -286, 86, 86), Vector2(1, 1), &"reload")
	_add_action_button(&"fire", &"fire", Rect2(-178, -178, 140, 140), Vector2(1, 1), &"fire", Color(0.82, 0.07, 0.09, 1.0))

	_build_quick_settings()

func _add_action_button(
	control_id: StringName,
	action: StringName,
	rect: Rect2,
	anchor: Vector2,
	icon: StringName,
	accent: Color = Color(0.56, 0.06, 0.08, 1.0)
) -> DeadfallTouchActionButton:
	var button: DeadfallTouchActionButton = ActionButtonScript.new()
	button.name = "%sButton" % String(control_id).capitalize()
	button.input_target = _input_target
	button.action_name = action
	button.icon_name = icon
	button.accent_color = accent
	button.anchor_left = anchor.x
	button.anchor_top = anchor.y
	button.anchor_right = anchor.x
	button.anchor_bottom = anchor.y
	button.position = rect.position
	button.size = rect.size
	button.modulate = Color(1.0, 1.0, 1.0, 0.86)
	_apply_saved_layout(button, control_id, rect, anchor)
	_safe_root.add_child(button)
	return button

func _apply_saved_layout(button: Control, control_id: StringName, fallback_rect: Rect2, fallback_anchor: Vector2) -> void:
	if Settings == null or not Settings.has_method("get_hud_element"):
		return
	var fallback := {
		"x": fallback_anchor.x,
		"y": fallback_anchor.y,
		"scale": 1.0,
		"opacity": 0.86,
		"visible": true,
	}
	var stored: Dictionary = Settings.get_hud_element(control_id, fallback)
	# Phase 11's editor stores normalized anchors. Existing defaults still use
	# pixel offsets so the initial layout remains deterministic across devices.
	if Settings.hud_layout.has(String(control_id)):
		button.anchor_left = float(stored.get("x", fallback_anchor.x))
		button.anchor_top = float(stored.get("y", fallback_anchor.y))
		button.anchor_right = button.anchor_left
		button.anchor_bottom = button.anchor_top
		button.position = -button.size * 0.5
	button.scale = Vector2.ONE * float(stored.get("scale", 1.0))
	button.modulate.a = float(stored.get("opacity", 0.86))
	button.visible = bool(stored.get("visible", true))

func _build_quick_settings() -> void:
	var settings_button: DeadfallTouchActionButton = ActionButtonScript.new()
	settings_button.name = "QuickSettingsButton"
	settings_button.icon_name = &"settings"
	settings_button.action_name = &""
	settings_button.input_target = null
	settings_button.anchor_left = 1.0
	settings_button.anchor_top = 0.0
	settings_button.anchor_right = 1.0
	settings_button.anchor_bottom = 0.0
	settings_button.position = Vector2(-92, 210)
	settings_button.size = Vector2(72, 72)
	settings_button.modulate = Color(1.0, 1.0, 1.0, 0.88)
	_safe_root.add_child(settings_button)
	settings_button.pressed.connect(_toggle_quick_settings)

	_quick_settings_panel = PanelContainer.new()
	_quick_settings_panel.name = "QuickSensitivityPanel"
	_quick_settings_panel.anchor_left = 0.5
	_quick_settings_panel.anchor_top = 0.0
	_quick_settings_panel.anchor_right = 0.5
	_quick_settings_panel.anchor_bottom = 0.0
	_quick_settings_panel.offset_left = -270.0
	_quick_settings_panel.offset_top = 82.0
	_quick_settings_panel.offset_right = 270.0
	_quick_settings_panel.offset_bottom = 218.0
	_quick_settings_panel.visible = false
	_quick_settings_panel.add_theme_stylebox_override("panel", _panel_style())
	_safe_root.add_child(_quick_settings_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_quick_settings_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "SENSIBILIDAD"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_sensitivity_value_label = Label.new()
	_sensitivity_value_label.add_theme_font_size_override("font_size", 20)
	header.add_child(_sensitivity_value_label)

	var slider := HSlider.new()
	slider.name = "CameraSensitivity"
	slider.min_value = Settings.CAMERA_SENSITIVITY_MIN
	slider.max_value = Settings.CAMERA_SENSITIVITY_MAX
	slider.step = 0.05
	slider.value = Settings.camera_sensitivity
	slider.custom_minimum_size = Vector2(460, 40)
	vbox.add_child(slider)
	slider.value_changed.connect(_on_sensitivity_changed)
	_update_sensitivity_label(float(slider.value))

func _toggle_quick_settings() -> void:
	if _quick_settings_panel != null:
		_quick_settings_panel.visible = not _quick_settings_panel.visible

func _on_sensitivity_changed(value: float) -> void:
	Settings.set_camera_sensitivity(value)
	_update_sensitivity_label(value)

func _update_sensitivity_label(value: float) -> void:
	if _sensitivity_value_label != null:
		_sensitivity_value_label.text = "%.2f" % value

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.022, 0.028, 0.92)
	style.border_color = Color(0.72, 0.08, 0.10, 0.70)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	return style
