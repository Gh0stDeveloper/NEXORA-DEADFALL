class_name DeadfallMobileHUD
extends CanvasLayer

const SafeAreaScript = preload("res://src/mobile/SafeArea.gd")
const JoystickScript = preload("res://src/mobile/TouchJoystick.gd")
const LookAreaScript = preload("res://src/mobile/TouchLookArea.gd")
const ActionButtonScript = preload("res://src/mobile/TouchActionButton.gd")
const TouchRouterScript = preload("res://src/mobile/TouchInputRouter.gd")
const CrosshairScript = preload("res://src/mobile/Crosshair.gd")
const HUDLayoutEditorScript = preload("res://src/mobile/HUDLayoutEditor.gd")

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
var _hud_layout_editor: Control
var _hud_elements: Dictionary = {}
var _hud_defaults: Dictionary = {}
var _gameplay_controls_enabled := true
var _hud_refresh := 0.0
var _leave_dialog: ConfirmationDialog

func _ready() -> void:
	add_to_group("deadfall_mobile_hud")
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
	if not enabled and _hud_layout_editor != null and is_instance_valid(_hud_layout_editor) and _hud_layout_editor.visible:
		_hud_layout_editor.call("close_editor")
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
	_hud_elements.clear()
	_hud_defaults.clear()
	_safe_root = SafeAreaScript.new()
	_safe_root.name = "SafeArea"
	preload("res://src/ui/TacticalTheme.gd").apply(_safe_root)
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
	_register_hud_element(&"move_joystick", joystick)
	_touch_router.call("register_joystick", joystick)
	_touch_router.call("register_look_area", look_area)

	_add_action_button(&"sprint", &"sprint", Rect2(134, -466, 102, 102), Vector2(0, 1), &"sprint", Color(0.08, 0.60, 0.66, 1.0), true)
	_add_action_button(&"interact", &"interact", Rect2(-506, -310, 88, 88), Vector2(1, 1), &"interact")
	_add_action_button(&"flashlight", &"flashlight", Rect2(40, -438, 78, 78), Vector2(0, 1), &"flashlight")
	_add_action_button(&"prone", &"prone", Rect2(-352, -140, 92, 92), Vector2(1, 1), &"prone")
	_add_action_button(&"crouch", &"crouch", Rect2(-182, -155, 100, 100), Vector2(1, 1), &"crouch")
	_add_action_button(&"camera", &"camera_cycle", Rect2(-478, 246, 76, 76), Vector2(1, 0), &"camera")
	_add_action_button(&"jump", &"jump", Rect2(-165, -350, 108, 108), Vector2(1, 1), &"jump", Color(0.10, 0.48, 0.76, 1.0))
	_add_action_button(&"reload", &"reload", Rect2(-360, -480, 88, 88), Vector2(1, 1), &"reload", Color(0.88, 0.45, 0.07, 1.0))
	_add_action_button(&"fire", &"fire", Rect2(-368, -337, 158, 158), Vector2(1, 1), &"fire", Color(0.90, 0.65, 0.22, 1.0))

	_add_action_button(&"aim", &"aim", Rect2(-165, -535, 98, 98), Vector2(1, 1), &"aim", Color("f2bb60"), true)

	_build_player_status()
	_build_weapon_selector()
	_build_crosshair()
	_build_quick_settings()
	_build_hud_editor()
	call_deferred("_finalize_hud_layout")
	set_gameplay_controls_enabled(_gameplay_controls_enabled)

func _build_player_status() -> void:
	var panel := PanelContainer.new()
	panel.name = "PlayerStatus"
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -270.0
	panel.offset_top = -92.0
	panel.offset_right = 270.0
	panel.offset_bottom = -28.0
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
	_health_bar = ProgressBar.new()
	_health_bar.min_value = 0.0
	_health_bar.max_value = 100.0
	_health_bar.value = 100.0
	_health_bar.show_percentage = false
	_health_bar.custom_minimum_size = Vector2(0, 14)
	_health_bar.add_theme_stylebox_override("background", _bar_style(Color(0.025, 0.035, 0.040, 0.96), Color(0.16, 0.27, 0.29, 0.78)))
	_health_bar.add_theme_stylebox_override("fill", _bar_style(Color(0.09, 0.78, 0.55, 1.0), Color(0.35, 1.0, 0.72, 0.94)))
	vbox.add_child(_health_bar)

	_register_hud_element(&"player_status", panel)

