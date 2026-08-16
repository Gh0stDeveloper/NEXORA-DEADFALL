class_name DeadfallLobbyController
extends Control

signal start_requested(mode: int)

enum PartyMode {
	SOLO = 1,
	DUO = 2,
	SQUAD = 4,
}

const SafeAreaScript = preload("res://src/mobile/SafeArea.gd")
const CharacterCatalog = preload("res://src/lobby/CharacterCatalog.gd")

var selected_mode: PartyMode = PartyMode.SOLO
var _safe_root: Control
var _username_label: Label
var _username_editor: LineEdit
var _status_label: Label
var _mode_buttons: Dictionary = {}
var _party_labels: Array[Label] = []
var _character_panel: PanelContainer
var _character_name: Label
var _character_role: Label
var _character_mesh: MeshInstance3D
var _start_button: Button
var _selected_character: StringName = &"operator_01"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_safe_layout()
	_selected_character = GuestIdentity.selected_character
	_refresh_identity()
	_refresh_character()
	_refresh_mode()
	GuestIdentity.username_changed.connect(_on_identity_username_changed)
	GuestIdentity.selected_character_changed.connect(_on_identity_character_changed)

func _build_background() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.012, 0.015, 0.020, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var red_glow := ColorRect.new()
	red_glow.name = "RedAccent"
	red_glow.color = Color(0.48, 0.025, 0.035, 0.16)
	red_glow.anchor_left = 0.32
	red_glow.anchor_top = 0.0
	red_glow.anchor_right = 0.72
	red_glow.anchor_bottom = 1.0
	background.add_child(red_glow)

func _build_safe_layout() -> void:
	_safe_root = SafeAreaScript.new()
	_safe_root.name = "SafeArea"
	_safe_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_safe_root)

	_build_top_bar()
	_build_left_navigation()
	_build_character_stage()
	_build_party_rail()
	_build_bottom_bar()
	_build_character_panel()

func _build_top_bar() -> void:
	var identity := PanelContainer.new()
	identity.name = "IdentityCard"
	identity.anchor_left = 0.0
	identity.anchor_top = 0.0
	identity.anchor_right = 0.32
	identity.anchor_bottom = 0.0
	identity.offset_left = 28.0
	identity.offset_top = 24.0
	identity.offset_right = -12.0
	identity.offset_bottom = 126.0
	identity.add_theme_stylebox_override("panel", _panel_style(Color(0.020, 0.025, 0.032, 0.94), Color(0.28, 0.31, 0.36, 0.65), 14))
	_safe_root.add_child(identity)

	var margin := MarginContainer.new()
	_set_margins(margin, 18, 18, 12, 12)
	identity.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)
	var brand := Label.new()
	brand.text = "NEXORA: DEADFALL"
	brand.add_theme_font_size_override("font_size", 17)
	brand.add_theme_color_override("font_color", Color(0.78, 0.10, 0.12))
	vbox.add_child(brand)
	_username_label = Label.new()
	_username_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_username_label)
	var id_label := Label.new()
	id_label.text = "ID  %s" % GuestIdentity.guest_id.trim_prefix("gst_").left(12).to_upper()
	id_label.add_theme_font_size_override("font_size", 12)
	id_label.add_theme_color_override("font_color", Color(0.58, 0.61, 0.66))
	vbox.add_child(id_label)

	var beta := Label.new()
	beta.text = "CLOSED BETA"
	beta.anchor_left = 0.5
	beta.anchor_right = 0.5
	beta.offset_left = -90.0
	beta.offset_top = 30.0
	beta.offset_right = 90.0
	beta.offset_bottom = 62.0
	beta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	beta.add_theme_font_size_override("font_size", 16)
	beta.add_theme_color_override("font_color", Color(0.70, 0.72, 0.76))
	_safe_root.add_child(beta)

	_status_label = Label.new()
	_status_label.anchor_left = 0.5
	_status_label.anchor_right = 0.5
	_status_label.offset_left = -280.0
	_status_label.offset_top = 66.0
	_status_label.offset_right = 280.0
	_status_label.offset_bottom = 98.0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.72, 0.74, 0.78))
	_safe_root.add_child(_status_label)

