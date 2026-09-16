class_name DeadfallDamageRules
extends RefCounted

const DamageEventScript = preload("res://src/core/damage/DamageEvent.gd")

static func resolve_amount(event) -> float:
	if event == null or not event.has_method("is_valid") or not event.is_valid():
		return 0.0
	return maxf(0.0, float(event.amount) * body_part_multiplier(int(event.body_part)) * damage_type_multiplier(int(event.damage_type)))

static func body_part_multiplier(body_part: int) -> float:
	match body_part:
		DamageEventScript.BodyPart.HEAD:
			return 2.25
		DamageEventScript.BodyPart.CHEST:
			return 1.0
		DamageEventScript.BodyPart.ABDOMEN:
			return 0.90
		DamageEventScript.BodyPart.LEFT_ARM, DamageEventScript.BodyPart.RIGHT_ARM:
			return 0.65
		DamageEventScript.BodyPart.LEFT_LEG, DamageEventScript.BodyPart.RIGHT_LEG:
			return 0.70
		_:
			return 1.0

static func damage_type_multiplier(damage_type: int) -> float:
	match damage_type:
		DamageEventScript.DamageType.FIRE:
			return 0.65
		_:
			return 1.0

static func is_critical(event) -> bool:
	if event == null:
		return false
	if int(event.body_part) != DamageEventScript.BodyPart.HEAD:
		return false
	return int(event.damage_type) in [DamageEventScript.DamageType.BULLET, DamageEventScript.DamageType.MELEE]
