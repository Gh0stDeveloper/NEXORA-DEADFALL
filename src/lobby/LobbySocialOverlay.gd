class_name DeadfallLobbySocialOverlay
extends Control

const POLL_SECONDS := 1.5

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
	SocialClient.request_failed.connect(_on_request_failed)
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
	if mode == 1:
		if not SocialClient.current_party.is_empty():
			SocialClient.leave_party()
	else:
		var current_capacity := int(SocialClient.current_party.get("capacity", 0))
		var leader_id := String(SocialClient.current_party.get("leader_guest_id", ""))
		if SocialClient.current_party.is_empty() or (current_capacity != mode and leader_id == GuestIdentity.guest_id):
			_set_status("CREANDO CÓDIGO DE %s..." % ("DÚO" if mode == 2 else "ESCUADRA"))
			SocialClient.create_party(mode)

func _build_top_actions() -> void:
	var row := HBoxContainer.new()
	row.name = "SocialActions"
	row.anchor_left = 0.73
	row.anchor_top = 0.035
	row.anchor_right = 0.985
	row.anchor_bottom = 0.11
	row.add_theme_constant_override("separation", 8)
	_safe_root.add_child(row)
	row.add_child(_small_button("PERFIL", _open_profile))
	row.add_child(_small_button("AMIGOS", _open_friends))
	row.add_child(_small_button("CHAT", _open_party_chat))

func _build_party_code_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "SquadCodePanel"
	panel.anchor_left = 0.015
	panel.anchor_top = 0.80
	panel.anchor_right = 0.19
	panel.anchor_bottom = 0.985
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.014, 0.019, 0.026, 0.94), Color(0.30, 0.32, 0.36, 0.62), 14))
	_safe_root.add_child(panel)
	var margin := MarginContainer.new()
	_set_margins(margin, 12, 12, 10, 10)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)
	_party_code_label = Label.new()
	_party_code_label.text = "CÓDIGO DE EQUIPO: —"
	_party_code_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_party_code_label)
	_join_code_edit = LineEdit.new()
	_join_code_edit.max_length = 6
	_join_code_edit.placeholder_text = "CÓDIGO"
	_join_code_edit.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(_join_code_edit)
	var join := Button.new()
	join.text = "UNIRSE"
	join.custom_minimum_size = Vector2(0, 40)
	_apply_button_style(join, true)
	vbox.add_child(join)
	join.pressed.connect(_join_by_code)
	_join_code_edit.text_submitted.connect(func(_value: String) -> void: _join_by_code())

func _build_modal() -> void:
	_modal = PanelContainer.new()
	_modal.name = "SocialModal"
	_modal.anchor_left = 0.22
	_modal.anchor_top = 0.13
	_modal.anchor_right = 0.96
	_modal.anchor_bottom = 0.83
	_modal.visible = false
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.add_theme_stylebox_override("panel", _panel_style(Color(0.010, 0.014, 0.020, 0.985), Color(0.58, 0.06, 0.08, 0.82), 20))
	_safe_root.add_child(_modal)
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
	_modal_body = VBoxContainer.new()
	_modal_body.name = "Body"
	_modal_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modal_body.add_theme_constant_override("separation", 10)
	vbox.add_child(_modal_body)

func _open_profile() -> void:
	_modal.visible = true
	_modal_title.text = "PERFIL"
	_clear_modal_body()
	var loading := Label.new()
	loading.text = "Cargando perfil..."
	_modal_body.add_child(loading)
	SocialClient.load_profile()

func _on_profile_loaded(profile: Dictionary) -> void:
	if not _modal.visible or _modal_title.text != "PERFIL":
		return
	_clear_modal_body()
	var username := Label.new()
	username.text = String(profile.get("username", GuestIdentity.username))
	username.add_theme_font_size_override("font_size", 34)
	_modal_body.add_child(username)
	var account_id := Label.new()
	account_id.text = "ID DE CUENTA\n%s" % String(profile.get("guest_id", GuestIdentity.guest_id))
	account_id.add_theme_font_size_override("font_size", 18)
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
		DisplayServer.clipboard_set(String(profile.get("guest_id", GuestIdentity.guest_id)))
		_set_status("ID COPIADO")
	)

func _open_friends() -> void:
	_modal.visible = true
	_modal_title.text = "AMIGOS"
	_clear_modal_body()
	var loading := Label.new()
	loading.text = "Cargando amigos..."
	_modal_body.add_child(loading)
	SocialClient.refresh_friends()

func _on_friends_updated(snapshot: Dictionary) -> void:
	if not _modal.visible or _modal_title.text != "AMIGOS":
		return
	_render_friends(snapshot)

