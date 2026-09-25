class_name DeadfallControlApiServer
extends Node

const MAX_REQUEST_BYTES := 32768
const VALID_CHARACTER_IDS := ["operator_01", "operator_02"]

var _server := TCPServer.new()
var _clients: Array = []
var _account_store: Node
var _social_service: Node
var _match_orchestrator: Node
var listen_port := 24562

func configure(account_store: Node, social_service: Node, match_orchestrator: Node = null) -> void:
	_account_store = account_store
	_social_service = social_service
	_match_orchestrator = match_orchestrator

func start(port: int = 24562) -> Error:
	listen_port = port
	var error := _server.listen(listen_port, "127.0.0.1")
	if error != OK:
		push_error("Unable to start control API on TCP %d: %s" % [listen_port, error_string(error)])
		return error
	set_process(true)
	print("NEXORA: DEADFALL control API listening on 127.0.0.1:%d" % listen_port)
	return OK

func stop() -> void:
	set_process(false)
	for client_value in _clients:
		var client: Dictionary = Dictionary(client_value)
		var peer: StreamPeerTCP = client.get("peer") as StreamPeerTCP
		if peer != null:
			peer.disconnect_from_host()
	_clients.clear()
	_server.stop()

func _exit_tree() -> void:
	stop()

func _process(_delta: float) -> void:
	while _server.is_connection_available():
		var peer := _server.take_connection()
		if peer != null:
			_clients.append({"peer": peer, "buffer": PackedByteArray()})
	for client_value in _clients.duplicate():
		var client: Dictionary = Dictionary(client_value)
		var peer: StreamPeerTCP = client.get("peer") as StreamPeerTCP
		if peer == null:
			_clients.erase(client_value)
			continue
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_ERROR or peer.get_status() == StreamPeerTCP.STATUS_NONE:
			_clients.erase(client_value)
			continue
		var available := peer.get_available_bytes()
		if available > 0:
			var read_result := peer.get_data(available)
			if int(read_result[0]) == OK:
				var buffer: PackedByteArray = client.get("buffer", PackedByteArray())
				buffer.append_array(read_result[1])
				client["buffer"] = buffer
				var index := _clients.find(client_value)
				if index >= 0:
					_clients[index] = client
				if buffer.size() > MAX_REQUEST_BYTES:
					_send_json(peer, 413, _reject("request_too_large"))
					_clients.erase(client)
					continue
		if _request_complete(client):
			_handle_request(peer, PackedByteArray(client.get("buffer", PackedByteArray())))
			_clients.erase(client)

func _request_complete(client: Dictionary) -> bool:
	var buffer: PackedByteArray = client.get("buffer", PackedByteArray())
	if buffer.is_empty():
		return false
	var text := buffer.get_string_from_utf8()
	var separator := text.find("\r\n\r\n")
	if separator < 0:
		return false
	var header_text := text.substr(0, separator)
	var content_length := 0
	for line in header_text.split("\r\n", false):
		if String(line).to_lower().begins_with("content-length:"):
			content_length = int(String(line).get_slice(":", 1).strip_edges())
			break
	var body_start_bytes := text.substr(0, separator + 4).to_utf8_buffer().size()
	return buffer.size() >= body_start_bytes + content_length

func _handle_request(peer: StreamPeerTCP, raw: PackedByteArray) -> void:
	var text := raw.get_string_from_utf8()
	var separator := text.find("\r\n\r\n")
	if separator < 0:
		_send_json(peer, 400, _reject("invalid_http_request"))
		return
	var header_text := text.substr(0, separator)
	var body_text := text.substr(separator + 4)
	var lines := header_text.split("\r\n", false)
	if lines.is_empty():
		_send_json(peer, 400, _reject("invalid_http_request"))
		return
	var request_parts := String(lines[0]).split(" ", false)
	if request_parts.size() < 2:
		_send_json(peer, 400, _reject("invalid_http_request"))
		return
	var method := String(request_parts[0]).to_upper()
	var raw_path := String(request_parts[1])
	var path := raw_path.split("?", false)[0]
	var headers := _parse_headers(lines)
	var payload: Dictionary = {}
	if not body_text.strip_edges().is_empty():
		var parsed = JSON.parse_string(body_text)
		if typeof(parsed) != TYPE_DICTIONARY:
			_send_json(peer, 400, _reject("invalid_json"))
			return
		payload = Dictionary(parsed)
	var token := _bearer_token(headers)
	var response := _route(method, path, token, payload)
	var status := int(response.get("_status", 200 if bool(response.get("ok", false)) else 400))
	response.erase("_status")
	_send_json(peer, status, response)

