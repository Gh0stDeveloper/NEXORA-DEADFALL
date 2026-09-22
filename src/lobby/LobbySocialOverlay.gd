class_name DeadfallLobbySocialOverlay
extends Control

signal online_match_ready(match: Dictionary)

const UI = preload("res://src/ui/TacticalTheme.gd")

const POLL_SECONDS := 1.25
const DEFAULT_MISSION := "mission_01_first_signal"

var _lobby: Control
var _safe_root: Control
var _party_code_label: Label
var _join_code_edit: LineEdit
var _modal: PanelContainer
var _modal_title: Label
var _modal_body: VBoxContainer
var _chat_log: RichTextLabel
var _chat_edit: LineEdit
var _chat_friend_id := ""
var _last_mode := 1
var _poll_timer: Timer
var _last_match_emitted := ""
var _start_after_party_created := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	call_deferred("_initialize")

func _initialize() -> void:
	_lobby = get_parent() as Control
	if _lobby == null:
		return
	_safe_root = _lobby.get_node_or_null("SafeArea") as Control
	if _safe_root == null:
		call_deferred("_initialize")
		return
	_build_top_actions()
	_build_party_code_panel()
	_build_modal()
	SocialClient.party_updated.connect(_on_party_updated)
	SocialClient.friends_updated.connect(_on_friends_updated)
	SocialClient.profile_loaded.connect(_on_profile_loaded)
	SocialClient.chat_updated.connect(_on_chat_updated)
	SocialClient.match_ready.connect(_on_match_ready)
	SocialClient.request_failed.connect(_on_request_failed)
	var start_button := _lobby.get("_start_button") as Button
	if start_button != null:
		start_button.pressed.connect(request_start_match)
	_last_mode = int(_lobby.get("selected_mode"))
	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_SECONDS
	_poll_timer.one_shot = false
	_poll_timer.timeout.connect(_poll_social_state)
	add_child(_poll_timer)
	_poll_timer.start()
	if SocialClient.has_session():
		SocialClient.refresh_party()

func _process(_delta: float) -> void:
	if _lobby == null or not SocialClient.has_session():
		return
	var mode := int(_lobby.get("selected_mode"))
	if mode == _last_mode:
		return
	_last_mode = mode
	var current_match := Dictionary(SocialClient.current_party.get("match", {}))
	if not current_match.is_empty() or not Dictionary(SocialClient.current_party.get("queue", {})).is_empty():
		_set_status("NO PUEDES CAMBIAR FORMACIÓN DURANTE EL EMPAREJAMIENTO")
		return
	var current_capacity := int(SocialClient.current_party.get("capacity", 0))
	var leader_id := String(SocialClient.current_party.get("leader_guest_id", ""))
	if SocialClient.current_party.is_empty() or (current_capacity != mode and leader_id == GuestIdentity.guest_id):
		_set_status("PREPARANDO FORMACIÓN...")
		SocialClient.create_party(mode)

func request_start_match() -> void:
	if _lobby == null:
		return
	if not GuestIdentity.has_complete_profile():
		_set_status("CONFIGURA UN NOMBRE ANTES DE FORMAR ESCUADRA")
		return
	if not SocialClient.has_session():
		_set_status("CONECTANDO AL SERVICIO SOCIAL · INTENTA DE NUEVO")
		return
	var party := SocialClient.current_party
	if party.is_empty():
		_start_after_party_created = true
		_set_status("PREPARANDO TU PARTIDA...")
		SocialClient.create_party(int(_lobby.get("selected_mode")))
		return
	if String(party.get("leader_guest_id", "")) != GuestIdentity.guest_id:
		_set_status("ESPERANDO A QUE EL LÍDER INICIE LA PARTIDA")
		return
	if not Dictionary(party.get("queue", {})).is_empty():
		SocialClient.cancel_party_match()
		return
	var members: Array = Array(party.get("members", []))
	var expected_capacity := int(_lobby.get("selected_mode"))
	if int(party.get("capacity", expected_capacity)) != expected_capacity:
		_set_status("LA FORMACIÓN CAMBIÓ · ACTUALIZANDO ESCUADRA")
		SocialClient.refresh_party()
		return
	for member_value in members:
		var member := Dictionary(member_value)
		if not bool(member.get("online", true)):
			_set_status("ESPERANDO A QUE %s VUELVA A CONECTARSE" % String(member.get("username", "JUGADOR")))
			return
	var match := Dictionary(party.get("match", {}))
	if not match.is_empty():
		var status := String(match.get("status", "")).to_upper()
		if status in ["STARTING", "READY", "IN_MATCH"]:
			_set_status("EMPAREJAMIENTO %s" % status)
			return
	_set_status("BUSCANDO SERVIDOR PARA TODA LA ESCUADRA...")
	SocialClient.start_party_match(DEFAULT_MISSION, String(_lobby.get("selected_game_mode")))

