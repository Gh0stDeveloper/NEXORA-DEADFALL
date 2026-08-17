extends Node

const DedicatedServerScript = preload("res://src/server/DedicatedServer.gd")
const TestRangeScene = preload("res://src/maps/test_range/TestRange.tscn")
const SquadArenaScene = preload("res://src/maps/duo/DuoArena.tscn")
const CampaignArenaScene = preload("res://src/maps/campaign/OutbreakDistrict.tscn")
const LoginGateScene = preload("res://src/login/LoginGate.tscn")
const LobbyScene = preload("res://src/lobby/Lobby.tscn")
const DirectoryClientScript = preload("res://src/network/RoomDirectoryClient.gd")
const AndroidDiagnosticsScript = preload("res://src/mobile/AndroidDiagnostics.gd")
const MatchLoadingOverlayScript = preload("res://src/ui/MatchLoadingOverlay.gd")

const MATCH_CONNECT_TIMEOUT_SECONDS := 18.0

var _pending_room_name := "Player"
var _pending_campaign_mode := false
var _pending_mission_id: StringName = &"mission_01_first_signal"
var _pending_lobby: Control
var _pending_network_arena: Node
var _pending_network_session: Node
var _match_loading: CanvasLayer
var _match_timeout: Timer
var _pending_match_id := ""
var _pending_match_endpoint := ""

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var campaign_mode := "--campaign" in args
	var mission_id := StringName(_arg_value(args, "--mission=", "mission_01_first_signal"))
	if "--server" in args:
		_boot_dedicated_server(args, campaign_mode, mission_id)
		return
	var connect_value := _arg_value(args, "--connect=")
	if not connect_value.is_empty():
		_boot_direct_network_client(connect_value, args, campaign_mode, mission_id)
		return
	var room_value := _arg_value(args, "--room=")
	var directory_value := _arg_value(args, "--directory=")
	if not room_value.is_empty() and not directory_value.is_empty():
		_boot_room_network_client(room_value, directory_value, args, campaign_mode, mission_id)
		return

	if "--test-range" in args:
		Game.start_local_session()
		_boot_local_test_range()
		_boot_android_diagnostics()
		print("NEXORA: DEADFALL test range client bootstrap ready")
		return

	if DisplayServer.get_name() != "headless" and "--skip-login" not in args and "--skip-lobby" not in args:
		_boot_login_gate(mission_id)
		_boot_android_diagnostics()
		print("NEXORA: DEADFALL guest login bootstrap ready")
		return

	if DisplayServer.get_name() != "headless" and "--skip-lobby" not in args:
		_boot_lobby(mission_id)
		_boot_android_diagnostics()
		print("NEXORA: DEADFALL lobby bootstrap ready")
		return

	Game.start_local_session()
	_boot_local_campaign(mission_id)
	_boot_android_diagnostics()
	print("NEXORA: DEADFALL client bootstrap ready")

func _boot_login_gate(mission_id: StringName) -> void:
	var gate := LoginGateScene.instantiate()
	gate.name = "LoginGate"
	add_child(gate)
	if gate.has_signal("login_complete"):
		gate.connect("login_complete", Callable(self, "_on_login_complete").bind(gate, mission_id))

func _on_login_complete(_account: Dictionary, gate: Node, mission_id: StringName) -> void:
	gate.queue_free()
	call_deferred("_boot_lobby", mission_id)

func _boot_lobby(mission_id: StringName) -> void:
	var lobby := LobbyScene.instantiate()
	lobby.name = "Lobby"
	add_child(lobby)
	if lobby.has_signal("start_requested"):
		lobby.connect("start_requested", Callable(self, "_on_lobby_start_requested").bind(lobby, mission_id))
	if lobby.has_signal("online_match_ready"):
		lobby.connect("online_match_ready", Callable(self, "_on_lobby_online_match_ready").bind(lobby))

func _on_lobby_start_requested(mode: int, lobby: Node, mission_id: StringName) -> void:
	if mode != 1:
		return
	Game.start_local_session()
	lobby.queue_free()
	call_deferred("_boot_local_campaign", mission_id)

