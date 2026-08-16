class_name DeadfallSocialService
extends Node

const RoomCodeScript = preload("res://src/network/RoomCodeService.gd")
const STATE_DIR := "user://server"
const STATE_PATH := "user://server/social_state.dat"
const SESSION_TTL_SECONDS := 60 * 60 * 24 * 7
const PRESENCE_ONLINE_SECONDS := 15
const MAX_CHAT_LENGTH := 160
const MAX_CHAT_HISTORY := 80

var account_store: Node
var _crypto := Crypto.new()
var _sessions: Dictionary = {}
var _parties: Dictionary = {}
var _guest_party: Dictionary = {}
var _friends: Dictionary = {}
var _incoming_requests: Dictionary = {}
var _outgoing_requests: Dictionary = {}
var _direct_messages: Dictionary = {}
var _presence: Dictionary = {}
var _rate_windows: Dictionary = {}
var _message_sequence := 0

func configure(store: Node) -> void:
	account_store = store
	_load()

func issue_session(guest_id: String) -> Dictionary:
	if account_store == null or account_store.public_account(guest_id).is_empty():
		return _reject("unknown_guest")
	_cleanup_sessions()
	var token := _crypto.generate_random_bytes(32).hex_encode()
	var expires := int(Time.get_unix_time_from_system()) + SESSION_TTL_SECONDS
	_sessions[token] = {"guest_id": guest_id, "expires_unix": expires}
	_touch_presence(guest_id, 999)
	return {"ok": true, "session_token": token, "expires_unix": expires, "account": account_store.public_account(guest_id)}

func guest_for_token(token: String) -> String:
	_cleanup_sessions()
	if token.is_empty() or not _sessions.has(token):
		return ""
	return String(Dictionary(_sessions[token]).get("guest_id", ""))

func update_presence(token: String, ping_ms: int) -> Dictionary:
	var guest_id := guest_for_token(token)
	if guest_id.is_empty():
		return _reject("unauthorized")
	if not _allow(guest_id, &"presence", 20, 20.0):
		return _reject("rate_limited")
	_touch_presence(guest_id, clampi(ping_ms, 0, 999))
	return {"ok": true, "presence": _presence_snapshot(guest_id)}

func profile_by_id(requester_token: String, target_guest_id: String) -> Dictionary:
	var requester := guest_for_token(requester_token)
	if requester.is_empty():
		return _reject("unauthorized")
	if not _allow(requester, &"profile", 20, 10.0):
		return _reject("rate_limited")
	var profile: Dictionary = account_store.public_account(target_guest_id) if account_store != null else {}
	if profile.is_empty():
		return _reject("profile_not_found")
	profile["is_friend"] = _friend_list(requester).has(target_guest_id)
	profile["request_pending"] = _outgoing_list(requester).has(target_guest_id)
	profile.merge(_presence_snapshot(target_guest_id), true)
	return {"ok": true, "profile": profile}

func create_party(token: String, requested_capacity: int) -> Dictionary:
	var guest_id := guest_for_token(token)
	if guest_id.is_empty():
		return _reject("unauthorized")
	if not _allow(guest_id, &"party", 8, 15.0):
		return _reject("rate_limited")
	var existing := server_party_record_for_guest(guest_id)
	if not existing.is_empty() and _party_is_match_locked(existing):
		return _reject("party_locked_for_match")
	var capacity := 2 if requested_capacity == 2 else 4
	_leave_party_internal(guest_id)
	var code := _new_party_code()
	var party := {
		"code": code,
		"leader_guest_id": guest_id,
		"capacity": capacity,
		"state": "OPEN",
		"members": [guest_id],
		"created_unix": int(Time.get_unix_time_from_system()),
		"chat": [],
		"match": {},
	}
	_parties[code] = party
	_guest_party[guest_id] = code
	return {"ok": true, "party": _party_snapshot(code, guest_id)}

