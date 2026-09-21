extends CanvasLayer

signal allowed()
const UI = preload("res://src/ui/TacticalTheme.gd")
const Build = preload("res://src/release/BuildInfo.gd")
const DOWNLOAD_PAGE := "https://nexoradeadfall.duckdns.org/"

var _request: HTTPRequest
var _title: Label
var _message: Label
var _version: Label
var _retry: Button
var _download: Button
var _busy := false
var state := "checking"

func _ready() -> void:
	layer = 220
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	UI.apply(root)
	root.add_child(preload("res://src/ui/TacticalBackdrop.gd").new())
	var safe := preload("res://src/mobile/SafeArea.gd").new()
	root.add_child(safe)
	UI.place(UI.label("N E X O R A", 38, UI.AMBER), safe, Rect2(0.07, 0.16, 0.5, 0.08))
	UI.place(UI.label("DEADFALL", 104), safe, Rect2(0.065, 0.24, 0.6, 0.15))
	UI.place(UI.label("PREPARA TU PRÓXIMA MISIÓN", 24, UI.CYAN), safe, Rect2(0.07, 0.40, 0.65, 0.06))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.style())
	UI.place(panel, safe, Rect2(0.07, 0.52, 0.86, 0.35))
	var body := UI.column(panel, 12)
	_title = UI.label("COMPROBANDO VERSIÓN", 38)
	body.add_child(_title)
	_version = UI.label("INSTALADA  ·  " + Build.APP_VERSION, 23, UI.CYAN)
	body.add_child(_version)
	_message = UI.label("Consultando la versión disponible…", 25, UI.MUTED)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_message)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	body.add_child(actions)
	_download = UI.button("DESCARGAR ACTUALIZACIÓN", _open_download, true)
	_download.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_download)
	_download.hide()
	_retry = UI.button("VOLVER A COMPROBAR", check_version)
	_retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_retry)
	_request = HTTPRequest.new()
	_request.timeout = 10.0
	_request.body_size_limit = 65536
	_request.max_redirects = 2
	add_child(_request)
	_request.request_completed.connect(_on_response)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func check_version() -> void:
	if _busy:
		return
	_busy = true
	state = "checking"
	_retry.disabled = true
	_title.text = "COMPROBANDO VERSIÓN"
	_message.text = "Consultando la versión disponible…"
	var url := SocialClient.api_base.trim_suffix("/") + "/health"
	var error := _request.request(url, PackedStringArray(["Accept: application/json", "Cache-Control: no-cache"]))
	if error != OK:
		_show_unavailable()

func _on_response(result: int, status: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
	_busy = false
	_retry.disabled = false
	var json := JSON.new()
	if result != HTTPRequest.RESULT_SUCCESS or status != 200 or json.parse(bytes.get_string_from_utf8()) != OK or not json.data is Dictionary:
		_show_unavailable()
		return
	var response: Dictionary = json.data
	var build_value: Variant = response.get("build")
	if not bool(response.get("ok", false)) or String(response.get("service", "")) != "deadfall-control" or not build_value is Dictionary:
		_show_unavailable()
		return
	var build: Dictionary = build_value
	for key in ["version_code", "protocol", "content_version", "min_client_version_code", "max_client_version_code"]:
		if typeof(build.get(key)) not in [TYPE_INT, TYPE_FLOAT] or float(build[key]) < 1 or float(build[key]) != floorf(float(build[key])):
			_show_unavailable()
			return
	var compatible := Build.validate_server_snapshot(build)
	var server_code := int(build.get("version_code", 0))
	if server_code > Build.VERSION_CODE or not bool(compatible.get("compatible", false)):
		state = "required"
		var newer := server_code > Build.VERSION_CODE or String(compatible.get("reason", "")) == "client_update_required"
		_title.text = "ACTUALIZACIÓN OBLIGATORIA" if newer else "ACTUALIZANDO EL SERVIDOR"
		_message.text = "Instala el nuevo APK para continuar. Tu cuenta se conserva al actualizar la aplicación." if newer else "El servidor todavía no es compatible con esta instalación. Vuelve a comprobar en unos minutos."
		_version.text = "INSTALADA  ·  %s     DISPONIBLE  ·  %s" % [Build.APP_VERSION, String(build.get("app_version", "Pendiente"))]
		_download.visible = newer
		return
	state = "allowed"
	allowed.emit()

func _show_unavailable() -> void:
	_busy = false
	state = "unavailable"
	_retry.disabled = false
	_title.text = "NO SE PUDO VERIFICAR"
	_message.text = "Revisa tu conexión y vuelve a intentarlo. Es necesario comprobar la versión antes de jugar."

func _open_download() -> void:
	OS.shell_open(DOWNLOAD_PAGE)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and is_instance_valid(_request):
		check_version()
