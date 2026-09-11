class_name DeadfallHUDLayoutEditor
extends Control

signal close_requested

var _hud_owner: Node
var _safe_root: Control
var _elements: Dictionary = {}
var _selected_id: StringName = &""
var _active_pointer := -1
var _last_pointer_position := Vector2.ZERO
var _dragging := false
var _toolbar: PanelContainer
var _selection_label: Label
var _scale_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_toolbar()
	queue_redraw()

func configure(hud_owner: Node, safe_root: Control, elements: Dictionary) -> void:
	_hud_owner = hud_owner
	_safe_root = safe_root
	_elements = elements.duplicate()
	_refresh_toolbar()
	queue_redraw()

func open_editor() -> void:
	_selected_id = &""
	if not _elements.is_empty():
		var keys: Array = _elements.keys()
		_selected_id = StringName(keys[0])
	_dragging = false
	_active_pointer = -1
	visible = true
	_refresh_toolbar()
	queue_redraw()

func close_editor() -> void:
	if not visible:
		return
	_dragging = false
	_active_pointer = -1
	visible = false
	queue_redraw()
	close_requested.emit()

func _build_toolbar() -> void:
	_toolbar = PanelContainer.new()
	_toolbar.name = "Toolbar"
	_toolbar.anchor_left = 0.5
	_toolbar.anchor_top = 0.0
	_toolbar.anchor_right = 0.5
	_toolbar.anchor_bottom = 0.0
	_toolbar.offset_left = -330.0
	_toolbar.offset_top = 18.0
	_toolbar.offset_right = 330.0
	_toolbar.offset_bottom = 150.0
	_toolbar.mouse_filter = Control.MOUSE_FILTER_STOP
	_toolbar.add_theme_stylebox_override("panel", _toolbar_style())
	add_child(_toolbar)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_toolbar.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)

	var title := Label.new()
	title.text = "PERSONALIZAR HUD"
	title.add_theme_font_size_override("font_size", 19)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_scale_label = Label.new()
	_scale_label.add_theme_font_size_override("font_size", 17)
	header.add_child(_scale_label)

	_selection_label = Label.new()
	_selection_label.text = "SELECCIONA UN CONTROL"
	_selection_label.add_theme_font_size_override("font_size", 14)
	_selection_label.add_theme_color_override("font_color", Color(0.65, 0.91, 0.92))
	box.add_child(_selection_label)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	box.add_child(controls)

	var smaller := _make_button(controls, "−", "ScaleDown", Vector2(54, 42))
	smaller.tooltip_text = "Reducir tamaño"
	smaller.pressed.connect(_adjust_selected_scale.bind(-0.10))

	var larger := _make_button(controls, "+", "ScaleUp", Vector2(54, 42))
	larger.tooltip_text = "Aumentar tamaño"
	larger.pressed.connect(_adjust_selected_scale.bind(0.10))

	var reset := _make_button(controls, "RESTABLECER", "ResetLayout", Vector2(142, 42))
	reset.pressed.connect(_on_reset_pressed)

	var save := _make_button(controls, "GUARDAR", "SaveLayout", Vector2(114, 42))
	save.pressed.connect(_on_save_pressed)

	var close := _make_button(controls, "CERRAR", "CloseEditor", Vector2(108, 42))
	close.pressed.connect(_on_close_pressed)

	var hint := Label.new()
	hint.text = "Arrastra un control · +/- cambia su tamaño · configuración local"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.67, 0.72, 0.75))
	box.add_child(hint)