func _build_top_actions() -> void:
	var row := HBoxContainer.new()
	row.name = "SocialActions"
	row.anchor_left = 0.68
	row.anchor_top = 0.028
	row.anchor_right = 0.97
	row.anchor_bottom = 0.085
	row.add_theme_constant_override("separation", 8)
	_safe_root.add_child(row)
	row.add_child(_small_button("EQUIPO", _open_party_management))
	row.add_child(_small_button("PERFIL", _open_profile))
	row.add_child(_small_button("AMIGOS", _open_friends))
	row.add_child(_small_button("CHAT", _open_party_chat))

func _build_party_code_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "SquadCodePanel"
	panel.anchor_left = 0.03
	panel.anchor_top = 0.78
	panel.anchor_right = 0.20
	panel.anchor_bottom = 0.97
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.014, 0.019, 0.026, 0.94), Color(0.30, 0.32, 0.36, 0.62), 14))
	_safe_root.add_child(panel)
	var margin := MarginContainer.new()
	_set_margins(margin, 12, 12, 10, 10)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)
	_party_code_label = Label.new()
	_party_code_label.text = "CÓDIGO: —"
	_party_code_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_party_code_label)
	_join_code_edit = LineEdit.new()
	_join_code_edit.max_length = 6
	_join_code_edit.placeholder_text = "CÓDIGO"
	_join_code_edit.custom_minimum_size = Vector2(0, 54)
	vbox.add_child(_join_code_edit)
	var join := Button.new()
	join.text = "UNIRSE"
	join.custom_minimum_size = Vector2(0, 54)
	_apply_button_style(join, true)
	vbox.add_child(join)
	join.pressed.connect(_join_by_code)
	_join_code_edit.text_submitted.connect(func(_value: String) -> void: _join_by_code())

func _build_modal() -> void:
	_modal = PanelContainer.new()
	_modal.name = "SocialModal"
	_modal.anchor_left = 0.20
	_modal.anchor_top = 0.14
	_modal.anchor_right = 0.97
	_modal.anchor_bottom = 0.79
	_modal.visible = false
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.add_theme_stylebox_override("panel", _panel_style(Color(0.010, 0.014, 0.020, 0.985), Color(0.58, 0.06, 0.08, 0.82), 20))
	_safe_root.add_child(_modal)
	_modal.visibility_changed.connect(func() -> void:
		if is_instance_valid(_lobby):
			_lobby.call("set_stage_covered", _modal.visible)
	)
	var margin := MarginContainer.new()
	_set_margins(margin, 24, 24, 20, 20)
	_modal.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	var header := HBoxContainer.new()
	vbox.add_child(header)
	_modal_title = Label.new()
	_modal_title.text = "SOCIAL"
	_modal_title.add_theme_font_size_override("font_size", 28)
	_modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_modal_title)
	var close := Button.new()
	close.text = "CERRAR"
	close.custom_minimum_size = Vector2(130, 46)
	_apply_button_style(close, false)
	header.add_child(close)
	close.pressed.connect(func() -> void: _modal.visible = false)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	_modal_body = VBoxContainer.new()
	_modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_body.name = "Body"
	_modal_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modal_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_modal_body)

