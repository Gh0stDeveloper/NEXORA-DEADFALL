extends RefCounted

# Original vector silhouettes; the reference image informs layout only.
static func draw_icon(canvas: CanvasItem, kind: StringName, bounds: Rect2, color: Color = Color.WHITE) -> void:
	canvas.draw_set_transform(bounds.position, 0.0, bounds.size / 64.0)
	match kind:
		&"rifle":
			_poly(canvas, [Vector2(3, 27), Vector2(16, 31), Vector2(18, 22), Vector2(44, 22), Vector2(44, 26), Vector2(60, 26), Vector2(60, 30), Vector2(43, 30), Vector2(38, 36), Vector2(42, 46), Vector2(33, 48), Vector2(29, 35), Vector2(24, 35), Vector2(22, 43), Vector2(17, 41), Vector2(17, 35), Vector2(3, 39)], color)
			canvas.draw_rect(Rect2(25, 16, 13, 4), color)
		&"pistol":
			_poly(canvas, [Vector2(12, 17), Vector2(56, 17), Vector2(56, 28), Vector2(32, 28), Vector2(29, 49), Vector2(15, 49), Vector2(19, 29), Vector2(12, 28)], color)
		&"machete":
			_poly(canvas, [Vector2(13, 46), Vector2(41, 9), Vector2(53, 5), Vector2(50, 20), Vector2(23, 50)], color)
			_line(canvas, Vector2(17, 49), Vector2(10, 59), color, 8)
		&"fire":
			for offset in [Vector2(-9, 5), Vector2(9, -5)]:
				_poly(canvas, [Vector2(17, 12) + offset, Vector2(29, 17) + offset, Vector2(46, 41) + offset, Vector2(36, 48) + offset, Vector2(20, 23) + offset], color)
				_line(canvas, Vector2(37, 51) + offset, Vector2(45, 46) + offset, color, 3)
		&"aim":
			canvas.draw_arc(Vector2(32, 32), 18, 0, TAU, 40, color, 3, true)
			for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				_line(canvas, Vector2(32, 32) + direction * 10, Vector2(32, 32) + direction * 27, color, 3)
			canvas.draw_circle(Vector2(32, 32), 3, color)
		&"sprint", &"jump", &"crouch", &"prone":
			var points: Array[Vector2]
			if kind == &"prone":
				points = [Vector2(11, 31), Vector2(23, 36), Vector2(40, 37), Vector2(55, 46), Vector2(55, 35), Vector2(20, 46), Vector2(34, 46)]
			elif kind == &"crouch":
				points = [Vector2(29, 12), Vector2(26, 25), Vector2(19, 38), Vector2(38, 43), Vector2(28, 55), Vector2(41, 25), Vector2(52, 21)]
			elif kind == &"jump":
				points = [Vector2(34, 10), Vector2(31, 25), Vector2(29, 39), Vector2(47, 47), Vector2(15, 54), Vector2(13, 12), Vector2(53, 20)]
			else:
				points = [Vector2(38, 10), Vector2(30, 24), Vector2(23, 38), Vector2(39, 53), Vector2(9, 49), Vector2(13, 20), Vector2(48, 29)]
			canvas.draw_circle(points[0], 6, color)
			_line(canvas, points[1], points[2], color, 9)
			_line(canvas, points[2], points[3], color, 6)
			_line(canvas, points[2], points[4], color, 6)
			_line(canvas, points[1], points[5], color, 5)
			_line(canvas, points[1], points[6], color, 5)
		&"reload":
			canvas.draw_arc(Vector2(32, 32), 23, -1.1, 3.6, 40, color, 4, true)
			_poly(canvas, [Vector2(5, 20), Vector2(18, 25), Vector2(7, 33)], color)
			canvas.draw_rect(Rect2(25, 19, 13, 26), color)
		&"interact":
			canvas.draw_circle(Vector2(32, 39), 12, color)
			for i in range(4):
				_line(canvas, Vector2(23 + i * 6, 35), Vector2(23 + i * 6, 12 + abs(i - 1) * 3), color, 5)
			_line(canvas, Vector2(24, 42), Vector2(12, 31), color, 7)
		&"flashlight":
			_poly(canvas, [Vector2(18, 24), Vector2(39, 24), Vector2(34, 36), Vector2(34, 55), Vector2(24, 55), Vector2(24, 36)], color)
			for x in [16, 28, 40]:
				_line(canvas, Vector2(x, 18), Vector2(x + (x - 28) * 0.4, 6), color, 3)
		&"camera":
			canvas.draw_arc(Vector2(32, 32), 22, 0.2, PI - 0.2, 24, color, 4, true)
			canvas.draw_arc(Vector2(32, 32), 22, PI + 0.2, TAU - 0.2, 24, color, 4, true)
			canvas.draw_circle(Vector2(32, 32), 8, color)
		&"settings":
			canvas.draw_arc(Vector2(32, 32), 14, 0, TAU, 32, color, 8, true)
			for i in range(8):
				var direction := Vector2.from_angle(i * TAU / 8)
				_line(canvas, Vector2(32, 32) + direction * 17, Vector2(32, 32) + direction * 24, color, 7)
	canvas.draw_set_transform(Vector2.ZERO)

static func _line(canvas: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	canvas.draw_line(a, b, color, width, true)
	canvas.draw_circle(a, width * 0.5, color)
	canvas.draw_circle(b, width * 0.5, color)

static func _poly(canvas: CanvasItem, points: Array[Vector2], color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array(points), color)