func _on_lobby_online_match_ready(match: Dictionary, lobby: Node) -> void:
	var host := String(match.get("host", "")).strip_edges()
	var port := int(match.get("port", 0))
	var ticket := String(match.get("join_ticket", "")).strip_edges()
	var mission_id := StringName(String(match.get("mission_id", "mission_01_first_signal")))
	var match_id := String(match.get("match_id", "")).strip_edges()
	if host.is_empty() or port <= 0 or ticket.length() != 64 or match_id.is_empty():
		_set_lobby_status(lobby, "ASIGNACIÓN DE PARTIDA INVÁLIDA")
		push_error("Invalid orchestrated match assignment")
		return
	if _is_loopback_host(host):
		_set_lobby_status(lobby, "EL SERVIDOR PUBLICÓ UNA DIRECCIÓN LOCAL · REVISA DEADFALL_PUBLIC_HOST")
		push_error("Orchestrated match advertised loopback host to a remote client: %s" % host)
		return
	if _pending_network_session != null:
		return
	_pending_lobby = lobby as Control
	_pending_match_id = match_id
	_pending_match_endpoint = "%s:%d" % [host, port]
	if _pending_lobby != null:
		_pending_lobby.visible = false
		_pending_lobby.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_begin_match_loading(_pending_match_endpoint)
	call_deferred("_boot_network_arena_client", host, port, GuestIdentity.username, "", true, mission_id, ticket)

func _boot_local_test_range() -> void:
	var test_range := TestRangeScene.instantiate()
	test_range.name = "TestRange"
	add_child(test_range)

func _boot_local_campaign(mission_id: StringName) -> void:
	var arena := CampaignArenaScene.instantiate()
	arena.name = "CampaignArena"
	arena.set("mission_id", mission_id)
	add_child(arena)
	print("NEXORA: DEADFALL local campaign boot mission=%s" % String(mission_id))

func _boot_direct_network_client(endpoint: String, args: PackedStringArray, campaign_mode: bool, mission_id: StringName) -> void:
	var host := endpoint
	var port := 24560
	if endpoint.contains(":"):
		host = endpoint.get_slice(":", 0)
		port = int(endpoint.get_slice(":", 1))
	_boot_network_arena_client(host, port, _arg_value(args, "--name="), _arg_value(args, "--resume-token="), campaign_mode, mission_id, _arg_value(args, "--match-ticket="))

func _boot_room_network_client(code: String, directory: String, args: PackedStringArray, campaign_mode: bool, mission_id: StringName) -> void:
	_pending_room_name = _arg_value(args, "--name=")
	_pending_campaign_mode = campaign_mode
	_pending_mission_id = mission_id
	var resolver := DirectoryClientScript.new()
	resolver.name = "RoomDirectoryClient"
	add_child(resolver)
	resolver.room_resolved.connect(_on_room_resolved.bind(resolver, _arg_value(args, "--resume-token=")))
	resolver.room_resolution_failed.connect(_on_room_resolution_failed.bind(resolver))
	resolver.call_deferred("resolve_room", code, directory)

func _on_room_resolved(endpoint: Dictionary, resolver: Node, resume: String) -> void:
	_boot_network_arena_client(String(endpoint.get("host", "")), int(endpoint.get("port", 24560)), _pending_room_name, resume, _pending_campaign_mode, _pending_mission_id, "")
	resolver.queue_free()

func _on_room_resolution_failed(reason: String, resolver: Node) -> void:
	push_error("Room resolution failed: %s" % reason)
	resolver.queue_free()