func _route(method: String, path: String, token: String, payload: Dictionary) -> Dictionary:
	if method == "GET" and path == "/v1/health":
		var active_matches := 0
		if _match_orchestrator != null and _match_orchestrator.has_method("get_status_snapshot"):
			active_matches = int(Dictionary(_match_orchestrator.call("get_status_snapshot")).get("active_count", 0))
		return {"ok": true, "service": "deadfall-control", "active_matches": active_matches, "build": preload("res://src/release/BuildInfo.gd").snapshot()}
	if method == "POST" and path == "/v1/match/leave":
		if _social_service == null:
			return _server_unavailable()
		return _social_service.leave_match(token, String(payload.get("match_id", "")))
	if method == "POST" and path == "/v1/guest/register":
		if _account_store == null or _social_service == null:
			return _server_unavailable()
		var registered: Dictionary = _account_store.register_claim(payload)
		if not bool(registered.get("ok", false)):
			registered["_status"] = 409 if String(registered.get("reason", "")) == "username_taken" else 400
			return registered
		var guest_id := String(Dictionary(registered.get("account", {})).get("guest_id", ""))
		return _social_service.issue_session(guest_id)
	if method == "POST" and path == "/v1/guest/challenge":
		if _account_store == null:
			return _server_unavailable()
		return _account_store.issue_challenge(String(payload.get("guest_id", "")))
	if method == "POST" and path == "/v1/guest/verify":
		if _account_store == null or _social_service == null:
			return _server_unavailable()
		var verified: Dictionary = _account_store.verify_challenge(
			String(payload.get("guest_id", "")),
			String(payload.get("nonce", "")),
			String(payload.get("proof", ""))
		)
		if not bool(verified.get("ok", false)):
			return verified
		var guest_id := String(Dictionary(verified.get("account", {})).get("guest_id", ""))
		return _social_service.issue_session(guest_id)
	if method == "POST" and path == "/v1/presence":
		return _social_service.update_presence(token, int(payload.get("ping_ms", 999))) if _social_service != null else _server_unavailable()
	if method == "GET" and path.begins_with("/v1/profile/"):
		if _account_store == null or _social_service == null:
			return _server_unavailable()
		var profile_guest_id := String(_account_store.resolve_guest_id(path.trim_prefix("/v1/profile/")))
		if profile_guest_id.is_empty():
			return {"ok": false, "reason": "profile_not_found", "_status": 404}
		return _social_service.profile_by_id(token, profile_guest_id)
	if method == "POST" and path == "/v1/profile/character":
		if _account_store == null or _social_service == null:
			return _server_unavailable()
		var owner_guest_id := String(_social_service.guest_for_token(token))
		if owner_guest_id.is_empty():
			return {"ok": false, "reason": "unauthorized", "_status": 401}
		var character_id := String(payload.get("character_id", ""))
		if character_id not in VALID_CHARACTER_IDS:
			return _reject("invalid_character")
		if not bool(_account_store.update_character(owner_guest_id, StringName(character_id))):
			return _reject("character_update_failed")
		return {"ok": true, "account": _account_store.public_account(owner_guest_id)}
	if method == "POST" and path == "/v1/party/create":
		return _social_service.create_party(token, int(payload.get("capacity", 4))) if _social_service != null else _server_unavailable()
	if method == "POST" and path == "/v1/party/join":
		return _social_service.join_party(token, String(payload.get("code", ""))) if _social_service != null else _server_unavailable()
	if method == "POST" and path == "/v1/party/leave":
		return _social_service.leave_party(token) if _social_service != null else _server_unavailable()
	if method == "POST" and path == "/v1/party/kick":
		return _social_service.kick_member(token, String(payload.get("guest_id", ""))) if _social_service != null else _server_unavailable()
	if method == "POST" and path == "/v1/party/state":
		return _social_service.set_party_state(token, String(payload.get("state", ""))) if _social_service != null else _server_unavailable()
	if method == "GET" and path == "/v1/party/current":
		return _social_service.current_party(token) if _social_service != null else _server_unavailable()
	if method == "POST" and path == "/v1/match/start":
		if _match_orchestrator == null:
			return _server_unavailable()
		return _match_orchestrator.start_party_match(token, String(payload.get("mission_id", "mission_01_first_signal")), String(payload.get("game_mode", "campaign")), true)
	if method == "POST" and path == "/v1/match/cancel":
		if _match_orchestrator == null:
			return _server_unavailable()
		return _match_orchestrator.cancel_party_match(token)
	if method == "GET" and path == "/v1/match/status":
		if _social_service == null:
			return _server_unavailable()
		var party: Dictionary = _social_service.party_snapshot_for_token(token)
		if party.is_empty() and _social_service.guest_for_token(token).is_empty():
			return {"ok": false, "reason": "unauthorized", "_status": 401}
		return {"ok": true, "party": party}
	if method == "GET" and path == "/v1/history":
		return _social_service.match_history(token) if _social_service != null else _server_unavailable()
	if method == "POST" and path == "/v1/players/search":
		return _social_service.search_players(token, String(payload.get("query", ""))) if _social_service != null else _server_unavailable()
	if method == "POST" and path == "/v1/friends/reject":
		return _social_service.reject_friend(token, String(payload.get("guest_id", ""))) if _social_service != null else _server_unavailable()
	if method == "POST" and path == "/v1/friends/request":
		if _account_store == null or _social_service == null:
			return _server_unavailable()
		var friend_identifier := String(payload.get("account_id", payload.get("guest_id", "")))
		var friend_guest_id := String(_account_store.resolve_guest_id(friend_identifier))
		if friend_guest_id.is_empty():
			return {"ok": false, "reason": "profile_not_found", "_status": 404}
		return _social_service.request_friend(token, friend_guest_id)
	if method == "POST" and path == "/v1/friends/accept":
		return _social_service.accept_friend(token, String(payload.get("guest_id", ""))) if _social_service != null else _server_unavailable()
	if method == "GET" and path == "/v1/friends":
		return _social_service.friends_snapshot(token) if _social_service != null else _server_unavailable()
	if method == "POST" and path == "/v1/chat/party":
		return _social_service.send_party_message(token, String(payload.get("text", ""))) if _social_service != null else _server_unavailable()
	if method == "POST" and path == "/v1/chat/friend":
		return _social_service.send_friend_message(token, String(payload.get("guest_id", "")), String(payload.get("text", ""))) if _social_service != null else _server_unavailable()
	if method == "GET" and path.begins_with("/v1/chat/friend/"):
		return _social_service.friend_messages(token, path.trim_prefix("/v1/chat/friend/")) if _social_service != null else _server_unavailable()
	return {"ok": false, "reason": "not_found", "_status": 404}

