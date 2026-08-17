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

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle_mode = toggle_action
	pivot_offset = size * 0.5
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

func is_latched() -> bool:
	return toggle_action and button_pressed

func _exit_tree() -> void:
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
	_feedback_tween.tween_property(self, "scale", Vector2(0.88, 0.88), 0.055)
	_feedback_tween.parallel().tween_property(self, "rotation", deg_to_rad(-2.0), 0.055)

func _play_release_feedback() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_tween = create_tween()
	_feedback_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(self, "scale", Vector2.ONE, 0.13)
	_feedback_tween.parallel().tween_property(self, "rotation", 0.0, 0.13)
	_feedback_tween.finished.connect(_refresh_rest_visual)

func _refresh_rest_visual() -> void:
	if toggle_action and button_pressed:
		modulate = Color(1.0, 0.96, 0.96, 1.0)
	else:
		modulate = Color.WHITE
	queue_redraw()

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
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.22
	var width := maxf(2.4, minf(size.x, size.y) * 0.025)
	if toggle_action and button_pressed:
		draw_arc(center, minf(size.x, size.y) * 0.40, 0.0, TAU, 40, Color(accent_color.r, accent_color.g, accent_color.b, 0.92), maxf(3.0, width * 1.15), true)
	match icon_name:
		&"fire":
			draw_arc(center, radius, 0.0, TAU, 32, icon_color, width, true)
			draw_circle(center, radius * 0.24, icon_color)
			draw_line(center + Vector2(-radius * 1.45, 0), center + Vector2(-radius * 0.72, 0), icon_color, width, true)
			draw_line(center + Vector2(radius * 0.72, 0), center + Vector2(radius * 1.45, 0), icon_color, width, true)
			draw_line(center + Vector2(0, -radius * 1.45), center + Vector2(0, -radius * 0.72), icon_color, width, true)
			draw_line(center + Vector2(0, radius * 0.72), center + Vector2(0, radius * 1.45), icon_color, width, true)
		&"jump":
			draw_line(center + Vector2(-radius, radius * 0.50), center + Vector2(0, -radius * 0.75), icon_color, width, true)
			draw_line(center + Vector2(0, -radius * 0.75), center + Vector2(radius, radius * 0.50), icon_color, width, true)
			draw_line(center + Vector2(-radius, radius), center + Vector2(radius, radius), icon_color, width, true)
		&"crouch":
			draw_circle(center + Vector2(-radius * 0.45, -radius * 0.65), radius * 0.26, icon_color)
			draw_line(center + Vector2(-radius * 0.30, -radius * 0.32), center + Vector2(radius * 0.20, radius * 0.10), icon_color, width, true)
			draw_line(center + Vector2(radius * 0.20, radius * 0.10), center + Vector2(radius * 0.90, radius * 0.10), icon_color, width, true)
			draw_line(center + Vector2(radius * 0.15, radius * 0.15), center + Vector2(-radius * 0.40, radius * 0.90), icon_color, width, true)
			draw_line(center + Vector2(radius * 0.15, radius * 0.15), center + Vector2(radius * 0.65, radius * 0.90), icon_color, width, true)
		&"prone":
			draw_circle(center + Vector2(-radius * 0.95, 0), radius * 0.25, icon_color)
			draw_line(center + Vector2(-radius * 0.55, 0), center + Vector2(radius * 0.75, radius * 0.15), icon_color, width, true)
			draw_line(center + Vector2(radius * 0.10, radius * 0.10), center + Vector2(radius, radius * 0.70), icon_color, width, true)
			draw_line(center + Vector2(-radius * 1.20, radius), center + Vector2(radius * 1.20, radius), icon_color, width, true)
		&"sprint":
			draw_line(center + Vector2(-radius * 0.75, radius * 0.80), center + Vector2(radius * 0.15, -radius * 0.20), icon_color, width, true)
			draw_line(center + Vector2(radius * 0.15, -radius * 0.20), center + Vector2(radius * 0.95, -radius * 0.55), icon_color, width, true)
			draw_line(center + Vector2(radius * 0.15, -radius * 0.20), center + Vector2(radius * 0.85, radius * 0.80), icon_color, width, true)
			draw_circle(center + Vector2(-radius * 0.15, -radius * 0.85), radius * 0.25, icon_color)
		&"reload":
			draw_arc(center, radius, deg_to_rad(-55.0), deg_to_rad(245.0), 24, icon_color, width, true)
			draw_line(center + Vector2(-radius * 0.95, -radius * 0.15), center + Vector2(-radius * 0.95, -radius * 0.85), icon_color, width, true)
			draw_line(center + Vector2(-radius * 0.95, -radius * 0.85), center + Vector2(-radius * 0.30, -radius * 0.75), icon_color, width, true)
		&"camera":
			draw_rect(Rect2(center - Vector2(radius, radius * 0.65), Vector2(radius * 2.0, radius * 1.3)), icon_color, false, width, true)
			draw_circle(center, radius * 0.42, icon_color, false, width, true)
			draw_line(center + Vector2(-radius * 0.55, -radius * 0.68), center + Vector2(-radius * 0.20, -radius), icon_color, width, true)
			draw_line(center + Vector2(-radius * 0.20, -radius), center + Vector2(radius * 0.22, -radius), icon_color, width, true)
		&"interact":
			draw_rect(Rect2(center - Vector2(radius * 0.85, radius * 0.75), Vector2(radius * 1.7, radius * 1.5)), icon_color, false, width, true)
			draw_line(center + Vector2(-radius * 0.45, 0), center + Vector2(radius * 0.45, 0), icon_color, width, true)
			draw_line(center + Vector2(radius * 0.45, 0), center + Vector2(radius * 0.10, -radius * 0.35), icon_color, width, true)
			draw_line(center + Vector2(radius * 0.45, 0), center + Vector2(radius * 0.10, radius * 0.35), icon_color, width, true)
		&"settings":
			draw_arc(center, radius * 0.90, 0.0, TAU, 24, icon_color, width, true)
			draw_circle(center, radius * 0.30, icon_color, false, width, true)
			for angle in range(0, 360, 45):
				var direction := Vector2.RIGHT.rotated(deg_to_rad(float(angle)))
				draw_line(center + direction * radius * 0.92, center + direction * radius * 1.28, icon_color, width, true)
		&"flashlight":
			draw_rect(Rect2(center + Vector2(-radius * 0.65, -radius * 0.32), Vector2(radius * 0.90, radius * 0.64)), icon_color, false, width, true)
			draw_line(center + Vector2(radius * 0.25, -radius * 0.55), center + Vector2(radius * 0.90, -radius), icon_color, width, true)
			draw_line(center + Vector2(radius * 0.25, radius * 0.55), center + Vector2(radius * 0.90, radius), icon_color, width, true)
			draw_line(center + Vector2(radius * 0.90, -radius), center + Vector2(radius * 0.90, radius), icon_color, width, true)
		_:
			draw_circle(center, radius, icon_color, false, width, true)
