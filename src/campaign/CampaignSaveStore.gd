class_name DeadfallCampaignSaveStore
extends RefCounted

const SAVE_VERSION := 2
const LEGACY_SAVE_VERSION := 1

static func save_progress(slot: String, data: Dictionary) -> bool:
	var primary := _path_for_slot(slot)
	var temporary := primary + ".tmp"
	var backup := primary + ".bak"
	var payload_json := JSON.stringify(data.duplicate(true))
	var wrapper := {
		"version": SAVE_VERSION,
		"saved_unix": int(Time.get_unix_time_from_system()),
		"payload_json": payload_json,
		"checksum": payload_json.sha256_text(),
	}
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(wrapper))
	file.flush()
	file.close()

	var primary_abs := ProjectSettings.globalize_path(primary)
	var temporary_abs := ProjectSettings.globalize_path(temporary)
	var backup_abs := ProjectSettings.globalize_path(backup)
	if FileAccess.file_exists(primary):
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup_abs)
		if DirAccess.rename_absolute(primary_abs, backup_abs) != OK:
			DirAccess.remove_absolute(temporary_abs)
			return false
	if DirAccess.rename_absolute(temporary_abs, primary_abs) != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup_abs, primary_abs)
		return false
	return true

static func load_progress(slot: String) -> Dictionary:
	var primary := _path_for_slot(slot)
	var backup := primary + ".bak"
	var first := _load_one(primary)
	if not first.is_empty():
		if bool(first.get("_legacy_migration", false)):
			first.erase("_legacy_migration")
			save_progress(slot, first)
		return first
	var fallback := _load_one(backup)
	if fallback.is_empty():
		return {}
	fallback.erase("_legacy_migration")
	if FileAccess.file_exists(primary):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(primary))
	save_progress(slot, fallback)
	return fallback

static func clear_progress(slot: String) -> bool:
	var success := true
	var primary := _path_for_slot(slot)
	for path in [primary, primary + ".tmp", primary + ".bak"]:
		if FileAccess.file_exists(path):
			success = DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK and success
	return success

static func get_path_for_slot(slot: String) -> String:
	return _path_for_slot(slot)

static func _load_one(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var wrapper: Dictionary = parsed
	var version := int(wrapper.get("version", 0))
	if version == LEGACY_SAVE_VERSION and not wrapper.has("payload_json"):
		var legacy := wrapper.duplicate(true)
		legacy.erase("version")
		legacy.erase("saved_unix")
		legacy["_legacy_migration"] = true
		return legacy
	if version != SAVE_VERSION:
		return {}
	var payload_json := String(wrapper.get("payload_json", ""))
	var checksum := String(wrapper.get("checksum", ""))
	if payload_json.is_empty() or checksum.is_empty() or payload_json.sha256_text() != checksum:
		return {}
	var payload = JSON.parse_string(payload_json)
	return payload if typeof(payload) == TYPE_DICTIONARY else {}

static func _path_for_slot(slot: String) -> String:
	var safe := slot.strip_edges().to_lower()
	if safe.is_empty():
		safe = "default"
	for token in ["/", "\\", "..", ":", " "]:
		safe = safe.replace(token, "_")
	return "user://campaign_%s.json" % safe