func _open_party_management() -> void:
	_lobby.call("_close_character_panel")
	_modal.visible = true
	_modal_title.text = "ESCUADRA"
	_render_party_management(SocialClient.current_party)
	SocialClient.refresh_party()

func _render_party_management(party: Dictionary) -> void:
	if not _modal.visible or _modal_title.text != "ESCUADRA":
		return
	_clear_modal_body()
	if party.is_empty():
		var empty := Label.new()
		empty.text = "Selecciona DÚO o ESCUADRA para crear un equipo."
		empty.add_theme_font_size_override("font_size", 18)
		_modal_body.add_child(empty)
		return
	var code := String(party.get("code", ""))
	var leader_id := String(party.get("leader_guest_id", ""))
	var is_leader := leader_id == GuestIdentity.guest_id
	var match := Dictionary(party.get("match", {}))
	var match_locked := not Dictionary(party.get("queue", {})).is_empty() or (not match.is_empty() and String(match.get("status", "")).to_upper() in ["STARTING", "READY", "IN_MATCH"])

	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 10)
	_modal_body.add_child(code_row)
	var code_label := Label.new()
	code_label.text = "CÓDIGO  %s" % code
	code_label.add_theme_font_size_override("font_size", 25)
	code_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_row.add_child(code_label)
	var copy := Button.new()
	copy.text = "COPIAR"
	copy.custom_minimum_size = Vector2(120, 44)
	_apply_button_style(copy, false)
	code_row.add_child(copy)
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(code)
		_set_status("CÓDIGO DE ESCUADRA COPIADO")
	)

	var state := Label.new()
	state.text = "ESTADO  %s · %d/%d JUGADORES" % [String(party.get("state", "OPEN")), Array(party.get("members", [])).size(), int(party.get("capacity", 4))]
	state.add_theme_color_override("font_color", Color(0.68, 0.71, 0.76))
	_modal_body.add_child(state)

	if not match.is_empty():
		var match_label := Label.new()
		match_label.text = "PREPARANDO LA PARTIDA DE TU EQUIPO"
		match_label.add_theme_color_override("font_color", Color(0.80, 0.20, 0.22))
		_modal_body.add_child(match_label)

	var members_title := Label.new()
	members_title.text = "MIEMBROS"
	members_title.add_theme_font_size_override("font_size", 18)
	_modal_body.add_child(members_title)
	for member_value in Array(party.get("members", [])):
		_modal_body.add_child(_party_member_row(Dictionary(member_value), is_leader, match_locked))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	_modal_body.add_child(actions)
	if is_leader:
		var start := Button.new()
		start.text = "INICIAR PARTIDA" if not match_locked else "EMPAREJANDO..."
		start.disabled = match_locked
		start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		start.custom_minimum_size = Vector2(0, 56)
		_apply_button_style(start, true)
		actions.add_child(start)
		start.pressed.connect(request_start_match)
		if match_locked and String(match.get("status", "")).to_upper() != "IN_MATCH":
			var cancel := Button.new()
			cancel.text = "CANCELAR"
			cancel.custom_minimum_size = Vector2(150, 56)
			_apply_button_style(cancel, false)
			actions.add_child(cancel)
			cancel.pressed.connect(func() -> void: SocialClient.cancel_party_match())
	else:
		var waiting := Label.new()
		waiting.text = "EL LÍDER CONTROLA EL INICIO DE LA PARTIDA"
		waiting.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		waiting.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		actions.add_child(waiting)
	var leave := Button.new()
	leave.text = "SALIR"
	leave.disabled = match_locked
	leave.custom_minimum_size = Vector2(140, 56)
	_apply_button_style(leave, false)
	actions.add_child(leave)
	leave.pressed.connect(func() -> void:
		SocialClient.leave_party()
		_modal.visible = false
	)

