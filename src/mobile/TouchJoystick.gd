class_name DeadfallTouchJoystick
extends Control

@export var radius := 118.0
@export var knob_radius := 42.0

var input_target: Node
var _touch_index := -1
var _value := Vector2.ZERO
var _center := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_center = size * 0.5
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_center = size * 0.5
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _begin_touch_local(event.index, event.position):
				accept_event()
		elif _end_touch(event.index):
			accept_event()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_value(event.position)
		accept_event()

func router_touch_down(index: int, screen_position: Vector2) -> bool:
	if _touch_index != -1:
		return false
	_touch_index = index
	_update_value(_screen_to_local(screen_position))
	return true

func router_touch_drag(index: int, screen_position: Vector2) -> bool:
	if index != _touch_index:
		return false
	_update_value(_screen_to_local(screen_position))
	return true

func router_touch_up(index: int) -> bool:
	return _end_touch(index)

func _begin_touch_local(index: int, local_position: Vector2) -> bool:
	if _touch_index != -1:
		return false
	_touch_index = index
	_update_value(local_position)
	return true

func _end_touch(index: int) -> bool:
	if index != _touch_index:
		return false
	_touch_index = -1
	_value = Vector2.ZERO
	_push_value()
	queue_redraw()
	return true

func _update_value(local_position: Vector2) -> void:
	var delta := local_position - _center
	_value = (delta / maxf(1.0, radius)).limit_length(1.0)
	_push_value()
	queue_redraw()

func _screen_to_local(screen_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_position

func _push_value() -> void:
	if input_target != null and input_target.has_method("set_mobile_move"):
		input_target.set_mobile_move(_value)

func _draw() -> void:
	draw_circle(_center, radius, Color(0.08, 0.08, 0.1, 0.34))
	draw_arc(_center, radius, 0.0, TAU, 48, Color(0.82, 0.84, 0.88, 0.5), 3.0)
	draw_circle(_center + _value * radius, knob_radius, Color(0.82, 0.84, 0.88, 0.55))
