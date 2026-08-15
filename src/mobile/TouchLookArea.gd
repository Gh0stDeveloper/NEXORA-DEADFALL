class_name DeadfallTouchLookArea
extends Control

@export var sensitivity_scale := 0.85

var input_target: Node
var _touch_index := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			accept_event()
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			accept_event()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		if input_target != null and input_target.has_method("add_mobile_look"):
			input_target.add_mobile_look(event.screen_relative * sensitivity_scale)
		accept_event()
