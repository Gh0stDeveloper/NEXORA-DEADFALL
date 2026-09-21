class_name DeadfallSocialClient
extends Node

signal login_succeeded(account: Dictionary)
signal login_failed(reason: String)
signal auth_stage_changed(stage: String)
signal party_updated(party: Dictionary)
signal match_ready(match: Dictionary)
signal friends_updated(snapshot: Dictionary)
signal profile_loaded(profile: Dictionary)
signal account_updated(account: Dictionary)
signal chat_updated(channel: String, messages: Array)
signal request_failed(operation: String, reason: String)

const DEFAULT_API_BASE := "https://nexoradeadfall.duckdns.org/api/deadfall/v1"

var api_base := DEFAULT_API_BASE
var session_token := ""
var session_expires_unix := 0
var current_account: Dictionary = {}
var current_party: Dictionary = {}
var friends: Dictionary = {}
var _pending_operations: Dictionary = {}
var _queued_character: StringName = &""
var _emitted_match_id := ""

func _ready() -> void:
	api_base = String(ProjectSettings.get_setting("deadfall/social_api_base", DEFAULT_API_BASE)).trim_suffix("/")

func has_session() -> bool:
	return not session_token.is_empty() and session_expires_unix > int(Time.get_unix_time_from_system())

func register_guest(username: String) -> bool:
	var claim: Dictionary = GuestIdentity.registration_claim_for_username(username)
	if claim.is_empty():
		login_failed.emit("invalid_username")
		return false
	return _request_json("register", HTTPClient.METHOD_POST, "/guest/register", claim, false, {"username": username.strip_edges()})

func authenticate_current_guest() -> bool:
	if not GuestIdentity.has_complete_profile():
		login_failed.emit("profile_incomplete")
		return false
	return _request_json("auth_challenge", HTTPClient.METHOD_POST, "/guest/challenge", {"guest_id": GuestIdentity.guest_id}, false)

func load_profile(account_id: String = "") -> bool:
	var target := account_id if not account_id.is_empty() else GuestIdentity.guest_id
	return _request_json("profile", HTTPClient.METHOD_GET, "/profile/%s" % target, {}, true)

func update_selected_character(character_id: StringName) -> bool:
	if bool(_pending_operations.get("character_update", false)):
		_queued_character = character_id
		return true
	_queued_character = &""
	return _request_json("character_update", HTTPClient.METHOD_POST, "/profile/character", {"character_id": String(character_id)}, true)

func _flush_queued_character() -> void:
	if _queued_character.is_empty():
		return
	var character_id := _queued_character
	_queued_character = &""
	update_selected_character(character_id)

func report_presence(ping_ms: int) -> bool:
	return _request_json("presence", HTTPClient.METHOD_POST, "/presence", {"ping_ms": clampi(ping_ms, 0, 999)}, true)

func create_party(capacity: int) -> bool:
	return _request_json("party_create", HTTPClient.METHOD_POST, "/party/create", {"capacity": capacity}, true)

func join_party(code: String) -> bool:
	return _request_json("party_join", HTTPClient.METHOD_POST, "/party/join", {"code": code}, true)

func leave_party() -> bool:
	return _request_json("party_leave", HTTPClient.METHOD_POST, "/party/leave", {}, true)

func kick_party_member(guest_id: String) -> bool:
	return _request_json("party_kick", HTTPClient.METHOD_POST, "/party/kick", {"guest_id": guest_id}, true)

func set_party_state(state: String) -> bool:
	return _request_json("party_state", HTTPClient.METHOD_POST, "/party/state", {"state": state}, true)

func refresh_party() -> bool:
	return _request_json("party_current", HTTPClient.METHOD_GET, "/party/current", {}, true)

func start_party_match(mission_id: String = "mission_01_first_signal") -> bool:
	return _request_json("match_start", HTTPClient.METHOD_POST, "/match/start", {"mission_id": mission_id}, true)

func cancel_party_match() -> bool:
	return _request_json("match_cancel", HTTPClient.METHOD_POST, "/match/cancel", {}, true)

func refresh_match_status() -> bool:
	return _request_json("match_status", HTTPClient.METHOD_GET, "/match/status", {}, true)

func allow_match_reentry(match_id: String = "") -> void:
	if match_id.is_empty() or _emitted_match_id == match_id:
		_emitted_match_id = ""

func request_friend(account_id: String) -> bool:
	return _request_json("friend_request", HTTPClient.METHOD_POST, "/friends/request", {"account_id": account_id}, true)

func accept_friend(guest_id: String) -> bool:
	return _request_json("friend_accept", HTTPClient.METHOD_POST, "/friends/accept", {"guest_id": guest_id}, true)

func refresh_friends() -> bool:
	return _request_json("friends", HTTPClient.METHOD_GET, "/friends", {}, true)

func send_party_message(text: String) -> bool:
	return _request_json("party_chat", HTTPClient.METHOD_POST, "/chat/party", {"text": text}, true)

func send_friend_message(guest_id: String, text: String) -> bool:
	return _request_json("friend_chat_send", HTTPClient.METHOD_POST, "/chat/friend", {"guest_id": guest_id, "text": text}, true, {"guest_id": guest_id})

func load_friend_messages(guest_id: String) -> bool:
	return _request_json("friend_chat_load", HTTPClient.METHOD_GET, "/chat/friend/%s" % guest_id, {}, true, {"guest_id": guest_id})

