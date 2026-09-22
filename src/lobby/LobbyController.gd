class_name DeadfallLobbyController
extends Control

signal start_requested(mode: int)
enum PartyMode { SOLO = 1, DUO = 2, SQUAD = 4 }
const UI = preload("res://src/ui/TacticalTheme.gd")
const Backdrop = preload("res://src/ui/TacticalBackdrop.gd")
const Stage = preload("res://src/lobby/TacticalStage.gd")
const SafeAreaScript = preload("res://src/mobile/SafeArea.gd")
const CharacterCatalog = preload("res://src/lobby/CharacterCatalog.gd")
const PartyAvatarScript = preload("res://src/lobby/LobbyPartyAvatar.gd")

var selected_game_mode := "campaign"
var _game_mode_button: Button
var selected_mode: PartyMode = PartyMode.SOLO
var _safe_root: Control
var _username_label: Label
var _status_label: Label
var _mode_buttons: Dictionary = {}
var _party_labels: Array[Label] = []
var _party_avatars: Array[Control] = []
var _party_slots: Array[Control] = []
var _party_title: Label
var _character_panel: PanelContainer
var _character_name: Label
var _character_role: Label
var _start_button: Button
var _selected_character: StringName = &"operator_01"
var _stage_view: Control
var _overlay: PanelContainer
var _stage_info: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI.apply(self)
	add_child(Backdrop.new())
	_safe_root = SafeAreaScript.new()
	_safe_root.name = "SafeArea"
	_safe_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_safe_root)
	_safe_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_selected_character = GuestIdentity.selected_character
	_build_top_bar()
	_build_stage()
	_build_navigation()
	_build_party_rail()
	_build_bottom_bar()
	_refresh_identity()
	_refresh_character()
	_refresh_mode()
	GuestIdentity.username_changed.connect(_on_identity_username_changed)
	GuestIdentity.selected_character_changed.connect(_on_identity_character_changed)
	SocialClient.account_updated.connect(func(_account: Dictionary) -> void: _refresh_identity())
	var old_badge := get_node_or_null("PublicPlayerId") as Control
	if old_badge != null:
		old_badge.hide()
	AudioDirector.set_context(&"lobby")
	NetworkTelemetry.set_frontend_mode(true)

func _build_top_bar() -> void:
	var card := VBoxContainer.new()
	card.name = "IdentityCard"
	UI.place(card, _safe_root, Rect2(0.03, 0.025, 0.30, 0.10))
	card.add_theme_constant_override("separation", 0)
	card.add_child(UI.label("N E X O R A   /   D E A D F A L L", 23, UI.AMBER))
	_username_label = UI.label("", 34)
	card.add_child(_username_label)
	var brand := UI.label("CENTRO DE OPERACIONES", 24, UI.MUTED)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.place(brand, _safe_root, Rect2(0.32, 0.035, 0.34, 0.05))
	_status_label = UI.label("", 21, UI.CYAN)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UI.place(_status_label, _safe_root, Rect2(0.25, 0.095, 0.49, 0.04))

func _build_stage() -> void:
	_stage_view = Stage.new()
	_stage_view.name = "OperatorStage"
	UI.place(_stage_view, _safe_root, Rect2(0.20, 0.14, 0.55, 0.65))
	var info := VBoxContainer.new()
	_stage_info = info
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 0)
	UI.place(info, _safe_root, Rect2(0.24, 0.70, 0.40, 0.10))
	_character_name = UI.label("", 46)
	info.add_child(_character_name)
	_character_role = UI.label("", 22, UI.AMBER)
	info.add_child(_character_role)

func _build_navigation() -> void:
	var briefing := PanelContainer.new()
	briefing.add_theme_stylebox_override("panel", UI.style())
	UI.place(briefing, _safe_root, Rect2(0.03, 0.18, 0.17, 0.19))
	var copy := UI.column(briefing, 2)
	copy.add_child(UI.label("CAMPAÑA  /  01", 21, UI.CYAN))
	copy.add_child(UI.label("PRIMERA\nSEÑAL", 39))
	copy.add_child(UI.label("Distrito del brote", 23, UI.MUTED))
	var nav := VBoxContainer.new()
	nav.name = "Navigation"
	UI.place(nav, _safe_root, Rect2(0.03, 0.42, 0.17, 0.31))
	for item in [
		["OPERADORES", "operator", _open_character_panel],
		["ARSENAL", "rifle", _open_armory],
		["AJUSTES", "settings", _open_settings],
	]:
		var button := UI.button(item[0], item[2], false, item[1])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nav.add_child(button)

