extends Node

const DedicatedServerScript = preload("res://src/server/DedicatedServer.gd")
const TestRangeScene = preload("res://src/maps/test_range/TestRange.tscn")
const SquadArenaScene = preload("res://src/maps/duo/DuoArena.tscn")
const CampaignArenaScene = preload("res://src/maps/campaign/OutbreakDistrict.tscn")
const LoginGateScene = preload("res://src/login/LoginGate.tscn")
const LobbyScene = preload("res://src/lobby/Lobby.tscn")
const DirectoryClientScript = preload("res://src/network/RoomDirectoryClient.gd")
const AndroidDiagnosticsScript = preload("res://src/mobile/AndroidDiagnostics.gd")

var _pending_room_name := "Player"
var _pending_campaign_mode := false
var _pending_mission_id: StringName = &"mission_01_first_signal"

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

	# Normal visible clients authenticate a persistent guest account before the
	# lobby. Headless smoke tests and explicit skip flags keep deterministic boot.
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

func _on_lobby_start_requested(mode: int, lobby: Node, mission_id: StringName) -> void:
	if mode != 1:
		return
	Game.start_local_session()
	lobby.queue_free()
	call_deferred("_boot_local_campaign", mission_id)

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
	_boot_network_arena_client(host, port, _arg_value(args, "--name="), _arg_value(args, "--resume-token="), campaign_mode, mission_id)

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
	_boot_network_arena_client(String(endpoint.get("host", "")), int(endpoint.get("port", 24560)), _pending_room_name, resume, _pending_campaign_mode, _pending_mission_id)
	resolver.queue_free()

func _on_room_resolution_failed(reason: String, resolver: Node) -> void:
	push_error("Room resolution failed: %s" % reason)
	resolver.queue_free()

func _boot_network_arena_client(host: String, port: int, requested_name: String, resume: String, campaign_mode: bool, mission_id: StringName) -> void:
	var arena := CampaignArenaScene.instantiate() if campaign_mode else SquadArenaScene.instantiate()
	arena.name = "CampaignArena" if campaign_mode else "DuoArena"
	if campaign_mode:
		arena.set("mission_id", mission_id)
	add_child(arena)
	var session := arena.get_node_or_null("NetworkSession")
	var name_value := requested_name if not requested_name.strip_edges().is_empty() else "Player"
	if session == null or not session.has_method("start_client"):
		push_error("NetworkSession missing")
		return
	var error := int(session.call("start_client", host, port, name_value, resume))
	if error != OK:
		push_error("Unable to start network client: %s" % error_string(error))
	_boot_android_diagnostics()
	print("NEXORA: DEADFALL %s client connecting to %s:%d" % ["Campaign" if campaign_mode else "Squad", host, port])

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
	var server := DedicatedServerScript.new()
	server.name = "DedicatedServer"
	add_child(server)
	server.start(port, 4, directory_port, public_host, requested_room, campaign_mode, mission_id)

func _arg_value(args: PackedStringArray, prefix: String, fallback: String = "") -> String:
	for arg in args:
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return fallback
