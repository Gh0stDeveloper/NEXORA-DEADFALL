extends Button

var slot := 0
var ammo_text := ""

func _draw() -> void:
	var glyph: StringName = [&"rifle", &"pistol", &"machete"][slot]
	preload("res://src/mobile/HUDIcons.gd").draw_icon(self, glyph, Rect2(Vector2(size.x * 0.15, 0), Vector2(size.x * 0.7, size.y * 0.72)))
	var font := preload("res://assets/fonts/Rajdhani-SemiBold.ttf")
	draw_string(font, Vector2(10, size.y - 9), ammo_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 22, Color.WHITE)