func _build_weapon_selector() -> void:
	if _loadout == null:
		return
	var panel := PanelContainer.new()
	panel.name = "WeaponSelector"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -446
	panel.offset_top = 34
	panel.offset_right = -120
	panel.offset_bottom = 228
	panel.add_theme_stylebox_override("panel", _selector_panel_style())
	_controls_root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	_weapon_name_label = Label.new()
	_weapon_name_label.add_theme_font_size_override("font_size", 20)
	_weapon_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_weapon_name_label)
	_ammo_label = Label.new()
	_ammo_label.add_theme_font_size_override("font_size", 34)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_ammo_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	column.add_child(row)
	_weapon_buttons.clear()
	for slot in range(3):
		var button := preload("res://src/mobile/WeaponSlotButton.gd").new()
		button.name = "WeaponSlot%d" % slot
		button.slot = slot
		button.tooltip_text = ["Rifle", "Pistola", "Machete · sin límite"][slot]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(106, 88)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_weapon_button_pressed.bind(slot))
		row.add_child(button)
		_touch_router.call("register_click_control", button)
		_weapon_buttons[slot] = button
	_refresh_weapon_buttons(int(_loadout.get("active_slot")))
	_register_hud_element(&"weapon_selector", panel)

func _process(delta: float) -> void:
	_hud_refresh += delta
	if _hud_refresh < 0.2 or not visible:
		return
	_hud_refresh = 0.0
	if is_instance_valid(_input_target):
		for action in [&"sprint", &"aim"]:
			var button := _hud_elements.get(action) as BaseButton
			if button != null:
				button.set_pressed_no_signal(bool(_input_target.call("is_action_pressed", action)))
	if is_instance_valid(_loadout):
		var state: Dictionary = _loadout.call("get_authoritative_state")
		for slot in _weapon_buttons:
			var button: Button = _weapon_buttons[slot]
			var data: Dictionary = state.get("primary" if slot == 0 else "secondary", {})
			button.set("ammo_text", "∞" if slot == 2 else str(int(data.get("ammo", 0)) + int(data.get("reserve", 0))))
			button.queue_redraw()

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
	_controls_root.add_child(button)
	_register_hud_element(control_id, button)
	_touch_router.call("register_action_button", button)
	return button

func _register_hud_element(element_id: StringName, control: Control) -> void:
	if control == null:
		return
	control.set_meta("deadfall_hud_element_id", String(element_id))
	_hud_elements[element_id] = control

func _finalize_hud_layout() -> void:
	if _safe_root == null or not is_instance_valid(_safe_root):
		return
	for value in _hud_elements.keys():
		var element_id: StringName = StringName(value)
		var control: Control = _hud_elements.get(value) as Control
		if control == null or not is_instance_valid(control):
			continue
		control.pivot_offset = control.size * 0.5
		if not _hud_defaults.has(element_id):
			_hud_defaults[element_id] = _capture_hud_layout(control)
		_apply_saved_hud_layout(element_id, control)
	if _hud_layout_editor != null and is_instance_valid(_hud_layout_editor):
		_hud_layout_editor.call("configure", self, _safe_root, _hud_elements)

func _capture_hud_layout(control: Control) -> Dictionary:
	if control == null or _safe_root == null:
		return {}
	var safe_rect: Rect2 = _safe_root.get_global_rect()
	var control_rect: Rect2 = control.get_global_rect()
	var center: Vector2 = control_rect.position + control_rect.size * 0.5
	var safe_size: Vector2 = safe_rect.size
	var color: Color = control.modulate
	return {
		"x": clampf((center.x - safe_rect.position.x) / maxf(1.0, safe_size.x), 0.0, 1.0),
		"y": clampf((center.y - safe_rect.position.y) / maxf(1.0, safe_size.y), 0.0, 1.0),
		"scale": clampf(float(control.call("get_layout_scale")) if control.has_method("get_layout_scale") else control.scale.x, 0.55, 1.75),
		"opacity": clampf(color.a, 0.15, 1.0),
		"visible": control.visible,
	}

