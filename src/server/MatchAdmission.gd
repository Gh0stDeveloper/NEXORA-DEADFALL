class_name DeadfallMatchAdmission
extends RefCounted

const SCHEMA_VERSION := 2

var match_id := ""
var party_code := ""
var public_host := ""
var port := 0
var mission_id := "mission_01_first_signal"
var created_unix := 0
var ready_path := ""
var heartbeat_path := ""
var result_path := ""
var expected_members := 0
var _members_by_ticket: Dictionary = {}
var _tickets_by_guest: Dictionary = {}

func load_from_file(path: String) -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return false
	var root: Dictionary = Dictionary(json.data)
	if int(root.get("schema_version", 0)) != SCHEMA_VERSION:
		return false
	match_id = String(root.get("match_id", "")).strip_edges()
	party_code = String(root.get("party_code", "")).strip_edges()
	public_host = String(root.get("public_host", "")).strip_edges()
	port = int(root.get("port", 0))
	mission_id = String(root.get("mission_id", "mission_01_first_signal"))
	created_unix = int(root.get("created_unix", 0))
	ready_path = String(root.get("ready_path", "")).strip_edges()
	heartbeat_path = String(root.get("heartbeat_path", "")).strip_edges()
	result_path = String(root.get("result_path", "")).strip_edges()
	_members_by_ticket.clear()
	_tickets_by_guest.clear()
	var members_value: Variant = root.get("members", [])
	if typeof(members_value) != TYPE_ARRAY:
		return false
	for item in Array(members_value):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var member := Dictionary(item).duplicate(true)
		var ticket := String(member.get("ticket", "")).strip_edges()
		var guest_id := String(member.get("guest_id", "")).strip_edges()
		if ticket.length() != 64 or not ticket.is_valid_hex_number(false) or guest_id.is_empty():
			continue
		_members_by_ticket[ticket] = member
		_tickets_by_guest[guest_id] = ticket
	expected_members = _members_by_ticket.size()
	return (
		not match_id.is_empty()
		and not party_code.is_empty()
		and port > 0
		and expected_members > 0
		and not ready_path.is_empty()
		and not heartbeat_path.is_empty()
		and not result_path.is_empty()
	)

func validate_ticket(ticket: String) -> Dictionary:
	var clean := ticket.strip_edges()
	if clean.is_empty() or not _members_by_ticket.has(clean):
		return {}
	return Dictionary(_members_by_ticket[clean]).duplicate(true)

func ticket_for_guest(guest_id: String) -> String:
	return String(_tickets_by_guest.get(guest_id, ""))

func member_for_guest(guest_id: String) -> Dictionary:
	var ticket := ticket_for_guest(guest_id)
	return validate_ticket(ticket) if not ticket.is_empty() else {}

func all_members() -> Array:
	var result: Array = []
	for member in _members_by_ticket.values():
		result.append(Dictionary(member).duplicate(true))
	return result

func snapshot() -> Dictionary:
	return {
		"match_id": match_id,
		"party_code": party_code,
		"public_host": public_host,
		"port": port,
		"mission_id": mission_id,
		"created_unix": created_unix,
		"ready_path": ready_path,
		"heartbeat_path": heartbeat_path,
		"result_path": result_path,
		"expected_members": expected_members,
	}
