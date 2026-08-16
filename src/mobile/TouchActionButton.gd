class_name DeadfallTouchActionButton
extends Button

var input_target: Node
var action_name: StringName
var icon_name: StringName = &"action"
var accent_color := Color(0.78, 0.08, 0.10, 1.0)
var icon_color := Color(0.96, 0.97, 0.98, 0.96)

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_theme()
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	queue_redraw()

func configure(icon: StringName, action: StringName, target: Node) -> void:
	icon_name = icon
	action_name = action
	input_target = target
	queue_redraw()

func _exit_tree() -> void:
	if not action_name.is_empty() and input_target != null and input_target.has_method("set_mobile_action"):
		input_target.set_mobile_action(action_name, false)

func _on_button_down() -> void:
	scale = Vector2(0.92, 0.92)
	pivot_offset = size * 0.5
	modulate = Color(1.0, 1.0, 1.0, 0.92)
	if not action_name.is_empty() and input_target != null and input_target.has_method("set_mobile_action"):
		input_target.set_mobile_action(action_name, true)

func _on_button_up() -> void:
	scale = Vector2.ONE
	modulate = Color.WHITE
	if not action_name.is_empty() and input_target != null and input_target.has_method("set_mobile_action"):
		input_target.set_mobile_action(action_name, false)

func _apply_theme() -> void:
	add_theme_stylebox_override("normal", _circle_style(Color(0.025, 0.030, 0.035, 0.48), Color(1.0, 1.0, 1.0, 0.28), 2))
	add_theme_stylebox_override("hover", _circle_style(Color(0.04, 0.045, 0.05, 0.62), Color(1.0, 1.0, 1.0, 0.42), 2))
	add_theme_stylebox_override("pressed", _circle_style(Color(accent_color.r, accent_color.g, accent_color.b, 0.76), Color(1.0, 1.0, 1.0, 0.72), 3))
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
