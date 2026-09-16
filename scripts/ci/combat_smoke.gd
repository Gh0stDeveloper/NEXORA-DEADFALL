extends SceneTree

const DamageEventScript = preload("res://src/core/damage/DamageEvent.gd")
const DamageRulesScript = preload("res://src/core/damage/DamageRules.gd")
const LocalAuthorityScript = preload("res://src/core/authority/LocalAuthority.gd")
const HealthComponentScript = preload("res://src/core/health/HealthComponent.gd")
const WeaponDataScript = preload("res://src/weapons/base/WeaponData.gd")
const WeaponRuntimeStateScript = preload("res://src/weapons/base/WeaponRuntimeState.gd")

func _initialize() -> void:
	if not _test_damage_rules_and_authority():
		return
	if not _test_weapon_cadence_ammo_and_reload():
		return
	print("NEXORA: DEADFALL combat smoke test passed")
	quit(0)

func _test_damage_rules_and_authority() -> bool:
	var authority = LocalAuthorityScript.new()
	authority.start()
	var health = HealthComponentScript.new()
	health.entity_id = 77
	health.max_health = 100.0
	health.reset_health()
	if not authority.register_damageable(77, health):
		return _fail("Authority could not register damageable target")

	var chest = _make_event(77, 20.0, DamageEventScript.DamageType.BULLET, DamageEventScript.BodyPart.CHEST)
	if not authority.resolve_damage(chest):
		return _fail("Chest bullet event was rejected")
	if not _close(chest.resolved_amount, 20.0) or not _close(health.current_health, 80.0):
		return _fail("Chest damage calculation mismatch")
	if chest.body_part != DamageEventScript.BodyPart.CHEST:
		return _fail("Body part was not preserved through authority resolution")

	health.reset_health()
	var head = _make_event(77, 20.0, DamageEventScript.DamageType.BULLET, DamageEventScript.BodyPart.HEAD)
	if not authority.resolve_damage(head):
		return _fail("Head bullet event was rejected")
	if not head.critical or not _close(head.resolved_amount, 45.0) or not _close(health.current_health, 55.0):
		return _fail("Headshot/critical damage mismatch")

	if not _test_limb_damage(authority, health, DamageEventScript.BodyPart.LEFT_ARM, 13.0, "left arm"):
		return false
	if not _test_limb_damage(authority, health, DamageEventScript.BodyPart.RIGHT_ARM, 13.0, "right arm"):
		return false
	if not _test_limb_damage(authority, health, DamageEventScript.BodyPart.LEFT_LEG, 14.0, "left leg"):
		return false
	if not _test_limb_damage(authority, health, DamageEventScript.BodyPart.RIGHT_LEG, 14.0, "right leg"):
		return false

	health.reset_health()
	var fire = _make_event(77, 20.0, DamageEventScript.DamageType.FIRE, DamageEventScript.BodyPart.ABDOMEN)
	if not authority.resolve_damage(fire):
		return _fail("Fire event was rejected")
	if not _close(fire.resolved_amount, 11.7) or not _close(health.current_health, 88.3):
		return _fail("Damage type/body multiplier mismatch")

	var unknown = _make_event(999, 20.0, DamageEventScript.DamageType.BULLET, DamageEventScript.BodyPart.CHEST)
	if authority.resolve_damage(unknown):
		return _fail("Authority accepted damage for an unregistered victim")

	authority.stop()
	health.free()
	return true

func _test_limb_damage(authority, health, body_part: int, expected_damage: float, label: String) -> bool:
	health.reset_health()
	var event = _make_event(77, 20.0, DamageEventScript.DamageType.BULLET, body_part)
	if not authority.resolve_damage(event):
		return _fail("%s bullet event was rejected" % label.capitalize())
	if event.critical:
		return _fail("%s damage must not be critical" % label.capitalize())
	if event.body_part != body_part:
		return _fail("%s body part was not preserved" % label.capitalize())
	if not _close(event.resolved_amount, expected_damage):
		return _fail("%s damage multiplier mismatch" % label.capitalize())
	if not _close(health.current_health, 100.0 - expected_damage):
		return _fail("%s health result mismatch" % label.capitalize())
	return true

func _test_weapon_cadence_ammo_and_reload() -> bool:
	var data = WeaponDataScript.new()
	data.magazine_size = 2
	data.starting_reserve_ammo = 4
	data.rounds_per_minute = 600.0
	data.reload_seconds = 1.0
	var state = WeaponRuntimeStateScript.new()
	state.configure(data)

	if not state.try_consume_shot(1_000_000):
		return _fail("First weapon shot should be allowed")
	if state.try_consume_shot(1_050_000):
		return _fail("Fire cadence was bypassed")
	if not state.try_consume_shot(1_100_000):
		return _fail("Second shot should be allowed after cadence interval")
	if state.try_consume_shot(1_200_000):
		return _fail("Empty magazine allowed an extra shot")
	if not state.try_start_reload(2_000_000):
		return _fail("Reload should start with empty magazine and reserve ammo")
	if state.update_reload(2_500_000):
		return _fail("Reload completed before configured duration")
	if not state.update_reload(3_000_000):
		return _fail("Reload did not complete at configured duration")
	if state.ammo_in_mag != 2 or state.reserve_ammo != 2:
		return _fail("Reload ammo transfer mismatch")
	return true

func _make_event(victim_id: int, amount: float, damage_type: int, body_part: int):
	var event = DamageEventScript.new()
	event.attacker_id = 1
	event.victim_id = victim_id
	event.weapon_id = &"test_weapon"
	event.amount = amount
	event.damage_type = damage_type
	event.body_part = body_part
	return event

func _close(a: float, b: float) -> bool:
	return absf(a - b) <= 0.001

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
