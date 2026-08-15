class_name DeadfallRoomCodeService
extends RefCounted

const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LENGTH := 6
const PROTOCOL_VERSION := 1

static func generate_code(rng: RandomNumberGenerator = null) -> String:
	var source := rng
	if source == null:
		source = RandomNumberGenerator.new()
		source.randomize()
	var result := ""
	for _index in range(CODE_LENGTH):
		result += ALPHABET[source.randi_range(0, ALPHABET.length() - 1)]
	return result

static func normalize(code: String) -> String:
	return code.to_upper().replace("-", "").replace(" ", "").strip_edges()

static func is_valid(code: String) -> bool:
	var normalized := normalize(code)
	if normalized.length() != CODE_LENGTH:
		return false
	for character in normalized:
		if ALPHABET.find(character) < 0:
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
	if int(payload.get("protocol", 0)) != PROTOCOL_VERSION:
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
	}