func _party_member_row(member: Dictionary, local_is_leader: bool, match_locked: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 64)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.030, 0.038, 0.90), Color(0.23, 0.25, 0.29, 0.62), 10))
	var margin := MarginContainer.new()
	_set_margins(margin, 12, 12, 8, 8)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var identity := Label.new()
	var leader_text := " · LÍDER" if bool(member.get("leader", false)) else ""
	identity.text = "%s%s\nID %s · %s" % [String(member.get("username", "Jugador")), leader_text, String(member.get("public_id", "—")), String(member.get("selected_character", "operator_01")).to_upper()]
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(identity)
	var ping := int(member.get("ping_ms", 999))
	var online := bool(member.get("online", false))
	var ping_label := Label.new()
	ping_label.text = "PING %s" % (str(ping) if online and ping < 999 else "+999")
	ping_label.custom_minimum_size = Vector2(100, 0)
	ping_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(ping_label)
	var guest_id := String(member.get("guest_id", ""))
	if local_is_leader and guest_id != GuestIdentity.guest_id:
		var kick := Button.new()
		kick.text = "EXPULSAR"
		kick.disabled = match_locked
		kick.custom_minimum_size = Vector2(130, 44)
		_apply_button_style(kick, false)
		row.add_child(kick)
		kick.pressed.connect(func() -> void: SocialClient.kick_party_member(guest_id))
	return panel

func _open_profile() -> void:
	_open_social_hub("profile")

func _open_social_hub(section: String) -> void:
	_lobby.call("_close_character_panel")
	_modal.hide()
	var old := _safe_root.get_node_or_null("SocialHub")
	if old != null:
		old.call("show_section", section)
		return
	_lobby.call("set_stage_covered", true)
	var hub := preload("res://src/lobby/SocialHub.gd").new()
	hub.section = section
	hub.closed.connect(func() -> void: _lobby.call("set_stage_covered", false))
	hub.chat_requested.connect(_open_friend_chat)
	_safe_root.add_child(hub)

func _on_profile_loaded(profile: Dictionary) -> void:
	if not _modal.visible or _modal_title.text != "PERFIL":
		return
	_clear_modal_body()
	var username := Label.new()
	username.text = String(profile.get("username", GuestIdentity.username))
	username.add_theme_font_size_override("font_size", 34)
	_modal_body.add_child(username)
	var public_id := String(profile.get("public_id", "—"))
	var account_id := Label.new()
	account_id.text = "ID DE CUENTA\n%s" % public_id
	account_id.add_theme_font_size_override("font_size", 22)
	account_id.add_theme_color_override("font_color", Color(0.72, 0.74, 0.78))
	_modal_body.add_child(account_id)
	var character := Label.new()
	character.text = "PERSONAJE  %s" % String(profile.get("selected_character", "operator_01")).to_upper()
	_modal_body.add_child(character)
	var copy := Button.new()
	copy.text = "COPIAR ID"
	copy.custom_minimum_size = Vector2(220, 52)
	_apply_button_style(copy, true)
	_modal_body.add_child(copy)
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(public_id)
		_set_status("ID COPIADO")
	)

func _open_friends() -> void:
	_open_social_hub("friends")

func _on_friends_updated(snapshot: Dictionary) -> void:
	if _modal.visible and _modal_title.text == "AMIGOS":
		_render_friends(snapshot)