func _render_friends(snapshot: Dictionary) -> void:
	_clear_modal_body()
	var add_title := Label.new()
	add_title.text = "AGREGAR POR ID"
	add_title.add_theme_font_size_override("font_size", 17)
	_modal_body.add_child(add_title)
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 8)
	_modal_body.add_child(add_row)
	var id_edit := LineEdit.new()
	id_edit.placeholder_text = "gst_..."
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
		if target.is_empty():
			return
		SocialClient.request_friend(target)
		_set_status("SOLICITUD ENVIADA")
	)

	var incoming: Array = Array(snapshot.get("incoming", []))
	if not incoming.is_empty():
		var incoming_title := Label.new()
		incoming_title.text = "SOLICITUDES RECIBIDAS"
		incoming_title.add_theme_font_size_override("font_size", 17)
		_modal_body.add_child(incoming_title)
		for item in incoming:
			var profile: Dictionary = Dictionary(item)
			_modal_body.add_child(_incoming_friend_row(profile))

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
			var profile: Dictionary = Dictionary(item)
			_modal_body.add_child(_friend_row(profile))

func _incoming_friend_row(profile: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 52)
	var label := Label.new()
	label.text = "%s  ·  %s" % [String(profile.get("username", "Jugador")), String(profile.get("guest_id", ""))]
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
	label.text = "%s  ·  %s" % [String(profile.get("username", "Jugador")), String(profile.get("guest_id", ""))]
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
	_modal.visible = true
	_modal_title.text = "CHAT DE ESCUADRA"
	_build_chat_body()
	if not SocialClient.current_party.is_empty():
		_render_chat(Array(SocialClient.current_party.get("chat", [])))
	SocialClient.refresh_party()

func _open_friend_chat(guest_id: String, username: String) -> void:
	_chat_friend_id = guest_id
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
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var message: Dictionary = Dictionary(item)
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
		_party_code_label.text = "CÓDIGO DE EQUIPO: —"
		_update_lobby_party_labels({})
		return
	var code := String(party.get("code", ""))
	_party_code_label.text = "CÓDIGO DE EQUIPO: %s" % code
	var capacity := int(party.get("capacity", 4))
	if _lobby != null and int(_lobby.get("selected_mode")) != capacity:
		_lobby.set("selected_mode", capacity)
		if _lobby.has_method("_refresh_mode"):
			_lobby.call("_refresh_mode")
	_update_lobby_party_labels(party)
	if _modal.visible and _chat_friend_id.is_empty() and _modal_title.text == "CHAT DE ESCUADRA":
		_render_chat(Array(party.get("chat", [])))
	_set_status("ESCUADRA ACTIVA · %s" % code)

func _update_lobby_party_labels(party: Dictionary) -> void:
	if _lobby == null:
		return
	var labels_value = _lobby.get("_party_labels")
	if typeof(labels_value) != TYPE_ARRAY:
		return
	var labels: Array = labels_value
	var members: Array = Array(party.get("members", [])) if not party.is_empty() else []
	var capacity := int(party.get("capacity", int(_lobby.get("selected_mode")))) if not party.is_empty() else int(_lobby.get("selected_mode"))
	for index in range(labels.size()):
		var label: Label = labels[index] as Label
		if label == null:
			continue
		if index < members.size():
			var member: Dictionary = Dictionary(members[index])
			var leader_text := "\n   LÍDER" if bool(member.get("leader", false)) else ""
			label.text = "%d  %s%s" % [index + 1, String(member.get("username", "Jugador")), leader_text]
			label.modulate = Color.WHITE
		elif index < capacity:
			label.text = "%d  ESPERANDO JUGADOR" % (index + 1)
			label.modulate = Color(0.66, 0.68, 0.72)
		else:
			label.text = "%d  CERRADO" % (index + 1)
			label.modulate = Color(0.38, 0.40, 0.44)

func _poll_social_state() -> void:
	if not SocialClient.has_session():
		return
	if int(_lobby.get("selected_mode")) > 1 or not SocialClient.current_party.is_empty():
		SocialClient.refresh_party()

func _on_request_failed(operation: String, reason: String) -> void:
	match reason:
		"party_not_found": _set_status("NO EXISTE UNA ESCUADRA CON ESE CÓDIGO")
		"party_full": _set_status("LA ESCUADRA ESTÁ LLENA")
		"leader_required": _set_status("SOLO EL LÍDER PUEDE HACER ESO")
		"profile_not_found": _set_status("NO SE ENCONTRÓ ESA CUENTA")
		"rate_limited": _set_status("DEMASIADAS SOLICITUDES · INTENTA DE NUEVO")
		_: _set_status("ERROR SOCIAL · %s · %s" % [operation.to_upper(), reason.to_upper()])

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
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 48)
	_apply_button_style(button, false)
	button.pressed.connect(callback)
	return button

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