func _parse_headers(lines: PackedStringArray) -> Dictionary:
	var headers := {}
	for index in range(1, lines.size()):
		var line := String(lines[index])
		var separator := line.find(":")
		if separator <= 0:
			continue
		var key := line.substr(0, separator).strip_edges().to_lower()
		var value := line.substr(separator + 1).strip_edges()
		headers[key] = value
	return headers

func _bearer_token(headers: Dictionary) -> String:
	var authorization := String(headers.get("authorization", ""))
	if not authorization.begins_with("Bearer "):
		return ""
	return authorization.trim_prefix("Bearer ").strip_edges()

func _send_json(peer: StreamPeerTCP, status_code: int, payload: Dictionary) -> void:
	var body := JSON.stringify(payload)
	var reason := _http_reason(status_code)
	var response := "HTTP/1.1 %d %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n\r\n%s" % [status_code, reason, body.to_utf8_buffer().size(), body]
	peer.put_data(response.to_utf8_buffer())
	peer.disconnect_from_host()

func _http_reason(status_code: int) -> String:
	match status_code:
		200: return "OK"
		400: return "Bad Request"
		401: return "Unauthorized"
		404: return "Not Found"
		409: return "Conflict"
		413: return "Payload Too Large"
		429: return "Too Many Requests"
		503: return "Service Unavailable"
		_: return "Error"

func _server_unavailable() -> Dictionary:
	return {"ok": false, "reason": "service_unavailable", "_status": 503}

func _reject(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