func _render_friends(snapshot: Dictionary) -> void:
	_clear_modal_body()
	var add_title := Label.new()
	add_title.text = "AGREGAR POR ID PÚBLICO"
	add_title.add_theme_font_size_override("font_size", 17)
	_modal_body.add_child(add_title)
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 8)
	_modal_body.add_child(add_row)
	var id_edit := LineEdit.new()
	id_edit.placeholder_text = "ID de 10 dígitos"
	id_edit.max_length = 10
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_edit.custom_minimum_size = Vector2(0, 48)
	add_row.add_child(id_edit)
	var send := Button.new()
	send.text = "SOLICITUD"
	send.custom_minimum_size = Vector2(150, 48)
	_apply_button_style(send, true)
	add_row.add_child(send)
	send.pressed.connect(func() -> void:
		var target := id_edit.text.strip_edges()
		if target.length() != 10 or not target.is_valid_int():
			_set_status("ID DE JUGADOR INVÁLIDO")
			return
		SocialClient.request_friend(target)
	)
	var incoming: Array = Array(snapshot.get("incoming", []))
	if not incoming.is_empty():
		var incoming_title := Label.new()
		incoming_title.text = "SOLICITUDES RECIBIDAS"
		incoming_title.add_theme_font_size_override("font_size", 17)
		_modal_body.add_child(incoming_title)
		for item in incoming:
			_modal_body.add_child(_incoming_friend_row(Dictionary(item)))
	var accepted: Array = Array(snapshot.get("accepted", []))
	var friends_title := Label.new()
	friends_title.text = "AMIGOS · %d" % accepted.size()
	friends_title.add_theme_font_size_override("font_size", 17)
	_modal_body.add_child(friends_title)
	if accepted.is_empty():
		var empty := Label.new()
		empty.text = "Aún no tienes amigos agregados."
		empty.add_theme_color_override("font_color", Color(0.58, 0.60, 0.64))
		_modal_body.add_child(empty)
	else:
		for item in accepted:
			_modal_body.add_child(_friend_row(Dictionary(item)))

func _incoming_friend_row(profile: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 52)
	var label := Label.new()
	label.text = "%s · ID %s" % [String(profile.get("username", "Jugador")), String(profile.get("public_id", "—"))]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var accept := Button.new()
	accept.text = "ACEPTAR"
	accept.custom_minimum_size = Vector2(130, 44)
	_apply_button_style(accept, true)
	row.add_child(accept)
	accept.pressed.connect(func() -> void: SocialClient.accept_friend(String(profile.get("guest_id", ""))))
	return row

func _friend_row(profile: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 52)
	var label := Label.new()
	var ping := int(profile.get("ping_ms", 999))
	label.text = "%s · ID %s · PING %s" % [String(profile.get("username", "Jugador")), String(profile.get("public_id", "—")), str(ping) if bool(profile.get("online", false)) and ping < 999 else "+999"]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var chat := Button.new()
	chat.text = "MENSAJE"
	chat.custom_minimum_size = Vector2(130, 44)
	_apply_button_style(chat, false)
	row.add_child(chat)
	chat.pressed.connect(_open_friend_chat.bind(String(profile.get("guest_id", "")), String(profile.get("username", "Jugador"))))
	return row

func _open_party_chat() -> void:
	_chat_friend_id = ""
	_lobby.call("_close_character_panel")
	_modal.visible = true
	_modal_title.text = "CHAT DE ESCUADRA"
	_build_chat_body()
	if not SocialClient.current_party.is_empty():
		_render_chat(Array(SocialClient.current_party.get("chat", [])))
	SocialClient.refresh_party()

func _open_friend_chat(guest_id: String, username: String) -> void:
	_chat_friend_id = guest_id
	_lobby.call("_close_character_panel")
	_modal.visible = true
	_modal_title.text = "CHAT · %s" % username
	_build_chat_body()
	SocialClient.load_friend_messages(guest_id)

func _build_chat_body() -> void:
	_clear_modal_body()
	_chat_log = RichTextLabel.new()
	_chat_log.bbcode_enabled = false
	_chat_log.fit_content = false
	_chat_log.scroll_active = true
	_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_log.custom_minimum_size = Vector2(0, 330)
	_modal_body.add_child(_chat_log)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_modal_body.add_child(row)
	_chat_edit = LineEdit.new()
	_chat_edit.max_length = 160
	_chat_edit.placeholder_text = "Escribe un mensaje"
	_chat_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_edit.custom_minimum_size = Vector2(0, 50)
	row.add_child(_chat_edit)
	var send := Button.new()
	send.text = "ENVIAR"
	send.custom_minimum_size = Vector2(140, 50)
	_apply_button_style(send, true)
	row.add_child(send)
	send.pressed.connect(_send_chat_message)
	_chat_edit.text_submitted.connect(func(_value: String) -> void: _send_chat_message())