func _build_left_navigation() -> void:
	var panel := PanelContainer.new()
	panel.name = "Navigation"
	panel.anchor_left = 0.0
	panel.anchor_top = 0.22
	panel.anchor_right = 0.18
	panel.anchor_bottom = 0.80
	panel.offset_left = 28.0
	panel.offset_right = -14.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.019, 0.025, 0.88), Color(0.22, 0.24, 0.28, 0.50), 16))
	_safe_root.add_child(panel)

	var margin := MarginContainer.new()
	_set_margins(margin, 14, 14, 18, 18)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	vbox.add_child(_nav_button("JUGAR", _close_character_panel))
	vbox.add_child(_nav_button("PERSONAJES", _open_character_panel))
	vbox.add_child(_nav_button("EQUIPAMIENTO", _show_coming_soon.bind("Equipamiento")))
	vbox.add_child(_nav_button("AJUSTES", _show_coming_soon.bind("Ajustes completos")))

func _build_character_stage() -> void:
	var stage := PanelContainer.new()
	stage.name = "OperatorStage"
	stage.anchor_left = 0.20
	stage.anchor_top = 0.14
	stage.anchor_right = 0.73
	stage.anchor_bottom = 0.84
	stage.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.021, 0.027, 0.62), Color(0.30, 0.31, 0.34, 0.28), 24))
	_safe_root.add_child(stage)

	var viewport_container := SubViewportContainer.new()
	viewport_container.name = "CharacterViewportContainer"
	viewport_container.stretch = true
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(viewport_container)
	var viewport := SubViewport.new()
	viewport.name = "CharacterViewport"
	viewport.size = Vector2i(720, 840)
	viewport.transparent_bg = true
	viewport_container.add_child(viewport)

	var root_3d := Node3D.new()
	viewport.add_child(root_3d)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.35, 4.8)
	camera.fov = 42.0
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.0, 0.0))
	root_3d.add_child(camera)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-40, -28, 0)
	key_light.light_energy = 1.2
	key_light.light_color = Color(0.88, 0.91, 1.0)
	key_light.shadow_enabled = true
	root_3d.add_child(key_light)
	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(-1.4, 2.0, -0.8)
	rim_light.light_color = Color(0.75, 0.04, 0.06)
	rim_light.light_energy = 3.0
	rim_light.omni_range = 5.0
	root_3d.add_child(rim_light)

	_character_mesh = MeshInstance3D.new()
	_character_mesh.name = "OperatorPlaceholder"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.48
	body_mesh.height = 2.05
	_character_mesh.mesh = body_mesh
	_character_mesh.position = Vector3(0, 1.02, 0)
	root_3d.add_child(_character_mesh)

	var stage_floor := MeshInstance3D.new()
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 1.35
	floor_mesh.bottom_radius = 1.55
	floor_mesh.height = 0.12
	stage_floor.mesh = floor_mesh
	stage_floor.position = Vector3(0, 0.02, 0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.06, 0.065, 0.075)
	floor_material.metallic = 0.35
	floor_material.roughness = 0.55
	floor_mesh.material = floor_material
	root_3d.add_child(stage_floor)

	var info := VBoxContainer.new()
	info.anchor_left = 0.04
	info.anchor_top = 0.70
	info.anchor_right = 0.50
	info.anchor_bottom = 0.94
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(info)
	_character_name = Label.new()
	_character_name.add_theme_font_size_override("font_size", 38)
	info.add_child(_character_name)
	_character_role = Label.new()
	_character_role.add_theme_font_size_override("font_size", 15)
	_character_role.add_theme_color_override("font_color", Color(0.74, 0.76, 0.80))
	info.add_child(_character_role)

