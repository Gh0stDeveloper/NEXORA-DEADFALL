class_name DeadfallMobileHUD
extends CanvasLayer

const SafeAreaScript = preload("res://src/mobile/SafeArea.gd")
const JoystickScript = preload("res://src/mobile/TouchJoystick.gd")
const LookAreaScript = preload("res://src/mobile/TouchLookArea.gd")
const ActionButtonScript = preload("res://src/mobile/TouchActionButton.gd")
const TouchRouterScript = preload("res://src/mobile/TouchInputRouter.gd")

@export var player_path := NodePath("../Player")
@export var show_on_desktop := false

var _safe_root: Control
var _controls_root: Control
var _touch_router: Control
var _player: Node
var _input_target: Node
var _health: Node
var _weapon: Node
var _loadout: Node
var _health_bar: ProgressBar
var _health_label: Label
var _ammo_label: Label
var _weapon_name_label: Label
var _weapon_buttons: Dictionary = {}
var _quick_settings_panel: PanelContainer
var _sensitivity_value_label: Label
var _gameplay_controls_enabled := true

func _ready() -> void:
	bind_player(get_node_or_null(player_path))

func bind_player(player: Node) -> bool:
	if player == null:
		push_warning("MobileHUD could not resolve player")
		return false
	_player = player
	_input_target = player.get_node_or_null("PlayerInput")
	if _input_target == null:
		push_warning("MobileHUD could not resolve PlayerInput")
		return false
	_health = player.get_node_or_null("Health")
	_loadout = player.get_node_or_null("WeaponLoadout")
	_weapon = _loadout.call("get_active_weapon") if _loadout != null and _loadout.has_method("get_active_weapon") else player.get_node_or_null("PrimaryWeapon")
	if _safe_root != null and is_instance_valid(_safe_root):
		_safe_root.queue_free()
	_build_hud()
	_bind_status_sources()
	visible = OS.has_feature("mobile") or show_on_desktop
	return true

func bind_weapon(weapon: Node) -> void:
	if _weapon != null and is_instance_valid(_weapon) and _weapon.has_signal("ammo_changed"):
		var previous_callable := Callable(self, "_on_ammo_changed")
		if _weapon.is_connected("ammo_changed", previous_callable):
			_weapon.disconnect("ammo_changed", previous_callable)
	_weapon = weapon
	if _weapon != null and _weapon.has_signal("ammo_changed"):
		var ammo_callable := Callable(self, "_on_ammo_changed")
		if not _weapon.is_connected("ammo_changed", ammo_callable):
			_weapon.connect("ammo_changed", ammo_callable)
		var in_mag := int(_weapon.call("get_ammo_in_mag")) if _weapon.has_method("get_ammo_in_mag") else 0
		var reserve := int(_weapon.call("get_reserve_ammo")) if _weapon.has_method("get_reserve_ammo") else 0
		_on_ammo_changed(in_mag, reserve)
	else:
		_set_infinite_ammo_display()

func set_gameplay_controls_enabled(enabled: bool) -> void:
	_gameplay_controls_enabled = enabled
	if _controls_root != null:
		_controls_root.visible = enabled
		_controls_root.mouse_filter = Control.MOUSE_FILTER_IGNORE if enabled else Control.MOUSE_FILTER_STOP
	if _touch_router != null and _touch_router.has_method("set_enabled"):
		_touch_router.call("set_enabled", enabled)
	if not enabled and _input_target != null and _input_target.has_method("clear_mobile_actions"):
		_input_target.call("clear_mobile_actions")

func are_gameplay_controls_enabled() -> bool:
	return _gameplay_controls_enabled

