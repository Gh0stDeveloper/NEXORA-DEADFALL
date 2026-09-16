class_name DeadfallRoomCodeService
extends RefCounted

const BuildInfoScript = preload("res://src/release/BuildInfo.gd")
const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LENGTH := 6
const PROTOCOL_VERSION := BuildInfoScript.NETWORK_PROTOCOL
const MAX_PLAYERS := BuildInfoScript.MAX_PLAYERS

static func generate_code(rng: RandomNumberGenerator = null) -> String:
	var source := rng
	if source == null:
		source = RandomNumberGenerator.new()
		source.randomize()
	var result := ""
	for _index in range(CODE_LENGTH):
		var alphabet_index := source.randi_range(0, ALPHABET.length() - 1)
		result += ALPHABET.substr(alphabet_index, 1)
	return result

static func normalize(code: String) -> String:
	return code.to_upper().replace("-", "").replace(" ", "").strip_edges()

static func is_valid(code: String) -> bool:
	var normalized := normalize(code)
	if normalized.length() != CODE_LENGTH:
		return false
	for index in range(normalized.length()):
		if ALPHABET.find(normalized.substr(index, 1)) < 0:
			return false
	return true

static func build_lookup_url(directory_base: String, code: String) -> String:
	var base := directory_base.strip_edges().trim_suffix("/")
	return "%s/room/%s" % [base, normalize(code)]

static func parse_resolution_payload(text: String) -> Dictionary:
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var payload: Dictionary = parsed
	if not bool(payload.get("ok", false)):
		return {}
	var compatibility := BuildInfoScript.validate_server_snapshot(payload)
	if not bool(compatibility.get("compatible", false)):
		return {}
	var host := String(payload.get("host", "")).strip_edges()
	var port := int(payload.get("port", 0))
	if host.is_empty() or port <= 0 or port > 65535:
		return {}
	return {
		"host": host,
		"port": port,
		"room_code": normalize(String(payload.get("room_code", ""))),
		"protocol": PROTOCOL_VERSION,
		"max_players": clampi(int(payload.get("max_players", MAX_PLAYERS)), 1, MAX_PLAYERS),
		"app_version": String(payload.get("app_version", "")),
		"version_code": int(payload.get("version_code", 0)),
		"content_version": int(payload.get("content_version", 0)),
		"build_channel": String(payload.get("build_channel", "")),
	}
