class_name DeadfallLoginGate
extends Control
signal login_complete(account: Dictionary)
const UI = preload("res://src/ui/TacticalTheme.gd")
const Backdrop = preload("res://src/ui/TacticalBackdrop.gd")
const StageView = preload("res://src/lobby/TacticalStage.gd")
const SafeAreaScript = preload("res://src/mobile/SafeArea.gd")
enum Stage { TAP_TO_START, ACCOUNT_CHOICE, USERNAME, CONNECTING, ERROR }

var _stage: Stage = Stage.TAP_TO_START
var _safe_root: Control
var _username_edit: LineEdit
var _status: Label
var _busy := false
var _last_error := ""
var _panel: PanelContainer
var _body: VBoxContainer
var _progress: ProgressBar
var _elapsed := 0.0
var _registration_recovery_attempted := false
var _candidate_username := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UI.apply(self)
	add_child(Backdrop.new())
	_safe_root = SafeAreaScript.new()
	add_child(_safe_root)
	_safe_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stage := StageView.new()
	UI.place(stage, _safe_root, Rect2(0.50, 0.14, 0.48, 0.72))
	stage.set_members([{"selected_character": GuestIdentity.selected_character}], 1)
	var brand := UI.label("N E X O R A", 38, UI.AMBER)
	UI.place(brand, _safe_root, Rect2(0.06, 0.09, 0.42, 0.06))
	UI.place(UI.label("DEADFALL", 110), _safe_root, Rect2(0.055, 0.14, 0.5, 0.15))
	UI.place(UI.label("SOBREVIVE A LA CAÍDA.", 30, UI.MUTED), _safe_root, Rect2(0.06, 0.29, 0.44, 0.06))
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UI.style())
	UI.place(_panel, _safe_root, Rect2(0.06, 0.43, 0.40, 0.37))
	_body = UI.column(_panel, 14)
	_body.alignment = BoxContainer.ALIGNMENT_CENTER
	_status = UI.label("", 24, UI.CYAN)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.place(_status, _safe_root, Rect2(0.06, 0.83, 0.68, 0.07))
	UI.place(UI.label("GHOST DEVELOPER  /  CLOSED BETA", 20, UI.MUTED), _safe_root, Rect2(0.06, 0.94, 0.8, 0.04))
	SocialClient.login_succeeded.connect(_on_login_succeeded)
	SocialClient.login_failed.connect(_on_login_failed)
	SocialClient.auth_stage_changed.connect(_on_auth_stage)
	AudioDirector.set_context(&"lobby")
	NetworkTelemetry.set_frontend_mode(true)
	_show_stage(Stage.TAP_TO_START)

func _show_stage(stage: Stage) -> void:
	_stage = stage
	if is_instance_valid(_username_edit):
		_candidate_username = _username_edit.text
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_username_edit = null
	_progress = null
	match stage:
		Stage.TAP_TO_START, Stage.ERROR:
			_body.add_child(UI.label("TU PRÓXIMA MISIÓN TE ESPERA" if stage == Stage.TAP_TO_START else "RECUPERAR CONEXIÓN", 30))
			var hint := UI.label("Entra con tu cuenta de superviviente." if GuestIdentity.has_complete_profile() else "Crea tu identidad y reúne a tu equipo.", 24, UI.MUTED)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_body.add_child(hint)
			_body.add_child(UI.button("TOCA PARA INICIAR" if stage == Stage.TAP_TO_START else "REINTENTAR", _begin_login_flow, true, "play"))
			if stage == Stage.TAP_TO_START:
				_status.text = "CAMPAÑA  /  SOLO · DÚO · ESCUADRA"
		Stage.ACCOUNT_CHOICE:
			_body.add_child(UI.label("BIENVENIDO, SUPERVIVIENTE", 30))
			var hint := UI.label("Tu cuenta de invitado se guarda en este dispositivo. Conserva los datos de la aplicación para mantener el acceso.", 24, UI.MUTED)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_body.add_child(hint)
			_body.add_child(UI.button("CREAR CUENTA DE INVITADO", _on_guest_account_pressed, true, "shield"))
			_status.text = "UN NOMBRE. UN EQUIPO. UNA OPORTUNIDAD."
		Stage.USERNAME:
			_body.add_child(UI.label("ELIGE TU NOMBRE", 32))
			_body.add_child(UI.label("Hasta 12 letras, números o guion bajo.", 24, UI.MUTED))
			_username_edit = LineEdit.new()
			_username_edit.placeholder_text = "Nombre de superviviente"
			_username_edit.max_length = 12
			_username_edit.text = _candidate_username
			_username_edit.custom_minimum_size.y = 64
			_body.add_child(_username_edit)
			_username_edit.text_submitted.connect(func(_value: String) -> void: _submit_username())
			_body.add_child(UI.button("CONFIRMAR IDENTIDAD", _submit_username, true, "shield"))
			_status.text = "El nombre debe estar disponible."
		Stage.CONNECTING:
			_elapsed = 0
			_body.add_child(UI.label("VERIFICANDO TU CUENTA", 34))
			_body.add_child(UI.label("Conectando con DEADFALL", 26, UI.MUTED))
			_progress = ProgressBar.new()
			_progress.indeterminate = true
			_progress.show_percentage = false
			_progress.custom_minimum_size.y = 8
			_body.add_child(_progress)
			_body.add_child(UI.label("Tu identidad se valida antes de entrar.", 24, UI.MUTED))

