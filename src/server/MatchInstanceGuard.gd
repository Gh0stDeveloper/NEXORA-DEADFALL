class_name DeadfallMatchInstanceGuard
extends Node

const STARTUP_GRACE_SECONDS := 90.0
const EMPTY_GRACE_SECONDS := 75.0
const MAX_MATCH_SECONDS := 60.0 * 60.0 * 2.0
const HEARTBEAT_INTERVAL_SECONDS := 2.0
const RESULT_DELIVERY_GRACE_SECONDS := 7.0

var network_session: Node
var campaign_director: Node
var horde_director: Node
var match_id := ""
var heartbeat_path := ""
var result_path := ""
var _started_usec := 0
var _ever_had_player := false
var _empty_since_usec := 0
var _heartbeat_elapsed := 0.0
var _heartbeat_sequence := 0
var _result_published := false
var _result_exit_usec := 0

func configure(
	session: Node,
	configured_match_id: String,
	configured_heartbeat_path: String = "",
	configured_result_path: String = "",
	campaign: Node = null,
	horde: Node = null
) -> void:
	network_session = session
	match_id = configured_match_id
	heartbeat_path = configured_heartbeat_path.strip_edges()
	result_path = configured_result_path.strip_edges()
	campaign_director = campaign
	horde_director = horde
	_started_usec = Time.get_ticks_usec()
	_bind_terminal_signals()
	_write_heartbeat("STARTING")
	set_process(true)

func _process(delta: float) -> void:
	if network_session == null or not is_instance_valid(network_session):
		return
	_heartbeat_elapsed += delta
	if _heartbeat_elapsed >= HEARTBEAT_INTERVAL_SECONDS:
		_heartbeat_elapsed = 0.0
		_write_heartbeat("RESULT" if _result_published else "RUNNING")

	var now := Time.get_ticks_usec()
	if _result_published:
		if _result_exit_usec > 0 and now >= _result_exit_usec:
			_shutdown("result_delivered")
		return

	var elapsed := float(now - _started_usec) / 1_000_000.0
	if elapsed >= MAX_MATCH_SECONDS:
		_finalize_result("ABORTED", "absolute_timeout")
		return

	var connected := _connected_players()
	if connected > 0:
		_ever_had_player = true
		_empty_since_usec = 0
		return
	if not _ever_had_player:
		if elapsed >= STARTUP_GRACE_SECONDS:
			_finalize_result("ABORTED", "startup_timeout")
		return
	if _empty_since_usec == 0:
		_empty_since_usec = now
		return
	if float(now - _empty_since_usec) / 1_000_000.0 >= EMPTY_GRACE_SECONDS:
		_finalize_result("ABORTED", "empty_timeout")

func _bind_terminal_signals() -> void:
	if campaign_director != null and campaign_director.has_signal("mission_completed"):
		var mission_callable := Callable(self, "_on_mission_completed")
		if not campaign_director.is_connected("mission_completed", mission_callable):
			campaign_director.connect("mission_completed", mission_callable)
	if horde_director != null and horde_director.has_signal("game_over"):
		var game_over_callable := Callable(self, "_on_game_over")
		if not horde_director.is_connected("game_over", game_over_callable):
			horde_director.connect("game_over", game_over_callable)

func _on_mission_completed(mission_id: StringName) -> void:
	_finalize_result("VICTORY", "mission_completed", String(mission_id))

func _on_game_over(wave_number: int, score: int, kills: int) -> void:
	_finalize_result("DEFEAT", "squad_eliminated", "", wave_number, score, kills)

func _finalize_result(
	outcome: String,
	reason: String,
	mission_id_override: String = "",
	wave_override: int = -1,
	score_override: int = -1,
	kills_override: int = -1
) -> void:
	if _result_published:
		return
	var horde_snapshot := _horde_snapshot()
	var campaign_snapshot := _campaign_snapshot()
	var result := {
		"match_id": match_id,
		"outcome": outcome,
		"reason": reason,
		"mission_id": mission_id_override if not mission_id_override.is_empty() else String(campaign_snapshot.get("mission_id", "")),
		"wave": wave_override if wave_override >= 0 else int(horde_snapshot.get("wave", 0)),
		"score": score_override if score_override >= 0 else int(horde_snapshot.get("score", 0)),
		"kills": kills_override if kills_override >= 0 else int(horde_snapshot.get("kills", 0)),
		"connected_players": _connected_players(),
		"uptime_seconds": int(float(Time.get_ticks_usec() - _started_usec) / 1_000_000.0),
		"completed_unix": int(Time.get_unix_time_from_system()),
		"server_authoritative": true,
	}
	_result_published = true
	if network_session != null and network_session.has_method("publish_match_result"):
		network_session.call("publish_match_result", result)
	if not result_path.is_empty() and not _write_json_atomic(result_path, result):
		push_error("Unable to write DEADFALL match result: %s" % result_path)
	_write_heartbeat("RESULT")
	_result_exit_usec = Time.get_ticks_usec() + int(RESULT_DELIVERY_GRACE_SECONDS * 1_000_000.0)
	print("DEADFALL_MATCH_INSTANCE_RESULT match=%s outcome=%s reason=%s" % [match_id, outcome, reason])

func _write_heartbeat(phase: String) -> void:
	if heartbeat_path.is_empty():
		return
	_heartbeat_sequence += 1
	var payload := {
		"match_id": match_id,
		"pid": OS.get_process_id(),
		"sequence": _heartbeat_sequence,
		"phase": phase,
		"connected_players": _connected_players(),
		"ever_had_player": _ever_had_player,
		"result_published": _result_published,
		"monotonic_msec": Time.get_ticks_msec(),
		"unix": int(Time.get_unix_time_from_system()),
		"uptime_seconds": int(float(Time.get_ticks_usec() - _started_usec) / 1_000_000.0),
	}
	var status := _session_snapshot()
	payload["reserved_slots"] = int(status.get("reserved_slots", 0))
	payload["orchestrated_reconnects"] = int(Dictionary(status.get("match_lifecycle", {})).get("orchestrated_reconnects", 0))
	if not _write_json_atomic(heartbeat_path, payload):
		push_warning("Unable to write DEADFALL match heartbeat: %s" % heartbeat_path)

func _connected_players() -> int:
	return int(_session_snapshot().get("connected_players", 0))

func _session_snapshot() -> Dictionary:
	if network_session != null and network_session.has_method("get_status_snapshot"):
		return Dictionary(network_session.call("get_status_snapshot"))
	return {}

func _horde_snapshot() -> Dictionary:
	if horde_director != null and horde_director.has_method("get_status_snapshot"):
		return Dictionary(horde_director.call("get_status_snapshot"))
	return {}

func _campaign_snapshot() -> Dictionary:
	if campaign_director != null and campaign_director.has_method("get_status_snapshot"):
		return Dictionary(campaign_director.call("get_status_snapshot"))
	return {}

func _write_json_atomic(path: String, payload: Dictionary) -> bool:
	if path.is_empty():
		return false
	var temporary := "%s.tmp" % path
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if DirAccess.rename_absolute(temporary, path) != OK:
		DirAccess.remove_absolute(temporary)
		return false
	return true

func _shutdown(reason: String) -> void:
	_write_heartbeat("EXITING")
	print("DEADFALL_MATCH_INSTANCE_EXIT match=%s reason=%s" % [match_id, reason])
	get_tree().quit(0)