func _build_hud() -> void:
	_safe_root = SafeAreaScript.new()
	_safe_root.name = "SafeArea"
	add_child(_safe_root)
	_safe_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_controls_root = Control.new()
	_controls_root.name = "GameplayControls"
	_controls_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_controls_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe_root.add_child(_controls_root)

	_touch_router = TouchRouterScript.new()
	_touch_router.name = "TouchInputRouter"
	_touch_router.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_touch_router.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls_root.add_child(_touch_router)

	var look_area := LookAreaScript.new()
	look_area.name = "LookArea"
	look_area.input_target = _input_target
	look_area.sensitivity_scale = 1.0
	look_area.anchor_left = 0.38
	look_area.anchor_top = 0.0
	look_area.anchor_right = 1.0
	look_area.anchor_bottom = 1.0
	_controls_root.add_child(look_area)

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
	_controls_root.add_child(joystick)
	_touch_router.call("register_joystick", joystick)
	_touch_router.call("register_look_area", look_area)

	_add_action_button(&"sprint", &"sprint", Rect2(326, -154, 92, 92), Vector2(0, 1), &"sprint", Color(0.08, 0.60, 0.66, 1.0), true)
	_add_action_button(&"interact", &"interact", Rect2(-492, -244, 88, 88), Vector2(1, 1), &"interact")
	_add_action_button(&"flashlight", &"flashlight", Rect2(-492, -344, 82, 82), Vector2(1, 1), &"flashlight")
	_add_action_button(&"prone", &"prone", Rect2(-395, -278, 84, 84), Vector2(1, 1), &"prone")
	_add_action_button(&"crouch", &"crouch", Rect2(-397, -174, 90, 90), Vector2(1, 1), &"crouch")
	_add_action_button(&"camera", &"camera_cycle", Rect2(-287, -374, 82, 82), Vector2(1, 1), &"camera")
	_add_action_button(&"jump", &"jump", Rect2(-292, -272, 96, 96), Vector2(1, 1), &"jump", Color(0.10, 0.48, 0.76, 1.0))
	_add_action_button(&"reload", &"reload", Rect2(-176, -286, 86, 86), Vector2(1, 1), &"reload", Color(0.88, 0.45, 0.07, 1.0))
	_add_action_button(&"fire", &"fire", Rect2(-178, -178, 140, 140), Vector2(1, 1), &"fire", Color(0.82, 0.07, 0.09, 1.0))

	_build_player_status()
	_build_weapon_selector()
	_build_quick_settings()
	set_gameplay_controls_enabled(_gameplay_controls_enabled)

func _build_player_status() -> void:
	var panel := PanelContainer.new()
	panel.name = "PlayerStatus"
	panel.anchor_left = 0.34
	panel.anchor_top = 0.018
	panel.anchor_right = 0.66
	panel.anchor_bottom = 0.155
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _status_panel_style())
	_safe_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	var row := HBoxContainer.new()
	vbox.add_child(row)
	_health_label = Label.new()
	_health_label.text = "HP 100 / 100"
	_health_label.add_theme_font_size_override("font_size", 17)
	_health_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_health_label)
	_ammo_label = Label.new()
	_ammo_label.text = "30 / 120"
	_ammo_label.add_theme_font_size_override("font_size", 20)
	_ammo_label.add_theme_color_override("font_color", Color(1.0, 0.79, 0.34))
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_ammo_label)

	_health_bar = ProgressBar.new()
	_health_bar.min_value = 0.0
	_health_bar.max_value = 100.0
	_health_bar.value = 100.0
	_health_bar.show_percentage = false
	_health_bar.custom_minimum_size = Vector2(0, 14)
	_health_bar.add_theme_stylebox_override("background", _bar_style(Color(0.025, 0.035, 0.040, 0.96), Color(0.16, 0.27, 0.29, 0.78)))
	_health_bar.add_theme_stylebox_override("fill", _bar_style(Color(0.09, 0.78, 0.55, 1.0), Color(0.35, 1.0, 0.72, 0.94)))
	vbox.add_child(_health_bar)

	_weapon_name_label = Label.new()
	_weapon_name_label.text = "NXR-4 CARBINE"
	_weapon_name_label.add_theme_font_size_override("font_size", 11)
	_weapon_name_label.add_theme_color_override("font_color", Color(0.54, 0.83, 0.86))
	_weapon_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(_weapon_name_label)