func join_party(token: String, raw_code: String) -> Dictionary:
	var guest_id := guest_for_token(token)
	if guest_id.is_empty():
		return _reject("unauthorized")
	if not _allow(guest_id, &"party", 10, 20.0):
		return _reject("rate_limited")
	var current := server_party_record_for_guest(guest_id)
	if not current.is_empty() and _party_is_match_locked(current):
		return _reject("party_locked_for_match")
	var code := RoomCodeScript.normalize(raw_code)
	if not RoomCodeScript.is_valid(code) or not _parties.has(code):
		return _reject("party_not_found")
	var party: Dictionary = Dictionary(_parties[code])
	if String(party.get("state", "OPEN")) != "OPEN" or _party_is_match_locked(party):
		return _reject("party_not_open")
	var members: Array = Array(party.get("members", []))
	if members.has(guest_id):
		_guest_party[guest_id] = code
		return {"ok": true, "party": _party_snapshot(code, guest_id)}
	if members.size() >= int(party.get("capacity", 4)):
		return _reject("party_full")
	_leave_party_internal(guest_id)
	members.append(guest_id)
	party["members"] = members
	_parties[code] = party
	_guest_party[guest_id] = code
	_append_party_system_message(code, "%s se unió a la escuadra" % _username(guest_id))
	return {"ok": true, "party": _party_snapshot(code, guest_id)}

func leave_party(token: String) -> Dictionary:
	var guest_id := guest_for_token(token)
	if guest_id.is_empty():
		return _reject("unauthorized")
	var party := server_party_record_for_guest(guest_id)
	if not party.is_empty() and _party_is_match_locked(party):
		return _reject("party_locked_for_match")
	var old_code := String(_guest_party.get(guest_id, ""))
	_leave_party_internal(guest_id)
	return {"ok": true, "left_party_code": old_code}

func kick_member(token: String, member_guest_id: String) -> Dictionary:
	var leader := guest_for_token(token)
	if leader.is_empty():
		return _reject("unauthorized")
	var code := String(_guest_party.get(leader, ""))
	if code.is_empty() or not _parties.has(code):
		return _reject("party_missing")
	var party: Dictionary = Dictionary(_parties[code])
	if String(party.get("leader_guest_id", "")) != leader:
		return _reject("leader_required")
	if _party_is_match_locked(party):
		return _reject("party_locked_for_match")
	if member_guest_id == leader:
		return _reject("cannot_kick_self")
	var members: Array = Array(party.get("members", []))
	if not members.has(member_guest_id):
		return _reject("member_not_found")
	members.erase(member_guest_id)
	party["members"] = members
	_parties[code] = party
	_guest_party.erase(member_guest_id)
	_append_party_system_message(code, "%s fue expulsado de la escuadra" % _username(member_guest_id))
	return {"ok": true, "party": _party_snapshot(code, leader)}

func current_party(token: String) -> Dictionary:
	var guest_id := guest_for_token(token)
	if guest_id.is_empty():
		return _reject("unauthorized")
	var code := String(_guest_party.get(guest_id, ""))
	if code.is_empty() or not _parties.has(code):
		return {"ok": true, "party": {}}
	return {"ok": true, "party": _party_snapshot(code, guest_id)}

func party_snapshot_for_token(token: String) -> Dictionary:
	var response := current_party(token)
	return Dictionary(response.get("party", {})).duplicate(true) if bool(response.get("ok", false)) else {}

func server_party_record_for_guest(guest_id: String) -> Dictionary:
	var code := String(_guest_party.get(guest_id, ""))
	if code.is_empty() or not _parties.has(code):
		return {}
	return Dictionary(_parties[code]).duplicate(true)

func server_party_record(code: String) -> Dictionary:
	return Dictionary(_parties[code]).duplicate(true) if _parties.has(code) else {}

func set_party_state(token: String, new_state: String) -> Dictionary:
	var guest_id := guest_for_token(token)
	if guest_id.is_empty():
		return _reject("unauthorized")
	var code := String(_guest_party.get(guest_id, ""))
	if code.is_empty() or not _parties.has(code):
		return _reject("party_missing")
	var party: Dictionary = Dictionary(_parties[code])
	if String(party.get("leader_guest_id", "")) != guest_id:
		return _reject("leader_required")
	var normalized := new_state.to_upper()
	if normalized not in ["OPEN", "STARTING", "IN_MATCH"]:
		return _reject("invalid_party_state")
	party["state"] = normalized
	_parties[code] = party
	return {"ok": true, "party": _party_snapshot(code, guest_id)}

func set_party_match_assignment(code: String, assignment: Dictionary) -> bool:
	if not _parties.has(code):
		return false
	var match_id := String(assignment.get("match_id", ""))
	var host := String(assignment.get("host", ""))
	var port := int(assignment.get("port", 0))
	var tickets: Dictionary = Dictionary(assignment.get("tickets", {}))
	if match_id.is_empty() or host.is_empty() or port <= 0 or tickets.is_empty():
		return false
	var party: Dictionary = Dictionary(_parties[code])
	party["match"] = assignment.duplicate(true)
	party["state"] = "STARTING"
	_parties[code] = party
	_append_party_system_message(code, "Buscando servidor de partida...")
	return true