func _apply_saved_hud_layout(element_id: StringName, control: Control) -> void:
	if Settings == null or not Settings.has_method("get_hud_element"):
		return
	if not Settings.hud_layout.has(String(element_id)):
		return
	var fallback: Dictionary = _hud_defaults.get(element_id, _capture_hud_layout(control))
	var stored: Dictionary = Settings.get_hud_element(element_id, fallback)
	_apply_hud_layout(control, stored)

func _apply_hud_layout(control: Control, value: Dictionary) -> void:
	if control == null:
		return
	var normalized_x: float = clampf(float(value.get("x", 0.5)), 0.02, 0.98)
	var normalized_y: float = clampf(float(value.get("y", 0.5)), 0.02, 0.98)
	var size: Vector2 = control.size
	control.anchor_left = normalized_x
	control.anchor_top = normalized_y
	control.anchor_right = normalized_x
	control.anchor_bottom = normalized_y
	control.offset_left = -size.x * 0.5
	control.offset_top = -size.y * 0.5
	control.offset_right = size.x * 0.5
	control.offset_bottom = size.y * 0.5
	control.pivot_offset = size * 0.5
	var layout_scale: float = clampf(float(value.get("scale", 1.0)), 0.55, 1.75)
	if control.has_method("set_layout_scale"):
		control.call("set_layout_scale", layout_scale)
	else:
		control.scale = Vector2.ONE * layout_scale
	var color: Color = control.modulate
	color.a = clampf(float(value.get("opacity", color.a)), 0.15, 1.0)
	control.modulate = color
	control.visible = bool(value.get("visible", true))

func _set_hud_element_center(element_id: StringName, normalized_x: float, normalized_y: float) -> void:
	var control: Control = _hud_elements.get(element_id) as Control
	if control == null:
		return
	var value: Dictionary = _capture_hud_layout(control)
	value["x"] = clampf(normalized_x, 0.02, 0.98)
	value["y"] = clampf(normalized_y, 0.02, 0.98)
	_apply_hud_layout(control, value)

func move_hud_element(element_id: StringName, delta: Vector2) -> void:
	var control: Control = _hud_elements.get(element_id) as Control
	if control == null or _safe_root == null:
		return
	var safe_rect: Rect2 = _safe_root.get_global_rect()
	var control_rect: Rect2 = control.get_global_rect()
	var half_size: Vector2 = control_rect.size * 0.5
	var center: Vector2 = control_rect.position + half_size + delta
	var safe_end: Vector2 = safe_rect.position + safe_rect.size
	var min_center: Vector2 = safe_rect.position + Vector2(maxf(16.0, half_size.x * 0.55), maxf(16.0, half_size.y * 0.55))
	var max_center: Vector2 = safe_end - Vector2(maxf(16.0, half_size.x * 0.55), maxf(16.0, half_size.y * 0.55))
	center.x = clampf(center.x, min_center.x, max_center.x)
	center.y = clampf(center.y, min_center.y, max_center.y)
	var normalized_x: float = (center.x - safe_rect.position.x) / maxf(1.0, safe_rect.size.x)
	var normalized_y: float = (center.y - safe_rect.position.y) / maxf(1.0, safe_rect.size.y)
	_set_hud_element_center(element_id, normalized_x, normalized_y)
	_save_hud_element(element_id)

func resize_hud_element(element_id: StringName, amount: float) -> void:
	var control: Control = _hud_elements.get(element_id) as Control
	if control == null:
		return
	var current_scale: float = float(control.call("get_layout_scale")) if control.has_method("get_layout_scale") else control.scale.x
	var next_scale: float = clampf(current_scale + amount, 0.55, 1.75)
	if control.has_method("set_layout_scale"):
		control.call("set_layout_scale", next_scale)
	else:
		control.scale = Vector2.ONE * next_scale
	control.pivot_offset = control.size * 0.5
	_save_hud_element(element_id)

