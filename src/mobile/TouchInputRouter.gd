class_name DeadfallTouchInputRouter
extends Control

var enabled := true

var _joystick: Node
var _look_area: Node
var _action_buttons: Array[Node] = []
var _click_controls: Array[Node] = []
var _passthrough_controls: Array[Node] = []
var _touch_routes: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_release_all_touches()

func register_joystick(value: Node) -> void:
	_joystick = value

func register_look_area(value: Node) -> void:
	_look_area = value

func register_action_button(value: Node) -> void:
	if value == null or value in _action_buttons:
		return
	_action_buttons.append(value)

func register_click_control(value: Node) -> void:
	if value == null or value in _click_controls:
		return
	_click_controls.append(value)

func register_passthrough_control(value: Node) -> void:
	if value == null or value in _passthrough_controls:
		return
	_passthrough_controls.append(value)

func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_touch(event.index, event.position)
		else:
			_end_touch(event.index)
	elif event is InputEventScreenDrag:
		_drag_touch(event.index, event.position, _screen_delta(event))

func _begin_touch(index: int, screen_position: Vector2) -> void:
	if _touch_routes.has(index):
		return
	var action_button := _find_action_button(screen_position)
	if action_button != null:
		if action_button.has_method("router_touch_down"):
			var accepted := bool(action_button.call("router_touch_down", index))
			_consume()
			if accepted:
				_touch_routes[index] = {"kind": "action", "target": action_button}
		return
	var joystick := _visible_control(_joystick)
	if joystick != null and joystick.get_global_rect().has_point(screen_position):
		if joystick.has_method("router_touch_down"):
			var joystick_accepted := bool(joystick.call("router_touch_down", index, screen_position))
			_consume()
			if joystick_accepted:
				_touch_routes[index] = {"kind": "joystick", "target": joystick}
		return
	var click_control := _find_control(_click_controls, screen_position)
	if click_control != null:
		_touch_routes[index] = {"kind": "click", "target": click_control}
		_consume()
		return
	if _contains_control(_passthrough_controls, screen_position):
		# Let normal Godot UI controls such as HSlider receive the touch.
		return
	var look_area := _visible_control(_look_area)
	if look_area != null and look_area.get_global_rect().has_point(screen_position):
		if look_area.has_method("router_touch_down"):
			var look_accepted := bool(look_area.call("router_touch_down", index))
			_consume()
			if look_accepted:
				_touch_routes[index] = {"kind": "look", "target": look_area}

func _drag_touch(index: int, screen_position: Vector2, delta: Vector2) -> void:
	if not _touch_routes.has(index):
		return
	var route: Dictionary = _touch_routes[index]
	var target := route.get("target") as Node
	if target == null or not is_instance_valid(target):
		_touch_routes.erase(index)
		return
	var kind := String(route.get("kind", ""))
	var accepted := false
	match kind:
		"action":
			accepted = true
		"click":
			accepted = true
		"joystick":
			if target.has_method("router_touch_drag"):
				accepted = bool(target.call("router_touch_drag", index, screen_position))
		"look":
			if target.has_method("router_touch_drag"):
				accepted = bool(target.call("router_touch_drag", index, delta))
	if accepted:
		_consume()

func _end_touch(index: int) -> void:
	if not _touch_routes.has(index):
		return
	var route: Dictionary = _touch_routes[index]
	_touch_routes.erase(index)
	var target := route.get("target") as Node
	var kind := String(route.get("kind", ""))
	if target == null or not is_instance_valid(target):
		return
	if kind == "click":
		if target is BaseButton and not (target as BaseButton).disabled:
			target.emit_signal("pressed")
	elif target.has_method("router_touch_up"):
		target.call("router_touch_up", index)
	_consume()

func _release_all_touches() -> void:
	var active_indices := _touch_routes.keys()
	for value in active_indices:
		_end_touch(int(value))
	_touch_routes.clear()

func _find_action_button(screen_position: Vector2) -> Node:
	return _find_control(_action_buttons, screen_position)

func _find_control(collection: Array[Node], screen_position: Vector2) -> Node:
	for reverse_index in range(collection.size()):
		var index := collection.size() - 1 - reverse_index
		var control := _visible_control(collection[index])
		if control != null and control.get_global_rect().has_point(screen_position):
			return control
	return null

func _contains_control(collection: Array[Node], screen_position: Vector2) -> bool:
	return _find_control(collection, screen_position) != null

func _visible_control(value: Node) -> Control:
	var control := value as Control
	if control == null or not is_instance_valid(control) or not control.is_inside_tree() or not control.is_visible_in_tree():
		return null
	return control

func _screen_delta(event: InputEventScreenDrag) -> Vector2:
	var delta := event.screen_relative
	return event.relative if delta.is_zero_approx() else delta

func _consume() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