func _build_party_rail() -> void:
	var rail := PanelContainer.new()
	rail.name = "PartyRail"
	rail.add_theme_stylebox_override("panel", UI.style())
	UI.place(rail, _safe_root, Rect2(0.77, 0.18, 0.20, 0.59))
	var column := UI.column(rail, 10)
	_party_title = UI.label("TU EQUIPO", 30)
	column.add_child(_party_title)
	column.add_child(UI.label("SUPERVIVIENTES", 20, UI.CYAN))
	for index in range(4):
		var slot := PanelContainer.new()
		slot.name = "PartySlot%d" % (index + 1)
		slot.custom_minimum_size.y = 104
		slot.add_theme_stylebox_override("panel", UI.style(Color(0.04, 0.10, 0.13, 0.86), Color(0.3, 0.6, 0.65, 0.22), 12))
		column.add_child(slot)
		_party_slots.append(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		slot.add_child(row)
		var number := UI.label("%02d" % (index + 1), 38, UI.AMBER)
		number.custom_minimum_size.x = 46
		row.add_child(number)
		var label := UI.label("", 22)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(label)
		_party_labels.append(label)

func _build_bottom_bar() -> void:
	var bar := PanelContainer.new()
	bar.name = "MatchControls"
	bar.add_theme_stylebox_override("panel", UI.style())
	UI.place(bar, _safe_root, Rect2(0.23, 0.80, 0.74, 0.17))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	bar.add_child(row)
	var column := UI.column(row, 4)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_game_mode_button = UI.button("ZOMBIS · CAMPAÑA  ›", _open_mode_picker)
	_game_mode_button.custom_minimum_size.y = 46
	_game_mode_button.add_theme_font_size_override("font_size", 23)
	column.add_child(_game_mode_button)
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 10)
	column.add_child(modes)
	for mode in [1, 2, 4]:
		var title := "SOLO" if mode == 1 else ("DÚO" if mode == 2 else "ESCUADRA")
		var button := UI.button(title, _set_mode.bind(mode), false, "operator" if mode == 1 else "squad")
		button.custom_minimum_size.x = 145 if mode != 4 else 190
		button.toggle_mode = true
		modes.add_child(button)
		_mode_buttons[mode] = button
	_start_button = UI.button("INICIAR SOLO", _on_start_pressed, true, "play")
	_start_button.custom_minimum_size.x = 290
	_start_button.add_theme_font_size_override("font_size", 32)
	row.add_child(_start_button)