func _send_chat_message() -> void:
	if _chat_edit == null:
		return
	var text := _chat_edit.text.strip_edges()
	if text.is_empty():
		return
	_chat_edit.clear()
	if _chat_friend_id.is_empty():
		SocialClient.send_party_message(text)
	else:
		SocialClient.send_friend_message(_chat_friend_id, text)

func _on_chat_updated(channel: String, messages: Array) -> void:
	if not _modal.visible:
		return
	if _chat_friend_id.is_empty() and channel == "party":
		_render_chat(messages)
	elif not _chat_friend_id.is_empty() and channel == "friend:%s" % _chat_friend_id:
		_render_chat(messages)

func _render_chat(messages: Array) -> void:
	if _chat_log == null:
		return
	var lines := PackedStringArray()
	for item in messages:
		if typeof(item) == TYPE_DICTIONARY:
			var message := Dictionary(item)
			lines.append("%s: %s" % [String(message.get("username", "Jugador")), String(message.get("text", ""))])
	_chat_log.text = "\n".join(lines)
	_chat_log.scroll_to_line(maxi(0, lines.size() - 1))

func _join_by_code() -> void:
	if _join_code_edit == null:
		return
	var code := _join_code_edit.text.strip_edges().to_upper()
	if code.length() != 6:
		_set_status("CÓDIGO DE EQUIPO INVÁLIDO")
		return
	_set_status("BUSCANDO ESCUADRA %s..." % code)
	SocialClient.join_party(code)

func _on_party_updated(party: Dictionary) -> void:
	if party.is_empty():
		_party_code_label.text = "CÓDIGO: —"
		_update_lobby_party_labels({})
		if _modal.visible and _modal_title.text == "ESCUADRA":
			_render_party_management({})
		return
	var code := String(party.get("code", ""))
	_party_code_label.text = "CÓDIGO: %s" % code
	var capacity := int(party.get("capacity", 4))
	if _lobby != null and int(_lobby.get("selected_mode")) != capacity:
		_lobby.set("selected_mode", capacity)
		if _lobby.has_method("_refresh_mode"):
			_lobby.call("_refresh_mode")
	_update_lobby_party_labels(party)
	if _modal.visible and _modal_title.text == "ESCUADRA":
		_render_party_management(party)
	elif _modal.visible and _chat_friend_id.is_empty() and _modal_title.text == "CHAT DE ESCUADRA":
		_render_chat(Array(party.get("chat", [])))
	var queue := Dictionary(party.get("queue", {}))
	var start_button := _lobby.get("_start_button") as Button
	if start_button != null:
		start_button.text = "CANCELAR BÚSQUEDA" if not queue.is_empty() else "INICIAR PARTIDA"
	if not queue.is_empty():
		_set_status("BUSCANDO JUGADORES · %s" % preload("res://src/modes/ModeCatalog.gd").find(String(queue.get("mode", "campaign"))).get("title", ""))
		return
	var queue_error := String(party.get("queue_error", ""))
	if not queue_error.is_empty():
		_set_status("NO HAY RIVALES DISPONIBLES · VUELVE A INTENTARLO" if queue_error == "no_opponents" else "BÚSQUEDA INTERRUMPIDA · REVISA LA CONEXIÓN DEL EQUIPO")
		return
	if _start_after_party_created:
		_start_after_party_created = false
		request_start_match()
		return
	var match := Dictionary(party.get("match", {}))
	if not match.is_empty():
		var match_status := String(match.get("status", "STARTING")).to_upper()
		_set_status("SERVIDOR DE PARTIDA · %s" % match_status)
		if match_status == "READY":
			_on_match_ready(match)
	else:
		_set_status("ESCUADRA ACTIVA · %s" % code)

