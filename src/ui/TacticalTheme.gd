class_name DeadfallTacticalTheme
extends RefCounted

const AMBER := Color("f2bb60")
const CYAN := Color("66d5dc")
const INK := Color("0b151e")
const MUTED := Color("a7bbc6")
const FONT = preload("res://assets/fonts/Rajdhani-SemiBold.ttf")

static func style(bg: Color = Color(0.035, 0.065, 0.09, 0.94), border: Color = Color(0.35, 0.58, 0.65, 0.35), margin: float = 16.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	return s

static func apply(root: Control) -> void:
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = 24
	t.set_color("font_color", "Label", Color("edf5f6"))
	t.set_color("font_color", "LineEdit", Color("edf5f6"))
	t.set_stylebox("normal", "LineEdit", style())
	t.set_stylebox("focus", "LineEdit", style(INK, CYAN))
	t.set_stylebox("background", "ProgressBar", style(Color("1b303a"), Color.TRANSPARENT, 0))
	t.set_stylebox("fill", "ProgressBar", style(AMBER, Color.TRANSPARENT, 0))
	root.theme = t

static func label(value: String, font_size: int = 24, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func button(value: String, callback: Callable = Callable(), primary: bool = false, icon_name: String = "") -> Button:
	var b := Button.new()
	b.text = value
	b.custom_minimum_size = Vector2(0, 64)
	skin_button(b, primary)
	if not icon_name.is_empty():
		b.icon = load("res://assets/ui/icons/%s.svg" % icon_name)
		b.add_theme_constant_override("icon_max_width", 28)
		b.add_theme_constant_override("h_separation", 14)
		b.expand_icon = true
	if callback.is_valid():
		b.pressed.connect(callback)
	return b

static func skin_button(b: Button, primary: bool = false) -> void:
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_stylebox_override("normal", style(AMBER if primary else Color(0.04, 0.09, 0.12, 0.94)))
	b.add_theme_stylebox_override("hover", style(Color("ffcc80") if primary else Color("183b48"), CYAN))
	b.add_theme_stylebox_override("pressed", style(Color("db9f3f") if primary else Color("205765"), AMBER))
	b.add_theme_stylebox_override("disabled", style(Color("192731"), Color("35434a")))
	b.add_theme_stylebox_override("focus", style(Color.TRANSPARENT, CYAN, 0))
	for property in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(property, INK if primary else Color("edf5f6"))
	if not b.has_meta("tactical_sound"):
		b.set_meta("tactical_sound", true)
		b.pressed.connect(func() -> void:
			var audio := b.get_node_or_null("/root/AudioDirector")
			if audio != null:
				audio.call("play_ui", &"ui_confirm" if primary else &"ui_click")
		)

static func place(node: Control, parent: Node, rect: Rect2) -> void:
	parent.add_child(node)
	node.anchor_left = rect.position.x
	node.anchor_top = rect.position.y
	node.anchor_right = rect.end.x
	node.anchor_bottom = rect.end.y

static func column(parent: Node, separation: int = 12) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	parent.add_child(box)
	return box
