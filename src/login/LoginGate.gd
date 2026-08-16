class_name DeadfallLoginGate
extends Control

signal login_complete(account: Dictionary)

const SafeAreaScript = preload("res://src/mobile/SafeArea.gd")

enum Stage {
	TAP_TO_START,
	ACCOUNT_CHOICE,
	USERNAME,
	CONNECTING,
	ERROR,
}

var _stage: Stage = Stage.TAP_TO_START
var _safe_root: Control
var _tap_layer: Control
var _account_panel: PanelContainer
var _username_panel: PanelContainer
var _username_edit: LineEdit
var _status: Label
var _busy := false
var _last_error := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_background()
	_build_ui()
	SocialClient.login_succeeded.connect(_on_login_succeeded)
	SocialClient.login_failed.connect(_on_login_failed)
	_show_stage(Stage.TAP_TO_START)

func _gui_input(event: InputEvent) -> void:
	if _stage != Stage.TAP_TO_START or _busy:
		return
	if event is InputEventScreenTouch and event.pressed:
		_begin_login_flow()
		accept_event()
	elif event is InputEventMouseButton and event.pressed:
		_begin_login_flow()
		accept_event()
	elif event is InputEventKey and event.pressed:
		_begin_login_flow()
		accept_event()

func _build_background() -> void:
	var background := ColorRect.new()
	background.name = "LoginBackground"
	background.color = Color(0.008, 0.011, 0.016, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var horizon := ColorRect.new()
	horizon.color = Color(0.48, 0.025, 0.035, 0.18)
	horizon.anchor_left = 0.0
	horizon.anchor_top = 0.58
	horizon.anchor_right = 1.0
	horizon.anchor_bottom = 1.0
	background.add_child(horizon)

	var center_glow := ColorRect.new()
	center_glow.color = Color(0.20, 0.022, 0.030, 0.24)
	center_glow.anchor_left = 0.30
	center_glow.anchor_top = 0.0
	center_glow.anchor_right = 0.70
	center_glow.anchor_bottom = 1.0
	background.add_child(center_glow)

func _build_ui() -> void:
	_safe_root = SafeAreaScript.new()
	_safe_root.name = "SafeArea"
	_safe_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_safe_root)

	var brand := VBoxContainer.new()
	brand.anchor_left = 0.5
	brand.anchor_top = 0.22
	brand.anchor_right = 0.5
	brand.anchor_bottom = 0.22
	brand.offset_left = -430.0
	brand.offset_right = 430.0
	brand.offset_bottom = 180.0
	brand.alignment = BoxContainer.ALIGNMENT_CENTER
	_safe_root.add_child(brand)

	var title := Label.new()
	title.text = "NEXORA: DEADFALL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color(0.93, 0.94, 0.96))
	brand.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "SURVIVE THE FALL"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color(0.68, 0.09, 0.11))
	brand.add_child(subtitle)

	_tap_layer = Control.new()
	_tap_layer.name = "TapToStart"
	_tap_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tap_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe_root.add_child(_tap_layer)
	var tap := Label.new()
	tap.text = "TOCA PARA INICIAR"
	tap.anchor_left = 0.5
	tap.anchor_top = 0.76
	tap.anchor_right = 0.5
	tap.anchor_bottom = 0.76
	tap.offset_left = -260.0
	tap.offset_top = -30.0
	tap.offset_right = 260.0
	tap.offset_bottom = 30.0
	tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tap.add_theme_font_size_override("font_size", 24)
	tap.add_theme_color_override("font_color", Color(0.88, 0.89, 0.92))
	_tap_layer.add_child(tap)

	_status = Label.new()
	_status.anchor_left = 0.5
	_status.anchor_top = 0.86
	_status.anchor_right = 0.5
	_status.anchor_bottom = 0.86
	_status.offset_left = -420.0
	_status.offset_top = -24.0
	_status.offset_right = 420.0
	_status.offset_bottom = 30.0
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_color_override("font_color", Color(0.62, 0.64, 0.68))
	_safe_root.add_child(_status)

	_build_account_choice()
	_build_username_panel()

func _build_account_choice() -> void:
	_account_panel = PanelContainer.new()
	_account_panel.name = "AccountChoice"
	_account_panel.anchor_left = 0.5
	_account_panel.anchor_top = 0.54
	_account_panel.anchor_right = 0.5
	_account_panel.anchor_bottom = 0.54
	_account_panel.offset_left = -300.0
	_account_panel.offset_top = -95.0
	_account_panel.offset_right = 300.0
	_account_panel.offset_bottom = 115.0
	_account_panel.add_theme_stylebox_override("panel", _panel_style())
	_safe_root.add_child(_account_panel)

	var margin := MarginContainer.new()
	_set_margins(margin, 26, 26, 22, 22)
	_account_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "INICIAR SESIÓN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	vbox.add_child(title)
	var hint := Label.new()
	hint.text = "Selecciona una cuenta para continuar"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.62, 0.64, 0.68))
	vbox.add_child(hint)
	var guest := Button.new()
	guest.text = "CUENTA DE INVITADO"
	guest.custom_minimum_size = Vector2(0, 62)
	_apply_primary_button(guest)
	vbox.add_child(guest)
	guest.pressed.connect(_on_guest_account_pressed)

