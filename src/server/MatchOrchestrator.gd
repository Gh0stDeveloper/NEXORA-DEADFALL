class_name DeadfallMatchOrchestrator
extends Node

const PORT_START := 24600
const PORT_END := 24749
const MAX_CONCURRENT_MATCHES := 24
const MATCH_SCHEMA_VERSION := 2
const ALLOWED_MISSIONS := ["mission_01_first_signal", "mission_02_extraction"]
const HEARTBEAT_STALE_SECONDS := 12
const STARTUP_HEARTBEAT_GRACE_SECONDS := 25
const MAX_MATCH_RUNTIME_SECONDS := 60 * 60 * 2 + 30
const RESULT_REAP_GRACE_SECONDS := 12

var account_store: Node
var social_service: Node
var public_host := "127.0.0.1"
var _crypto := Crypto.new()
var _matches: Dictionary = {}
var _party_match: Dictionary = {}
var _match_dir := ""
var _port_start := PORT_START
var _port_end := PORT_END
var _metrics := {
	"started_total": 0,
	"completed_total": 0,
	"defeated_total": 0,
	"aborted_total": 0,
	"failed_total": 0,
	"frozen_total": 0,
	"crashed_total": 0,
	"cancelled_total": 0,
	"reaped_total": 0,
	"reconnects_total": 0,
}

func configure(store: Node, social: Node, configured_public_host: String) -> void:
	account_store = store
	social_service = social
	public_host = configured_public_host.strip_edges()
	if public_host.is_empty():
		public_host = "127.0.0.1"
	_match_dir = ProjectSettings.globalize_path("user://server/matches")
	DirAccess.make_dir_recursive_absolute(_match_dir)
	set_process(true)

func configure_validation_port_range(start_port: int, end_port: int) -> bool:
	if start_port <= 0 or end_port < start_port or end_port > 65535:
		return false
	if end_port - start_port > 32:
		return false
	if not _matches.is_empty():
		return false
	_port_start = start_port
	_port_end = end_port
	return true

func start_party_match(token: String, requested_mission_id: String = "mission_01_first_signal") -> Dictionary:
	if social_service == null or account_store == null:
		return _reject("orchestrator_unavailable")
	var leader_guest_id := String(social_service.call("guest_for_token", token))
	if leader_guest_id.is_empty():
		return _reject("unauthorized")
	var party: Dictionary = Dictionary(social_service.call("server_party_record_for_guest", leader_guest_id))
	if party.is_empty():
		return _reject("party_missing")
	if String(party.get("leader_guest_id", "")) != leader_guest_id:
		return _reject("leader_required")
	var party_code := String(party.get("code", ""))
	var members: Array = Array(party.get("members", []))
	if members.size() < 2:
		return _reject("party_needs_teammate")
	if members.size() > int(party.get("capacity", 4)):
		return _reject("party_capacity_invalid")
	if _party_match.has(party_code):
		var existing_match_id := String(_party_match.get(party_code, ""))
		if _matches.has(existing_match_id):
			var existing: Dictionary = Dictionary(_matches[existing_match_id])
			if _is_match_process_alive(existing) and String(existing.get("status", "")) != "RESULT":
				return {"ok": true, "reused": true, "party": social_service.call("party_snapshot_for_token", token)}
			_cleanup_match(existing_match_id, "stale_process", true)
	if _matches.size() >= MAX_CONCURRENT_MATCHES:
		return _reject("match_capacity_reached")
	var port := _allocate_port()
	if port <= 0:
		return _reject("match_ports_exhausted")
	var mission_id := requested_mission_id if requested_mission_id in ALLOWED_MISSIONS else ALLOWED_MISSIONS[0]
	var match_id := "mtc_%s" % _crypto.generate_random_bytes(8).hex_encode()
	var member_configs: Array = []
	var tickets_by_guest := {}
	for guest_value in members:
		var guest_id := String(guest_value)
		var profile: Dictionary = Dictionary(account_store.call("public_account", guest_id))
		if profile.is_empty():
			return _reject("party_member_profile_missing")
		var ticket := _crypto.generate_random_bytes(32).hex_encode()
		tickets_by_guest[guest_id] = ticket
		member_configs.append({
			"guest_id": guest_id,
			"public_id": String(profile.get("public_id", "")),
			"username": String(profile.get("username", "Player")),
			"selected_character": String(profile.get("selected_character", "operator_01")),
			"ticket": ticket,
		})
	var config_path := "%s/%s.json" % [_match_dir, match_id]
	var ready_path := "%s.ready" % config_path
	var heartbeat_path := "%s.heartbeat" % config_path
	var result_path := "%s.result" % config_path
	_remove_paths([config_path, ready_path, heartbeat_path, result_path, "%s.tmp" % heartbeat_path, "%s.tmp" % result_path])
	var created_unix := int(Time.get_unix_time_from_system())
	var config := {
		"schema_version": MATCH_SCHEMA_VERSION,
		"match_id": match_id,
		"party_code": party_code,
		"public_host": public_host,
		"port": port,
		"mission_id": mission_id,
		"created_unix": created_unix,
		"ready_path": ready_path,
		"heartbeat_path": heartbeat_path,
		"result_path": result_path,
		"members": member_configs,
	}
	if not _write_match_config(config_path, config):
		return _reject("match_config_write_failed")
	var executable := OS.get_executable_path()
	var project_root := ProjectSettings.globalize_path("res://")
	var args := PackedStringArray([
		"--headless",
		"--path", project_root,
		"--",
		"--server",
		"--match-instance",
		"--campaign",
		"--port=%d" % port,
		"--public-host=%s" % public_host,
		"--room=%s" % party_code,
		"--mission=%s" % mission_id,
		"--match-config=%s" % config_path,
	])
	var pid := OS.create_process(executable, args, false)
	if pid <= 0:
		_remove_paths([config_path, ready_path, heartbeat_path, result_path])
		return _reject("match_process_start_failed")
	var record := {
		"match_id": match_id,
		"party_code": party_code,
		"host": public_host,
		"port": port,
		"mission_id": mission_id,
		"pid": pid,
		"config_path": config_path,
		"ready_path": ready_path,
		"heartbeat_path": heartbeat_path,
		"result_path": result_path,
		"status": "STARTING",
		"created_unix": created_unix,
		"ready_unix": 0,
		"last_heartbeat_unix": 0,
		"last_heartbeat_sequence": 0,
		"connected_players": 0,
		"observed_reconnects": 0,
		"result_seen_unix": 0,
		"result": {},
		"tickets": tickets_by_guest,
		"member_count": members.size(),
	}
	_matches[match_id] = record
	_party_match[party_code] = match_id
	_metrics["started_total"] = int(_metrics["started_total"]) + 1
	social_service.call("set_party_match_assignment", party_code, _assignment_from_record(record))
	print("DEADFALL_MATCH_START match=%s party=%s port=%d pid=%d members=%d" % [match_id, party_code, port, pid, members.size()])
	return {"ok": true, "reused": false, "party": social_service.call("party_snapshot_for_token", token)}

