class_name DeadfallGuestAccountStore
extends Node

const SCHEMA_VERSION := 2
const STORE_DIR := "user://server"
const STORE_PATH := "user://server/guest_accounts.dat"
const USERNAME_PATTERN := "^[A-Za-z0-9_]{1,12}$"
const PUBLIC_ID_PATTERN := "^[0-9]{10}$"
const CHALLENGE_TTL_SECONDS := 30

var _accounts: Dictionary = {}
var _username_index: Dictionary = {}
var _public_id_index: Dictionary = {}
var _challenges: Dictionary = {}
var _crypto := Crypto.new()
var _username_regex := RegEx.new()
var _public_id_regex := RegEx.new()

func _ready() -> void:
	_username_regex.compile(USERNAME_PATTERN)
	_public_id_regex.compile(PUBLIC_ID_PATTERN)
	_load()

func register_claim(claim: Dictionary) -> Dictionary:
	var guest_id := String(claim.get("guest_id", "")).strip_edges()
	var username := String(claim.get("username", "")).strip_edges()
	var verifier := String(claim.get("secret_verifier", "")).to_lower()
	var character_id := String(claim.get("selected_character", "operator_01"))
	if not _valid_guest_id(guest_id):
		return _reject("invalid_guest_id")
	if not _valid_username(username):
		return _reject("invalid_username")
	if verifier.length() != 64 or not verifier.is_valid_hex_number(false):
		return _reject("invalid_verifier")

	var username_key := username.to_lower()
	var existing_owner := String(_username_index.get(username_key, ""))
	if not existing_owner.is_empty() and existing_owner != guest_id:
		return _reject("username_taken")

	if _accounts.has(guest_id):
		var current: Dictionary = Dictionary(_accounts[guest_id])
		var trusted := String(current.get("secret_verifier", "")).hex_decode()
		var received := verifier.hex_decode()
		if trusted.size() != received.size() or not _crypto.constant_time_compare(trusted, received):
			return _reject("credential_mismatch")
		var previous_key := String(current.get("username_key", ""))
		if not previous_key.is_empty() and previous_key != username_key:
			_username_index.erase(previous_key)
		_ensure_public_id(current, guest_id)
		current["username"] = username
		current["username_key"] = username_key
		current["selected_character"] = character_id
		current["updated_unix"] = int(Time.get_unix_time_from_system())
		_accounts[guest_id] = current
		_username_index[username_key] = guest_id
		_save()
		return {"ok": true, "created": false, "account": public_account(guest_id)}

	var now := int(Time.get_unix_time_from_system())
	var public_id := _new_public_id()
	_accounts[guest_id] = {
		"guest_id": guest_id,
		"public_id": public_id,
		"username": username,
		"username_key": username_key,
		"secret_verifier": verifier,
		"selected_character": character_id,
		"created_unix": now,
		"updated_unix": now,
	}
	_username_index[username_key] = guest_id
	_public_id_index[public_id] = guest_id
	_save()
	return {"ok": true, "created": true, "account": public_account(guest_id)}

func issue_challenge(guest_id: String) -> Dictionary:
	_cleanup_challenges()
	if not _accounts.has(guest_id):
		return _reject("unknown_guest")
	var nonce := _crypto.generate_random_bytes(32).hex_encode()
	var expires := int(Time.get_unix_time_from_system()) + CHALLENGE_TTL_SECONDS
	_challenges[guest_id] = {"nonce": nonce, "expires_unix": expires}
	return {"ok": true, "nonce": nonce, "expires_unix": expires}

func verify_challenge(guest_id: String, nonce: String, proof_hex: String) -> Dictionary:
	_cleanup_challenges()
	if not _accounts.has(guest_id) or not _challenges.has(guest_id):
		return _reject("challenge_missing")
	var challenge: Dictionary = Dictionary(_challenges[guest_id])
	_challenges.erase(guest_id)
	if String(challenge.get("nonce", "")) != nonce:
		return _reject("challenge_mismatch")
	if proof_hex.length() != 64 or not proof_hex.is_valid_hex_number(false):
		return _reject("invalid_proof")
	var account: Dictionary = Dictionary(_accounts[guest_id])
	var verifier_hex := String(account.get("secret_verifier", ""))
	var key := verifier_hex.hex_decode()
	var expected := _crypto.hmac_digest(HashingContext.HASH_SHA256, key, nonce.to_utf8_buffer())
	var received := proof_hex.to_lower().hex_decode()
	if expected.size() != received.size() or not _crypto.constant_time_compare(expected, received):
		return _reject("authentication_failed")
	return {"ok": true, "account": public_account(guest_id)}

