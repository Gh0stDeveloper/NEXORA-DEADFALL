class_name DeadfallCampaignSaveStore
extends RefCounted

const SAVE_VERSION := 1

static func save_progress(slot: String, data: Dictionary) -> bool:
	var payload := data.duplicate(true)
	payload["version"] = SAVE_VERSION
	payload["saved_unix"] = int(Time.get_unix_time_from_system())
	var file := FileAccess.open(_path_for_slot(slot), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	return true

static func load_progress(slot: String) -> Dictionary:
	var path := _path_for_slot(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != SAVE_VERSION:
		return {}
	return data

static func clear_progress(slot: String) -> bool:
	var path := _path_for_slot(slot)
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK

static func _path_for_slot(slot: String) -> String:
	var safe := slot.strip_edges().to_lower()
	if safe.is_empty():
		safe = "default"
	for token in ["/", "\\", "..", ":", " "]:
		safe = safe.replace(token, "_")
	return "user://campaign_%s.json" % safe