func cancel_party_match(token: String) -> Dictionary:
	if social_service == null:
		return _reject("orchestrator_unavailable")
	var guest_id := String(social_service.call("guest_for_token", token))
	if guest_id.is_empty():
		return _reject("unauthorized")
	var party: Dictionary = Dictionary(social_service.call("server_party_record_for_guest", guest_id))
	if party.is_empty():
		return _reject("party_missing")
	if String(party.get("leader_guest_id", "")) != guest_id:
		return _reject("leader_required")
	var party_code := String(party.get("code", ""))
	var match_id := String(_party_match.get(party_code, ""))
	if match_id.is_empty() or not _matches.has(match_id):
		return {"ok": true, "party": social_service.call("party_snapshot_for_token", token)}
	var record: Dictionary = Dictionary(_matches[match_id])
	var status := String(record.get("status", ""))
	if status == "IN_MATCH" or status == "RESULT":
		return _reject("match_already_running")
	_metrics["cancelled_total"] = int(_metrics["cancelled_total"]) + 1
	_kill_process(record)
	_cleanup_match(match_id, "cancelled_by_leader", true)
	return {"ok": true, "party": social_service.call("party_snapshot_for_token", token)}

func mark_party_match_in_progress(party_code: String, match_id: String) -> void:
	if not _matches.has(match_id):
		return
	var record: Dictionary = Dictionary(_matches[match_id])
	if String(record.get("party_code", "")) != party_code:
		return
	if String(record.get("status", "")) == "IN_MATCH":
		return
	record["status"] = "IN_MATCH"
	_matches[match_id] = record
	if social_service != null:
		social_service.call("update_party_match_status", party_code, match_id, "IN_MATCH")
	print("DEADFALL_MATCH_IN_PROGRESS match=%s party=%s" % [match_id, party_code])