func update_character(guest_id: String, character_id: StringName) -> bool:
	if not _accounts.has(guest_id) or character_id.is_empty():
		return false
	var account: Dictionary = Dictionary(_accounts[guest_id])
	account["selected_character"] = String(character_id)
	account["updated_unix"] = int(Time.get_unix_time_from_system())
	_accounts[guest_id] = account
	_save()
	return true

func public_account(guest_id: String) -> Dictionary:
	if not _accounts.has(guest_id):
		return {}
	var account: Dictionary = Dictionary(_accounts[guest_id])
	return {
		"guest_id": String(account.get("guest_id", guest_id)),
		"public_id": String(account.get("public_id", "")),
		"username": String(account.get("username", "")),
		"selected_character": String(account.get("selected_character", "operator_01")),
		"created_unix": int(account.get("created_unix", 0)),
	}

func public_account_by_lookup(account_id: String) -> Dictionary:
	var guest_id := resolve_guest_id(account_id)
	return public_account(guest_id) if not guest_id.is_empty() else {}

func resolve_guest_id(account_id: String) -> String:
	var value := account_id.strip_edges()
	if _accounts.has(value):
		return value
	if _valid_public_id(value):
		return String(_public_id_index.get(value, ""))
	return ""

func username_available(username: String, except_guest_id: String = "") -> bool:
	if not _valid_username(username):
		return false
	var owner := String(_username_index.get(username.to_lower(), ""))
	return owner.is_empty() or owner == except_guest_id

func _valid_guest_id(value: String) -> bool:
	return value.begins_with("gst_") and value.length() >= 20 and value.length() <= 80

func _valid_public_id(value: String) -> bool:
	return _public_id_regex.search(value) != null

func _valid_username(value: String) -> bool:
	return value.length() <= 12 and _username_regex.search(value) != null

func _new_public_id() -> String:
	for _attempt in range(64):
		var bytes := _crypto.generate_random_bytes(8)
		var value: int = 0
		for byte_value in bytes:
			value = ((value * 256) + int(byte_value)) % 9_000_000_000
		var candidate := "%010d" % (1_000_000_000 + value)
		if not _public_id_index.has(candidate):
			return candidate
	push_error("Unable to allocate unique DEADFALL public player ID")
	return ""

func _ensure_public_id(account: Dictionary, guest_id: String) -> bool:
	var public_id := String(account.get("public_id", ""))
	if _valid_public_id(public_id) and (not _public_id_index.has(public_id) or String(_public_id_index[public_id]) == guest_id):
		_public_id_index[public_id] = guest_id
		return false
	public_id = _new_public_id()
	if public_id.is_empty():
		return false
	account["public_id"] = public_id
	_public_id_index[public_id] = guest_id
	return true

func _cleanup_challenges() -> void:
	var now := int(Time.get_unix_time_from_system())
	for guest_id in _challenges.keys():
		var challenge: Dictionary = Dictionary(_challenges[guest_id])
		if int(challenge.get("expires_unix", 0)) < now:
			_challenges.erase(guest_id)

func _reject(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

func _load() -> void:
	_accounts.clear()
	_username_index.clear()
	_public_id_index.clear()
	if not FileAccess.file_exists(STORE_PATH):
		return
	var file := FileAccess.open(STORE_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_warning("Ignoring invalid DEADFALL guest account store")
		return
	var root: Dictionary = json.data
	var stored: Variant = root.get("accounts", {})
	if typeof(stored) != TYPE_DICTIONARY:
		return
	_accounts = Dictionary(stored).duplicate(true)
	var migrated := false
	for guest_id_value in _accounts.keys():
		var guest_id := String(guest_id_value)
		var account: Dictionary = Dictionary(_accounts[guest_id])
		var key := String(account.get("username_key", ""))
		if not key.is_empty():
			_username_index[key] = guest_id
		if _ensure_public_id(account, guest_id):
			_accounts[guest_id] = account
			migrated = true
	if migrated:
		_save()

func _save() -> void:
	var base := DirAccess.open("user://")
	if base == null:
		push_warning("Unable to open DEADFALL server data directory")
		return
	if not base.dir_exists("server"):
		var error := base.make_dir_recursive("server")
		if error != OK:
			push_warning("Unable to create DEADFALL server data directory: %s" % error_string(error))
			return
	var file := FileAccess.open(STORE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Unable to persist DEADFALL guest accounts")
		return
	file.store_string(JSON.stringify({
		"schema_version": SCHEMA_VERSION,
		"accounts": _accounts,
	}, "\t"))