func update_party_match_status(code: String, match_id: String, status: String) -> bool:
	if not _parties.has(code):
		return false
	var party: Dictionary = Dictionary(_parties[code])
	var assignment: Dictionary = Dictionary(party.get("match", {}))
	if String(assignment.get("match_id", "")) != match_id:
		return false
	var normalized := status.to_upper()
	if normalized not in ["STARTING", "READY", "IN_MATCH", "FAILED"]:
		return false
	assignment["status"] = normalized
	party["match"] = assignment
	party["state"] = "IN_MATCH" if normalized == "IN_MATCH" else "STARTING"
	_parties[code] = party
	if normalized == "READY":
		_append_party_system_message(code, "Servidor listo. Entrando a la misma partida.")
	return true

func clear_party_match_assignment(code: String, match_id: String) -> bool:
	if not _parties.has(code):
		return false
	var party: Dictionary = Dictionary(_parties[code])
	var assignment: Dictionary = Dictionary(party.get("match", {}))
	if not match_id.is_empty() and String(assignment.get("match_id", "")) != match_id:
		return false
	party["match"] = {}
	party["state"] = "OPEN"
	_parties[code] = party
	_append_party_system_message(code, "La instancia de partida terminó.")
	return true

func request_friend(token: String, target_guest_id: String) -> Dictionary:
	var source := guest_for_token(token)
	if source.is_empty():
		return _reject("unauthorized")
	if source == target_guest_id:
		return _reject("cannot_friend_self")
	if not _allow(source, &"friend", 8, 30.0):
		return _reject("rate_limited")
	if account_store == null or account_store.public_account(target_guest_id).is_empty():
		return _reject("profile_not_found")
	if _friend_list(source).has(target_guest_id):
		return {"ok": true, "already_friends": true, "friends": _friends_snapshot(source)}
	var outgoing := _outgoing_list(source)
	var incoming := _incoming_list(target_guest_id)
	if not outgoing.has(target_guest_id):
		outgoing.append(target_guest_id)
	if not incoming.has(source):
		incoming.append(source)
	_outgoing_requests[source] = outgoing
	_incoming_requests[target_guest_id] = incoming
	_save()
	return {"ok": true, "friends": _friends_snapshot(source)}

func accept_friend(token: String, source_guest_id: String) -> Dictionary:
	var target := guest_for_token(token)
	if target.is_empty():
		return _reject("unauthorized")
	var incoming := _incoming_list(target)
	if not incoming.has(source_guest_id):
		return _reject("request_not_found")
	incoming.erase(source_guest_id)
	_incoming_requests[target] = incoming
	var source_outgoing := _outgoing_list(source_guest_id)
	source_outgoing.erase(target)
	_outgoing_requests[source_guest_id] = source_outgoing
	var target_friends := _friend_list(target)
	var source_friends := _friend_list(source_guest_id)
	if not target_friends.has(source_guest_id):
		target_friends.append(source_guest_id)
	if not source_friends.has(target):
		source_friends.append(target)
	_friends[target] = target_friends
	_friends[source_guest_id] = source_friends
	_save()
	return {"ok": true, "friends": _friends_snapshot(target)}

func friends_snapshot(token: String) -> Dictionary:
	var guest_id := guest_for_token(token)
	if guest_id.is_empty():
		return _reject("unauthorized")
	return {"ok": true, "friends": _friends_snapshot(guest_id)}

func send_party_message(token: String, raw_text: String) -> Dictionary:
	var guest_id := guest_for_token(token)
	if guest_id.is_empty():
		return _reject("unauthorized")
	if not _allow(guest_id, &"chat", 8, 10.0):
		return _reject("rate_limited")
	var text := _sanitize_message(raw_text)
	if text.is_empty():
		return _reject("invalid_message")
	var code := String(_guest_party.get(guest_id, ""))
	if code.is_empty() or not _parties.has(code):
		return _reject("party_missing")
	_append_party_message(code, guest_id, text, false)
	return {"ok": true, "party": _party_snapshot(code, guest_id)}

func send_friend_message(token: String, target_guest_id: String, raw_text: String) -> Dictionary:
	var source := guest_for_token(token)
	if source.is_empty():
		return _reject("unauthorized")
	if not _friend_list(source).has(target_guest_id):
		return _reject("friend_required")
	if not _allow(source, &"chat", 8, 10.0):
		return _reject("rate_limited")
	var text := _sanitize_message(raw_text)
	if text.is_empty():
		return _reject("invalid_message")
	var key := _dm_key(source, target_guest_id)
	var history: Array = Array(_direct_messages.get(key, []))
	history.append(_new_message(source, text, false))
	while history.size() > MAX_CHAT_HISTORY:
		history.pop_front()
	_direct_messages[key] = history
	_save()
	return {"ok": true, "messages": _public_messages(history)}