func get_hud_element_scale(element_id: StringName) -> float:
	var control: Control = _hud_elements.get(element_id) as Control
	if control == null:
		return 1.0
	return float(control.call("get_layout_scale")) if control.has_method("get_layout_scale") else control.scale.x

func save_hud_layout() -> void:
	for value in _hud_elements.keys():
		var element_id: StringName = StringName(value)
		_save_hud_element(element_id)
	if Settings != null and Settings.has_method("save_configuration"):
		Settings.call("save_configuration")

func _save_hud_element(element_id: StringName) -> void:
	if Settings == null or not Settings.has_method("set_hud_element"):
		return
	var control: Control = _hud_elements.get(element_id) as Control
	if control == null:
		return
	Settings.set_hud_element(element_id, _capture_hud_layout(control))

func reset_hud_layout_to_defaults() -> void:
	if Settings != null and Settings.has_method("reset_hud_layout"):
		Settings.call("reset_hud_layout")
	for value in _hud_elements.keys():
		var element_id: StringName = StringName(value)
		var control: Control = _hud_elements.get(value) as Control
		var fallback: Dictionary = _hud_defaults.get(element_id, {})
		if control != null and not fallback.is_empty():
			_apply_hud_layout(control, fallback)
	if _hud_layout_editor != null and is_instance_valid(_hud_layout_editor):
		_hud_layout_editor.call("configure", self, _safe_root, _hud_elements)

func _build_crosshair() -> void:
	var crosshair: Control = CrosshairScript.new()
	crosshair.name = "Crosshair"
	crosshair.anchor_left = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -24.0
	crosshair.offset_top = -24.0
	crosshair.offset_right = 24.0
	crosshair.offset_bottom = 24.0
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe_root.add_child(crosshair)
	_register_hud_element(&"crosshair", crosshair)

func _build_hud_editor() -> void:
	_hud_layout_editor = HUDLayoutEditorScript.new()
	_hud_layout_editor.name = "HUDLayoutEditor"
	_safe_root.add_child(_hud_layout_editor)
	if _hud_layout_editor.has_signal("close_requested"):
		_hud_layout_editor.connect("close_requested", Callable(self, "_on_hud_editor_closed"))
	_hud_layout_editor.call("configure", self, _safe_root, _hud_elements)