func get_status_snapshot() -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	var active: Array = []
	for record_value in _matches.values():
		var record: Dictionary = Dictionary(record_value)
		var last_heartbeat := int(record.get("last_heartbeat_unix", 0))
		active.append({
			"match_id": String(record.get("match_id", "")),
			"party_code": String(record.get("party_code", "")),
			"port": int(record.get("port", 0)),
			"pid": int(record.get("pid", 0)),
			"status": String(record.get("status", "")),
			"members": int(record.get("member_count", 0)),
			"connected_players": int(record.get("connected_players", 0)),
			"reconnects": int(record.get("observed_reconnects", 0)),
			"heartbeat_age_seconds": now - last_heartbeat if last_heartbeat > 0 else -1,
		})
	return {
		"active_matches": active,
		"active_count": active.size(),
		"max_concurrent": MAX_CONCURRENT_MATCHES,
		"port_start": _port_start,
		"port_end": _port_end,
		"production_port_start": PORT_START,
		"production_port_end": PORT_END,
		"heartbeat_stale_seconds": HEARTBEAT_STALE_SECONDS,
		"max_match_runtime_seconds": MAX_MATCH_RUNTIME_SECONDS,
		"metrics": _metrics.duplicate(true),
	}

func _process(_delta: float) -> void:
	var now := int(Time.get_unix_time_from_system())
	for match_id_value in _matches.keys().duplicate():
		var match_id := String(match_id_value)
		if not _matches.has(match_id):
			continue
		var record: Dictionary = Dictionary(_matches[match_id])
		var result_path := String(record.get("result_path", ""))
		if not result_path.is_empty() and FileAccess.file_exists(result_path):
			var result := _read_json(result_path)
			if not result.is_empty() and String(result.get("match_id", "")) == match_id:
				_accept_result(match_id, result, now)
				if not _matches.has(match_id):
					continue
				record = Dictionary(_matches[match_id])

		if not _is_match_process_alive(record):
			if String(record.get("status", "")) == "RESULT":
				_cleanup_match(match_id, "result_process_exited", false)
			else:
				_fail_match(match_id, "process_exited", "crashed")
			continue

		if String(record.get("status", "")) == "RESULT":
			var result_seen := int(record.get("result_seen_unix", now))
			if now - result_seen >= RESULT_REAP_GRACE_SECONDS:
				_metrics["reaped_total"] = int(_metrics["reaped_total"]) + 1
				_kill_process(record)
				_cleanup_match(match_id, "result_reaped", false)
			continue

		var created := int(record.get("created_unix", now))
		if now - created >= MAX_MATCH_RUNTIME_SECONDS:
			_fail_match(match_id, "orchestrator_ttl", "aborted")
			continue

		var ready_path := String(record.get("ready_path", ""))
		if String(record.get("status", "")) == "STARTING" and not ready_path.is_empty() and FileAccess.file_exists(ready_path):
			record["status"] = "READY"
			record["ready_unix"] = now
			_matches[match_id] = record
			if social_service != null:
				social_service.call("update_party_match_status", String(record.get("party_code", "")), match_id, "READY")
			print("DEADFALL_MATCH_READY match=%s party=%s port=%d" % [match_id, String(record.get("party_code", "")), int(record.get("port", 0))])

		var heartbeat_path := String(record.get("heartbeat_path", ""))
		if not heartbeat_path.is_empty() and FileAccess.file_exists(heartbeat_path):
			var heartbeat := _read_json(heartbeat_path)
			if String(heartbeat.get("match_id", "")) == match_id:
				record = Dictionary(_matches.get(match_id, record))
				var heartbeat_unix := int(heartbeat.get("unix", 0))
				var heartbeat_sequence := int(heartbeat.get("sequence", 0))
				if heartbeat_sequence >= int(record.get("last_heartbeat_sequence", 0)):
					record["last_heartbeat_sequence"] = heartbeat_sequence
					record["last_heartbeat_unix"] = heartbeat_unix
					record["connected_players"] = int(heartbeat.get("connected_players", 0))
					var reconnects := int(heartbeat.get("orchestrated_reconnects", 0))
					var previous_reconnects := int(record.get("observed_reconnects", 0))
					if reconnects > previous_reconnects:
						_metrics["reconnects_total"] = int(_metrics["reconnects_total"]) + reconnects - previous_reconnects
					record["observed_reconnects"] = maxi(previous_reconnects, reconnects)
					_matches[match_id] = record
					if String(record.get("status", "")) == "READY" and int(record.get("connected_players", 0)) > 0:
						mark_party_match_in_progress(String(record.get("party_code", "")), match_id)
						record = Dictionary(_matches.get(match_id, record))

		var last_heartbeat := int(record.get("last_heartbeat_unix", 0))
		var status := String(record.get("status", ""))
		if last_heartbeat > 0 and now - last_heartbeat > HEARTBEAT_STALE_SECONDS:
			_fail_match(match_id, "heartbeat_timeout", "frozen")
			continue
		if status == "STARTING" and last_heartbeat <= 0 and now - created > STARTUP_HEARTBEAT_GRACE_SECONDS:
			_fail_match(match_id, "startup_heartbeat_missing", "frozen")

