class_name DeadfallGorePoolBudget
extends RefCounted

const LIMBS: StringName = &"limbs"
const BLOOD: StringName = &"blood"
const DECALS: StringName = &"decals"

var _limits: Dictionary = {
	LIMBS: 1,
	BLOOD: 1,
	DECALS: 1,
}
var _cursors: Dictionary = {
	LIMBS: 0,
	BLOOD: 0,
	DECALS: 0,
}

func configure(profile: Dictionary) -> void:
	_limits[LIMBS] = maxi(1, int(profile.get("gore_parts", 4)))
	_limits[BLOOD] = maxi(1, int(profile.get("blood_emitters", 2)))
	_limits[DECALS] = maxi(1, int(profile.get("decals", 8)))
	for kind in [LIMBS, BLOOD, DECALS]:
		_cursors[kind] = int(_cursors.get(kind, 0)) % get_limit(kind)

func acquire(kind: StringName) -> int:
	var limit := get_limit(kind)
	if limit <= 0:
		return -1
	var cursor := int(_cursors.get(kind, 0))
	var slot := cursor % limit
	_cursors[kind] = (cursor + 1) % limit
	return slot

func get_limit(kind: StringName) -> int:
	return maxi(0, int(_limits.get(kind, 0)))

func reset_cursors() -> void:
	for kind in _cursors:
		_cursors[kind] = 0

func snapshot() -> Dictionary:
	return {
		"limbs": get_limit(LIMBS),
		"blood": get_limit(BLOOD),
		"decals": get_limit(DECALS),
	}