func _new_overlay(title: String) -> VBoxContainer:
	if is_instance_valid(_overlay):
		_overlay.free()
	var social := get_node_or_null("SocialOverlay")
	if social != null and is_instance_valid(social.get("_modal")):
		social.get("_modal").hide()
	set_stage_covered(true)
	_overlay = PanelContainer.new()
	_overlay.name = "TacticalOverlay"
	_overlay.add_theme_stylebox_override("panel", UI.style(Color(0.02, 0.04, 0.06, 0.99), UI.CYAN, 26))
	UI.place(_overlay, _safe_root, Rect2(0.20, 0.14, 0.77, 0.65))
	var box := UI.column(_overlay, 16)
	var header := HBoxContainer.new()
	box.add_child(header)
	var label := UI.label(title, 38)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	header.add_child(UI.button("VOLVER", _close_character_panel, false, "back"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var content := UI.column(scroll, 16)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return content

func _open_character_panel() -> void:
	var content := _new_overlay("OPERADORES")
	_character_panel = _overlay
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	content.add_child(row)
	for character in CharacterCatalog.all():
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", UI.style())
		row.add_child(card)
		var box := UI.column(card, 8)
		var preview := Stage.new()
		preview.custom_minimum_size = Vector2(300, 270)
		box.add_child(preview)
		preview.set_members([{"selected_character": character.id}], 1)
		box.add_child(UI.label(character.name, 32, character.accent))
		box.add_child(UI.label(character.role, 22, UI.MUTED))
		var desc := UI.label(character.description, 22)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(desc)
		var selected: bool = GuestIdentity.selected_character == character.id
		box.add_child(UI.button("EQUIPADO" if selected else "EQUIPAR", _select_character.bind(character.id), not selected, "operator"))

func _open_armory() -> void:
	var box := _new_overlay("ARSENAL")
	box.add_child(UI.label("Tu equipo de supervivencia", 24, UI.MUTED))
	var preview := Stage.new()
	preview.custom_minimum_size.y = 270
	box.add_child(preview)
	preview.show_weapon(&"nxr_rifle_01")
	var name_label := UI.label("NXR-4  /  FUSIL DE ASALTO", 32, UI.AMBER)
	box.add_child(name_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	for item in [["nxr_rifle_01", "NXR-4", "FUSIL DE ASALTO"], ["nxr_pistol_01", "NXR-9", "ARMA SECUNDARIA"], ["machete", "MACHETE", "COMBATE CUERPO A CUERPO"]]:
		var button := UI.button(item[1], func() -> void:
			preview.show_weapon(StringName(item[0]))
			name_label.text = "%s  /  %s" % [item[1], item[2]]
		, false, "rifle")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	box.add_child(UI.label("Cambia de arma durante la partida con el selector del HUD.", 22, UI.MUTED))

func _open_settings() -> void:
	var box := _new_overlay("AJUSTES")
	_add_slider(box, "Volumen general", Settings.master_volume, Settings.set_master_volume)
	_add_slider(box, "Música", Settings.music_volume, Settings.set_music_volume)
	for bus in ["SFX", "UI", "Ambience"]:
		var title: String = {"SFX": "Combate y enemigos", "UI": "Interfaz", "Ambience": "Ambiente"}[bus]
		_add_slider(box, title, Settings.get_audio_volume(bus), Settings.set_audio_volume.bind(bus))
	_add_slider(box, "Sensibilidad", Settings.camera_sensitivity, Settings.set_camera_sensitivity, 0.10)
	var row := HBoxContainer.new()
	box.add_child(row)
	var label := UI.label("Calidad gráfica", 26)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var quality := OptionButton.new()
	quality.custom_minimum_size = Vector2(320, 60)
	for value in ["Fluida", "Estándar", "Ultra", "Ultra HD"]:
		quality.add_item(value)
	quality.select(int(Settings.quality_tier))
	quality.item_selected.connect(Settings.set_quality_tier)
	row.add_child(quality)
	box.add_child(UI.label("Los cambios se guardan automáticamente. El HUD se personaliza durante la partida.", 22, UI.MUTED))

func _add_slider(box: Control, title: String, value: float, callback: Callable, minimum: float = 0.0) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 54
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	var label := UI.label(title, 26)
	label.custom_minimum_size.x = 270
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var amount := UI.label("%d%%" % roundi(value * 100), 26, UI.AMBER)
	amount.custom_minimum_size.x = 72
	row.add_child(amount)
	slider.value_changed.connect(func(next: float) -> void:
		callback.call(next)
		amount.text = "%d%%" % roundi(next * 100)
	)

func _close_character_panel() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_character_panel = null
	set_stage_covered(false)

func set_stage_covered(covered: bool) -> void:
	if is_instance_valid(_stage_view):
		_stage_view.visible = not covered
	if is_instance_valid(_stage_info):
		_stage_info.visible = not covered

func _select_character(character_id: StringName) -> void:
	GuestIdentity.set_selected_character(character_id)
	_close_character_panel()
	_status_label.text = "OPERADOR EQUIPADO"

func _set_mode(mode: int) -> void:
	if mode not in preload("res://src/modes/ModeCatalog.gd").find(selected_game_mode).get("formations", [1, 2, 4]):
		_status_label.text = "ESA FORMACIÓN NO ESTÁ DISPONIBLE EN ESTE MODO"
		return
	if mode not in [1, 2, 4]:
		return
	var party := SocialClient.current_party
	if not Dictionary(party.get("match", {})).is_empty() or not Dictionary(party.get("queue", {})).is_empty():
		_status_label.text = "ESPERA A QUE TERMINE LA PARTIDA"
		return
	if mode > 1 and not party.is_empty() and String(party.get("leader_guest_id", "")) != GuestIdentity.guest_id:
		_status_label.text = "SOLO EL LÍDER PUEDE CAMBIAR LA FORMACIÓN"
		return
	selected_mode = mode as PartyMode
	_refresh_mode()

func _refresh_mode() -> void:
	for key in _mode_buttons:
		var button: Button = _mode_buttons[key]
		button.disabled = int(key) not in preload("res://src/modes/ModeCatalog.gd").find(selected_game_mode).get("formations", [1, 2, 4])
		button.set_pressed_no_signal(int(key) == int(selected_mode))
		UI.skin_button(button, button.button_pressed)
	var title := "SOLO" if selected_mode == 1 else ("DÚO" if selected_mode == 2 else "ESCUADRA")
	_party_title.text = "TU EQUIPO  /  %s" % title
	_start_button.text = "INICIAR %s" % title
	_status_label.text = "PREPARADO" if selected_mode == 1 else "INVITA A TUS COMPAÑEROS"
	if is_instance_valid(_game_mode_button):
		_game_mode_button.text = "%s  ›" % preload("res://src/modes/ModeCatalog.gd").find(selected_game_mode).get("title", "CAMPAÑA")
	update_party_members(Array(SocialClient.current_party.get("members", [])), int(selected_mode))

func update_party_members(members: Array, capacity: int) -> void:
	var shown := members.duplicate(true)
	if shown.is_empty():
		shown.append({"guest_id": GuestIdentity.guest_id, "username": _display_username(), "selected_character": _selected_character, "leader": true, "online": true})
	_stage_view.call("set_members", shown, capacity)
	for index in range(_party_slots.size()):
		_party_slots[index].visible = index < capacity
		if index < shown.size():
			var member: Dictionary = shown[index]
			_party_labels[index].text = "%s\n%s" % [String(member.get("username", "Superviviente")), "LÍDER" if member.get("leader", false) else "EN EL EQUIPO"]
		else:
			_party_labels[index].text = "PLAZA LIBRE\nInvita por código"
	if capacity > 1:
		_character_name.text = "JUNTOS SOBREVIVIMOS"
		_character_name.add_theme_font_size_override("font_size", 34)
		_character_role.text = "%d / %d SUPERVIVIENTES" % [shown.size(), capacity]
	else:
		_character_name.add_theme_font_size_override("font_size", 46)
		_refresh_character()

func _refresh_identity() -> void:
	_username_label.text = "%s   /   ID %s" % [_display_username(), String(SocialClient.current_account.get("public_id", "—"))]

func _display_username() -> String:
	return GuestIdentity.username if not GuestIdentity.username.is_empty() else "SUPERVIVIENTE"

func _refresh_character() -> void:
	var character := CharacterCatalog.get_character(_selected_character)
	_character_name.text = character.name
	_character_role.text = "%s  /  ARRASTRA PARA GIRAR" % character.role

func _on_identity_username_changed(_username: String) -> void:
	_refresh_identity()

func _on_identity_character_changed(character_id: StringName) -> void:
	_selected_character = character_id
	var members: Array = Array(SocialClient.current_party.get("members", [])).duplicate(true)
	for member in members:
		if String(member.get("guest_id", "")) == GuestIdentity.guest_id:
			member["selected_character"] = character_id
	update_party_members(members, int(selected_mode))

func _on_start_pressed() -> void:
	if not GuestIdentity.has_complete_profile():
		_status_label.text = "COMPLETA TU CUENTA ANTES DE INICIAR"
		return
	# SocialOverlay owns online start for every formation, including solo.
	_status_label.text = "PREPARANDO PARTIDA"

func _open_mode_picker() -> void:
	var box := _new_overlay("ELIGE TU PARTIDA")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	box.add_child(grid)
	for definition in preload("res://src/modes/ModeCatalog.gd").MODES:
		var card := PanelContainer.new()
		card.custom_minimum_size.x = 590
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", UI.style(Color(0.025, 0.07, 0.09, 0.96), UI.AMBER if definition.id == selected_game_mode else UI.CYAN, 20))
		grid.add_child(card)
		var content := UI.column(card, 8)
		content.add_child(UI.label(String(definition.tag), 20, UI.CYAN))
		content.add_child(UI.label(String(definition.title), 30, UI.AMBER))
		var description := UI.label(String(definition.description), 23, UI.MUTED)
		description.custom_minimum_size = Vector2(520, 64)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(description)
		content.add_child(UI.button("SELECCIONADO" if definition.id == selected_game_mode else "SELECCIONAR", _select_game_mode.bind(String(definition.id)), definition.id == selected_game_mode))

func _select_game_mode(value: String) -> void:
	var party := SocialClient.current_party
	if not Dictionary(party.get("match", {})).is_empty() or not Dictionary(party.get("queue", {})).is_empty():
		_status_label.text = "CANCELA LA BÚSQUEDA ANTES DE CAMBIAR DE MODO"
		return
	if not party.is_empty() and String(party.get("leader_guest_id", "")) != GuestIdentity.guest_id:
		_status_label.text = "SOLO EL LÍDER PUEDE ELEGIR EL MODO"
		return
	var definition := preload("res://src/modes/ModeCatalog.gd").find(value)
	if definition.is_empty(): return
	if Array(party.get("members", [])).size() > int(Array(definition.formations).back()):
		_status_label.text = "EL EQUIPO ES DEMASIADO GRANDE PARA ESTE MODO"
		return
	selected_game_mode = value
	if int(selected_mode) not in definition.formations: selected_mode = int(Array(definition.formations).back()) as PartyMode
	_refresh_mode()
	_close_character_panel()
