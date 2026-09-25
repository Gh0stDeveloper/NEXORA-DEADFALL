class_name DeadfallSocialHub
extends Control

signal closed
signal chat_requested(guest_id: String, username: String)
const UI = preload("res://src/ui/TacticalTheme.gd")
const Stage = preload("res://src/lobby/TacticalStage.gd")
const Catalog = preload("res://src/lobby/CharacterCatalog.gd")
var section := "profile"
var _content: Control
var _nav: Dictionary = {}
var _status: Label
var _profile: Dictionary = {}
var _friends: Dictionary = {}
var _history: Array = []
var _search_results: Array = []
var _query := ""
var _search: LineEdit
var _history_received := false
var _friends_received := false

func _ready() -> void:
	name = "SocialHub"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI.apply(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := preload("res://src/ui/TacticalBackdrop.gd").new()
	add_child(backdrop)
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.03, 0.05, 0.80)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(dim, self, Rect2(0, 0, 1, 1))
	var safe := preload("res://src/mobile/SafeArea.gd").new()
	add_child(safe)
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI.place(UI.label("N E X O R A  /  EXPEDIENTE", 28, UI.AMBER), safe, Rect2(0.035, 0.03, 0.7, 0.06))
	UI.place(UI.button("VOLVER", _close, false, "back"), safe, Rect2(0.82, 0.025, 0.15, 0.07))
	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	UI.place(nav, safe, Rect2(0.035, 0.17, 0.17, 0.66))
	for item in [["profile", "PERFIL"], ["history", "HISTORIAL"], ["friends", "AMIGOS"], ["search", "AÑADIR"], ["requests", "SOLICITUDES"]]:
		var button := UI.button(item[1], show_section.bind(item[0]))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 80
		nav.add_child(button)
		_nav[item[0]] = button
	_content = Control.new()
	UI.place(_content, safe, Rect2(0.235, 0.135, 0.735, 0.76))
	_status = UI.label("", 23, UI.CYAN)
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UI.place(_status, safe, Rect2(0.235, 0.915, 0.735, 0.05))
	_profile = SocialClient.current_account.duplicate(true)
	_friends = SocialClient.friends.duplicate(true)
	SocialClient.profile_loaded.connect(_on_profile)
	SocialClient.friends_updated.connect(_on_friends)
	SocialClient.history_loaded.connect(_on_history)
	SocialClient.players_found.connect(_on_search)
	SocialClient.request_failed.connect(_on_failure)
	var poll := Timer.new()
	poll.wait_time = 5.0
	poll.timeout.connect(func() -> void:
		if section in ["friends", "requests"]: SocialClient.refresh_friends()
	)
	add_child(poll)
	poll.start()
	show_section(section)

func show_section(value: String) -> void:
	section = value
	if not is_instance_valid(_content):
		return
	for key in _nav:
		UI.skin_button(_nav[key], key == section)
	_status.text = ""
	_render()
	match section:
		"profile": SocialClient.load_profile()
		"history": SocialClient.load_history()
		"friends", "requests": SocialClient.refresh_friends()

func _clear() -> void:
	_search = null
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

func _render() -> void:
	_clear()
	match section:
		"profile": _render_profile()
		"history": _render_history()
		"friends", "requests", "search": _render_friends()

func _render_profile() -> void:
	var character := Catalog.get_character(StringName(_profile.get("selected_character", GuestIdentity.selected_character)))
	var preview := Stage.new()
	UI.place(preview, _content, Rect2(0, 0.02, 0.51, 0.86))
	preview.set_members([{"selected_character": character.id}], 1)
	UI.place(UI.label(character.name, 48, character.accent), _content, Rect2(0.04, 0.82, 0.46, 0.09))
	UI.place(UI.label(character.role, 24, UI.MUTED), _content, Rect2(0.04, 0.92, 0.46, 0.06))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.style(Color(0.025, 0.065, 0.09, 0.95), UI.CYAN, 24))
	UI.place(card, _content, Rect2(0.53, 0.015, 0.47, 0.94))
	var box := UI.column(card, 14)
	box.add_child(UI.label("SUPERVIVIENTE  /  DEADFALL", 22, UI.CYAN))
	var user := UI.label(String(_profile.get("username", GuestIdentity.username)), 42)
	user.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(user)
	var public_id := String(_profile.get("public_id", "—"))
	box.add_child(UI.label("ID  %s" % public_id, 28, UI.AMBER))
	var copy := UI.button("COPIAR ID", func() -> void:
		DisplayServer.clipboard_set(public_id)
		_status.text = "ID copiado. Compártelo con tus amigos."
	, false, "operator")
	copy.disabled = public_id == "—"
	box.add_child(copy)
	box.add_child(HSeparator.new())
	box.add_child(UI.label("TU TRAYECTORIA", 28))
	var stats := Dictionary(_profile.get("stats", {}))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	box.add_child(grid)
	for item in [["PARTIDAS", "matches"], ["VICTORIAS", "wins"], ["BAJAS", "kills"], ["DAÑO", "damage"]]:
		var stat := UI.column(grid, 0)
		stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat.add_child(UI.label(str(int(stats.get(item[1], 0))), 42, UI.AMBER))
		stat.add_child(UI.label(item[0], 21, UI.MUTED))
	box.add_child(UI.label("Últimas 100 partidas · desde esta versión", 20, UI.MUTED))
	box.add_child(UI.button("VER HISTORIAL", show_section.bind("history"), true))