func _build_weapon_selector() -> void:
	if _loadout == null:
		return
	var panel := PanelContainer.new()
	panel.name = "WeaponSelector"
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -188.0
	panel.offset_top = -102.0
	panel.offset_right = 188.0
	panel.offset_bottom = -38.0
	panel.add_theme_stylebox_override("panel", _selector_panel_style())
	_controls_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)
	_weapon_buttons.clear()
	var labels := {0: "RIFLE", 1: "PISTOLA", 2: "MACHETE"}
	for slot in range(3):
		var button := Button.new()
		button.name = "WeaponSlot%d" % slot
		button.text = String(labels[slot])
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(114, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_weapon_button_pressed.bind(slot))
		row.add_child(button)
		_weapon_buttons[slot] = button
	_refresh_weapon_buttons(int(_loadout.get("active_slot")))

func _bind_status_sources() -> void:
	if _health != null and _health.has_signal("health_changed"):
		var health_callable := Callable(self, "_on_health_changed")
		if not _health.is_connected("health_changed", health_callable):
			_health.connect("health_changed", health_callable)
		_on_health_changed(float(_health.get("current_health")), float(_health.get("max_health")), null)
	if _loadout != null and _loadout.has_signal("active_weapon_changed"):
		var loadout_callable := Callable(self, "_on_active_weapon_changed")
		if not _loadout.is_connected("active_weapon_changed", loadout_callable):
			_loadout.connect("active_weapon_changed", loadout_callable)
		var active_slot := int(_loadout.get("active_slot"))
		_on_active_weapon_changed(active_slot, StringName(_loadout.call("get_active_weapon_id")), String(_loadout.call("get_active_display_name")), _loadout.call("get_active_weapon"))
	else:
		bind_weapon(_weapon)

func _on_health_changed(current: float, maximum: float, _event = null) -> void:
	var safe_max := maxf(1.0, maximum)
	var ratio := clampf(current / safe_max, 0.0, 1.0)
	if _health_bar != null:
		_health_bar.max_value = safe_max
		_health_bar.value = clampf(current, 0.0, safe_max)
		var fill := Color(0.09, 0.78, 0.55, 1.0)
		var border := Color(0.35, 1.0, 0.72, 0.94)
		if ratio <= 0.25:
			fill = Color(0.90, 0.07, 0.08, 1.0)
			border = Color(1.0, 0.32, 0.18, 0.96)
		elif ratio <= 0.55:
			fill = Color(0.95, 0.48, 0.08, 1.0)
			border = Color(1.0, 0.72, 0.22, 0.96)
		_health_bar.add_theme_stylebox_override("fill", _bar_style(fill, border))
	if _health_label != null:
		_health_label.text = "HP %d / %d" % [int(round(current)), int(round(safe_max))]

func _on_ammo_changed(in_mag: int, reserve: int) -> void:
	if _ammo_label == null:
		return
	_ammo_label.text = "%02d / %03d" % [maxi(0, in_mag), maxi(0, reserve)]
	if in_mag <= 0:
		_ammo_label.add_theme_color_override("font_color", Color(1.0, 0.22, 0.16))
	elif reserve <= 0:
		_ammo_label.add_theme_color_override("font_color", Color(1.0, 0.52, 0.18))
	else:
		_ammo_label.add_theme_color_override("font_color", Color(1.0, 0.79, 0.34))

func _set_infinite_ammo_display() -> void:
	if _ammo_label != null:
		_ammo_label.text = "∞"
		_ammo_label.add_theme_color_override("font_color", Color(0.65, 0.94, 0.96))

func _on_active_weapon_changed(slot: int, _weapon_id: StringName, display_name: String, weapon: Node) -> void:
	bind_weapon(weapon)
	if _weapon_name_label != null:
		_weapon_name_label.text = display_name.to_upper()
	_refresh_weapon_buttons(slot)

func _on_weapon_button_pressed(slot: int) -> void:
	if _loadout == null or not _gameplay_controls_enabled:
		return
	if _loadout.has_method("request_slot"):
		_loadout.call("request_slot", slot)
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(22)

