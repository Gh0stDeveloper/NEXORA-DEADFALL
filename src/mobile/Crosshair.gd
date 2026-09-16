class_name DeadfallCrosshair
extends Control

var dot_color := Color(0.96, 1.0, 0.98, 0.96)
var ring_color := Color(0.78, 0.96, 0.94, 0.76)
var shadow_color := Color(0.005, 0.012, 0.016, 0.78)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(48, 48)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var ring_radius: float = minf(size.x, size.y) * 0.29
	var dot_radius: float = maxf(2.5, minf(size.x, size.y) * 0.065)
	draw_arc(center, ring_radius, 0.0, TAU, 32, shadow_color, 4.0, true)
	draw_arc(center, ring_radius, 0.0, TAU, 32, ring_color, 1.6, true)
	draw_circle(center, dot_radius + 1.8, shadow_color)
	draw_circle(center, dot_radius, dot_color)
