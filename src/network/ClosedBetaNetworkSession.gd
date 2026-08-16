class_name DeadfallClosedBetaNetworkSession
extends "res://src/network/DuoNetworkSession.gd"

const BuildInfoScript = preload("res://src/release/BuildInfo.gd")
const AbuseGuardScript = preload("res://src/network/NetworkAbuseGuard.gd")
const BetaPlayerCommandScript = preload("res://src/network/PlayerCommand.gd")

var _guard = AbuseGuardScript.new()
var _build_verified_peers: Dictionary = {}
var _client_build_verified := false
var _security_rejections := 0

func _on_connected_to_server() -> void:
	rpc_id(SERVER_PEER_ID, "_server_beta_hello", BuildInfoScript.NETWORK_PROTOCOL, BuildInfoScript.VERSION_CODE, BuildInfoScript.CONTENT_VERSION, BuildInfoScript.APP_VERSION)

@rpc("any_peer", "call_remote", "reliable", 0)
func _server_beta_hello(protocol: int, version_code: int, content_version: int, app_version: String) -> void:
	if role != Role.SERVER:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _guard.allow(sender, &"hello"):
		_enforce_guard(sender)
		return
	if app_version.length() > 48:
		_security_reject(sender, "invalid_build_label", 2)
		return
	var compatibility := BuildInfoScript.validate_client(protocol, version_code, content_version)
	if not bool(compatibility.get("compatible", false)):
		_reject_join(sender, String(compatibility.get("reason", "incompatible_build")), true)
		return
	_build_verified_peers[sender] = {
		"version_code": version_code,
		"content_version": content_version,
		"app_version": app_version.left(48),
	}
	rpc_id(sender, "_client_beta_hello_accepted", BuildInfoScript.snapshot())

@rpc("authority", "call_remote", "reliable", 0)
func _client_beta_hello_accepted(server_build: Dictionary) -> void:
	if role != Role.CLIENT:
		return
	var compatibility := BuildInfoScript.validate_server_snapshot(server_build)
	if not bool(compatibility.get("compatible", false)):
		_client_join_rejected(String(compatibility.get("reason", "incompatible_server")))
		return
	_client_build_verified = true
	rpc_id(SERVER_PEER_ID, "_server_join_request", PROTOCOL_VERSION, resume_token, display_name)

@rpc("any_peer", "call_remote", "reliable", 0)
func _server_join_request(protocol: int, requested_token: String, requested_name: String) -> void:
	if role != Role.SERVER:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _build_verified_peers.has(sender):
		_reject_join(sender, "build_handshake_required", true)
		return
	if not _guard.allow(sender, &"join"):
		_enforce_guard(sender)
		return
	if requested_token.length() > 64:
		_security_reject(sender, "invalid_resume_token", 3)
		return
	var clean_name := requested_name.strip_edges()
	if clean_name.is_empty() or clean_name.length() > 24:
		_security_reject(sender, "invalid_display_name", 2)
		return
	super._server_join_request(protocol, requested_token, clean_name)

@rpc("any_peer", "call_remote", "unreliable_ordered", 0)
func _server_submit_command(raw_command: Dictionary) -> void:
	if role != Role.SERVER:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _is_verified_gameplay_peer(sender):
		_security_reject(sender, "command_before_join", 3)
		return
	if not _guard.allow(sender, &"command"):
		_enforce_guard(sender)
		return
	if not _guard.validate_payload(raw_command, 1024):
		_security_reject(sender, "command_payload_too_large", 3)
		return
	var record: Dictionary = _peers.get(sender, {})
	if not BetaPlayerCommandScript.validate_shape(raw_command, int(record.get("last_command_seq", -1))):
		_security_reject(sender, "malformed_command", 2)
		return
	super._server_submit_command(raw_command)

@rpc("any_peer", "call_remote", "reliable", 2)
func _server_fire_request(request_sequence: int, client_tick: int) -> void:
	if role != Role.SERVER:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _is_verified_gameplay_peer(sender):
		_security_reject(sender, "fire_before_join", 3)
		return
	if not _guard.allow(sender, &"fire"):
		_enforce_guard(sender)
		return
	if request_sequence <= 0 or client_tick < 0:
		_security_reject(sender, "invalid_fire_request", 2)
		return
	super._server_fire_request(request_sequence, client_tick)

@rpc("any_peer", "call_remote", "reliable", 2)
func _server_reload_request(request_sequence: int) -> void:
	if role != Role.SERVER:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _is_verified_gameplay_peer(sender):
		_security_reject(sender, "reload_before_join", 3)
		return
	if not _guard.allow(sender, &"reload"):
		_enforce_guard(sender)
		return
	if request_sequence <= 0:
		_security_reject(sender, "invalid_reload_request", 2)
		return
	super._server_reload_request(request_sequence)

@rpc("any_peer", "call_remote", "reliable", 2)
func _server_restart_request() -> void:
	if role != Role.SERVER:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _is_verified_gameplay_peer(sender):
		_security_reject(sender, "restart_before_join", 3)
		return
	if not _guard.allow(sender, &"restart"):
		_enforce_guard(sender)
		return
	super._server_restart_request()

func _on_server_peer_disconnected(peer_id: int) -> void:
	_build_verified_peers.erase(peer_id)
	_guard.forget_peer(peer_id)
	super._on_server_peer_disconnected(peer_id)

func get_status_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.get_status_snapshot()
	snapshot["build"] = BuildInfoScript.snapshot()
	snapshot["build_verified"] = _client_build_verified if role == Role.CLIENT else false
	snapshot["verified_peers"] = _build_verified_peers.size() if role == Role.SERVER else 0
	snapshot["security_rejections"] = _security_rejections
	return snapshot

func _is_verified_gameplay_peer(peer_id: int) -> bool:
	return _build_verified_peers.has(peer_id) and _peers.has(peer_id)

func _security_reject(peer_id: int, reason: String, weight: int = 1) -> void:
	_security_rejections += 1
	var strikes := _guard.record_strike(peer_id, reason, weight)
	_record_security_event(peer_id, reason, strikes)
	_enforce_guard(peer_id)

func _reject_join(peer_id: int, reason: String, immediate_disconnect: bool) -> void:
	_security_rejections += 1
	var strikes := _guard.record_strike(peer_id, reason, 2)
	_record_security_event(peer_id, reason, strikes)
	rpc_id(peer_id, "_client_join_rejected", reason)
	if immediate_disconnect:
		call_deferred("_disconnect_peer", peer_id)

func _enforce_guard(peer_id: int) -> void:
	if _guard.should_disconnect(peer_id):
		call_deferred("_disconnect_peer", peer_id)

func _disconnect_peer(peer_id: int) -> void:
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.has_method("disconnect_peer"):
		multiplayer.multiplayer_peer.disconnect_peer(peer_id, false)

func _record_security_event(peer_id: int, reason: String, strikes: int) -> void:
	var runtime := get_node_or_null("/root/BetaRuntime")
	if runtime != null and runtime.has_method("record_security_event"):
		runtime.call("record_security_event", peer_id, reason, strikes)