func friend_messages(token: String, target_guest_id: String) -> Dictionary:
	var source := guest_for_token(token)
	if source.is_empty():
		return _reject("unauthorized")
	if not _friend_list(source).has(target_guest_id):
		return _reject("friend_required")
	var history: Array = Array(_direct_messages.get(_dm_key(source, target_guest_id), []))
	return {"ok": true, "messages": _public_messages(history)}

func _party_snapshot(code: String, requester_guest_id: String = "") -> Dictionary:
	if not _parties.has(code):
		return {}
	var party: Dictionary = Dictionary(_parties[code])
	var members_public: Array = []
	for guest_id_value in Array(party.get("members", [])):
		var guest_id := String(guest_id_value)
		var profile: Dictionary = account_store.public_account(guest_id) if account_store != null else {}
		if not profile.is_empty():
			profile["leader"] = guest_id == String(party.get("leader_guest_id", ""))
			profile.merge(_presence_snapshot(guest_id), true)
			members_public.append(profile)
	var match_public := {}
	var assignment: Dictionary = Dictionary(party.get("match", {}))
	if not assignment.is_empty():
		var tickets: Dictionary = Dictionary(assignment.get("tickets", {}))
		match_public = {
			"match_id": String(assignment.get("match_id", "")),
			"host": String(assignment.get("host", "")),
			"port": int(assignment.get("port", 0)),
			"mission_id": String(assignment.get("mission_id", "mission_01_first_signal")),
			"status": String(assignment.get("status", "STARTING")),
			"created_unix": int(assignment.get("created_unix", 0)),
			"join_ticket": String(tickets.get(requester_guest_id, "")),
		}
	return {
		"code": code,
		"leader_guest_id": String(party.get("leader_guest_id", "")),
		"capacity": int(party.get("capacity", 4)),
		"state": String(party.get("state", "OPEN")),
		"members": members_public,
		"chat": _public_messages(Array(party.get("chat", []))),
		"match": match_public,
	}

func _friends_snapshot(guest_id: String) -> Dictionary:
	var friends_public: Array = []
	for friend_id_value in _friend_list(guest_id):
		var friend_id := String(friend_id_value)
		var profile := account_store.public_account(friend_id) if account_store != null else {}
		if not profile.is_empty():
			profile.merge(_presence_snapshot(friend_id), true)
			friends_public.append(profile)
	var incoming_public: Array = []
	for request_id_value in _incoming_list(guest_id):
		var request_id := String(request_id_value)
		var profile := account_store.public_account(request_id) if account_store != null else {}
		if not profile.is_empty():
			profile.merge(_presence_snapshot(request_id), true)
			incoming_public.append(profile)
	return {"accepted": friends_public, "incoming": incoming_public, "outgoing_ids": _outgoing_list(guest_id)}

func _leave_party_internal(guest_id: String) -> void:
	var code := String(_guest_party.get(guest_id, ""))
	_guest_party.erase(guest_id)
	if code.is_empty() or not _parties.has(code):
		return
	var party: Dictionary = Dictionary(_parties[code])
	var members: Array = Array(party.get("members", []))
	members.erase(guest_id)
	if members.is_empty():
		_parties.erase(code)
		return
	if String(party.get("leader_guest_id", "")) == guest_id:
		party["leader_guest_id"] = String(members[0])
	party["members"] = members
	_parties[code] = party
	_append_party_system_message(code, "%s salió de la escuadra" % _username(guest_id))

func _party_is_match_locked(party: Dictionary) -> bool:
	var assignment: Dictionary = Dictionary(party.get("match", {}))
	if assignment.is_empty():
		return false
	return String(assignment.get("status", "")).to_upper() in ["STARTING", "READY", "IN_MATCH"]

func _touch_presence(guest_id: String, ping_ms: int) -> void:
	_presence[guest_id] = {
		"last_seen_unix": int(Time.get_unix_time_from_system()),
		"ping_ms": clampi(ping_ms, 0, 999),
	}