func _open_hud_editor() -> void:
	if _input_target != null:
		_input_target.call("clear_mobile_actions")
	if _quick_settings_panel != null:
		_quick_settings_panel.visible = false
	if _hud_layout_editor == null or not is_instance_valid(_hud_layout_editor):
		return
	if _touch_router != null and _touch_router.has_method("set_enabled"):
		_touch_router.call("set_enabled", false)
	if _hud_layout_editor.has_method("open_editor"):
		_hud_layout_editor.call("open_editor")

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
	settings_button.offset_top = 30.0
	settings_button.offset_right = -20.0
	settings_button.offset_bottom = 102.0
	settings_button.modulate = Color(1.0, 1.0, 1.0, 0.90)
	_controls_root.add_child(settings_button)
	_register_hud_element(&"settings", settings_button)
	_touch_router.call("register_action_button", settings_button)
	settings_button.pressed.connect(_toggle_quick_settings)
	var exit_button := Button.new()
	exit_button.name = "ExitMatchButton"
	exit_button.text = "SALIR"
	exit_button.focus_mode = Control.FOCUS_NONE
	exit_button.add_theme_font_size_override("font_size", 20)
	exit_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	exit_button.offset_left = -104
	exit_button.offset_right = -16
	exit_button.offset_top = 118
	exit_button.offset_bottom = 174
	_safe_root.add_child(exit_button)
	_touch_router.call("register_passthrough_control", exit_button)
	exit_button.pressed.connect(request_leave_confirmation)

	_quick_settings_panel = PanelContainer.new()
	_quick_settings_panel.name = "QuickSensitivityPanel"
	_quick_settings_panel.anchor_left = 0.5
	_quick_settings_panel.anchor_top = 0.0
	_quick_settings_panel.anchor_right = 0.5
	_quick_settings_panel.anchor_bottom = 0.0
	_quick_settings_panel.offset_left = -270.0
	_quick_settings_panel.offset_top = 82.0
	_quick_settings_panel.offset_right = 270.0
	_quick_settings_panel.offset_bottom = 300.0
	_quick_settings_panel.visible = false
	_quick_settings_panel.add_theme_stylebox_override("panel", _panel_style())
	_controls_root.add_child(_quick_settings_panel)
	_touch_router.call("register_passthrough_control", _quick_settings_panel)

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
	title.text = "PARTIDA · SENSIBILIDAD"
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

	var editor_button := Button.new()
	editor_button.name = "EditHudButton"
	editor_button.text = "EDITAR HUD Y GUARDAR"
	editor_button.focus_mode = Control.FOCUS_NONE
	editor_button.custom_minimum_size = Vector2(0, 42)
	vbox.add_child(editor_button)
	_touch_router.call("register_click_control", editor_button)
	editor_button.pressed.connect(_open_hud_editor)

	var leave := Button.new()
	leave.name = "LeaveMatchButton"
	leave.text = "ABANDONAR PARTIDA"
	leave.custom_minimum_size.y = 58
	vbox.add_child(leave)
	_touch_router.call("register_click_control", leave)
	leave.pressed.connect(request_leave_confirmation)
	var resume := Button.new()
	resume.text = "CONTINUAR"
	resume.custom_minimum_size.y = 48
	vbox.add_child(resume)
	_touch_router.call("register_click_control", resume)
	resume.pressed.connect(_toggle_quick_settings)

	var persistence_hint := Label.new()
	persistence_hint.text = "Sensibilidad y HUD se guardan en este dispositivo."
	persistence_hint.add_theme_font_size_override("font_size", 12)
	persistence_hint.add_theme_color_override("font_color", Color(0.62, 0.75, 0.77))
	vbox.add_child(persistence_hint)

func _toggle_quick_settings() -> void:
	if is_instance_valid(_input_target):
		_input_target.call("clear_mobile_actions")
	if _quick_settings_panel != null:
		_quick_settings_panel.visible = not _quick_settings_panel.visible

func _on_sensitivity_changed(value: float) -> void:
	if Settings != null and Settings.has_method("set_camera_sensitivity"):
		Settings.set_camera_sensitivity(value)
	_update_sensitivity_label(value)

func _on_hud_editor_closed() -> void:
	if _touch_router != null and _touch_router.has_method("set_enabled"):
		_touch_router.call("set_enabled", _gameplay_controls_enabled)

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
	style.bg_color = Color(0.30, 0.23, 0.11, 0.90) if active else Color(0.018, 0.055, 0.066, 0.90)
	if emphasized:
		style.bg_color = Color(0.86, 0.045, 0.06, 1.0) if active else Color(0.025, 0.11, 0.13, 0.98)
	style.border_color = Color("f2bb60") if active else Color(0.20, 0.68, 0.72, 0.50)
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

func request_leave_confirmation() -> void:
	if _input_target != null:
		_input_target.call("clear_mobile_actions")
	_touch_router.call("set_enabled", false)
	if not is_instance_valid(_leave_dialog):
		_leave_dialog = ConfirmationDialog.new()
		_leave_dialog.title = "ABANDONAR PARTIDA"
		_leave_dialog.dialog_text = "¿Volver al lobby? Tu personaje abandonará esta partida."
		_leave_dialog.ok_button_text = "ABANDONAR"
		_leave_dialog.cancel_button_text = "CONTINUAR JUGANDO"
		_safe_root.add_child(_leave_dialog)
		_leave_dialog.theme = _safe_root.theme
		_leave_dialog.confirmed.connect(_confirm_leave)
		_leave_dialog.canceled.connect(func() -> void: _touch_router.call("set_enabled", _gameplay_controls_enabled))
	_leave_dialog.popup_centered(Vector2i(680, 220))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _confirm_leave() -> void:
	var flow := get_tree().get_first_node_in_group("deadfall_match_flow")
	if flow != null:
		flow.call_deferred("leave_current_match")
