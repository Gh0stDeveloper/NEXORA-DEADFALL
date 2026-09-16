class_name DeadfallTacticalBackdrop
extends Control

const ART = preload("res://assets/ui/quarantine_hangar.webp")
var _clock := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var picture := TextureRect.new()
	picture.texture = ART
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.show_behind_parent = true
	add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade(Vector2(0, 0), Vector2(0.70, 0), Color(0.015, 0.035, 0.052, 0.85), Color.TRANSPARENT)
	_fade(Vector2(0, 1), Vector2(0, 0.48), Color(0.01, 0.025, 0.04, 0.94), Color.TRANSPARENT)
	_fade(Vector2(0, 0), Vector2(0, 0.35), Color(0.01, 0.025, 0.04, 0.82), Color.TRANSPARENT)
	visibility_changed.connect(func() -> void: set_process(is_visible_in_tree()))

func _fade(from: Vector2, to: Vector2, a: Color, b: Color) -> void:
	var g := Gradient.new()
	g.colors = PackedColorArray([a, b])
	var texture := GradientTexture2D.new()
	texture.gradient = g
	texture.fill_from = from
	texture.fill_to = to
	var rect := TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.show_behind_parent = true
	add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	_clock += delta
	if is_visible_in_tree():
		queue_redraw()

func _draw() -> void:
	for i in range(18):
		var x := fposmod(float(i) * 0.618 + _clock * 0.003, 1.0) * size.x
		var y := fposmod(float(i) * 0.237 - _clock * 0.012, 1.0) * size.y
		draw_circle(Vector2(x, y), 1.2 + float(i % 3), Color(1.0, 0.78, 0.44, 0.20))
