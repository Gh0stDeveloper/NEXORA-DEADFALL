class_name DeadfallWeaponRuntimeState
extends RefCounted

var data: Resource
var ammo_in_mag: int = 0
var reserve_ammo: int = 0
var reloading := false
var reload_end_usec: int = 0
var last_shot_usec: int = -1

func configure(weapon_data: Resource) -> void:
	data = weapon_data
	ammo_in_mag = int(data.magazine_size) if data != null else 0
	reserve_ammo = int(data.starting_reserve_ammo) if data != null else 0
	reloading = false
	reload_end_usec = 0
	last_shot_usec = -1

func can_fire(now_usec: int) -> bool:
	if data == null or reloading or ammo_in_mag <= 0:
		return false
	if last_shot_usec < 0:
		return true
	return now_usec - last_shot_usec >= int(data.fire_interval_usec())

func try_consume_shot(now_usec: int) -> bool:
	if not can_fire(now_usec):
		return false
	ammo_in_mag -= 1
	last_shot_usec = now_usec
	return true

func try_start_reload(now_usec: int) -> bool:
	if data == null or reloading or reserve_ammo <= 0 or ammo_in_mag >= int(data.magazine_size):
		return false
	reloading = true
	reload_end_usec = now_usec + int(round(float(data.reload_seconds) * 1_000_000.0))
	return true

func update_reload(now_usec: int) -> bool:
	if not reloading or now_usec < reload_end_usec:
		return false
	var needed := maxi(0, int(data.magazine_size) - ammo_in_mag)
	var transferred := mini(needed, reserve_ammo)
	ammo_in_mag += transferred
	reserve_ammo -= transferred
	reloading = false
	reload_end_usec = 0
	return true

func cancel_reload() -> void:
	reloading = false
	reload_end_usec = 0
