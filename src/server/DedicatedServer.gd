class_name DeadfallDedicatedServer
extends Node

const DEFAULT_MAX_CLIENTS := 4
var peer := ENetMultiplayerPeer.new()
var listen_port := 24560

func start(port: int = 24560, max_clients: int = DEFAULT_MAX_CLIENTS) -> Error:
	listen_port = port
	var error := peer.create_server(listen_port, max_clients)
	if error != OK:
		push_error("Unable to start ENet server on UDP %d: %s" % [listen_port, error_string(error)])
		return error

	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	Game.start_dedicated_server_session()
	print("NEXORA: DEADFALL dedicated server listening on UDP %d" % listen_port)
	return OK

func stop() -> void:
	if peer != null:
		peer.close()
	if Game.session_mode == Game.SessionMode.DEDICATED_SERVER:
		Game.stop_session()

func _exit_tree() -> void:
	if Game.session_mode == Game.SessionMode.DEDICATED_SERVER:
		Game.stop_session()

func _on_peer_connected(peer_id: int) -> void:
	print("Peer connected: %d" % peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	print("Peer disconnected: %d" % peer_id)
