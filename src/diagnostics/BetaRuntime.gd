class_name DeadfallBetaRuntime
extends Node

const BuildInfoScript = preload("res://src/release/BuildInfo.gd")
const EVENT_LIMIT := 96
const RECENT_CRASH_EVENTS := 24
const EVENT_PATH := "user://beta_runtime_events.json"
const SESSION_PATH := "user://beta_session_state.json"
const LAST_CRASH_PATH := "user://beta_last_crash_report.json"

var _session_id := ""
var _started_unix := 0
var _previous_unclean_exit := false
var _events: Array = []
var _device: Dictionary = {}

func _ready() -> void:
	_started_unix = int(Time.get_unix_time_from_system())
	_session_id = Crypto.new().generate_random_bytes(8).hex_encode()
	_load_events()
	_device = _capture_device()
	var previous := _load_json(SESSION_PATH)
	_previous_unclean_exit = not previous.is_empty() and not bool(previous.get("clean_shutdown", true))
	if _previous_unclean_exit:
		_write_unclean_report(previous)
	_write_session_marker(false)
	record_event("runtime", "session_start", {"previous_unclean_exit": _previous_unclean_exit})
	print("DEADFALL_BETA_READY %s" % JSON.stringify(get_status_snapshot()))

func _exit_tree() -> void:
	record_event("runtime", "session_end", {})
	_write_session_marker(true)

func record_event(category: String, event_name: String, data: Dictionary = {}) -> void:
	var entry := {
		"unix": int(Time.get_unix_time_from_system()),
		"category": category.left(32),
		"event": event_name.left(64),
		"data": _sanitize_dictionary(data, 0),
	}
	_events.append(entry)
	while _events.size() > EVENT_LIMIT:
		_events.pop_front()
	_write_json(EVENT_PATH, {"version": 1, "events": _events})

func record_security_event(peer_id: int, reason: String, strikes: int) -> void:
	record_event("security", "network_rejection", {
		"peer_id": peer_id,
		"reason": reason.left(96),
		"strikes": strikes,
	})

func get_status_snapshot() -> Dictionary:
	return {
		"build": BuildInfoScript.snapshot(),
		"session_id": _session_id,
		"previous_unclean_exit": _previous_unclean_exit,
		"event_count": _events.size(),
		"recommended_quality": _recommended_quality(_device),
		"device": _device,
		"last_crash_report": LAST_CRASH_PATH if FileAccess.file_exists(LAST_CRASH_PATH) else "",
	}

func get_last_crash_report_path() -> String:
	return LAST_CRASH_PATH if FileAccess.file_exists(LAST_CRASH_PATH) else ""

func _capture_device() -> Dictionary:
	var memory: Dictionary = OS.get_memory_info()
	var snapshot := {
		"os": OS.get_name(),
		"os_version": OS.get_version(),
		"model": OS.get_model_name(),
		"processor_count": OS.get_processor_count(),
		"memory_physical": int(memory.get("physical", 0)),
		"memory_available": int(memory.get("available", 0)),
		"headless": DisplayServer.get_name() == "headless",
		"engine": Engine.get_version_info(),
	}
	if DisplayServer.get_name() != "headless":
		var window := DisplayServer.window_get_size()
		snapshot["window_width"] = window.x
		snapshot["window_height"] = window.y
		snapshot["gpu_vendor"] = RenderingServer.get_video_adapter_vendor()
		snapshot["gpu_name"] = RenderingServer.get_video_adapter_name()
		snapshot["gpu_type"] = int(RenderingServer.get_video_adapter_type())
		snapshot["rendering_method"] = RenderingServer.get_current_rendering_method()
		snapshot["rendering_driver"] = RenderingServer.get_current_rendering_driver_name()
	return snapshot

func _recommended_quality(device: Dictionary) -> Dictionary:
	if String(device.get("os", "")) != "Android":
		return {"tier": 1, "name": "STANDARD", "automatic": false}
	var bytes := int(device.get("memory_physical", 0))
	var gib := float(bytes) / 1073741824.0 if bytes > 0 else 0.0
	var cores := int(device.get("processor_count", 0))
	if (gib > 0.0 and gib <= 3.5) or (cores > 0 and cores <= 4):
		return {"tier": 0, "name": "SMOOTH", "automatic": false}
	if (gib > 0.0 and gib <= 5.5) or (cores > 0 and cores <= 6):
		return {"tier": 1, "name": "STANDARD", "automatic": false}
	if gib > 0.0 and gib <= 8.5:
		return {"tier": 2, "name": "ULTRA", "automatic": false}
	return {"tier": 3, "name": "ULTRA_HD", "automatic": false}

func _load_events() -> void:
	var wrapper := _load_json(EVENT_PATH)
	var stored = wrapper.get("events", [])
	if typeof(stored) == TYPE_ARRAY:
		_events = Array(stored)
		while _events.size() > EVENT_LIMIT:
			_events.pop_front()

func _write_unclean_report(previous: Dictionary) -> void:
	var recent: Array = []
	var start := maxi(0, _events.size() - RECENT_CRASH_EVENTS)
	for index in range(start, _events.size()):
		recent.append(_events[index])
	_write_json(LAST_CRASH_PATH, {
		"version": 1,
		"detected_unix": int(Time.get_unix_time_from_system()),
		"reason": "previous_session_unclean",
		"previous_session": _sanitize_dictionary(previous, 0),
		"recent_events": recent,
		"current_build": BuildInfoScript.snapshot(),
		"device": _device,
	})
	print("DEADFALL_BETA_PREVIOUS_UNCLEAN report=%s" % LAST_CRASH_PATH)

func _write_session_marker(clean_shutdown: bool) -> void:
	_write_json(SESSION_PATH, {
		"version": 1,
		"session_id": _session_id,
		"started_unix": _started_unix,
		"updated_unix": int(Time.get_unix_time_from_system()),
		"clean_shutdown": clean_shutdown,
		"build": BuildInfoScript.snapshot(),
		"device": _device,
	})

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _write_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value))
	file.flush()
	file.close()
	return true

func _sanitize_dictionary(value: Dictionary, depth: int) -> Dictionary:
	if depth > 3:
		return {}
	var clean := {}
	for raw_key in value.keys():
		var key := String(raw_key).left(48)
		var lowered := key.to_lower()
		if "token" in lowered or "password" in lowered or "secret" in lowered or "host" in lowered or "address" in lowered or lowered == "ip":
			continue
		clean[key] = _sanitize_value(value[raw_key], depth + 1)
	return clean

func _sanitize_value(value, depth: int):
	if depth > 3:
		return null
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT:
			return value
		TYPE_STRING, TYPE_STRING_NAME:
			return String(value).left(160)
		TYPE_VECTOR2:
			return [value.x, value.y]
		TYPE_VECTOR3:
			return [value.x, value.y, value.z]
		TYPE_DICTIONARY:
			return _sanitize_dictionary(value, depth)
		TYPE_ARRAY:
			var clean_array: Array = []
			var items: Array = value
			for index in range(mini(items.size(), 16)):
				clean_array.append(_sanitize_value(items[index], depth + 1))
			return clean_array
		_:
			return String(value).left(160)