func _refresh_weapon_buttons(active_slot: int) -> void:
	for slot_value in _weapon_buttons.keys():
		var slot := int(slot_value)
		var button := _weapon_buttons[slot] as Button
		if button == null:
			continue
		var active := slot == active_slot
		button.add_theme_stylebox_override("normal", _weapon_button_style(active, false))
		button.add_theme_stylebox_override("hover", _weapon_button_style(active, true))
		button.add_theme_stylebox_override("pressed", _weapon_button_style(true, true))
		button.add_theme_color_override("font_color", Color.WHITE if active else Color(0.72, 0.80, 0.82))

func _add_action_button(
	control_id: StringName,
	action: StringName,
	rect: Rect2,
	anchor: Vector2,
	icon: StringName,
	accent: Color = Color(0.56, 0.06, 0.08, 1.0),
	toggle_action: bool = false
) -> DeadfallTouchActionButton:
	var button: DeadfallTouchActionButton = ActionButtonScript.new()
	button.name = "%sButton" % String(control_id).capitalize()
	button.input_target = _input_target
	button.action_name = action
	button.icon_name = icon
	button.accent_color = accent
	button.toggle_action = toggle_action
	button.anchor_left = anchor.x
	button.anchor_top = anchor.y
	button.anchor_right = anchor.x
	button.anchor_bottom = anchor.y
	button.offset_left = rect.position.x
	button.offset_top = rect.position.y
	button.offset_right = rect.position.x + rect.size.x
	button.offset_bottom = rect.position.y + rect.size.y
	button.modulate = Color(1.0, 1.0, 1.0, 0.90)
	_apply_saved_layout(button, control_id, rect, anchor)
	_controls_root.add_child(button)
	_touch_router.call("register_action_button", button)
	return button

func _apply_saved_layout(button: Control, control_id: StringName, fallback_rect: Rect2, fallback_anchor: Vector2) -> void:
	if Settings == null or not Settings.has_method("get_hud_element"):
		return
	var fallback := {
		"x": fallback_anchor.x,
		"y": fallback_anchor.y,
		"scale": 1.0,
		"opacity": 0.90,
		"visible": true,
	}
	var stored: Dictionary = Settings.get_hud_element(control_id, fallback)
	if Settings.hud_layout.has(String(control_id)):
		button.anchor_left = float(stored.get("x", fallback_anchor.x))
		button.anchor_top = float(stored.get("y", fallback_anchor.y))
		button.anchor_right = button.anchor_left
		button.anchor_bottom = button.anchor_top
		button.offset_left = -button.size.x * 0.5
		button.offset_top = -button.size.y * 0.5
		button.offset_right = button.size.x * 0.5
		button.offset_bottom = button.size.y * 0.5
	button.scale = Vector2.ONE * float(stored.get("scale", 1.0))
	var color := button.modulate
	color.a = float(stored.get("opacity", 0.90))
	button.modulate = color
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
	settings_button.offset_left = -92.0
	settings_button.offset_top = 210.0
	settings_button.offset_right = -20.0
	settings_button.offset_bottom = 282.0
	settings_button.modulate = Color(1.0, 1.0, 1.0, 0.90)
	_controls_root.add_child(settings_button)
	_touch_router.call("register_action_button", settings_button)
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
	_controls_root.add_child(_quick_settings_panel)

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
	style.bg_color = Color(0.018, 0.030, 0.038, 0.94)
	style.border_color = Color(0.16, 0.66, 0.70, 0.72)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	return style

func _status_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.008, 0.018, 0.024, 0.84)
	style.border_color = Color(0.10, 0.52, 0.58, 0.72)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	return style

func _selector_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.006, 0.018, 0.024, 0.86)
	style.border_color = Color(0.12, 0.52, 0.58, 0.52)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	return style

func _weapon_button_style(active: bool, emphasized: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.67, 0.035, 0.05, 0.96) if active else Color(0.018, 0.055, 0.066, 0.90)
	if emphasized:
		style.bg_color = Color(0.86, 0.045, 0.06, 1.0) if active else Color(0.025, 0.11, 0.13, 0.98)
	style.border_color = Color(1.0, 0.22, 0.18, 0.92) if active else Color(0.20, 0.68, 0.72, 0.50)
	style.set_border_width_all(2 if active else 1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style

func _bar_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style