func _build_party_rail() -> void:
	var rail := PanelContainer.new()
	rail.name = "PartyRail"
	rail.anchor_left = 0.75
	rail.anchor_top = 0.15
	rail.anchor_right = 1.0
	rail.anchor_bottom = 0.78
	rail.offset_left = 12.0
	rail.offset_right = -28.0
	rail.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.019, 0.025, 0.90), Color(0.25, 0.27, 0.31, 0.52), 18))
	_safe_root.add_child(rail)

	var margin := MarginContainer.new()
	_set_margins(margin, 16, 16, 18, 18)
	rail.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "ESCUADRA"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	for index in range(4):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(0, 76)
		slot.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.030, 0.038, 0.86), Color(0.23, 0.25, 0.29, 0.62), 12))
		vbox.add_child(slot)
		var slot_margin := MarginContainer.new()
		_set_margins(slot_margin, 14, 14, 10, 10)
		slot.add_child(slot_margin)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 17)
		slot_margin.add_child(label)
		_party_labels.append(label)

func _build_bottom_bar() -> void:
	var bar := PanelContainer.new()
	bar.name = "MatchControls"
	bar.anchor_left = 0.20
	bar.anchor_top = 0.86
	bar.anchor_right = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_right = -28.0
	bar.offset_bottom = -22.0
	bar.add_theme_stylebox_override("panel", _panel_style(Color(0.014, 0.018, 0.023, 0.94), Color(0.30, 0.31, 0.34, 0.50), 18))
	_safe_root.add_child(bar)
	var margin := MarginContainer.new()
	_set_margins(margin, 18, 18, 14, 14)
	bar.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var mode_column := VBoxContainer.new()
	mode_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mode_column)
	var mode_title := Label.new()
	mode_title.text = "FORMACIÓN"
	mode_title.add_theme_font_size_override("font_size", 13)
	mode_title.add_theme_color_override("font_color", Color(0.62, 0.64, 0.68))
	mode_column.add_child(mode_title)
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	mode_column.add_child(mode_row)
	_add_mode_button(mode_row, "SOLO", PartyMode.SOLO)
	_add_mode_button(mode_row, "DÚO", PartyMode.DUO)
	_add_mode_button(mode_row, "ESCUADRA", PartyMode.SQUAD)

	var character_button := Button.new()
	character_button.text = "PERSONAJE"
	character_button.custom_minimum_size = Vector2(180, 70)
	_apply_button_style(character_button, false)
	row.add_child(character_button)
	character_button.pressed.connect(_open_character_panel)

	_start_button = Button.new()
	_start_button.text = "INICIAR"
	_start_button.custom_minimum_size = Vector2(260, 74)
	_start_button.add_theme_font_size_override("font_size", 23)
	_apply_button_style(_start_button, true)
	row.add_child(_start_button)
	_start_button.pressed.connect(_on_start_pressed)

func _build_character_panel() -> void:
	_character_panel = PanelContainer.new()
	_character_panel.name = "CharacterSelection"
	_character_panel.anchor_left = 0.18
	_character_panel.anchor_top = 0.12
	_character_panel.anchor_right = 0.98
	_character_panel.anchor_bottom = 0.84
	_character_panel.visible = false
	_character_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.012, 0.016, 0.022, 0.985), Color(0.60, 0.07, 0.09, 0.72), 22))
	_safe_root.add_child(_character_panel)

	var margin := MarginContainer.new()
	_set_margins(margin, 28, 28, 24, 24)
	_character_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)
	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "PERSONAJES"
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "CERRAR"
	close.custom_minimum_size = Vector2(140, 48)
	_apply_button_style(close, false)
	header.add_child(close)
	close.pressed.connect(_close_character_panel)

	var cards := HBoxContainer.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 18)
	vbox.add_child(cards)
	for character in CharacterCatalog.all():
		cards.add_child(_character_card(Dictionary(character)))

