class_name DeadfallLobbyVisualPolish
extends Node

const COLOR_RED := Color(0.92, 0.055, 0.075, 1.0)
const COLOR_CYAN := Color(0.06, 0.68, 0.72, 1.0)
const COLOR_AMBER := Color(0.96, 0.58, 0.14, 1.0)
const COLOR_NAVY := Color(0.010, 0.035, 0.046, 1.0)

var _button_tweens: Dictionary = {}

func _ready() -> void:
	call_deferred("_apply_polish")

func _apply_polish() -> void:
	var lobby := get_parent() as Control
	if lobby == null:
		return
	var background := lobby.get_node_or_null("Background") as ColorRect
	if background != null:
		background.color = COLOR_NAVY
		var red_accent := background.get_node_or_null("RedAccent") as ColorRect
		if red_accent != null:
			red_accent.color = Color(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b, 0.20)
		_add_atmosphere(background)

	_restyle_panel(lobby.get_node_or_null("SafeArea/IdentityCard"), Color(0.012, 0.045, 0.056, 0.95), Color(COLOR_CYAN.r, COLOR_CYAN.g, COLOR_CYAN.b, 0.60), 16)
	_restyle_panel(lobby.get_node_or_null("SafeArea/Navigation"), Color(0.010, 0.032, 0.042, 0.92), Color(COLOR_CYAN.r, COLOR_CYAN.g, COLOR_CYAN.b, 0.34), 18)
	_restyle_panel(lobby.get_node_or_null("SafeArea/OperatorStage"), Color(0.018, 0.028, 0.036, 0.76), Color(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b, 0.48), 26)
	_restyle_panel(lobby.get_node_or_null("SafeArea/PartyRail"), Color(0.010, 0.034, 0.043, 0.94), Color(COLOR_CYAN.r, COLOR_CYAN.g, COLOR_CYAN.b, 0.42), 18)
	_restyle_panel(lobby.get_node_or_null("SafeArea/MatchControls"), Color(0.010, 0.032, 0.040, 0.96), Color(COLOR_AMBER.r, COLOR_AMBER.g, COLOR_AMBER.b, 0.42), 18)
	_restyle_panel(lobby.get_node_or_null("SafeArea/CharacterSelection"), Color(0.008, 0.025, 0.034, 0.985), Color(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b, 0.72), 22)

	_polish_buttons(lobby)
	_polish_character_stage(lobby)

func _add_atmosphere(background: ColorRect) -> void:
	if background.get_node_or_null("TealAtmosphere") != null:
		return
	var teal := ColorRect.new()
	teal.name = "TealAtmosphere"
	teal.color = Color(COLOR_CYAN.r, COLOR_CYAN.g, COLOR_CYAN.b, 0.13)
	teal.anchor_left = 0.0
	teal.anchor_top = 0.10
	teal.anchor_right = 0.37
	teal.anchor_bottom = 0.90
	teal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_child(teal)

	var amber := ColorRect.new()
	amber.name = "AmberHorizon"
	amber.color = Color(COLOR_AMBER.r, COLOR_AMBER.g, COLOR_AMBER.b, 0.065)
	amber.anchor_left = 0.0
	amber.anchor_top = 0.60
	amber.anchor_right = 1.0
	amber.anchor_bottom = 0.76
	amber.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_child(amber)

	var upper := ColorRect.new()
	upper.name = "ColdUpperGlow"
	upper.color = Color(0.12, 0.28, 0.36, 0.13)
	upper.anchor_left = 0.20
	upper.anchor_top = 0.0
	upper.anchor_right = 0.88
	upper.anchor_bottom = 0.22
	upper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_child(upper)

	for index in range(5):
		var stripe := ColorRect.new()
		stripe.name = "HazardStripe%d" % index
		stripe.color = Color(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b, 0.10 if index % 2 == 0 else 0.04)
		stripe.anchor_left = 0.0
		stripe.anchor_top = 0.91 + float(index) * 0.012
		stripe.anchor_right = 1.0
		stripe.anchor_bottom = stripe.anchor_top + 0.004
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.add_child(stripe)