func _request_json(operation: String, method: int, path: String, payload: Dictionary, authenticated: bool, context: Dictionary = {}) -> bool:
	if bool(_pending_operations.get(operation, false)):
		return false
	if authenticated and not has_session():
		request_failed.emit(operation, "not_authenticated")
		return false
	match operation:
		"register":
			auth_stage_changed.emit("register")
		"auth_challenge":
			auth_stage_changed.emit("challenge")
		"auth_verify":
			auth_stage_changed.emit("verify")
	var request := HTTPRequest.new()
	request.name = "Request_%s_%d" % [operation, Time.get_ticks_msec()]
	add_child(request)
	request.timeout = 12.0
	request.request_completed.connect(_on_request_completed.bind(request, operation, context))
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json", "Cache-Control: no-store"])
	if authenticated:
		headers.append("Authorization: Bearer %s" % session_token)
	var body := "" if method == HTTPClient.METHOD_GET else JSON.stringify(payload)
	_pending_operations[operation] = true
	var error := request.request("%s%s" % [api_base, path], headers, method, body)
	if error != OK:
		_pending_operations.erase(operation)
		request.queue_free()
		_fail_operation(operation, "request_start_failed:%s" % error_string(error))
		return false
	return true

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest, operation: String, context: Dictionary) -> void:
	_pending_operations.erase(operation)
	if operation == "character_update" and not _queued_character.is_empty():
		call_deferred("_flush_queued_character")
	if is_instance_valid(request):
		request.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail_operation(operation, "transport_error:%d" % result)
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail_operation(operation, "invalid_server_payload")
		return
	var response: Dictionary = Dictionary(parsed)
	if response_code < 200 or response_code >= 300 or not bool(response.get("ok", false)):
		_fail_operation(operation, String(response.get("reason", "http_%d" % response_code)))
		return
	_handle_success(operation, response, context)

func _handle_success(operation: String, response: Dictionary, context: Dictionary) -> void:
	match operation:
		"register":
			if not _adopt_session(response):
				login_failed.emit("invalid_session")
				return
			var accepted_username := String(context.get("username", ""))
			if not GuestIdentity.set_username(accepted_username):
				session_token = ""
				session_expires_unix = 0
				login_failed.emit("local_username_commit_failed")
				return
			current_account = Dictionary(response.get("account", {})).duplicate(true)
			login_succeeded.emit(current_account)
		"auth_challenge":
			var nonce := String(response.get("nonce", ""))
			var proof := GuestIdentity.build_auth_proof(nonce)
			if proof.is_empty():
				login_failed.emit("proof_generation_failed")
				return
			_request_json("auth_verify", HTTPClient.METHOD_POST, "/guest/verify", {"guest_id": GuestIdentity.guest_id, "nonce": nonce, "proof": proof}, false)
		"auth_verify":
			if not _adopt_session(response):
				login_failed.emit("invalid_session")
				return
			current_account = Dictionary(response.get("account", {})).duplicate(true)
			login_succeeded.emit(current_account)
		"profile":
			profile_loaded.emit(Dictionary(response.get("profile", {})))
		"character_update":
			current_account = Dictionary(response.get("account", {})).duplicate(true)
			account_updated.emit(current_account)
			if not current_party.is_empty():
				refresh_party()
		"party_create", "party_join", "party_kick", "party_state", "party_current", "party_chat", "match_start", "match_cancel", "match_status":
			_adopt_party(Dictionary(response.get("party", {})))
			if operation == "party_chat":
				chat_updated.emit("party", Array(current_party.get("chat", [])).duplicate(true))
		"party_leave":
			current_party = {}
			_emitted_match_id = ""
			party_updated.emit(current_party)
		"friends", "friend_request", "friend_accept":
			friends = Dictionary(response.get("friends", {})).duplicate(true)
			friends_updated.emit(friends)
		"friend_chat_send", "friend_chat_load":
			chat_updated.emit("friend:%s" % String(context.get("guest_id", "")), Array(response.get("messages", [])).duplicate(true))
		"presence":
			pass

func _adopt_party(party: Dictionary) -> void:
	current_party = party.duplicate(true)
	party_updated.emit(current_party)
	var match: Dictionary = Dictionary(current_party.get("match", {}))
	if match.is_empty():
		_emitted_match_id = ""
		return
	var match_id := String(match.get("match_id", ""))
	var status := String(match.get("status", "")).to_upper()
	var ticket := String(match.get("join_ticket", ""))
	if status == "READY" and not match_id.is_empty() and ticket.length() == 64 and _emitted_match_id != match_id:
		_emitted_match_id = match_id
		match_ready.emit(match.duplicate(true))

func _adopt_session(response: Dictionary) -> bool:
	# A successful HTTP response must contain a usable session for this guest.
	# Validate before mutating state or reporting the account as verified.
	var token_value: Variant = response.get("session_token")
	var expiry_value: Variant = response.get("expires_unix")
	var account_value: Variant = response.get("account")
	if typeof(token_value) != TYPE_STRING or typeof(expiry_value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	if typeof(account_value) != TYPE_DICTIONARY:
		return false
	var token := String(token_value).strip_edges()
	var expires := int(expiry_value)
	var account: Dictionary = account_value
	if token.is_empty() or expires <= int(Time.get_unix_time_from_system()):
		return false
	if GuestIdentity.guest_id.is_empty() or account.get("guest_id") != GuestIdentity.guest_id:
		return false
	session_token = token
	session_expires_unix = expires
	return true

func _fail_operation(operation: String, reason: String) -> void:
	if operation in ["register", "auth_challenge", "auth_verify"]:
		login_failed.emit(reason)
	else:
		request_failed.emit(operation, reason)