func _boot_network_arena_client(host: String, port: int, requested_name: String, resume: String, campaign_mode: bool, mission_id: StringName, match_ticket: String = "") -> void:
	var arena := CampaignArenaScene.instantiate() if campaign_mode else SquadArenaScene.instantiate()
	arena.name = "CampaignArena" if campaign_mode else "DuoArena"
	if campaign_mode:
		arena.set("mission_id", mission_id)
	add_child(arena)
	var session := arena.get_node_or_null("NetworkSession")
	var name_value := requested_name if not requested_name.strip_edges().is_empty() else "Player"
	if session == null or not session.has_method("start_client"):
		push_error("NetworkSession missing")
		if not match_ticket.is_empty():
			_fail_pending_match("El mapa no contiene una sesión de red válida.")
		return
	if not match_ticket.is_empty() and _pending_lobby != null:
		_pending_network_arena = arena
		_pending_network_session = session
		if session.has_signal("joined"):
			session.connect("joined", Callable(self, "_on_orchestrated_joined"), CONNECT_ONE_SHOT)
		if session.has_signal("join_failed"):
			session.connect("join_failed", Callable(self, "_on_orchestrated_join_failed"), CONNECT_ONE_SHOT)
		if session.has_signal("disconnected"):
			session.connect("disconnected", Callable(self, "_on_orchestrated_disconnected"), CONNECT_ONE_SHOT)
		if session.has_signal("snapshot_received"):
			session.connect("snapshot_received", Callable(self, "_on_orchestrated_first_snapshot"), CONNECT_ONE_SHOT)
		_set_match_loading_stage("Conectando por ENet al servidor dedicado…", 0.42)
	var error := int(session.call("start_client", host, port, name_value, resume, match_ticket))
	if error != OK:
		push_error("Unable to start network client: %s" % error_string(error))
		if not match_ticket.is_empty():
			_fail_pending_match("No se pudo iniciar la conexión ENet: %s" % error_string(error))
		return
	if not match_ticket.is_empty() and _pending_lobby != null:
		_start_match_timeout()
		_set_match_loading_stage("Validando versión, ticket privado y escuadra…", 0.58)
	_boot_android_diagnostics()
	print("NEXORA: DEADFALL %s client connecting to %s:%d orchestrated=%s" % ["Campaign" if campaign_mode else "Squad", host, port, str(not match_ticket.is_empty())])

func _on_orchestrated_joined(entity_id: int, _resume_token: String, room_code: String) -> void:
	_stop_match_timeout()
	_set_match_loading_stage("Jugador %d admitido · escuadra %s · sincronizando mundo…" % [entity_id, room_code], 0.88)
	if _match_loading != null and _match_loading.has_method("complete"):
		_match_loading.call("complete")
	if _pending_lobby != null and is_instance_valid(_pending_lobby):
		_pending_lobby.queue_free()
	_pending_lobby = null
	_pending_network_session = null
	_pending_network_arena = null
	_pending_match_id = ""
	_pending_match_endpoint = ""
	await get_tree().create_timer(0.30).timeout
	_clear_match_loading()

func _on_orchestrated_first_snapshot(_snapshot: Dictionary) -> void:
	_set_match_loading_stage("Estado autoritativo recibido · preparando HUD…", 0.95)

func _on_orchestrated_join_failed(reason: String) -> void:
	_fail_pending_match(_match_failure_message(reason))

func _on_orchestrated_disconnected(reason: String) -> void:
	if _pending_lobby == null:
		return
	_fail_pending_match("El servidor cerró la conexión durante la carga: %s" % reason)

func _start_match_timeout() -> void:
	_stop_match_timeout()
	_match_timeout = Timer.new()
	_match_timeout.name = "MatchConnectTimeout"
	_match_timeout.one_shot = true
	_match_timeout.wait_time = MATCH_CONNECT_TIMEOUT_SECONDS
	_match_timeout.timeout.connect(_on_match_timeout)
	add_child(_match_timeout)
	_match_timeout.start()

func _stop_match_timeout() -> void:
	if _match_timeout != null and is_instance_valid(_match_timeout):
		_match_timeout.stop()
		_match_timeout.queue_free()
	_match_timeout = null

func _on_match_timeout() -> void:
	_fail_pending_match("Tiempo de conexión agotado con %s. Verifica UDP 24600–24749 en la Security List/NSG de Oracle y que DEADFALL_PUBLIC_HOST sea público." % _pending_match_endpoint)

func _begin_match_loading(endpoint: String) -> void:
	_clear_match_loading()
	_match_loading = MatchLoadingOverlayScript.new()
	_match_loading.name = "MatchLoadingOverlay"
	add_child(_match_loading)
	if _match_loading.has_signal("return_requested"):
		_match_loading.connect("return_requested", Callable(self, "_on_match_loading_return_requested"))
	_match_loading.call_deferred("begin", endpoint)

func _set_match_loading_stage(text: String, progress_ratio: float) -> void:
	if _match_loading != null and is_instance_valid(_match_loading) and _match_loading.has_method("set_stage"):
		_match_loading.call("set_stage", text, progress_ratio)

