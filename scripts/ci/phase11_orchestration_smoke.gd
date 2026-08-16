extends SceneTree

const OrchestratorScript = preload("res://src/server/MatchOrchestrator.gd")
const MatchAdmissionScript = preload("res://src/server/MatchAdmission.gd")
const LEADER_TOKEN := "phase11-leader-token"
const MEMBER_TOKEN := "phase11-member-token"
const LEADER_GUEST := "gst_phase11_smoke_leader"
const MEMBER_GUEST := "gst_phase11_smoke_member"
const PARTY_CODE := "DFT242"
const TEST_PORT_START := 30000
const TEST_PORT_END := 30007
const READY_TIMEOUT_SECONDS := 20.0
const CLIENT_PROBE_TIMEOUT_SECONDS := 5
const INVALID_TICKET := "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"

class FakeAccountStore:
	extends Node
	const LEADER_GUEST_ID := "gst_phase11_smoke_leader"
	const MEMBER_GUEST_ID := "gst_phase11_smoke_member"
	var profiles := {
		LEADER_GUEST_ID: {
			"guest_id": LEADER_GUEST_ID,
			"public_id": "1111111111",
			"username": "SmokeLead",
			"selected_character": "operator_01",
		},
		MEMBER_GUEST_ID: {
			"guest_id": MEMBER_GUEST_ID,
			"public_id": "2222222222",
			"username": "SmokeMate",
			"selected_character": "operator_02",
		},
	}

	func public_account(guest_id: String) -> Dictionary:
		return Dictionary(profiles.get(guest_id, {})).duplicate(true)

class FakeSocialService:
	extends Node
	const LEADER_SESSION := "phase11-leader-token"
	const MEMBER_SESSION := "phase11-member-token"
	const LEADER_GUEST_ID := "gst_phase11_smoke_leader"
	const MEMBER_GUEST_ID := "gst_phase11_smoke_member"
	const TEAM_CODE := "DFT242"
	var assignment: Dictionary = {}
	var state := "OPEN"

	func guest_for_token(token: String) -> String:
		if token == LEADER_SESSION:
			return LEADER_GUEST_ID
		if token == MEMBER_SESSION:
			return MEMBER_GUEST_ID
		return ""

	func server_party_record_for_guest(guest_id: String) -> Dictionary:
		if guest_id not in [LEADER_GUEST_ID, MEMBER_GUEST_ID]:
			return {}
		return {
			"code": TEAM_CODE,
			"leader_guest_id": LEADER_GUEST_ID,
			"capacity": 2,
			"state": state,
			"members": [LEADER_GUEST_ID, MEMBER_GUEST_ID],
			"match": assignment.duplicate(true),
		}

	func set_party_match_assignment(code: String, value: Dictionary) -> bool:
		if code != TEAM_CODE:
			return false
		assignment = value.duplicate(true)
		state = "STARTING"
		return true

	func update_party_match_status(code: String, match_id: String, new_status: String) -> bool:
		if code != TEAM_CODE or String(assignment.get("match_id", "")) != match_id:
			return false
		assignment["status"] = new_status.to_upper()
		state = "IN_MATCH" if new_status.to_upper() == "IN_MATCH" else "STARTING"
		return true

	func clear_party_match_assignment(code: String, match_id: String) -> bool:
		if code != TEAM_CODE:
			return false
		if not assignment.is_empty() and String(assignment.get("match_id", "")) != match_id:
			return false
		assignment.clear()
		state = "OPEN"
		return true

	func party_snapshot_for_token(token: String) -> Dictionary:
		var guest_id := guest_for_token(token)
		if guest_id.is_empty():
			return {}
		var match_snapshot: Dictionary = {}
		if not assignment.is_empty():
			match_snapshot = assignment.duplicate(true)
			var tickets := Dictionary(match_snapshot.get("tickets", {}))
			match_snapshot.erase("tickets")
			match_snapshot["join_ticket"] = String(tickets.get(guest_id, ""))
		return {
			"code": TEAM_CODE,
			"leader_guest_id": LEADER_GUEST_ID,
			"capacity": 2,
			"state": state,
			"members": [LEADER_GUEST_ID, MEMBER_GUEST_ID],
			"match": match_snapshot,
		}

