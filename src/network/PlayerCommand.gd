class_name DeadfallPlayerCommand
extends RefCounted

const MAX_PITCH := deg_to_rad(80.0)

static func sanitize(raw: Dictionary, last_sequence: int = -1) -> Dictionary:
	var sequence := int(raw.get("sequence", -1))
	if sequence <= last_sequence:
		return {}
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
		"jump_serial": maxi(0, int(raw.get("jump_serial", 0))),
		"crouch_serial": maxi(0, int(raw.get("crouch_serial", 0))),
		"prone_serial": maxi(0, int(raw.get("prone_serial", 0))),
	}

static func is_valid(raw: Dictionary, last_sequence: int = -1) -> bool:
	return not sanitize(raw, last_sequence).is_empty()