func _fail_pending_match(message: String) -> void:
	_stop_match_timeout()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if Game.is_network_client():
		Game.stop_session()
	if _pending_network_arena != null and is_instance_valid(_pending_network_arena):
		_pending_network_arena.queue_free()
	_pending_network_arena = null
	_pending_network_session = null
	if _pending_lobby != null and is_instance_valid(_pending_lobby):
		_pending_lobby.visible = false
		_set_lobby_status(_pending_lobby, "CONEXIÓN FALLIDA · REVISA EL SERVIDOR")
	if _match_loading != null and is_instance_valid(_match_loading) and _match_loading.has_method("show_error"):
		_match_loading.call("show_error", message)
	print("DEADFALL_MATCH_CLIENT_LOAD_FAILED match=%s endpoint=%s reason=%s" % [_pending_match_id, _pending_match_endpoint, message])

func _on_match_loading_return_requested() -> void:
	var failed_match_id := _pending_match_id
	_clear_match_loading()
	if _pending_lobby != null and is_instance_valid(_pending_lobby):
		_pending_lobby.visible = true
		_pending_lobby.mouse_filter = Control.MOUSE_FILTER_STOP
		_set_lobby_status(_pending_lobby, "VOLVISTE AL LOBBY · PUEDES REINTENTAR")
		var overlay := _pending_lobby.get_node_or_null("SocialOverlay")
		if overlay != null and overlay.has_method("allow_match_reentry"):
			overlay.call("allow_match_reentry", failed_match_id)
	if SocialClient != null and SocialClient.has_method("allow_match_reentry"):
		SocialClient.call("allow_match_reentry", failed_match_id)
	# Do not refresh here: a READY party would immediately re-emit the same
	# assignment and throw the player back into loading without user intent.
	_pending_lobby = null
	_pending_match_id = ""
	_pending_match_endpoint = ""

func _clear_match_loading() -> void:
	if _match_loading != null and is_instance_valid(_match_loading):
		_match_loading.queue_free()
	_match_loading = null

func _match_failure_message(reason: String) -> String:
	match reason:
		"connection_failed":
			return "No hubo respuesta del servidor dedicado. Verifica UDP 24600–24749 en Oracle/NSG."
		"match_ticket_required", "invalid_match_ticket", "match_ticket_in_use":
			return "El ticket privado de la partida fue rechazado (%s). Vuelve al lobby para solicitar una asignación nueva." % reason
		"protocol_mismatch", "protocol_mismatch_server", "client_too_old", "client_too_new", "content_version_mismatch":
			return "La versión cliente/servidor no es compatible: %s" % reason
		_:
			return "No se pudo entrar a la partida: %s" % reason

func _set_lobby_status(lobby: Node, text: String) -> void:
	if lobby == null:
		return
	var status := lobby.get("_status_label") as Label
	if status != null:
		status.text = text

func _is_loopback_host(host: String) -> bool:
	var normalized := host.strip_edges().to_lower()
	return normalized in ["127.0.0.1", "localhost", "::1", "0.0.0.0"]

func _boot_android_diagnostics() -> void:
	if not OS.has_feature("android") or not OS.is_debug_build():
		return
	var diagnostics := AndroidDiagnosticsScript.new()
	diagnostics.name = "AndroidDiagnostics"
	add_child(diagnostics)

func _boot_dedicated_server(args: PackedStringArray, campaign_mode: bool, mission_id: StringName) -> void:
	var port := int(_arg_value(args, "--port=", "24560"))
	var directory_port := int(_arg_value(args, "--directory-port=", "24561"))
	var public_host := _arg_value(args, "--public-host=", "127.0.0.1")
	var requested_room := _arg_value(args, "--room=")
	var match_instance := "--match-instance" in args
	var match_config_path := _arg_value(args, "--match-config=")
	var server := DedicatedServerScript.new()
	server.name = "DedicatedServer"
	add_child(server)
	server.start(port, 4, directory_port, public_host, requested_room, campaign_mode, mission_id, match_instance, match_config_path)

func _arg_value(args: PackedStringArray, prefix: String, fallback: String = "") -> String:
	for arg in args:
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return fallback
