class_name DeadfallMatchOrchestrator
extends Node

const PORT_START := 24600
const PORT_END := 24749
const MAX_CONCURRENT_MATCHES := 24
const MATCH_SCHEMA_VERSION := 1
const ALLOWED_MISSIONS := ["mission_01_first_signal", "mission_02_extraction"]

var account_store: Node
var social_service: Node
var public_host := "127.0.0.1"
var _crypto := Crypto.new()
var _matches: Dictionary = {}
var _party_match: Dictionary = {}
var _match_dir := ""

func configure(store: Node, social: Node, configured_public_host: String) -> void:
	account_store = store
	social_service = social
	public_host = configured_public_host.strip_edges()
	if public_host.is_empty():
		public_host = "127.0.0.1"
	_match_dir = ProjectSettings.globalize_path("user://server/matches")
	DirAccess.make_dir_recursive_absolute(_match_dir)
	set_process(true)

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
			if _is_match_process_alive(existing):
				return {"ok": true, "reused": true, "party": social_service.call("party_snapshot_for_token", token)}
			_cleanup_match(existing_match_id, "stale_process")
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
	if FileAccess.file_exists(ready_path):
		DirAccess.remove_absolute(ready_path)
	var config := {
		"schema_version": MATCH_SCHEMA_VERSION,
		"match_id": match_id,
		"party_code": party_code,
		"public_host": public_host,
		"port": port,
		"mission_id": mission_id,
		"created_unix": int(Time.get_unix_time_from_system()),
		"ready_path": ready_path,
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
		DirAccess.remove_absolute(config_path)
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
		"status": "STARTING",
		"created_unix": int(Time.get_unix_time_from_system()),
		"tickets": tickets_by_guest,
		"member_count": members.size(),
	}
	_matches[match_id] = record
	_party_match[party_code] = match_id
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
	if status == "IN_MATCH":
		return _reject("match_already_running")
	var pid := int(record.get("pid", 0))
	if pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)
	_cleanup_match(match_id, "cancelled_by_leader")
	return {"ok": true, "party": social_service.call("party_snapshot_for_token", token)}

func mark_party_match_in_progress(party_code: String, match_id: String) -> void:
	if not _matches.has(match_id):
		return
	var record: Dictionary = Dictionary(_matches[match_id])
	if String(record.get("party_code", "")) != party_code:
		return
	record["status"] = "IN_MATCH"
	_matches[match_id] = record
	if social_service != null:
		social_service.call("update_party_match_status", party_code, match_id, "IN_MATCH")

func get_status_snapshot() -> Dictionary:
	var active: Array = []
	for record_value in _matches.values():
		var record: Dictionary = Dictionary(record_value)
		active.append({
			"match_id": String(record.get("match_id", "")),
			"party_code": String(record.get("party_code", "")),
			"port": int(record.get("port", 0)),
			"pid": int(record.get("pid", 0)),
			"status": String(record.get("status", "")),
			"members": int(record.get("member_count", 0)),
		})
	return {
		"active_matches": active,
		"active_count": active.size(),
		"max_concurrent": MAX_CONCURRENT_MATCHES,
		"port_start": PORT_START,
		"port_end": PORT_END,
	}

func _process(_delta: float) -> void:
	for match_id_value in _matches.keys().duplicate():
		var match_id := String(match_id_value)
		if not _matches.has(match_id):
			continue
		var record: Dictionary = Dictionary(_matches[match_id])
		if not _is_match_process_alive(record):
			_cleanup_match(match_id, "process_exited")
			continue
		var ready_path := String(record.get("ready_path", ""))
		if String(record.get("status", "")) == "STARTING" and not ready_path.is_empty() and FileAccess.file_exists(ready_path):
			record["status"] = "READY"
			_matches[match_id] = record
			if social_service != null:
				social_service.call("update_party_match_status", String(record.get("party_code", "")), match_id, "READY")
			print("DEADFALL_MATCH_READY match=%s party=%s port=%d" % [match_id, String(record.get("party_code", "")), int(record.get("port", 0))])

func _exit_tree() -> void:
	for match_id_value in _matches.keys().duplicate():
		var match_id := String(match_id_value)
		if not _matches.has(match_id):
			continue
		var record: Dictionary = Dictionary(_matches[match_id])
		var pid := int(record.get("pid", 0))
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
		_cleanup_match(match_id, "orchestrator_shutdown")

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
	for candidate_port in range(PORT_START, PORT_END + 1):
		if not used.has(candidate_port):
			return candidate_port
	return 0

func _is_match_process_alive(record: Dictionary) -> bool:
	var pid := int(record.get("pid", 0))
	return pid > 0 and OS.is_process_running(pid)

func _cleanup_match(match_id: String, reason: String) -> void:
	if not _matches.has(match_id):
		return
	var record: Dictionary = Dictionary(_matches[match_id])
	var party_code := String(record.get("party_code", ""))
	var config_path := String(record.get("config_path", ""))
	var ready_path := String(record.get("ready_path", ""))
	_matches.erase(match_id)
	if String(_party_match.get(party_code, "")) == match_id:
		_party_match.erase(party_code)
	if social_service != null:
		social_service.call("clear_party_match_assignment", party_code, match_id)
	for path in [config_path, ready_path]:
		if not path.is_empty() and FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("DEADFALL_MATCH_END match=%s party=%s reason=%s" % [match_id, party_code, reason])

func _write_match_config(path: String, payload: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true

func _reject(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