func _presence_snapshot(guest_id: String) -> Dictionary:
	var record: Dictionary = Dictionary(_presence.get(guest_id, {}))
	var now := int(Time.get_unix_time_from_system())
	var last_seen := int(record.get("last_seen_unix", 0))
	var online := last_seen > 0 and now - last_seen <= PRESENCE_ONLINE_SECONDS
	return {
		"online": online,
		"ping_ms": int(record.get("ping_ms", 999)) if online else 999,
		"last_seen_unix": last_seen,
	}

func _new_party_code() -> String:
	for _attempt in range(40):
		var candidate := RoomCodeScript.generate_code()
		if not _parties.has(candidate):
			return candidate
	return _crypto.generate_random_bytes(4).hex_encode().left(6).to_upper()

func _append_party_system_message(code: String, text: String) -> void:
	_append_party_message(code, "", text, true)

func _append_party_message(code: String, guest_id: String, text: String, system_message: bool) -> void:
	if not _parties.has(code):
		return
	var party: Dictionary = Dictionary(_parties[code])
	var history: Array = Array(party.get("chat", []))
	history.append(_new_message(guest_id, text, system_message))
	while history.size() > MAX_CHAT_HISTORY:
		history.pop_front()
	party["chat"] = history
	_parties[code] = party

func _new_message(guest_id: String, text: String, system_message: bool) -> Dictionary:
	_message_sequence += 1
	return {
		"id": _message_sequence,
		"guest_id": guest_id,
		"username": "SISTEMA" if system_message else _username(guest_id),
		"text": text,
		"system": system_message,
		"unix": int(Time.get_unix_time_from_system()),
	}

func _public_messages(history: Array) -> Array:
	var result: Array = []
	for item in history:
		if typeof(item) == TYPE_DICTIONARY:
			result.append(Dictionary(item).duplicate(true))
	return result

func _username(guest_id: String) -> String:
	if account_store == null:
		return "Jugador"
	var account: Dictionary = account_store.public_account(guest_id)
	return String(account.get("username", "Jugador"))

func _friend_list(guest_id: String) -> Array:
	return Array(_friends.get(guest_id, [])).duplicate()

func _incoming_list(guest_id: String) -> Array:
	return Array(_incoming_requests.get(guest_id, [])).duplicate()

func _outgoing_list(guest_id: String) -> Array:
	return Array(_outgoing_requests.get(guest_id, [])).duplicate()

func _dm_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]

func _sanitize_message(raw_text: String) -> String:
	var text := raw_text.strip_edges()
	if text.is_empty() or text.length() > MAX_CHAT_LENGTH:
		return ""
	for index in range(text.length()):
		var code := text.unicode_at(index)
		if code < 32 or code == 127:
			return ""
	return text

func _allow(guest_id: String, action: StringName, limit: int, window_seconds: float) -> bool:
	var now := Time.get_ticks_msec()
	var key := "%s:%s" % [guest_id, String(action)]
	var samples: Array = Array(_rate_windows.get(key, []))
	var cutoff := now - int(window_seconds * 1000.0)
	var retained: Array = []
	for sample in samples:
		if int(sample) > cutoff:
			retained.append(sample)
	if retained.size() >= limit:
		_rate_windows[key] = retained
		return false
	retained.append(now)
	_rate_windows[key] = retained
	return true

func _cleanup_sessions() -> void:
	var now := int(Time.get_unix_time_from_system())
	for token in _sessions.keys():
		if int(Dictionary(_sessions[token]).get("expires_unix", 0)) <= now:
			_sessions.erase(token)

func _reject(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

func _load() -> void:
	_friends.clear()
	_incoming_requests.clear()
	_outgoing_requests.clear()
	_direct_messages.clear()
	if not FileAccess.file_exists(STATE_PATH):
		return
	var file := FileAccess.open(STATE_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_warning("Ignoring invalid DEADFALL social state")
		return
	var root: Dictionary = json.data
	_friends = Dictionary(root.get("friends", {})).duplicate(true)
	_incoming_requests = Dictionary(root.get("incoming_requests", {})).duplicate(true)
	_outgoing_requests = Dictionary(root.get("outgoing_requests", {})).duplicate(true)
	_direct_messages = Dictionary(root.get("direct_messages", {})).duplicate(true)
	_message_sequence = int(root.get("message_sequence", 0))

func _save() -> void:
	var base := DirAccess.open("user://")
	if base == null:
		return
	if not base.dir_exists("server") and base.make_dir_recursive("server") != OK:
		return
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"schema_version": 1,
		"friends": _friends,
		"incoming_requests": _incoming_requests,
		"outgoing_requests": _outgoing_requests,
		"direct_messages": _direct_messages,
		"message_sequence": _message_sequence,
	}, "\t"))
