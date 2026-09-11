class_name DeadfallTouchLookArea
extends Control

@export var sensitivity_scale := 0.85

var input_target: Node
var _touch_index := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if router_touch_down(event.index):
				accept_event()
		elif router_touch_up(event.index):
			accept_event()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		var delta := event.screen_relative
		if delta.is_zero_approx():
			delta = event.relative
		router_touch_drag(event.index, delta)
		accept_event()

func router_touch_down(index: int) -> bool:
	if _touch_index != -1:
		return false
	_touch_index = index
	return true

func router_touch_drag(index: int, delta: Vector2) -> bool:
	if index != _touch_index:
		return false
	if input_target != null and input_target.has_method("add_mobile_look"):
		input_target.add_mobile_look(delta * sensitivity_scale)
	return true

func router_touch_up(index: int) -> bool:
	if index != _touch_index:
		return false
	_touch_index = -1
	return true