func _on_match_ready(match: Dictionary) -> void:
	var match_id := String(match.get("match_id", ""))
	if match_id.is_empty() or _last_match_emitted == match_id:
		return
	if String(match.get("join_ticket", "")).length() != 64:
		return
	_last_match_emitted = match_id
	_set_status("SERVIDOR LISTO · ENTRANDO CON TU ESCUADRA...")
	online_match_ready.emit(match.duplicate(true))

func _update_lobby_party_labels(party: Dictionary) -> void:
	if _lobby == null:
		return
	var labels_value = _lobby.get("_party_labels")
	var labels: Array = labels_value if typeof(labels_value) == TYPE_ARRAY else []
	var members: Array = Array(party.get("members", [])) if not party.is_empty() else []
	var capacity := int(party.get("capacity", int(_lobby.get("selected_mode")))) if not party.is_empty() else int(_lobby.get("selected_mode"))
	if _lobby.has_method("update_party_members"):
		_lobby.call("update_party_members", members, capacity)
	for index in range(labels.size()):
		var label := labels[index] as Label
		if label == null:
			continue
		if index < members.size():
			var member := Dictionary(members[index])
			var leader_text := " · LÍDER" if bool(member.get("leader", false)) else ""
			var ping := int(member.get("ping_ms", 999))
			var ping_text := str(ping) if bool(member.get("online", false)) and ping < 999 else "+999"
			label.text = "%s%s\n%s ms" % [String(member.get("username", "Jugador")), leader_text, ping_text]
			label.modulate = Color.WHITE
		elif index < capacity:
			label.text = "PLAZA LIBRE\nInvita por código"
			label.modulate = Color(0.66, 0.68, 0.72)
		else:
			label.text = ""
			label.modulate = Color(0.38, 0.40, 0.44)

func _poll_social_state() -> void:
	if not SocialClient.has_session():
		return
	if int(_lobby.get("selected_mode")) > 1 or not SocialClient.current_party.is_empty():
		SocialClient.refresh_party()

func _on_request_failed(operation: String, reason: String) -> void:
	if operation == "party_create": _start_after_party_created = false
	match reason:
		"party_not_found": _set_status("NO EXISTE UNA ESCUADRA CON ESE CÓDIGO")
		"party_full": _set_status("LA ESCUADRA ESTÁ LLENA")
		"party_needs_teammate", "party_needs_opponent": _set_status("EL DUELO INTERNO NECESITA AL MENOS DOS JUGADORES")
		"party_locked_for_match": _set_status("LA ESCUADRA ESTÁ BLOQUEADA POR EMPAREJAMIENTO")
		"leader_required": _set_status("SOLO EL LÍDER PUEDE HACER ESO")
		"profile_not_found": _set_status("NO SE ENCONTRÓ ESA CUENTA")
		"match_capacity_reached", "match_ports_exhausted": _set_status("SERVIDORES OCUPADOS · INTENTA DE NUEVO")
		"rate_limited": _set_status("DEMASIADAS SOLICITUDES · INTENTA DE NUEVO")
		_: _set_status("NO SE PUDO COMPLETAR LA SOLICITUD · VUELVE A INTENTARLO")

func _set_status(text: String) -> void:
	if _lobby == null:
		return
	var status := _lobby.get("_status_label") as Label
	if status != null:
		status.text = text

func _clear_modal_body() -> void:
	if _modal_body == null:
		return
	for child in _modal_body.get_children():
		child.queue_free()
	_chat_log = null
	_chat_edit = null

func _small_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 22)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 56)
	_apply_button_style(button, false)
	button.pressed.connect(callback)
	return button

func _set_margins(container: MarginContainer, left: int, right: int, top: int, bottom: int) -> void:
	container.add_theme_constant_override("margin_left", left)
	container.add_theme_constant_override("margin_right", right)
	container.add_theme_constant_override("margin_top", top)
	container.add_theme_constant_override("margin_bottom", bottom)

func _panel_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	return UI.style(background, Color(0.35, 0.58, 0.65, 0.5), 0)

func _apply_button_style(button: Button, primary: bool) -> void:
	UI.skin_button(button, primary)