func _list_layout(title: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	_content.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_child(UI.label(title, 34, UI.AMBER))
	return column

func _scroll_list(parent: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var list := UI.column(scroll, 12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return list

func _render_friends() -> void:
	var title: String = {"friends": "AMIGOS DEL JUEGO", "requests": "SOLICITUDES RECIBIDAS", "search": "ENCUENTRA A TU EQUIPO"}[section]
	var column := _list_layout(title)
	if section == "search":
		var row := HBoxContainer.new()
		column.add_child(row)
		_search = LineEdit.new()
		_search.placeholder_text = "Nombre o ID de jugador"
		_search.max_length = 24
		_search.text = _query
		_search.custom_minimum_size.y = 64
		_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(_search)
		_search.text_submitted.connect(func(_text: String) -> void: _submit_search())
		row.add_child(UI.button("BUSCAR", _submit_search, true))
	var list := _scroll_list(column)
	var items: Array = _search_results if section == "search" else Array(_friends.get("incoming" if section == "requests" else "accepted", []))
	if items.is_empty():
		var empty := "Escribe al menos dos caracteres para buscar."
		if section == "friends": empty = "Tu equipo empieza con una amistad. Usa AÑADIR para buscar jugadores." if _friends_received else "Cargando amigos…"
		if section == "requests": empty = "No tienes solicitudes pendientes." if _friends_received else "Cargando solicitudes…"
		if section == "search" and not _query.is_empty(): empty = "No hay jugadores que coincidan con tu búsqueda."
		var label := UI.label(empty, 28, UI.MUTED)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(label)
	for value in items:
		list.add_child(_friend_card(Dictionary(value)))

func _friend_card(profile: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size.y = 116
	card.add_theme_stylebox_override("panel", UI.style(Color(0.025, 0.06, 0.08, 0.95), Color(0.3, 0.6, 0.7, 0.35), 16))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	card.add_child(row)
	var character := Catalog.get_character(StringName(profile.get("selected_character", "operator_01")))
	var badge := PanelContainer.new()
	badge.custom_minimum_size.x = 72
	badge.add_theme_stylebox_override("panel", UI.style(Color(0.08, 0.18, 0.22), character.accent, 8))
	var monogram := UI.label(String(profile.get("username", "?" )).left(1).to_upper(), 44, character.accent)
	monogram.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(monogram)
	row.add_child(badge)
	var identity := UI.column(row, 0)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(UI.label(String(profile.get("username", "Jugador")), 32))
	identity.add_child(UI.label("ID %s  ·  %s" % [profile.get("public_id", "—"), character.name], 22, UI.MUTED))
	var activity := String(profile.get("activity", "ONLINE" if profile.get("online", false) else "OFFLINE"))
	row.add_child(UI.label(String({"ONLINE": "EN LÍNEA", "IN_PARTY": "EN EQUIPO", "IN_MATCH": "JUGANDO", "OFFLINE": "DESCONECTADO"}.get(activity, "EN LÍNEA")), 23, UI.CYAN if activity != "OFFLINE" else UI.MUTED))
	var guest := String(profile.get("guest_id", ""))
	if section == "requests" or bool(profile.get("incoming_request", false)):
		row.add_child(_action("ACEPTAR", func() -> void: SocialClient.accept_friend(guest), true))
		row.add_child(_action("RECHAZAR", func() -> void: SocialClient.reject_friend(guest)))
	elif section == "friends" or bool(profile.get("is_friend", false)):
		row.add_child(_action("MENSAJE", func() -> void:
			_close()
			chat_requested.emit(guest, String(profile.get("username", "Jugador")))
		))
	else:
		var pending: bool = bool(profile.get("request_pending", false)) or Array(_friends.get("outgoing_ids", [])).has(guest)
		var button := _action("ENVIADA" if pending else "AÑADIR", func() -> void:
			SocialClient.request_friend(String(profile.get("public_id", "")))
			_status.text = "Enviando solicitud…"
		, true)
		button.disabled = pending
		row.add_child(button)
	return card

func _action(text: String, callback: Callable, primary: bool = false) -> Button:
	var button := UI.button(text, callback, primary)
	button.add_theme_font_size_override("font_size", 21)
	button.custom_minimum_size.y = 54
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return button

func _submit_search() -> void:
	if not is_instance_valid(_search): return
	_query = _search.text.strip_edges()
	if _query.length() < 2:
		_status.text = "Escribe al menos dos caracteres."
		return
	_status.text = "Buscando jugadores…"
	SocialClient.search_players(_query)

func _render_history() -> void:
	var column := _list_layout("HISTORIAL DE PARTIDAS")
	var headings := HBoxContainer.new()
	headings.add_theme_constant_override("separation", 20)
	column.add_child(headings)
	for item in [["RESULTADO", 208], ["MODO", 265], ["BAJAS", 70], ["DURACIÓN", 100], ["FECHA (UTC)", 210]]:
		var heading := UI.label(String(item[0]), 21, UI.MUTED)
		heading.custom_minimum_size.x = int(item[1])
		headings.add_child(heading)
	var list := _scroll_list(column)
	if _history.is_empty():
		var label := UI.label("Aún no hay partidas guardadas. Tu próxima partida aparecerá aquí." if _history_received else "Cargando historial…", 28, UI.MUTED)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(label)
	for value in _history:
		var entry := Dictionary(value)
		var outcome := String(entry.get("outcome", "ABORTED"))
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.style(Color(0.025, 0.06, 0.08, 0.95), UI.AMBER if outcome == "VICTORY" else Color(0.3, 0.5, 0.6, 0.35), 18))
		list.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		card.add_child(row)
		var date := Time.get_datetime_string_from_unix_time(int(entry.get("completed_unix", 0))).replace("T", " ").left(16)
		var mode := String(entry.get("mode", "campaign"))
		var names := {"campaign": "CAMPAÑA", "waves": "10 OLEADAS", "endless": "INFINITAS", "pvp_ffa": "TODOS CONTRA TODOS", "pvp_duo": "DUELO DÚOS", "pvp_squad": "DUELO INTERNO"}
		for item in [[{"VICTORY": "VICTORIA", "DEFEAT": "DERROTA", "DRAW": "EMPATE", "ABORTED": "INTERRUMPIDA"}.get(outcome, outcome), 190], [names.get(mode, mode), 265], [str(int(entry.get("kills", 0))), 70], ["%02d:%02d" % [int(entry.get("duration", 0)) / 60, int(entry.get("duration", 0)) % 60], 100], [date, 210]]:
			var label := UI.label(String(item[0]), 23, UI.AMBER if outcome == "VICTORY" else Color.WHITE)
			label.custom_minimum_size.x = int(item[1])
			row.add_child(label)
		row.add_child(_action("VER", _show_match.bind(entry)))

func _show_match(entry: Dictionary) -> void:
	_status.text = "Daño: %d  ·  Puntuación del equipo: %d  ·  Oleada: %d  ·  Jugadores: %d" % [int(entry.get("damage", 0)), int(entry.get("score", 0)), int(entry.get("wave", 0)), int(entry.get("players", 1))]
	if String(entry.get("mode", "")).begins_with("pvp_"):
		_status.text = "Bajas: %d  ·  Daño: %d  ·  Jugadores: %d  ·  Objetivo: 10 bajas en 5 minutos" % [int(entry.get("kills", 0)), int(entry.get("damage", 0)), int(entry.get("players", 1))]

func _on_profile(profile: Dictionary) -> void:
	if String(profile.get("guest_id", "")) != GuestIdentity.guest_id: return
	_profile = profile.duplicate(true)
	if section == "profile": _render()

func _on_friends(snapshot: Dictionary) -> void:
	_friends = snapshot.duplicate(true)
	_friends_received = true
	_nav["requests"].text = "SOLICITUDES  %d" % Array(snapshot.get("incoming", [])).size()
	if section in ["friends", "requests", "search"]:
		_render()
		_status.text = "Lista actualizada"

func _on_search(players: Array, query: String) -> void:
	if query != _query: return
	_search_results = players.duplicate(true)
	if section == "search":
		_render()
		_status.text = "%d jugadores encontrados" % players.size()

func _on_history(matches: Array, stats: Dictionary) -> void:
	_history = matches.duplicate(true)
	_history_received = true
	_profile["stats"] = stats
	if section == "history": _render()

func _on_failure(operation: String, reason: String) -> void:
	if operation not in ["profile", "history", "friends", "player_search", "friend_request", "friend_accept", "friend_reject"]: return
	_status.text = "No se pudo completar. Reintenta desde esta sección."
	if reason == "rate_limited": _status.text = "Espera unos segundos antes de volver a intentarlo."
	if reason == "profile_not_found": _status.text = "No se encontró ese jugador. Revisa su nombre o ID."

func _close() -> void:
	closed.emit()
	queue_free()
