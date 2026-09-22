class_name DeadfallTouchActionButton
extends Button

var input_target: Node
var action_name: StringName
var icon_name: StringName = &"action"
var accent_color := Color(0.78, 0.08, 0.10, 1.0)
var icon_color := Color(0.96, 0.97, 0.98, 0.96)
var toggle_action := false
var haptic_feedback := true

var _feedback_tween: Tween
var _layout_scale := 1.0
var _router_touch_index := -1
var _router_toggle_guard := false

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	text = ""
	mouse_filter = Control.MOUSE_FILTER_IGNORE if _mobile_runtime() else Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle_mode = toggle_action
	pivot_offset = size * 0.5
	_layout_scale = clampf(scale.x, 0.55, 1.75)
	_apply_theme()
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	if toggle_action:
		toggled.connect(_on_toggled)
	queue_redraw()

func configure(icon: StringName, action: StringName, target: Node) -> void:
	icon_name = icon
	action_name = action
	input_target = target
	queue_redraw()

func set_latched(active: bool) -> void:
	if not toggle_action:
		return
	button_pressed = active
	_apply_mobile_action(active)
	_refresh_rest_visual()

func set_layout_scale(value: float) -> void:
	_layout_scale = clampf(value, 0.55, 1.75)
	scale = Vector2.ONE * _layout_scale

func get_layout_scale() -> float:
	return _layout_scale

func is_latched() -> bool:
	return toggle_action and button_pressed

func router_touch_down(index: int) -> bool:
	if _router_touch_index != -1:
		return false
	_router_touch_index = index
	_play_press_feedback()
	if toggle_action:
		_router_toggle_guard = true
		button_pressed = not button_pressed
		_router_toggle_guard = false
		_apply_mobile_action(button_pressed)
		if haptic_feedback and OS.has_feature("mobile"):
			Input.vibrate_handheld(28 if button_pressed else 16)
		_refresh_rest_visual()
	else:
		_apply_mobile_action(true)
	return true

func router_touch_drag(_index: int, _screen_position: Vector2) -> bool:
	return true

func router_touch_up(index: int) -> bool:
	if index != _router_touch_index:
		return false
	_router_touch_index = -1
	if not toggle_action:
		_apply_mobile_action(false)
		_play_release_feedback()
		if action_name.is_empty():
			emit_signal("pressed")
	else:
		_play_release_feedback()
	return true

func router_touch_cancel() -> void:
	if _router_touch_index != -1:
		router_touch_up(_router_touch_index)

func _exit_tree() -> void:
	_router_touch_index = -1
	if not action_name.is_empty() and input_target != null and input_target.has_method("set_mobile_action"):
		input_target.set_mobile_action(action_name, false)

func _on_button_down() -> void:
	_play_press_feedback()
	if not toggle_action:
		_apply_mobile_action(true)

func _on_button_up() -> void:
	if not toggle_action:
		_apply_mobile_action(false)
	_play_release_feedback()

func _on_toggled(active: bool) -> void:
	if _router_toggle_guard:
		return
	_apply_mobile_action(active)
	if haptic_feedback and OS.has_feature("mobile"):
		Input.vibrate_handheld(28 if active else 16)
	_refresh_rest_visual()

func _apply_mobile_action(active: bool) -> void:
	if action_name.is_empty() or input_target == null or not input_target.has_method("set_mobile_action"):
		return
	input_target.set_mobile_action(action_name, active)

func _play_press_feedback() -> void:
	if haptic_feedback and OS.has_feature("mobile") and not toggle_action:
		Input.vibrate_handheld(14)
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_tween = create_tween()
	_feedback_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(self, "scale", Vector2.ONE * _layout_scale * 0.88, 0.055)
	_feedback_tween.parallel().tween_property(self, "rotation", deg_to_rad(-2.0), 0.055)

func _play_release_feedback() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_tween = create_tween()
	_feedback_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(self, "scale", Vector2.ONE * _layout_scale, 0.13)
	_feedback_tween.parallel().tween_property(self, "rotation", 0.0, 0.13)
	_feedback_tween.finished.connect(_refresh_rest_visual)

func _refresh_rest_visual() -> void:
	var alpha: float = clampf(modulate.a, 0.15, 1.0)
	if toggle_action and button_pressed:
		modulate = Color(1.0, 0.96, 0.96, alpha)
	else:
		modulate = Color(1.0, 1.0, 1.0, alpha)
	queue_redraw()

func _mobile_runtime() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")

func _apply_theme() -> void:
	add_theme_stylebox_override("normal", _circle_style(Color(0.018, 0.028, 0.036, 0.64), Color(0.55, 0.78, 0.82, 0.38), 2))
	add_theme_stylebox_override("hover", _circle_style(Color(0.035, 0.065, 0.074, 0.78), Color(0.72, 0.92, 0.94, 0.60), 2))
	add_theme_stylebox_override("pressed", _circle_style(Color(accent_color.r, accent_color.g, accent_color.b, 0.88), Color(1.0, 0.72, 0.60, 0.94), 3))
	add_theme_stylebox_override("disabled", _circle_style(Color(0.018, 0.022, 0.026, 0.32), Color(0.35, 0.38, 0.40, 0.25), 1))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _circle_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 999
	style.corner_radius_top_right = 999
	style.corner_radius_bottom_left = 999
	style.corner_radius_bottom_right = 999
	style.anti_aliasing = true
	return style

func _draw() -> void:
	if toggle_action and button_pressed:
		draw_arc(size * 0.5, minf(size.x, size.y) * 0.43, 0.0, TAU, 48, Color("f2bb60"), 4.0, true)
	preload("res://src/mobile/HUDIcons.gd").draw_icon(self, icon_name, Rect2(size * 0.18, size * 0.64), icon_color)
