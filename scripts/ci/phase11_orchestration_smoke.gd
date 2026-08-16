extends SceneTree

const OrchestratorScript = preload("res://src/server/MatchOrchestrator.gd")
const LEADER_TOKEN := "phase11-leader-token"
const MEMBER_TOKEN := "phase11-member-token"
const LEADER_GUEST := "gst_phase11_smoke_leader"
const MEMBER_GUEST := "gst_phase11_smoke_member"
const PARTY_CODE := "DFT242"
const TEST_PORT_START := 30000
const TEST_PORT_END := 30007
const READY_TIMEOUT_SECONDS := 20.0

class FakeAccountStore:
	extends Node
	var profiles := {
		LEADER_GUEST: {
			"guest_id": LEADER_GUEST,
			"public_id": "1111111111",
			"username": "SmokeLead",
			"selected_character": "operator_01",
		},
		MEMBER_GUEST: {
			"guest_id": MEMBER_GUEST,
			"public_id": "2222222222",
			"username": "SmokeMate",
			"selected_character": "operator_02",
		},
	}

	func public_account(guest_id: String) -> Dictionary:
		return Dictionary(profiles.get(guest_id, {})).duplicate(true)

class FakeSocialService:
	extends Node
	var assignment: Dictionary = {}
	var state := "OPEN"

	func guest_for_token(token: String) -> String:
		if token == LEADER_TOKEN:
			return LEADER_GUEST
		if token == MEMBER_TOKEN:
			return MEMBER_GUEST
		return ""

	func server_party_record_for_guest(guest_id: String) -> Dictionary:
		if guest_id not in [LEADER_GUEST, MEMBER_GUEST]:
			return {}
		return {
			"code": PARTY_CODE,
			"leader_guest_id": LEADER_GUEST,
			"capacity": 2,
			"state": state,
			"members": [LEADER_GUEST, MEMBER_GUEST],
			"match": assignment.duplicate(true),
		}

	func set_party_match_assignment(code: String, value: Dictionary) -> bool:
		if code != PARTY_CODE:
			return false
		assignment = value.duplicate(true)
		state = "STARTING"
		return true

	func update_party_match_status(code: String, match_id: String, new_status: String) -> bool:
		if code != PARTY_CODE or String(assignment.get("match_id", "")) != match_id:
			return false
		assignment["status"] = new_status.to_upper()
		state = "IN_MATCH" if new_status.to_upper() == "IN_MATCH" else "STARTING"
		return true

	func clear_party_match_assignment(code: String, match_id: String) -> bool:
		if code != PARTY_CODE:
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
			"code": PARTY_CODE,
			"leader_guest_id": LEADER_GUEST,
			"capacity": 2,
			"state": state,
			"members": [LEADER_GUEST, MEMBER_GUEST],
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

	var assigned_port := int(leader_match.get("port", 0))
	if assigned_port < TEST_PORT_START or assigned_port > TEST_PORT_END:
		_fail("Validation match did not use isolated test port range")
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