func _begin_login_flow() -> void:
	if _busy:
		return
	_registration_recovery_attempted = false
	if not GuestIdentity.has_local_credentials():
		GuestIdentity.call("_ensure_identity")
	if GuestIdentity.has_complete_profile():
		_busy = true
		_show_stage(Stage.CONNECTING)
		SocialClient.authenticate_current_guest()
	else:
		_show_stage(Stage.ACCOUNT_CHOICE)

func _on_guest_account_pressed() -> void:
	if _busy:
		return
	_show_stage(Stage.USERNAME)
	_username_edit.grab_focus()

func _submit_username() -> void:
	if _busy or _username_edit == null:
		return
	var username := _username_edit.text.strip_edges()
	if not GuestIdentity.is_valid_username(username):
		_status.text = "Usa de 1 a 12 letras, números o guion bajo."
		return
	_busy = true
	_show_stage(Stage.CONNECTING)
	SocialClient.register_guest(username)

func _on_auth_stage(stage: String) -> void:
	if not _busy:
		return
	_status.text = {
		"challenge": "Conectando con el servicio de cuentas…",
		"verify": "Validando tu identidad…",
		"register": "Comprobando disponibilidad del nombre…",
	}.get(stage, "Preparando tu cuenta…")

func _on_login_succeeded(account: Dictionary) -> void:
	if not _busy:
		return
	_busy = false
	_status.text = "CUENTA VERIFICADA"
	AudioDirector.play_ui(&"ui_confirm")
	login_complete.emit(account)

func _on_login_failed(reason: String) -> void:
	if not _busy:
		return
	_busy = false
	_last_error = reason
	if reason == "unknown_guest" and GuestIdentity.has_complete_profile() and not _registration_recovery_attempted:
		_registration_recovery_attempted = true
		_busy = true
		SocialClient.register_guest(GuestIdentity.username)
		return
	if reason in ["username_taken", "invalid_username"]:
		if _candidate_username.is_empty():
			_candidate_username = GuestIdentity.username
		_show_stage(Stage.USERNAME)
		_status.text = "Ese nombre ya está en uso. Elige otro." if reason == "username_taken" else "Revisa el nombre e inténtalo de nuevo."
		_username_edit.grab_focus()
	else:
		_show_stage(Stage.ERROR)
		_status.text = "No se pudo conectar. Revisa tu conexión y vuelve a intentar."
		if reason == "credential_mismatch":
			_status.text = "La identidad guardada no coincide con esta cuenta."
	AudioDirector.play_ui(&"ui_error")

func _process(delta: float) -> void:
	if _busy:
		_elapsed += delta
		if _elapsed > 9.0:
			_status.text = "La conexión está tardando. Esperando respuesta…"

func handle_back() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
	if _busy:
		return
	if _stage == Stage.USERNAME:
		_show_stage(Stage.ACCOUNT_CHOICE)
	elif _stage != Stage.TAP_TO_START:
		_show_stage(Stage.TAP_TO_START)