func _make_button(parent: Container, label_text: String, button_name: String, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = label_text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = minimum_size
	parent.add_child(button)
	return button

func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		var screen_position: Vector2 = _to_global_position(touch_event.position)
		if touch_event.pressed:
			_pointer_down(touch_event.index, screen_position)
		else:
			_pointer_up(touch_event.index)
		accept_event()
	elif event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event as InputEventScreenDrag
		_pointer_drag(drag_event.index, _to_global_position(drag_event.position))
		accept_event()
	elif event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			var screen_position: Vector2 = _to_global_position(mouse_button.position)
			if mouse_button.pressed:
				_pointer_down(0, screen_position)
			else:
				_pointer_up(0)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		_pointer_drag(0, _to_global_position(motion_event.position))
		accept_event()

func _pointer_down(pointer_id: int, screen_position: Vector2) -> void:
	if _active_pointer != -1:
		return
	_active_pointer = pointer_id
	_last_pointer_position = screen_position
	_selected_id = _find_element(screen_position)
	_dragging = not _selected_id.is_empty()
	_refresh_toolbar()
	queue_redraw()

func _pointer_drag(pointer_id: int, screen_position: Vector2) -> void:
	if not _dragging or pointer_id != _active_pointer:
		return
	var delta: Vector2 = screen_position - _last_pointer_position
	if not delta.is_zero_approx() and _hud_owner != null and _hud_owner.has_method("move_hud_element"):
		_hud_owner.call("move_hud_element", _selected_id, delta)
	_last_pointer_position = screen_position
	queue_redraw()

func _pointer_up(pointer_id: int) -> void:
	if pointer_id != _active_pointer:
		return
	_active_pointer = -1
	_dragging = false
	if _hud_owner != null and _hud_owner.has_method("save_hud_layout"):
		_hud_owner.call("save_hud_layout")
	_refresh_toolbar()
	queue_redraw()

func _find_element(screen_position: Vector2) -> StringName:
	var keys: Array = _elements.keys()
	for reverse_index in range(keys.size()):
		var index: int = keys.size() - 1 - reverse_index
		var key: Variant = keys[index]
		var control: Control = _elements.get(key) as Control
		if control == null or not is_instance_valid(control) or not control.is_visible_in_tree():
			continue
		if control.get_global_rect().grow(16.0).has_point(screen_position):
			return StringName(key)
	return &""

func _adjust_selected_scale(amount: float) -> void:
	if _selected_id.is_empty() or _hud_owner == null:
		return
	if _hud_owner.has_method("resize_hud_element"):
		_hud_owner.call("resize_hud_element", _selected_id, amount)
	_refresh_toolbar()
	queue_redraw()

func _on_reset_pressed() -> void:
	if _hud_owner != null and _hud_owner.has_method("reset_hud_layout_to_defaults"):
		_hud_owner.call("reset_hud_layout_to_defaults")
	_refresh_toolbar()
	queue_redraw()

func _on_save_pressed() -> void:
	if _hud_owner != null and _hud_owner.has_method("save_hud_layout"):
		_hud_owner.call("save_hud_layout")
	_refresh_toolbar()

func _on_close_pressed() -> void:
	close_editor()

func _refresh_toolbar() -> void:
	if _selection_label == null or _scale_label == null:
		return
	if _selected_id.is_empty():
		_selection_label.text = "SELECCIONA UN CONTROL"
		_scale_label.text = "TAMAÑO —"
		return
	_selection_label.text = "SELECCIONADO: %s" % String(_selected_id).to_upper()
	var scale_value: float = 1.0
	if _hud_owner != null and _hud_owner.has_method("get_hud_element_scale"):
		scale_value = float(_hud_owner.call("get_hud_element_scale", _selected_id))
	_scale_label.text = "TAMAÑO %.2fx" % scale_value

func _to_global_position(local_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas() * local_position

func _global_rect_to_local(global_rect: Rect2) -> Rect2:
	var local_position: Vector2 = get_global_transform_with_canvas().affine_inverse() * global_rect.position
	return Rect2(local_position, global_rect.size)

func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.005, 0.012, 0.016, 0.30), true)
	for key in _elements.keys():
		var control: Control = _elements.get(key) as Control
		if control == null or not is_instance_valid(control) or not control.is_visible_in_tree():
			continue
		var local_rect: Rect2 = _global_rect_to_local(control.get_global_rect()).grow(7.0)
		var is_selected: bool = StringName(key) == _selected_id
		var color := Color(0.30, 0.78, 0.80, 0.74) if is_selected else Color(0.72, 0.78, 0.80, 0.38)
		draw_rect(local_rect, color, false, 2.0, true)
		if is_selected:
			draw_circle(local_rect.get_center(), 4.5, Color(0.96, 0.78, 0.25, 0.94))

func _toolbar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.026, 0.034, 0.96)
	style.border_color = Color(0.20, 0.78, 0.80, 0.84)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	return style