func _polish_buttons(root: Node) -> void:
	for child in root.get_children():
		if child is Button:
			var button := child as Button
			var upper := button.text.to_upper()
			var primary := upper in ["INICIAR", "UNIRSE", "SELECCIONAR", "CONFIRMAR", "INICIAR PARTIDA"]
			_apply_button_palette(button, primary)
			if not button.button_down.is_connected(_on_button_down.bind(button)):
				button.button_down.connect(_on_button_down.bind(button))
			if not button.button_up.is_connected(_on_button_up.bind(button)):
				button.button_up.connect(_on_button_up.bind(button))
		_polish_buttons(child)

func _apply_button_palette(button: Button, primary: bool) -> void:
	var normal := Color(0.68, 0.025, 0.045, 0.96) if primary else Color(0.018, 0.070, 0.082, 0.96)
	var hover := Color(0.90, 0.040, 0.060, 1.0) if primary else Color(0.025, 0.13, 0.145, 1.0)
	var pressed := Color(0.46, 0.018, 0.030, 1.0) if primary else Color(0.015, 0.18, 0.19, 1.0)
	var border := COLOR_RED if primary else COLOR_CYAN
	button.add_theme_stylebox_override("normal", _style(normal, Color(border.r, border.g, border.b, 0.72), 12, 2))
	button.add_theme_stylebox_override("hover", _style(hover, Color(border.r, border.g, border.b, 1.0), 12, 2))
	button.add_theme_stylebox_override("pressed", _style(pressed, Color(1.0, 0.72, 0.48, 0.98), 12, 3))
	button.add_theme_stylebox_override("disabled", _style(Color(0.018, 0.028, 0.032, 0.72), Color(0.22, 0.30, 0.31, 0.45), 12, 1))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(0.95, 0.98, 0.98))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)

func _on_button_down(button: Button) -> void:
	if button == null:
		return
	button.pivot_offset = button.size * 0.5
	_kill_button_tween(button)
	var tween := button.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_button_tweens[button.get_instance_id()] = tween
	tween.tween_property(button, "scale", Vector2(0.96, 0.94), 0.06)

func _on_button_up(button: Button) -> void:
	if button == null:
		return
	_kill_button_tween(button)
	var tween := button.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_button_tweens[button.get_instance_id()] = tween
	tween.tween_property(button, "scale", Vector2.ONE, 0.14)

func _kill_button_tween(button: Button) -> void:
	var key := button.get_instance_id()
	var tween = _button_tweens.get(key)
	if tween is Tween and tween.is_valid():
		tween.kill()
	_button_tweens.erase(key)

func _polish_character_stage(lobby: Control) -> void:
	var viewport := lobby.get_node_or_null("SafeArea/OperatorStage/CharacterViewportContainer/CharacterViewport") as SubViewport
	if viewport == null or viewport.get_child_count() == 0:
		return
	var root_3d := viewport.get_child(0) as Node3D
	if root_3d == null:
		return
	var world := WorldEnvironment.new()
	world.name = "LobbyWorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.012, 0.024, 0.030)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.48, 0.68, 0.72)
	environment.ambient_light_energy = 0.82
	environment.tonemap_exposure = 1.18
	world.environment = environment
	root_3d.add_child(world)

	for child in root_3d.get_children():
		if child is DirectionalLight3D:
			var key := child as DirectionalLight3D
			key.light_color = Color(0.74, 0.91, 0.95)
			key.light_energy = 1.55
		elif child is OmniLight3D:
			var rim := child as OmniLight3D
			rim.light_color = COLOR_RED
			rim.light_energy = 4.0

	var fill := OmniLight3D.new()
	fill.name = "TealFill"
	fill.position = Vector3(1.8, 1.4, 1.5)
	fill.light_color = COLOR_CYAN
	fill.light_energy = 2.2
	fill.omni_range = 5.5
	fill.shadow_enabled = false
	root_3d.add_child(fill)

func _restyle_panel(node: Node, background: Color, border: Color, radius: int) -> void:
	if node is PanelContainer:
		(node as PanelContainer).add_theme_stylebox_override("panel", _style(background, border, radius, 1))

func _style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.anti_aliasing = true
	return style