func _character_card(character: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(320, 420)
	var accent: Color = character.get("accent", Color(0.6, 0.08, 0.1))
	card.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.030, 0.038, 0.98), Color(accent.r, accent.g, accent.b, 0.72), 18))
	var margin := MarginContainer.new()
	_set_margins(margin, 20, 20, 20, 20)
	card.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var silhouette := ColorRect.new()
	silhouette.custom_minimum_size = Vector2(0, 220)
	silhouette.color = Color(accent.r, accent.g, accent.b, 0.18)
	vbox.add_child(silhouette)
	var name_label := Label.new()
	name_label.text = String(character.get("name", "OPERADOR"))
	name_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(name_label)
	var role := Label.new()
	role.text = String(character.get("role", "SUPERVIVIENTE"))
	role.add_theme_color_override("font_color", accent)
	vbox.add_child(role)
	var description := Label.new()
	description.text = String(character.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(description)
	var model_state := Label.new()
	model_state.text = "MODELO 3D: PENDIENTE DE IMPORTAR"
	model_state.add_theme_font_size_override("font_size", 12)
	model_state.add_theme_color_override("font_color", Color(0.54, 0.56, 0.60))
	vbox.add_child(model_state)
	var select := Button.new()
	select.text = "SELECCIONAR"
	select.custom_minimum_size = Vector2(0, 56)
	_apply_button_style(select, true)
	vbox.add_child(select)
	select.pressed.connect(_select_character.bind(StringName(character.get("id", &"operator_01"))))
	return card

func _nav_button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 58)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 17)
	_apply_button_style(button, false)
	button.pressed.connect(callback)
	return button

func _add_mode_button(parent: Control, label: String, mode: PartyMode) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(150, 48)
	button.toggle_mode = true
	_apply_button_style(button, false)
	parent.add_child(button)
	_mode_buttons[int(mode)] = button
	button.pressed.connect(_set_mode.bind(mode))

func _set_mode(mode: PartyMode) -> void:
	selected_mode = mode
	_refresh_mode()

func _refresh_mode() -> void:
	for key in _mode_buttons:
		var button: Button = _mode_buttons[key]
		button.button_pressed = int(key) == int(selected_mode)
		if button.button_pressed:
			button.add_theme_color_override("font_color", Color.WHITE)
		else:
			button.remove_theme_color_override("font_color")
	for index in range(_party_labels.size()):
		var label := _party_labels[index]
		if index == 0:
			label.text = "1  %s\n   LÍDER" % _display_username()
			label.modulate = Color.WHITE
		elif index < int(selected_mode):
			label.text = "%d  INVITAR JUGADOR" % (index + 1)
			label.modulate = Color(0.72, 0.74, 0.78)
		else:
			label.text = "%d  CERRADO" % (index + 1)
			label.modulate = Color(0.38, 0.40, 0.44)
	_status_label.text = "SOLO" if selected_mode == PartyMode.SOLO else ("DÚO · LÍDER LOCAL" if selected_mode == PartyMode.DUO else "ESCUADRA · LÍDER LOCAL")

func _refresh_identity() -> void:
	if _username_label == null:
		return
	_username_label.text = _display_username()
	if GuestIdentity.username.is_empty():
		_build_username_editor()
	elif _username_editor != null and is_instance_valid(_username_editor):
		_username_editor.get_parent().queue_free()
		_username_editor = null

func _build_username_editor() -> void:
	if _username_editor != null and is_instance_valid(_username_editor):
		return
	var panel := PanelContainer.new()
	panel.name = "UsernameSetup"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300.0
	panel.offset_top = -120.0
	panel.offset_right = 300.0
	panel.offset_bottom = 120.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.020, 0.027, 0.98), Color(0.66, 0.07, 0.09, 0.78), 20))
	_safe_root.add_child(panel)
	var margin := MarginContainer.new()
	_set_margins(margin, 24, 24, 20, 20)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "ELIGE TU NOMBRE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	var hint := Label.new()
	hint.text = "1–12 caracteres · letras, números o _ · sin emojis"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.64, 0.66, 0.70))
	vbox.add_child(hint)
	_username_editor = LineEdit.new()
	_username_editor.max_length = 12
	_username_editor.placeholder_text = "Nombre de superviviente"
	_username_editor.custom_minimum_size = Vector2(0, 54)
	vbox.add_child(_username_editor)
	var confirm := Button.new()
	confirm.text = "CONFIRMAR"
	confirm.custom_minimum_size = Vector2(0, 54)
	_apply_button_style(confirm, true)
	vbox.add_child(confirm)
	confirm.pressed.connect(_submit_username)
	_username_editor.text_submitted.connect(func(_value: String) -> void: _submit_username())

