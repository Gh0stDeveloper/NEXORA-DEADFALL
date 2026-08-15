extends Node

const DedicatedServerScript = preload("res://src/server/DedicatedServer.gd")
const TestRangeScene = preload("res://src/maps/test_range/TestRange.tscn")
const DuoArenaScene = preload("res://src/maps/duo/DuoArena.tscn")
const DirectoryClientScript = preload("res://src/network/RoomDirectoryClient.gd")
const AndroidDiagnosticsScript = preload("res://src/mobile/AndroidDiagnostics.gd")

var _pending_room_name := "Player"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--server" in args:
		_boot_dedicated_server(args)
		return
	var connect_value := _arg_value(args, "--connect=")
	if not connect_value.is_empty():
		_boot_direct_network_client(connect_value, args)
		return
	var room_value := _arg_value(args, "--room=")
	var directory_value := _arg_value(args, "--directory=")
	if not room_value.is_empty() and not directory_value.is_empty():
		_boot_room_network_client(room_value, directory_value, args)
		return
	Game.start_local_session()
	_boot_local_vertical_slice()
	_boot_android_diagnostics()
	print("NEXORA: DEADFALL client bootstrap ready")

func _boot_local_vertical_slice() -> void:
	var test_range := TestRangeScene.instantiate()
	test_range.name = "TestRange"
	add_child(test_range)

func _boot_direct_network_client(endpoint: String, args: PackedStringArray) -> void:
	var host := endpoint
	var port := 24560
	if endpoint.contains(":"):
		host = endpoint.get_slice(":", 0)
		port = int(endpoint.get_slice(":", 1))
	_boot_duo_arena_client(host, port, _arg_value(args, "--name="), _arg_value(args, "--resume-token="))

func _boot_room_network_client(code: String, directory: String, args: PackedStringArray) -> void:
	_pending_room_name = _arg_value(args, "--name=")
	var resolver := DirectoryClientScript.new()
	resolver.name = "RoomDirectoryClient"
	add_child(resolver)
	resolver.room_resolved.connect(_on_room_resolved.bind(resolver, _arg_value(args, "--resume-token=")))
	resolver.room_resolution_failed.connect(_on_room_resolution_failed.bind(resolver))
	resolver.call_deferred("resolve_room", code, directory)

func _on_room_resolved(endpoint: Dictionary, resolver: Node, resume: String) -> void:
	_boot_duo_arena_client(String(endpoint.get("host", "")), int(endpoint.get("port", 24560)), _pending_room_name, resume)
	resolver.queue_free()

func _on_room_resolution_failed(reason: String, resolver: Node) -> void:
	push_error("Room resolution failed: %s" % reason)
	resolver.queue_free()

func _boot_duo_arena_client(host: String, port: int, requested_name: String, resume: String) -> void:
	var arena := DuoArenaScene.instantiate()
	arena.name = "DuoArena"
	add_child(arena)
	var session := arena.get_node_or_null("NetworkSession")
	var name_value := requested_name if not requested_name.strip_edges().is_empty() else "Player"
	if session == null or not session.has_method("start_client"):
		push_error("DuoArena NetworkSession missing")
		return
	var error: Error = session.call("start_client", host, port, name_value, resume)
	if error != OK:
		push_error("Unable to start duo client: %s" % error_string(error))
	_boot_android_diagnostics()
	print("NEXORA: DEADFALL duo client connecting to %s:%d" % [host, port])

func _boot_android_diagnostics() -> void:
	if not OS.has_feature("android") or not OS.is_debug_build():
		return
	var diagnostics := AndroidDiagnosticsScript.new()
	diagnostics.name = "AndroidDiagnostics"
	add_child(diagnostics)

func _boot_dedicated_server(args: PackedStringArray) -> void:
	var port := int(_arg_value(args, "--port=", "24560"))
	var directory_port := int(_arg_value(args, "--directory-port=", "24561"))
	var public_host := _arg_value(args, "--public-host=", "127.0.0.1")
	var requested_room := _arg_value(args, "--room=")
	var server := DedicatedServerScript.new()
	server.name = "DedicatedServer"
	add_child(server)
	server.start(port, 2, directory_port, public_host, requested_room)

func _arg_value(args: PackedStringArray, prefix: String, fallback: String = "") -> String:
	for arg in args:
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return fallback