func _accept_result(match_id: String, result: Dictionary, now: int) -> void:
	if not _matches.has(match_id):
		return
	var record: Dictionary = Dictionary(_matches[match_id])
	if String(record.get("status", "")) == "RESULT":
		return
	record["status"] = "RESULT"
	record["result_seen_unix"] = now
	record["result"] = result.duplicate(true)
	_matches[match_id] = record
	var outcome := String(result.get("outcome", "ABORTED")).to_upper()
	match outcome:
		"VICTORY":
			_metrics["completed_total"] = int(_metrics["completed_total"]) + 1
		"DEFEAT":
			_metrics["defeated_total"] = int(_metrics["defeated_total"]) + 1
		_:
			_metrics["aborted_total"] = int(_metrics["aborted_total"]) + 1
	var party_code := String(record.get("party_code", ""))
	if String(_party_match.get(party_code, "")) == match_id:
		_party_match.erase(party_code)
	if social_service != null:
		social_service.call("clear_party_match_assignment", party_code, match_id)
	print("DEADFALL_MATCH_RESULT_ACCEPTED match=%s party=%s outcome=%s score=%d kills=%d" % [
		match_id,
		party_code,
		outcome,
		int(result.get("score", 0)),
		int(result.get("kills", 0)),
	])

func _fail_match(match_id: String, reason: String, category: String) -> void:
	if not _matches.has(match_id):
		return
	var record: Dictionary = Dictionary(_matches[match_id])
	_metrics["failed_total"] = int(_metrics["failed_total"]) + 1
	match category:
		"frozen": _metrics["frozen_total"] = int(_metrics["frozen_total"]) + 1
		"crashed": _metrics["crashed_total"] = int(_metrics["crashed_total"]) + 1
		"aborted": _metrics["aborted_total"] = int(_metrics["aborted_total"]) + 1
	_kill_process(record)
	var party_code := String(record.get("party_code", ""))
	if social_service != null:
		social_service.call("update_party_match_status", party_code, match_id, "FAILED")
	_cleanup_match(match_id, reason, true)

func _exit_tree() -> void:
	for match_id_value in _matches.keys().duplicate():
		var match_id := String(match_id_value)
		if not _matches.has(match_id):
			continue
		var record: Dictionary = Dictionary(_matches[match_id])
		_kill_process(record)
		_cleanup_match(match_id, "orchestrator_shutdown", true)

func _assignment_from_record(record: Dictionary) -> Dictionary:
	return {
		"match_id": String(record.get("match_id", "")),
		"host": String(record.get("host", public_host)),
		"port": int(record.get("port", 0)),
		"mission_id": String(record.get("mission_id", ALLOWED_MISSIONS[0])),
		"status": String(record.get("status", "STARTING")),
		"created_unix": int(record.get("created_unix", 0)),
		"tickets": Dictionary(record.get("tickets", {})).duplicate(true),
	}

func _allocate_port() -> int:
	var used := {}
	for record_value in _matches.values():
		var record: Dictionary = Dictionary(record_value)
		if _is_match_process_alive(record):
			used[int(record.get("port", 0))] = true
	for candidate_port in range(_port_start, _port_end + 1):
		if not used.has(candidate_port):
			return candidate_port
	return 0

func _is_match_process_alive(record: Dictionary) -> bool:
	var pid := int(record.get("pid", 0))
	return pid > 0 and OS.is_process_running(pid)

func _kill_process(record: Dictionary) -> void:
	var pid := int(record.get("pid", 0))
	if pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)

func _cleanup_match(match_id: String, reason: String, clear_social: bool) -> void:
	if not _matches.has(match_id):
		return
	var record: Dictionary = Dictionary(_matches[match_id])
	var party_code := String(record.get("party_code", ""))
	_matches.erase(match_id)
	if String(_party_match.get(party_code, "")) == match_id:
		_party_match.erase(party_code)
	if clear_social and social_service != null:
		social_service.call("clear_party_match_assignment", party_code, match_id)
	_remove_paths([
		String(record.get("config_path", "")),
		String(record.get("ready_path", "")),
		String(record.get("heartbeat_path", "")),
		String(record.get("result_path", "")),
		"%s.tmp" % String(record.get("heartbeat_path", "")),
		"%s.tmp" % String(record.get("result_path", "")),
	])
	print("DEADFALL_MATCH_END match=%s party=%s reason=%s" % [match_id, party_code, reason])

func _remove_paths(paths: Array) -> void:
	for path_value in paths:
		var path := String(path_value).strip_edges()
		if not path.is_empty() and FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _write_match_config(path: String, payload: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true

func _read_json(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return Dictionary(parsed) if typeof(parsed) == TYPE_DICTIONARY else {}

func _reject(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