var _orchestrator: Node
var _store: Node
var _social: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_store = FakeAccountStore.new()
	_social = FakeSocialService.new()
	_orchestrator = OrchestratorScript.new()
	root.add_child(_orchestrator)

	if not bool(_orchestrator.call("configure_validation_port_range", TEST_PORT_START, TEST_PORT_END)):
		_fail("Could not configure isolated validation port range")
		return
	_orchestrator.call("configure", _store, _social, "127.0.0.1")

	var started: Dictionary = Dictionary(_orchestrator.call("start_party_match", LEADER_TOKEN, "mission_01_first_signal"))
	if not bool(started.get("ok", false)):
		_fail("Match orchestrator failed to start child process: %s" % String(started.get("reason", "unknown")))
		return

	var ready := false
	var deadline_usec := Time.get_ticks_usec() + int(READY_TIMEOUT_SECONDS * 1_000_000.0)
	while Time.get_ticks_usec() < deadline_usec:
		await create_timer(0.10).timeout
		var status: Dictionary = Dictionary(_orchestrator.call("get_status_snapshot"))
		var active: Array = Array(status.get("active_matches", []))
		if active.is_empty():
			_fail("Spawned match child exited before READY")
			return
		if String(Dictionary(active[0]).get("status", "")) == "READY":
			ready = true
			break

	if not ready:
		_fail("Spawned match child did not publish READY within %.1f seconds" % READY_TIMEOUT_SECONDS)
		return

	var leader_party: Dictionary = Dictionary(_social.call("party_snapshot_for_token", LEADER_TOKEN))
	var member_party: Dictionary = Dictionary(_social.call("party_snapshot_for_token", MEMBER_TOKEN))
	var leader_match: Dictionary = Dictionary(leader_party.get("match", {}))
	var member_match: Dictionary = Dictionary(member_party.get("match", {}))
	if leader_match.is_empty() or member_match.is_empty():
		_fail("Match assignment missing after READY")
		return

	for field in ["match_id", "host", "port"]:
		if leader_match.get(field) != member_match.get(field):
			_fail("Party members received different %s values" % field)
			return

	var leader_ticket := String(leader_match.get("join_ticket", ""))
	var member_ticket := String(member_match.get("join_ticket", ""))
	if leader_ticket.length() != 64 or member_ticket.length() != 64:
		_fail("Admission tickets are not 64 hex characters")
		return
	if not leader_ticket.is_valid_hex_number(false) or not member_ticket.is_valid_hex_number(false):
		_fail("Admission tickets are not valid hexadecimal values")
		return
	if leader_ticket == member_ticket:
		_fail("Party members received the same admission ticket")
		return

	var match_id := String(leader_match.get("match_id", ""))
	var config_path := ProjectSettings.globalize_path("user://server/matches/%s.json" % match_id)
	var admission = MatchAdmissionScript.new()
	if not bool(admission.load_from_file(config_path)):
		_fail("Generated match admission config could not be reloaded")
		return
	var leader_admission: Dictionary = admission.validate_ticket(leader_ticket)
	var member_admission: Dictionary = admission.validate_ticket(member_ticket)
	if String(leader_admission.get("guest_id", "")) != LEADER_GUEST:
		_fail("Leader ticket does not resolve to the leader identity")
		return
	if String(member_admission.get("guest_id", "")) != MEMBER_GUEST:
		_fail("Member ticket does not resolve to the member identity")
		return
	if not admission.validate_ticket("").is_empty():
		_fail("Empty ticket unexpectedly passed admission")
		return
	if not admission.validate_ticket(INVALID_TICKET).is_empty():
		_fail("Unknown ticket unexpectedly passed admission")
		return

	var assigned_port := int(leader_match.get("port", 0))
	if assigned_port < TEST_PORT_START or assigned_port > TEST_PORT_END:
		_fail("Validation match did not use isolated test port range")
		return

	if OS.get_name() != "Linux":
		_fail("Phase 11.3 network probes require the Linux/VPS validation environment")
		return
	if not _run_network_probe(assigned_port, "", "DEADFALL_SQUAD_JOIN_REJECTED reason=match_ticket_required", "NoTicket"):
		return
	if not _run_network_probe(assigned_port, leader_ticket, "DEADFALL_SQUAD_JOIN_ACCEPTED", "TicketLeader"):
		return
	if not _run_network_probe(assigned_port, member_ticket, "DEADFALL_SQUAD_JOIN_ACCEPTED", "TicketMember"):
		return

	var status_after_ready: Dictionary = Dictionary(_orchestrator.call("get_status_snapshot"))
	if int(status_after_ready.get("production_port_start", 0)) != 24600 or int(status_after_ready.get("production_port_end", 0)) != 24749:
		_fail("Production match port contract changed during validation")
		return

	var cancelled: Dictionary = Dictionary(_orchestrator.call("cancel_party_match", LEADER_TOKEN))
	if not bool(cancelled.get("ok", false)):
		_fail("Validation match child could not be cancelled cleanly")
		return
	await create_timer(0.20).timeout
	var final_status: Dictionary = Dictionary(_orchestrator.call("get_status_snapshot"))
	if int(final_status.get("active_count", -1)) != 0:
		_fail("Validation match was not cleaned from orchestrator state")
		return

	_cleanup()
	print("NEXORA: DEADFALL Phase 11.3 real child-process orchestration smoke passed")
	quit(0)

func _run_network_probe(port: int, ticket: String, expected_marker: String, probe_name: String) -> bool:
	var project_root := ProjectSettings.globalize_path("res://")
	var process_args := PackedStringArray([
		"%ds" % CLIENT_PROBE_TIMEOUT_SECONDS,
		OS.get_executable_path(),
		"--headless",
		"--path", project_root,
		"--",
		"--connect=127.0.0.1:%d" % port,
		"--campaign",
		"--name=%s" % probe_name,
	])
	if not ticket.is_empty():
		process_args.append("--match-ticket=%s" % ticket)
	var output: Array = []
	var exit_code := OS.execute("timeout", process_args, output, true)
	var text := String(output[0]) if not output.is_empty() else ""
	if not text.contains(expected_marker):
		_fail("Network probe %s did not produce expected marker '%s' (exit=%d): %s" % [probe_name, expected_marker, exit_code, text])
		return false
	print("DEADFALL_PHASE11_NETWORK_PROBE name=%s marker=%s exit=%d" % [probe_name, expected_marker, exit_code])
	return true

func _cleanup() -> void:
	if _orchestrator != null and is_instance_valid(_orchestrator):
		_orchestrator.free()
	_orchestrator = null
	if _social != null and is_instance_valid(_social):
		_social.free()
	_social = null
	if _store != null and is_instance_valid(_store):
		_store.free()
	_store = null

func _fail(message: String) -> void:
	push_error(message)
	_cleanup()
	quit(1)
