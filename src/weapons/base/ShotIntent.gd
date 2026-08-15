class_name DeadfallShotIntent
extends RefCounted

var attacker_id: int = 0
var weapon_id: StringName = &""
var origin := Vector3.ZERO
var direction := Vector3.FORWARD
var max_distance: float = 0.0
var simulation_tick: int = 0
var sequence: int = 0

func is_valid() -> bool:
	return attacker_id != 0 and weapon_id != &"" and max_distance > 0.0 and not direction.is_zero_approx()