func _build_username_panel() -> void:
	_username_panel = PanelContainer.new()
	_username_panel.name = "UsernameSetup"
	_username_panel.anchor_left = 0.5
	_username_panel.anchor_top = 0.55
	_username_panel.anchor_right = 0.5
	_username_panel.anchor_bottom = 0.55
	_username_panel.offset_left = -330.0
	_username_panel.offset_top = -125.0
	_username_panel.offset_right = 330.0
	_username_panel.offset_bottom = 145.0
	_username_panel.add_theme_stylebox_override("panel", _panel_style())
	_safe_root.add_child(_username_panel)

	var margin := MarginContainer.new()
	_set_margins(margin, 28, 28, 24, 24)
	_username_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 13)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "CREA TU IDENTIDAD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	vbox.add_child(title)
	var hint := Label.new()
	hint.text = "Nombre único · máximo 12 caracteres · letras, números o _"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.62, 0.64, 0.68))
	vbox.add_child(hint)
	_username_edit = LineEdit.new()
	_username_edit.max_length = 12
	_username_edit.placeholder_text = "Nombre de superviviente"
	_username_edit.custom_minimum_size = Vector2(0, 58)
	vbox.add_child(_username_edit)
	var confirm := Button.new()
	confirm.text = "CONFIRMAR"
	confirm.custom_minimum_size = Vector2(0, 60)
	_apply_primary_button(confirm)
	vbox.add_child(confirm)
	confirm.pressed.connect(_submit_username)
	_username_edit.text_submitted.connect(func(_value: String) -> void: _submit_username())

func _begin_login_flow() -> void:
	if _busy:
		return
	if GuestIdentity.has_complete_profile():
		_busy = true
		_show_stage(Stage.CONNECTING)
		_status.text = "VERIFICANDO CUENTA DE INVITADO..."
		SocialClient.authenticate_current_guest()
	else:
		_show_stage(Stage.ACCOUNT_CHOICE)

func _on_guest_account_pressed() -> void:
	_show_stage(Stage.USERNAME)
	_username_edit.grab_focus()

func _submit_username() -> void:
	if _busy or _username_edit == null:
		return
	var username := _username_edit.text.strip_edges()
	if not GuestIdentity.is_valid_username(username):
		_status.text = "NOMBRE INVÁLIDO"
		return
	_busy = true
	_show_stage(Stage.CONNECTING)
	_status.text = "VERIFICANDO DISPONIBILIDAD DEL NOMBRE..."
	SocialClient.register_guest(username)

func _on_login_succeeded(account: Dictionary) -> void:
	_busy = false
	_status.text = "CUENTA VERIFICADA"
	login_complete.emit(account)

func _on_login_failed(reason: String) -> void:
	_busy = false
	_last_error = reason
	if reason == "unknown_guest" and GuestIdentity.has_complete_profile():
		_busy = true
		_show_stage(Stage.CONNECTING)
		_status.text = "REGISTRANDO CUENTA EN EL SERVIDOR..."
		SocialClient.register_guest(GuestIdentity.username)
		return
	_show_stage(Stage.ERROR)
	match reason:
		"username_taken":
			_status.text = "ESE NOMBRE YA ESTÁ EN USO"
		"invalid_username":
			_status.text = "NOMBRE INVÁLIDO"
		"credential_mismatch":
			_status.text = "LA CUENTA LOCAL NO COINCIDE CON EL SERVIDOR"
		_:
			_status.text = "NO SE PUDO CONECTAR · TOCA PARA REINTENTAR"

func _show_stage(stage: Stage) -> void:
	_stage = stage
	_tap_layer.visible = stage == Stage.TAP_TO_START or stage == Stage.ERROR
	_account_panel.visible = stage == Stage.ACCOUNT_CHOICE
	_username_panel.visible = stage == Stage.USERNAME
	if stage == Stage.TAP_TO_START:
		_status.text = "CLOSED BETA"
	elif stage == Stage.ACCOUNT_CHOICE:
		_status.text = "NO SE DETECTÓ UNA CUENTA CONFIGURADA"
	elif stage == Stage.USERNAME:
		_status.text = "EL SERVIDOR VALIDARÁ QUE EL NOMBRE ESTÉ DISPONIBLE"
	elif stage == Stage.CONNECTING:
		_account_panel.visible = false
		_username_panel.visible = false
	elif stage == Stage.ERROR:
		_tap_layer.visible = true

func _set_margins(container: MarginContainer, left: int, right: int, top: int, bottom: int) -> void:
	container.add_theme_constant_override("margin_left", left)
	container.add_theme_constant_override("margin_right", right)
	container.add_theme_constant_override("margin_top", top)
	container.add_theme_constant_override("margin_bottom", bottom)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.014, 0.019, 0.026, 0.97)
	style.border_color = Color(0.58, 0.06, 0.08, 0.82)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	return style

func _apply_primary_button(button: Button) -> void:
	var normal := _panel_style()
	normal.bg_color = Color(0.60, 0.035, 0.045, 0.96)
	var pressed := _panel_style()
	pressed.bg_color = Color(0.42, 0.020, 0.030, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size", 19)
