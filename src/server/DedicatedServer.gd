class_name DeadfallDedicatedServer
extends Node

const DEFAULT_MAX_CLIENTS := 2
const DuoArenaScene = preload("res://src/maps/duo/DuoArena.tscn")
const RoomCodeScript = preload("res://src/network/RoomCodeService.gd")
const DirectoryServerScript = preload("res://src/network/RoomDirectoryServer.gd")

var peer := ENetMultiplayerPeer.new()
var listen_port := 24560
var room_code := ""
var _arena: Node3D
var _directory: Node

func start(port: int = 24560, max_clients: int = DEFAULT_MAX_CLIENTS, directory_port: int = 24561, public_host: String = "127.0.0.1", requested_room_code: String = "") -> Error:
	listen_port = port
	room_code = RoomCodeScript.normalize(requested_room_code)
	if not RoomCodeScript.is_valid(room_code):
		room_code = RoomCodeScript.generate_code()
	var error := peer.create_server(listen_port, mini(DEFAULT_MAX_CLIENTS, max_clients))
	if error != OK:
		push_error("Unable to start ENet server on UDP %d: %s" % [listen_port, error_string(error)])
		return error
	multiplayer.multiplayer_peer = peer
	Game.start_dedicated_server_session()
	_boot_network_arena()
	_directory = DirectoryServerScript.new()
	_directory.name = "RoomDirectoryServer"
	add_child(_directory)
	var directory_error := int(_directory.call("start", directory_port, room_code, public_host, listen_port))
	if directory_error != OK:
		push_error("Unable to start Duo room directory on TCP %d: %s" % [directory_port, error_string(directory_error)])
		stop()
		return directory_error as Error
	print("NEXORA: DEADFALL dedicated server listening on UDP %d" % listen_port)
	print("DEADFALL_DUO_ROOM code=%s directory_port=%d public_host=%s" % [room_code, directory_port, public_host])
	return OK

func _boot_network_arena() -> void:
	_arena = DuoArenaScene.instantiate() as Node3D
	_arena.name = "DuoArena"
	get_parent().add_child(_arena)
	var session := _arena.get_node_or_null("NetworkSession")
	if session != null and session.has_method("configure_server"):
		session.call("configure_server", room_code)

func stop() -> void:
	if _directory != null and is_instance_valid(_directory) and _directory.has_method("stop"):
		_directory.call("stop")
	if _arena != null and is_instance_valid(_arena):
		_arena.queue_free()
	if peer != null:
		peer.close()
	if Game.session_mode == Game.SessionMode.DEDICATED_SERVER:
		Game.stop_session()

func _exit_tree() -> void:
	if Game.session_mode == Game.SessionMode.DEDICATED_SERVER:
		Game.stop_session()