func _submit_username() -> void:
	if _username_editor == null:
		return
	if GuestIdentity.set_username(_username_editor.text):
		_status_label.text = "IDENTIDAD GUEST GUARDADA"
	else:
		_status_label.text = "NOMBRE INVÁLIDO · USA 1–12 LETRAS, NÚMEROS O _"

func _display_username() -> String:
	return GuestIdentity.username if not GuestIdentity.username.is_empty() else "NUEVO SUPERVIVIENTE"

func _open_character_panel() -> void:
	_character_panel.visible = true

func _close_character_panel() -> void:
	_character_panel.visible = false

func _select_character(character_id: StringName) -> void:
	GuestIdentity.set_selected_character(character_id)
	_selected_character = character_id
	_refresh_character()
	_character_panel.visible = false
	_status_label.text = "PERSONAJE SELECCIONADO"

func _refresh_character() -> void:
	var character := CharacterCatalog.get_character(_selected_character)
	if _character_name != null:
		_character_name.text = String(character.get("name", "OPERADOR"))
	if _character_role != null:
		_character_role.text = String(character.get("role", "SUPERVIVIENTE"))
	if _character_mesh != null:
		var material := StandardMaterial3D.new()
		var accent: Color = character.get("accent", Color(0.65, 0.07, 0.09))
		material.albedo_color = Color(accent.r * 0.75 + 0.12, accent.g * 0.75 + 0.12, accent.b * 0.75 + 0.12)
		material.metallic = 0.18
		material.roughness = 0.58
		_character_mesh.material_override = material

func _on_start_pressed() -> void:
	if not GuestIdentity.has_complete_profile():
		_status_label.text = "CONFIGURA UN NOMBRE ANTES DE INICIAR"
		_build_username_editor()
		return
	if selected_mode != PartyMode.SOLO:
		_status_label.text = "CREA O COMPLETA TU %s ANTES DE INICIAR" % ("DÚO" if selected_mode == PartyMode.DUO else "ESCUADRA")
		return
	_start_button.disabled = true
	_status_label.text = "PREPARANDO PARTIDA..."
	start_requested.emit(int(selected_mode))

func _on_identity_username_changed(_username: String) -> void:
	_refresh_identity()
	_refresh_mode()

func _on_identity_character_changed(character_id: StringName) -> void:
	_selected_character = character_id
	_refresh_character()

func _show_coming_soon(section: String) -> void:
	_status_label.text = "%s · SIGUIENTE BLOQUE DE PHASE 11" % section.to_upper()

func _set_margins(container: MarginContainer, left: int, right: int, top: int, bottom: int) -> void:
	container.add_theme_constant_override("margin_left", left)
	container.add_theme_constant_override("margin_right", right)
	container.add_theme_constant_override("margin_top", top)
	container.add_theme_constant_override("margin_bottom", bottom)

func _panel_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style

func _apply_button_style(button: Button, primary: bool) -> void:
	var normal_bg := Color(0.62, 0.035, 0.045, 0.94) if primary else Color(0.035, 0.042, 0.052, 0.94)
	var hover_bg := Color(0.74, 0.045, 0.055, 1.0) if primary else Color(0.060, 0.068, 0.080, 1.0)
	var border := Color(0.88, 0.12, 0.14, 0.82) if primary else Color(0.28, 0.31, 0.36, 0.72)
	button.add_theme_stylebox_override("normal", _panel_style(normal_bg, border, 10))
	button.add_theme_stylebox_override("hover", _panel_style(hover_bg, border, 10))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.48, 0.025, 0.035, 1.0), Color(1.0, 0.20, 0.22, 0.90), 10))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
