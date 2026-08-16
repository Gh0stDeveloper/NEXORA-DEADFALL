class_name DeadfallPlayerCommand
extends RefCounted

const MAX_PITCH := 1.3962634015954636
const MAX_SEQUENCE_JUMP := 600
const MAX_SERIAL := 1_000_000
const ALLOWED_KEYS := {
	"sequence": true,
	"client_tick": true,
	"move": true,
	"yaw": true,
	"pitch": true,
	"sprint": true,
	"interact": true,
	"jump_serial": true,
	"crouch_serial": true,
	"prone_serial": true,
}

static func validate_shape(raw: Dictionary, last_sequence: int = -1) -> bool:
	if raw.size() > ALLOWED_KEYS.size():
		return false
	for key in raw.keys():
		if not ALLOWED_KEYS.has(String(key)):
			return false
	if typeof(raw.get("sequence", null)) != TYPE_INT:
		return false
	var sequence := int(raw.get("sequence", -1))
	if sequence < 0 or sequence <= last_sequence:
		return false
	if last_sequence >= 0 and sequence - last_sequence > MAX_SEQUENCE_JUMP:
		return false
	if raw.has("client_tick") and typeof(raw["client_tick"]) != TYPE_INT:
		return false
	if int(raw.get("client_tick", 0)) < 0:
		return false
	if raw.has("move"):
		if typeof(raw["move"]) != TYPE_VECTOR2 or not Vector2(raw["move"]).is_finite():
			return false
	for key in ["yaw", "pitch"]:
		if raw.has(key):
			var value_type := typeof(raw[key])
			if value_type != TYPE_INT and value_type != TYPE_FLOAT:
				return false
			var number := float(raw[key])
			if is_nan(number) or is_inf(number):
				return false
	for key in ["sprint", "interact"]:
		if raw.has(key) and typeof(raw[key]) != TYPE_BOOL:
			return false
	for key in ["jump_serial", "crouch_serial", "prone_serial"]:
		if raw.has(key):
			if typeof(raw[key]) != TYPE_INT:
				return false
			var serial := int(raw[key])
			if serial < 0 or serial > MAX_SERIAL:
				return false
	return true

static func sanitize(raw: Dictionary, last_sequence: int = -1) -> Dictionary:
	if not validate_shape(raw, last_sequence):
		return {}
	var sequence := int(raw.get("sequence", -1))
	var move := Vector2(raw.get("move", Vector2.ZERO)).limit_length(1.0)
	var yaw := wrapf(float(raw.get("yaw", 0.0)), -PI, PI)
	var pitch := clampf(float(raw.get("pitch", 0.0)), -MAX_PITCH, MAX_PITCH)
	return {
		"sequence": sequence,
		"client_tick": maxi(0, int(raw.get("client_tick", 0))),
		"move": move,
		"yaw": yaw,
		"pitch": pitch,
		"sprint": bool(raw.get("sprint", false)),
		"interact": bool(raw.get("interact", false)),
		"jump_serial": clampi(int(raw.get("jump_serial", 0)), 0, MAX_SERIAL),
		"crouch_serial": clampi(int(raw.get("crouch_serial", 0)), 0, MAX_SERIAL),
		"prone_serial": clampi(int(raw.get("prone_serial", 0)), 0, MAX_SERIAL),
	}

static func is_valid(raw: Dictionary, last_sequence: int = -1) -> bool:
	return validate_shape(raw, last_sequence)
