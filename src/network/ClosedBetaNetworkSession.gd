class_name DeadfallClosedBetaNetworkSession
extends "res://src/network/DuoNetworkSession.gd"

signal match_ping_updated(display_ping_ms: int, raw_ping_ms: int, quality: String)

const BuildInfoScript = preload("res://src/release/BuildInfo.gd")
const AbuseGuardScript = preload("res://src/network/NetworkAbuseGuard.gd")
const BetaPlayerCommandScript = preload("res://src/network/PlayerCommand.gd")
const PING_INTERVAL_SECONDS := 1.0
const PING_OFFLINE_SECONDS := 4.0
const EXCELLENT_PING_THRESHOLD_MS := 25
const STALE_COMMAND_USEC := 350_000

var _guard = AbuseGuardScript.new()
var _build_verified_peers: Dictionary = {}
var _client_build_verified := false
var _security_rejections := 0
var _match_admission: RefCounted
var _active_match_tickets: Dictionary = {}
var _client_match_ticket := ""
var _ping_elapsed := 0.0
var _ping_sequence := 0
var _ping_requests: Dictionary = {}
var _last_pong_usec := 0
var _raw_ping_ms := 999
var _display_ping_ms := 999
var _ping_quality := "SIN CONEXIÓN"

func configure_match_admission(admission: RefCounted) -> void:
	_match_admission = admission

func start_client(host: String, port: int = 24560, requested_name: String = "Player", requested_resume_token: String = "", requested_match_ticket: String = "") -> Error:
	_client_match_ticket = requested_match_ticket.strip_edges()
	_ping_elapsed = 0.0
	_last_pong_usec = Time.get_ticks_usec()
	_set_ping(999)
	return super.start_client(host, port, requested_name, requested_resume_token)

func _process(delta: float) -> void:
	if role == Role.SERVER:
		_neutralize_stale_server_inputs()
		return
	if role != Role.CLIENT or local_entity_id == 0:
		return
	_ping_elapsed += delta
	var now := Time.get_ticks_usec()
	if _ping_elapsed >= PING_INTERVAL_SECONDS:
		_ping_elapsed = 0.0
		_ping_sequence += 1
		_ping_requests[_ping_sequence] = now
		rpc_id(SERVER_PEER_ID, "_server_ping", _ping_sequence, now)
		_cleanup_old_ping_requests(now)
	if _last_pong_usec > 0 and float(now - _last_pong_usec) / 1_000_000.0 >= PING_OFFLINE_SECONDS:
		_set_ping(999)

func _on_connected_to_server() -> void:
	rpc_id(SERVER_PEER_ID, "_server_beta_hello", BuildInfoScript.NETWORK_PROTOCOL, BuildInfoScript.VERSION_CODE, BuildInfoScript.CONTENT_VERSION, BuildInfoScript.APP_VERSION)

func _on_server_disconnected() -> void:
	_set_ping(999)
	var telemetry := get_node_or_null("/root/NetworkTelemetry")
	if telemetry != null and telemetry.has_method("clear_match_ping"):
		telemetry.call("clear_match_ping")
	super._on_server_disconnected()

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
	rpc_id(SERVER_PEER_ID, "_server_join_request", PROTOCOL_VERSION, resume_token, display_name, _client_match_ticket)

@rpc("any_peer", "call_remote", "reliable", 0)
func _server_join_request(protocol: int, requested_token: String, requested_name: String, requested_match_ticket: String = "") -> void:
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
	var admitted_member: Dictionary = {}
	var clean_ticket := requested_match_ticket.strip_edges()
	if _match_admission != null:
		if clean_ticket.length() != 64 or not clean_ticket.is_valid_hex_number(false):
			_reject_join(sender, "match_ticket_required", true)
			return
		admitted_member = Dictionary(_match_admission.call("validate_ticket", clean_ticket))
		if admitted_member.is_empty():
			_reject_join(sender, "invalid_match_ticket", true)
			return
		var active_peer := int(_active_match_tickets.get(clean_ticket, 0))
		if active_peer > 0 and active_peer != sender and _peers.has(active_peer):
			_reject_join(sender, "match_ticket_in_use", true)
			return
		clean_name = String(admitted_member.get("username", clean_name)).strip_edges()

	if clean_name.is_empty() or clean_name.length() > 24:
		_security_reject(sender, "invalid_display_name", 2)
		return

	super._server_join_request(protocol, requested_token, clean_name)
	if not _peers.has(sender):
		return
	var record: Dictionary = Dictionary(_peers[sender])
	record["last_command_usec"] = Time.get_ticks_usec()
	if not admitted_member.is_empty():
		record["guest_id"] = String(admitted_member.get("guest_id", ""))
		record["public_id"] = String(admitted_member.get("public_id", ""))
		record["selected_character"] = String(admitted_member.get("selected_character", "operator_01"))
		record["match_ticket"] = clean_ticket
		_active_match_tickets[clean_ticket] = sender
		var player := record.get("player") as Node3D
		_configure_player_model(player, StringName(record["selected_character"]))
	_peers[sender] = record

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
	if _peers.has(sender):
		record = Dictionary(_peers[sender])
		record["last_command_usec"] = Time.get_ticks_usec()
		_peers[sender] = record

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

@rpc("any_peer", "call_remote", "unreliable_ordered", 3)
func _server_ping(sequence: int, client_sent_usec: int) -> void:
	if role != Role.SERVER:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _is_verified_gameplay_peer(sender):
		return
	if sequence <= 0 or client_sent_usec <= 0 or not _guard.allow(sender, &"ping"):
		_enforce_guard(sender)
		return
	rpc_id(sender, "_client_pong", sequence, client_sent_usec)

