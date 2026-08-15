class_name DeadfallRoomDirectoryServer
extends Node

const RoomCodeScript = preload("res://src/network/RoomCodeService.gd")

var _server := TCPServer.new()
var _clients: Array[StreamPeerTCP] = []
var room_code := ""
var public_host := "127.0.0.1"
var gameplay_port := 24560
var listen_port := 24561

func start(port: int, code: String, advertised_host: String, advertised_gameplay_port: int) -> Error:
	listen_port = port
	room_code = RoomCodeScript.normalize(code)
	public_host = advertised_host.strip_edges() if not advertised_host.strip_edges().is_empty() else "127.0.0.1"
	gameplay_port = advertised_gameplay_port
	var error := _server.listen(listen_port)
	if error != OK:
		push_error("Unable to start room directory on TCP %d: %s" % [listen_port, error_string(error)])
		return error
	set_process(true)
	print("NEXORA: DEADFALL room directory listening on TCP %d room=%s" % [listen_port, room_code])
	return OK

func stop() -> void:
	set_process(false)
	_clients.clear()
	_server.stop()

func _exit_tree() -> void:
	stop()

func _process(_delta: float) -> void:
	while _server.is_connection_available():
		var peer := _server.take_connection()
		if peer != null:
			_clients.append(peer)
	for peer in _clients.duplicate():
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_ERROR or peer.get_status() == StreamPeerTCP.STATUS_NONE:
			_clients.erase(peer)
			continue
		if peer.get_available_bytes() <= 0:
			continue
		var request := peer.get_utf8_string(peer.get_available_bytes())
		_respond(peer, request)
		_clients.erase(peer)

func _respond(peer: StreamPeerTCP, request: String) -> void:
	var first_line := request.split("\r\n", false)[0] if not request.is_empty() else ""
	var parts := first_line.split(" ", false)
	var requested_code := ""
	if parts.size() >= 2 and String(parts[0]) == "GET" and String(parts[1]).begins_with("/room/"):
		requested_code = RoomCodeScript.normalize(String(parts[1]).trim_prefix("/room/").split("?", false)[0])
	var ok := RoomCodeScript.is_valid(requested_code) and requested_code == room_code
	var payload := {
		"ok": ok,
		"room_code": room_code if ok else requested_code,
		"host": public_host if ok else "",
		"port": gameplay_port if ok else 0,
		"protocol": RoomCodeScript.PROTOCOL_VERSION,
		"max_players": RoomCodeScript.MAX_PLAYERS,
	}
	var body := JSON.stringify(payload)
	var status := "200 OK" if ok else "404 Not Found"
	var response := "HTTP/1.1 %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n%s" % [status, body.to_utf8_buffer().size(), body]
	peer.put_data(response.to_utf8_buffer())
	peer.disconnect_from_host()
