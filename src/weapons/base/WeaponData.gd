class_name DeadfallWeaponData
extends Resource

@export var weapon_id: StringName = &"weapon"
@export var display_name: String = "Weapon"
@export_range(0.1, 1000.0, 0.1) var base_damage: float = 20.0
@export_range(1, 300, 1) var magazine_size: int = 30
@export_range(0, 999, 1) var starting_reserve_ammo: int = 120
@export_range(0, 1999, 1) var max_reserve_ammo: int = 360
@export_range(30.0, 1500.0, 1.0) var rounds_per_minute: float = 600.0
@export_range(0.1, 10.0, 0.05) var reload_seconds: float = 2.0
@export_range(1.0, 1000.0, 1.0) var max_distance: float = 150.0
@export_range(0.0, 1.0, 0.01) var penetration: float = 0.0
@export var automatic: bool = true

func fire_interval_usec() -> int:
	return maxi(1, int(round(60_000_000.0 / maxf(rounds_per_minute, 1.0))))
