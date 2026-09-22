class_name DeadfallLifecycleMtuSafeNetworkSession
extends "res://src/network/MtuSafeClosedBetaNetworkSession.gd"

signal match_finished(result: Dictionary)

const MATCH_RECONNECT_GRACE_SECONDS := 45.0

var _orchestrated_reconnects := 0
var _published_result_id := ""
var _client_result_id := ""

# Match tickets are already random 256-bit capabilities scoped to one dedicated
# match process and one guest identity. For beta.5 the server also uses that
# ticket as the internal resume-record key, so a reconnect restores only the
# authoritative entity/slot/state that belongs to the same admitted member.
@rpc("any_peer", "call_remote", "reliable", 0)
func _server_join_request(protocol: int, requested_token: String, requested_name: String, requested_match_ticket: String = "") -> void:
	if role != Role.SERVER or _match_admission == null:
		super._server_join_request(protocol, requested_token, requested_name, requested_match_ticket)
		return

	var sender := multiplayer.get_remote_sender_id()
	var clean_ticket := requested_match_ticket.strip_edges()
	if clean_ticket.length() != 64 or not clean_ticket.is_valid_hex_number(false):
		_reject_join(sender, "match_ticket_required", true)
		return
	var admitted_member: Dictionary = Dictionary(_match_admission.call("validate_ticket", clean_ticket))
	if admitted_member.is_empty():
		_reject_join(sender, "invalid_match_ticket", true)
		return
	var active_peer := int(_active_match_tickets.get(clean_ticket, 0))
	if active_peer > 0 and active_peer != sender and _peers.has(active_peer):
		_reject_join(sender, "match_ticket_in_use", true)
		return

	_cleanup_expired_resume_records()
	var reconnecting := _resume_records.has(clean_ticket)
	var clean_name := String(admitted_member.get("username", requested_name)).strip_edges()
	if clean_name.is_empty() or clean_name.length() > 24:
		_reject_join(sender, "invalid_display_name", true)
		return

	# ClosedBetaNetworkSession intentionally disables generic room resume inside
	# ticketed matches. We validate the ticket above, then temporarily expose the
	# already-authenticated join to the inherited room-resume implementation so
	# it can restore entity/slot/HP/loadout from the ticket-keyed server record.
	# This is synchronous and _match_admission is restored before returning.
	var admission := _match_admission
	_match_admission = null
	super._server_join_request(protocol, clean_ticket if reconnecting else "", clean_name, "")
	_match_admission = admission
	if not _peers.has(sender):
		return

	var record: Dictionary = Dictionary(_peers[sender])
	record["guest_id"] = String(admitted_member.get("guest_id", ""))
	record["public_id"] = String(admitted_member.get("public_id", ""))
	record["selected_character"] = String(admitted_member.get("selected_character", "operator_01"))
	record["match_ticket"] = clean_ticket
	# The inherited disconnect path stores its authoritative snapshot under
	# record.token. Binding token to this match ticket makes the resume record
	# identity- and match-scoped without trusting any client-provided state.
	record["token"] = clean_ticket
	record["last_command_usec"] = Time.get_ticks_usec()
	_peers[sender] = record
	_active_match_tickets[clean_ticket] = sender
	var player := record.get("player") as Node3D
	_configure_player_model(player, StringName(record["selected_character"]))
	record["team_id"] = int(admitted_member.get("team_id", 0))
	_peers[sender] = record
	var mode := get_parent().get_node_or_null("MatchModeDirector")
	if mode != null: mode.call("register_member", player, admitted_member, reconnecting)
	if reconnecting:
		_orchestrated_reconnects += 1
		print("DEADFALL_MATCH_RECONNECT_ACCEPTED peer=%d entity=%d guest=%s count=%d" % [
			sender,
			int(record.get("entity_id", 0)),
			String(record.get("guest_id", "")),
			_orchestrated_reconnects,
		])

func _on_server_peer_disconnected(peer_id: int) -> void:
	if role == Role.SERVER and _match_admission != null and _peers.has(peer_id):
		var record: Dictionary = Dictionary(_peers[peer_id])
		var ticket := String(record.get("match_ticket", ""))
		if ticket.length() == 64:
			record["token"] = ticket
			_peers[peer_id] = record
	super._on_server_peer_disconnected(peer_id)

func publish_match_result(raw_result: Dictionary) -> bool:
	if role != Role.SERVER or _match_admission == null or raw_result.is_empty():
		return false
	var admission: Dictionary = Dictionary(_match_admission.call("snapshot"))
	var match_id := String(admission.get("match_id", ""))
	if match_id.is_empty():
		return false
	var result := raw_result.duplicate(true)
	result["match_id"] = match_id
	result["mission_id"] = String(result.get("mission_id", admission.get("mission_id", "mission_01_first_signal")))
	result["server_authoritative"] = true
	result["completed_unix"] = int(result.get("completed_unix", Time.get_unix_time_from_system()))
	var result_id := "%s:%s:%d" % [match_id, String(result.get("outcome", "UNKNOWN")), int(result["completed_unix"])]
	if _published_result_id == result_id:
		return true
	_published_result_id = result_id
	result["result_id"] = result_id
	for peer_id in _peers.keys():
		var personal := result.duplicate(true)
		if String(result.get("game_mode", "")).begins_with("pvp_") and int(result.get("winner_team", -1)) >= 0:
			personal["outcome"] = "VICTORY" if int(_peers[peer_id].get("team_id", -2)) == int(result.winner_team) else "DEFEAT"
		rpc_id(int(peer_id), "_client_match_finished", personal)
	print("DEADFALL_MATCH_RESULT_BROADCAST match=%s outcome=%s peers=%d" % [match_id, String(result.get("outcome", "UNKNOWN")), _peers.size()])
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _client_match_finished(result: Dictionary) -> void:
	if role != Role.CLIENT or result.is_empty() or not bool(result.get("server_authoritative", false)):
		return
	var result_id := String(result.get("result_id", ""))
	if result_id.is_empty() or result_id == _client_result_id:
		return
	_client_result_id = result_id
	match_finished.emit(result.duplicate(true))
	print("DEADFALL_MATCH_RESULT_RECEIVED id=%s outcome=%s" % [result_id, String(result.get("outcome", "UNKNOWN"))])

func get_status_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.get_status_snapshot()
	snapshot["match_lifecycle"] = {
		"ticket_scoped_reconnect": _match_admission != null,
		"reconnect_grace_seconds": MATCH_RECONNECT_GRACE_SECONDS,
		"orchestrated_reconnects": _orchestrated_reconnects,
		"authoritative_result_rpc": true,
		"result_published": not _published_result_id.is_empty(),
	}
	return snapshot

func _build_player_state(peer_id: int, record: Dictionary, player: Node3D) -> Dictionary:
	var state: Dictionary = super._build_player_state(peer_id, record, player)
	state["team_id"] = int(record.get("team_id", 0))
	return state

func _apply_client_player_snapshot(player: Node3D, snapshot: Dictionary, local_player: bool) -> void:
	super._apply_client_player_snapshot(player, snapshot, local_player)
	var mode := get_parent().get_node_or_null("MatchModeDirector")
	if mode != null and preload("res://src/modes/ModeCatalog.gd").is_pvp(String(mode.game_mode)):
		mode.call("configure_pvp_player", player, int(snapshot.get("team_id", 0)))
