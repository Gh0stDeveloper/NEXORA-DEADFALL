extends SceneTree

const SocialServiceScript = preload("res://src/server/SocialService.gd")
const LEADER_GUEST := "gst_phase11_social_leader"
const MEMBER_GUEST := "gst_phase11_social_member"
const LEADER_TICKET := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const MEMBER_TICKET := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
const MATCH_ID := "mtc_phase11_social_smoke"

class FakeAccountStore:
	extends Node
	var profiles := {
		"gst_phase11_social_leader": {
			"guest_id": "gst_phase11_social_leader",
			"public_id": "3333333333",
			"username": "SocialLead",
			"selected_character": "operator_01",
			"created_unix": 1,
		},
		"gst_phase11_social_member": {
			"guest_id": "gst_phase11_social_member",
			"public_id": "4444444444",
			"username": "SocialMate",
			"selected_character": "operator_02",
			"created_unix": 1,
		},
	}

	func public_account(guest_id: String) -> Dictionary:
		return Dictionary(profiles.get(guest_id, {})).duplicate(true)

var _service: Node
var _store: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_store = FakeAccountStore.new()
	_service = SocialServiceScript.new()
	_service.account_store = _store
	root.add_child(_service)

	var leader_session: Dictionary = _service.issue_session(LEADER_GUEST)
	var member_session: Dictionary = _service.issue_session(MEMBER_GUEST)
	if not bool(leader_session.get("ok", false)) or not bool(member_session.get("ok", false)):
		_fail("Could not issue isolated social smoke sessions")
		return
	var leader_token := String(leader_session.get("session_token", ""))
	var member_token := String(member_session.get("session_token", ""))

	var created: Dictionary = _service.create_party(leader_token, 2)
	if not bool(created.get("ok", false)):
		_fail("Leader could not create Duo party")
		return
	var created_party: Dictionary = Dictionary(created.get("party", {}))
	var code := String(created_party.get("code", ""))
	if code.length() != 6:
		_fail("Duo party did not receive a six-character code")
		return

	var joined: Dictionary = _service.join_party(member_token, code)
	if not bool(joined.get("ok", false)):
		_fail("Member could not join leader party")
		return
	var leader_before: Dictionary = Dictionary(_service.party_snapshot_for_token(leader_token))
	var member_before: Dictionary = Dictionary(_service.party_snapshot_for_token(member_token))
	if String(leader_before.get("code", "")) != code or String(member_before.get("code", "")) != code:
		_fail("Party members do not observe the same squad code")
		return
	if Array(leader_before.get("members", [])).size() != 2 or Array(member_before.get("members", [])).size() != 2:
		_fail("Party members do not observe the same two-member roster")
		return

	var assignment: Dictionary = {
		"match_id": MATCH_ID,
		"host": "203.0.113.77",
		"port": 24642,
		"mission_id": "mission_01_first_signal",
		"status": "STARTING",
		"created_unix": int(Time.get_unix_time_from_system()),
		"tickets": {
			LEADER_GUEST: LEADER_TICKET,
			MEMBER_GUEST: MEMBER_TICKET,
		},
	}
	if not bool(_service.set_party_match_assignment(code, assignment)):
		_fail("Social service rejected a valid match assignment")
		return
	if not _validate_private_match_snapshot(Dictionary(_service.party_snapshot_for_token(leader_token)), LEADER_TICKET, MEMBER_TICKET, "leader"):
		return
	if not _validate_private_match_snapshot(Dictionary(_service.party_snapshot_for_token(member_token)), MEMBER_TICKET, LEADER_TICKET, "member"):
		return

	var kick_locked: Dictionary = _service.kick_member(leader_token, MEMBER_GUEST)
	if bool(kick_locked.get("ok", false)) or String(kick_locked.get("reason", "")) != "party_locked_for_match":
		_fail("Leader was able to kick a member while matchmaking was locked")
		return
	var leave_locked: Dictionary = _service.leave_party(member_token)
	if bool(leave_locked.get("ok", false)) or String(leave_locked.get("reason", "")) != "party_locked_for_match":
		_fail("Member was able to leave while matchmaking was locked")
		return

	if not bool(_service.update_party_match_status(code, MATCH_ID, "READY")):
		_fail("Could not transition social match assignment to READY")
		return
	var leader_ready: Dictionary = Dictionary(_service.party_snapshot_for_token(leader_token))
	var member_ready: Dictionary = Dictionary(_service.party_snapshot_for_token(member_token))
	if String(Dictionary(leader_ready.get("match", {})).get("status", "")) != "READY" or String(Dictionary(member_ready.get("match", {})).get("status", "")) != "READY":
		_fail("READY state is not shared by both party members")
		return

	if not bool(_service.clear_party_match_assignment(code, MATCH_ID)):
		_fail("Could not clear finished/cancelled match assignment")
		return
	var kick_open: Dictionary = _service.kick_member(leader_token, MEMBER_GUEST)
	if not bool(kick_open.get("ok", false)):
		_fail("Leader could not kick a member after party returned to OPEN")
		return
	var member_after_kick: Dictionary = Dictionary(_service.party_snapshot_for_token(member_token))
	if not member_after_kick.is_empty():
		_fail("Kicked member still sees the old party")
		return

	var rejoined: Dictionary = _service.join_party(member_token, code)
	if not bool(rejoined.get("ok", false)):
		_fail("Kicked member could not rejoin the open party for leave validation")
		return
	var left: Dictionary = _service.leave_party(member_token)
	if not bool(left.get("ok", false)):
		_fail("Member could not leave an open party")
		return
	if not Dictionary(_service.party_snapshot_for_token(member_token)).is_empty():
		_fail("Member still sees a party after leaving")
		return

	# Leaving an active match removes only the departing member and cannot
	# accidentally remove a new party when an old HTTP retry arrives late.
	_service.join_party(member_token, code)
	_service.set_party_match_assignment(code, assignment)
	var abandoned: Dictionary = _service.leave_match(leader_token, MATCH_ID)
	var remaining: Dictionary = _service.party_snapshot_for_token(member_token)
	if not bool(abandoned.get("ok", false)) or not Dictionary(_service.party_snapshot_for_token(leader_token)).is_empty() or String(remaining.get("leader_guest_id", "")) != MEMBER_GUEST or String(Dictionary(remaining.get("match", {})).get("match_id", "")) != MATCH_ID:
		_fail("Abandoning match disrupted the remaining teammate or retained departing membership")
		return
	_service.create_party(leader_token, 4)
	var new_party: Dictionary = _service.party_snapshot_for_token(leader_token)
	_service.leave_match(leader_token, MATCH_ID)
	if Dictionary(_service.party_snapshot_for_token(leader_token)) != new_party:
		_fail("Late leave retry removed the player's new party")
		return
	_cleanup()
	print("NEXORA: DEADFALL Phase 11.3 social matchmaking privacy/lock smoke passed")
	quit(0)

func _validate_private_match_snapshot(snapshot: Dictionary, expected_ticket: String, forbidden_ticket: String, label: String) -> bool:
	var match_snapshot: Dictionary = Dictionary(snapshot.get("match", {}))
	if String(match_snapshot.get("match_id", "")) != MATCH_ID:
		_fail("%s snapshot has wrong match id" % label)
		return false
	if String(match_snapshot.get("host", "")) != "203.0.113.77" or int(match_snapshot.get("port", 0)) != 24642:
		_fail("%s snapshot has wrong host/port" % label)
		return false
	if String(match_snapshot.get("join_ticket", "")) != expected_ticket:
		_fail("%s snapshot did not receive its own private ticket" % label)
		return false
	if match_snapshot.has("tickets"):
		_fail("%s snapshot leaked the internal ticket dictionary" % label)
		return false
	if str(snapshot).contains(forbidden_ticket):
		_fail("%s snapshot leaked another member ticket" % label)
		return false
	return true

func _cleanup() -> void:
	if _service != null and is_instance_valid(_service):
		_service.free()
	_service = null
	if _store != null and is_instance_valid(_store):
		_store.free()
	_store = null

func _fail(message: String) -> void:
	push_error(message)
	_cleanup()
	quit(1)
