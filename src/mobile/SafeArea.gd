class_name DeadfallSafeArea
extends Control

func _ready() -> void:
	get_viewport().size_changed.connect(_apply_safe_area)
	call_deferred("_apply_safe_area")

func _apply_safe_area() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var window_size := DisplayServer.window_get_size()
	var safe_area := DisplayServer.get_display_safe_area()

	if DisplayServer.get_name() == "headless" or window_size.x <= 0 or window_size.y <= 0 or safe_area.size.x <= 0 or safe_area.size.y <= 0:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		return

	var scale := Vector2(viewport_size.x / float(window_size.x), viewport_size.y / float(window_size.y))
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(safe_area.position) * scale
	size = Vector2(safe_area.size) * scale
