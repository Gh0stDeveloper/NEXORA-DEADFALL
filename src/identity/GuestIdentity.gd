class_name DeadfallGuestIdentity
extends Node

signal identity_ready(snapshot: Dictionary)
signal username_changed(username: String)
signal selected_character_changed(character_id: StringName)

const SCHEMA_VERSION := 1
const ACCOUNT_DIR := "user://account"
const ACCOUNT_PATH := "user://account/guest.dat"
const DEFAULT_CHARACTER: StringName = &"operator_01"
const USERNAME_PATTERN := "^[A-Za-z0-9_]{1,12}$"

var guest_id := ""
var username := ""
var auth_secret := ""
var selected_character: StringName = DEFAULT_CHARACTER
var created_unix := 0

var _crypto := Crypto.new()
var _username_regex := RegEx.new()

func _ready() -> void:
	_username_regex.compile(USERNAME_PATTERN)
	_ensure_identity()
	identity_ready.emit(snapshot())

func snapshot() -> Dictionary:
	return {
		"guest_id": guest_id,
		"username": username,
		"selected_character": String(selected_character),
		"created_unix": created_unix,
		"requires_username": username.is_empty(),
	}

func has_complete_profile() -> bool:
	return not guest_id.is_empty() and not auth_secret.is_empty() and is_valid_username(username)

func is_valid_username(value: String) -> bool:
	var clean := value.strip_edges()
	return clean.length() <= 12 and _username_regex.search(clean) != null

func set_username(value: String) -> bool:
	var clean := value.strip_edges()
	if not is_valid_username(clean):
		return false
	if username == clean:
		return true
	username = clean
	_save()
	username_changed.emit(username)
	return true

func set_selected_character(character_id: StringName) -> void:
	if character_id.is_empty() or selected_character == character_id:
		return
	selected_character = character_id
	_save()
	selected_character_changed.emit(selected_character)

func registration_claim() -> Dictionary:
	# The game-generated secret never needs to be stored by the server. The
	# server enrolls only this verifier and then authenticates with nonce/HMAC.
	return {
		"guest_id": guest_id,
		"username": username,
		"secret_verifier": auth_secret.sha256_text(),
		"selected_character": String(selected_character),
	}

func build_auth_proof(nonce: String) -> String:
	if nonce.is_empty() or auth_secret.is_empty():
		return ""
	var key := auth_secret.sha256_buffer()
	return _crypto.hmac_digest(HashingContext.HASH_SHA256, key, nonce.to_utf8_buffer()).hex_encode()

func account_path() -> String:
	return ACCOUNT_PATH

func _ensure_identity() -> void:
	if _load():
		return
	guest_id = "gst_%s" % _crypto.generate_random_bytes(16).hex_encode()
	auth_secret = _crypto.generate_random_bytes(32).hex_encode()
	username = ""
	selected_character = DEFAULT_CHARACTER
	created_unix = int(Time.get_unix_time_from_system())
	_save()

func _load() -> bool:
	if not FileAccess.file_exists(ACCOUNT_PATH):
		return false
	var file := FileAccess.open(ACCOUNT_PATH, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = json.data
	var loaded_id := String(data.get("guest_id", ""))
	var loaded_secret := String(data.get("auth_secret", ""))
	if not loaded_id.begins_with("gst_") or loaded_id.length() < 20 or loaded_secret.length() != 64:
		return false
	guest_id = loaded_id
	auth_secret = loaded_secret
	username = String(data.get("username", "")).strip_edges()
	if not username.is_empty() and not is_valid_username(username):
		username = ""
	selected_character = StringName(String(data.get("selected_character", String(DEFAULT_CHARACTER))))
	created_unix = int(data.get("created_unix", 0))
	return true

func _save() -> void:
	var base := DirAccess.open("user://")
	if base == null:
		push_warning("Unable to open DEADFALL user data directory")
		return
	if not base.dir_exists("account"):
		var error := base.make_dir_recursive("account")
		if error != OK:
			push_warning("Unable to create DEADFALL account directory: %s" % error_string(error))
			return
	var file := FileAccess.open(ACCOUNT_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Unable to persist DEADFALL guest identity")
		return
	file.store_string(JSON.stringify({
		"schema_version": SCHEMA_VERSION,
		"guest_id": guest_id,
		"username": username,
		"auth_secret": auth_secret,
		"selected_character": String(selected_character),
		"created_unix": created_unix,
	}, "\t"))
