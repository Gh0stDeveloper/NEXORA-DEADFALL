class_name DamageEvent
extends RefCounted

enum DamageType {
	BULLET,
	EXPLOSIVE,
	FIRE,
	MELEE,
	FALL,
	ENVIRONMENT,
}

enum BodyPart {
	HEAD,
	CHEST,
	ABDOMEN,
	LEFT_ARM,
	RIGHT_ARM,
	LEFT_LEG,
	RIGHT_LEG,
}

var attacker_id: int = 0
var victim_id: int = 0
var weapon_id: StringName = &""
var amount: float = 0.0
var damage_type: DamageType = DamageType.BULLET
var body_part: BodyPart = BodyPart.CHEST
var hit_position := Vector3.ZERO
var hit_direction := Vector3.ZERO
var penetration: float = 0.0
var critical: bool = false
var simulation_tick: int = 0

func is_valid() -> bool:
	return victim_id != 0 and amount > 0.0