@rpc("authority", "call_remote", "unreliable_ordered", 3)
func _client_pong(sequence: int, client_sent_usec: int) -> void:
	if role != Role.CLIENT or not _ping_requests.has(sequence):
		return
	var stored_sent := int(_ping_requests.get(sequence, 0))
	_ping_requests.erase(sequence)
	if stored_sent <= 0 or stored_sent != client_sent_usec:
		return
	var now := Time.get_ticks_usec()
	_last_pong_usec = now
	var measured := clampi(int(round(float(now - stored_sent) / 1000.0)), 0, 999)
	_set_ping(measured)

func _build_player_state(peer_id: int, record: Dictionary, player: Node3D) -> Dictionary:
	var state: Dictionary = super._build_player_state(peer_id, record, player)
	state["public_id"] = String(record.get("public_id", ""))
	state["selected_character"] = String(record.get("selected_character", "operator_01"))
	return state

func _apply_client_player_snapshot(player: Node3D, snapshot: Dictionary, local_player: bool) -> void:
	super._apply_client_player_snapshot(player, snapshot, local_player)
	_configure_player_model(player, StringName(String(snapshot.get("selected_character", "operator_01"))))

func _configure_player_model(player: Node3D, character_id: StringName) -> void:
	if player == null or not is_instance_valid(player):
		return
	var presenter := player.get_node_or_null("VisualRoot/ModelPresenter")
	if presenter != null and presenter.has_method("configure_character"):
		presenter.call("configure_character", character_id)

func _neutralize_stale_server_inputs() -> void:
	var now := Time.get_ticks_usec()
	for peer_id in _peers.keys():
		var record: Dictionary = Dictionary(_peers[peer_id])
		var last_command_usec := int(record.get("last_command_usec", 0))
		if last_command_usec <= 0 or now - last_command_usec <= STALE_COMMAND_USEC:
			continue
		var player := record.get("player") as Node3D
		if player != null and is_instance_valid(player):
			player.set("_server_command", {})
		record["interact"] = false
		record["last_command_usec"] = 0
		_peers[peer_id] = record

func _on_server_peer_disconnected(peer_id: int) -> void:
	if _peers.has(peer_id):
		var record: Dictionary = Dictionary(_peers[peer_id])
		var ticket := String(record.get("match_ticket", ""))
		if not ticket.is_empty() and int(_active_match_tickets.get(ticket, 0)) == peer_id:
			_active_match_tickets.erase(ticket)
	_build_verified_peers.erase(peer_id)
	_guard.forget_peer(peer_id)
	super._on_server_peer_disconnected(peer_id)

func get_status_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.get_status_snapshot()
	snapshot["build"] = BuildInfoScript.snapshot()
	snapshot["build_verified"] = _client_build_verified if role == Role.CLIENT else false
	snapshot["verified_peers"] = _build_verified_peers.size() if role == Role.SERVER else 0
	snapshot["security_rejections"] = _security_rejections
	snapshot["match_admission"] = _match_admission != null
	snapshot["ping_ms"] = _display_ping_ms if role == Role.CLIENT else -1
	snapshot["raw_ping_ms"] = _raw_ping_ms if role == Role.CLIENT else -1
	snapshot["ping_quality"] = _ping_quality if role == Role.CLIENT else "SERVER"
	snapshot["authoritative_state"] = {
		"client_position_writes": false,
		"client_health_writes": false,
		"client_damage_writes": false,
		"client_ammo_writes": false,
		"client_hit_result_writes": false,
		"server_simulates_movement": true,
		"server_resolves_hits": true,
		"server_resolves_damage": true,
		"server_owns_health": true,
		"stale_input_neutralization_ms": int(STALE_COMMAND_USEC / 1000),
	}
	return snapshot

func _is_verified_gameplay_peer(peer_id: int) -> bool:
	return _build_verified_peers.has(peer_id) and _peers.has(peer_id)

func _set_ping(raw_ms: int) -> void:
	_raw_ping_ms = clampi(raw_ms, 0, 999)
	if _raw_ping_ms >= 999:
		_display_ping_ms = 999
		_ping_quality = "SIN CONEXIÓN"
	elif _raw_ping_ms <= EXCELLENT_PING_THRESHOLD_MS:
		_display_ping_ms = 0
		_ping_quality = "EXCELENTE"
	elif _raw_ping_ms <= 70:
		_display_ping_ms = _raw_ping_ms
		_ping_quality = "BUENO"
	elif _raw_ping_ms <= 140:
		_display_ping_ms = _raw_ping_ms
		_ping_quality = "MEDIO"
	else:
		_display_ping_ms = _raw_ping_ms
		_ping_quality = "ALTO"
	match_ping_updated.emit(_display_ping_ms, _raw_ping_ms, _ping_quality)
	var telemetry := get_node_or_null("/root/NetworkTelemetry")
	if telemetry != null and telemetry.has_method("set_match_ping"):
		telemetry.call("set_match_ping", _display_ping_ms, _raw_ping_ms, _ping_quality)

func _cleanup_old_ping_requests(now_usec: int) -> void:
	for sequence in _ping_requests.keys():
		if now_usec - int(_ping_requests[sequence]) > int(PING_OFFLINE_SECONDS * 2.0 * 1_000_000.0):
			_ping_requests.erase(sequence)

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
