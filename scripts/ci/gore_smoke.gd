extends SceneTree

const DamageEventScript = preload("res://src/core/damage/DamageEvent.gd")
const LocalAuthorityScript = preload("res://src/core/authority/LocalAuthority.gd")
const GoreBudgetScript = preload("res://src/gore/GorePoolBudget.gd")
const SettingsScript = preload("res://src/autoload/Settings.gd")
const ZombieControllerScript = preload("res://src/zombies/base/ZombieController.gd")
const ZombieScene = preload("res://src/zombies/base/Zombie.tscn")

func _initialize() -> void:
	if not _test_quality_budgets():
		return
	if not _test_prepared_rig_contract():
		return
	if not _test_arm_dismemberment():
		return
	if not _test_leg_to_crawler():
		return
	if not _test_head_destruction_is_lethal():
		return
	print("NEXORA: DEADFALL gore smoke test passed")
	quit(0)

func _test_quality_budgets() -> bool:
	var budget = GoreBudgetScript.new()
	for tier in range(4):
		var profile: Dictionary = SettingsScript.QUALITY_PROFILES[tier]
		budget.configure(profile)
		if int(profile.get("decals", 0)) > 8:
			return _fail("Mobile gore profile exceeded the eight-decal safety limit")
		for kind in [GoreBudgetScript.LIMBS, GoreBudgetScript.BLOOD, GoreBudgetScript.DECALS]:
			var limit := budget.get_limit(kind)
			if limit <= 0:
				return _fail("Gore budget must stay enabled on every quality tier")
			for _request_index in range(limit * 5 + 7):
				var slot := budget.acquire(kind)
				if slot < 0 or slot >= limit:
					return _fail("Gore pool cursor escaped configured budget")
	if int(SettingsScript.QUALITY_PROFILES[SettingsScript.QualityTier.SMOOTH].get("gore_parts", 0)) != 4:
		return _fail("Smooth gore limb budget changed unexpectedly")
	if int(SettingsScript.QUALITY_PROFILES[SettingsScript.QualityTier.ULTRA_HD].get("decals", 0)) != 8:
		return _fail("Ultra HD mobile decal budget changed unexpectedly")
	return true

func _test_prepared_rig_contract() -> bool:
	var zombie := ZombieScene.instantiate() as Node3D
	if zombie == null:
		return _fail("Zombie scene could not be instantiated for gore contract")
	root.add_child(zombie)
	for path in [
		"VisualRoot/PreparedRig/Head",
		"VisualRoot/PreparedRig/LeftArm",
		"VisualRoot/PreparedRig/RightArm",
		"VisualRoot/PreparedRig/LeftLeg",
		"VisualRoot/PreparedRig/RightLeg",
		"VisualRoot/Wounds/Head",
		"VisualRoot/Wounds/LeftArm",
		"VisualRoot/Wounds/RightArm",
		"VisualRoot/Wounds/LeftLeg",
		"VisualRoot/Wounds/RightLeg",
		"Gore",
	]:
		if zombie.get_node_or_null(path) == null:
			zombie.free()
			return _fail("Prepared gore rig node missing: %s" % path)
	for wound_name in ["Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg"]:
		var wound := zombie.get_node("VisualRoot/Wounds/%s" % wound_name) as MeshInstance3D
		if wound.visible:
			zombie.free()
			return _fail("Wound mesh must start hidden: %s" % wound_name)
	zombie.free()
	return true

func _test_arm_dismemberment() -> bool:
	var fixture := _spawn_authoritative_zombie(3101)
	if fixture.is_empty():
		return false
	var authority = fixture.get("authority")
	var zombie = fixture.get("zombie")
	var health = fixture.get("health")
	var gore = fixture.get("gore")

	var left_arm = _make_event(3101, 56.0, DamageEventScript.BodyPart.LEFT_ARM)
	if not authority.resolve_damage(left_arm):
		_cleanup_fixture(fixture)
		return _fail("Left-arm damage event was rejected")
	if not bool(gore.call("is_limb_destroyed", DamageEventScript.BodyPart.LEFT_ARM)):
		_cleanup_fixture(fixture)
		return _fail("Left arm did not detach at accumulated threshold")
	if absf(float(zombie.call("get_attack_damage_multiplier")) - 0.72) > 0.001:
		_cleanup_fixture(fixture)
		return _fail("One-arm loss did not reduce zombie attack damage")
	var left_mesh := zombie.get_node("VisualRoot/PreparedRig/LeftArm") as MeshInstance3D
	var left_wound := zombie.get_node("VisualRoot/Wounds/LeftArm") as MeshInstance3D
	if left_mesh.visible or not left_wound.visible:
		_cleanup_fixture(fixture)
		return _fail("Left-arm mesh/wound visibility swap failed")
	if int((zombie.get_node("Hitboxes/LeftArm") as Area3D).collision_layer) != 0:
		_cleanup_fixture(fixture)
		return _fail("Destroyed arm hitbox remained active")

	var right_arm = _make_event(3101, 56.0, DamageEventScript.BodyPart.RIGHT_ARM)
	if not authority.resolve_damage(right_arm):
		_cleanup_fixture(fixture)
		return _fail("Right-arm damage event was rejected")
	if absf(float(zombie.call("get_attack_damage_multiplier")) - 0.45) > 0.001:
		_cleanup_fixture(fixture)
		return _fail("Two-arm loss did not apply severe melee reduction")
	if float(health.get("current_health")) <= 0.0:
		_cleanup_fixture(fixture)
		return _fail("Arm dismemberment fixture died before behavior could be tested")
	_cleanup_fixture(fixture)
	return true

func _test_leg_to_crawler() -> bool:
	var fixture := _spawn_authoritative_zombie(3201)
	if fixture.is_empty():
		return false
	var authority = fixture.get("authority")
	var zombie = fixture.get("zombie")
	var gore = fixture.get("gore")
	var leg = _make_event(3201, 55.0, DamageEventScript.BodyPart.LEFT_LEG)
	if not authority.resolve_damage(leg):
		_cleanup_fixture(fixture)
		return _fail("Leg damage event was rejected")
	if not bool(gore.call("is_limb_destroyed", DamageEventScript.BodyPart.LEFT_LEG)):
		_cleanup_fixture(fixture)
		return _fail("Leg did not detach at configured threshold")
	if not bool(zombie.call("is_crawler")):
		_cleanup_fixture(fixture)
		return _fail("Leg loss did not transition zombie into crawler locomotion")
	var collision := zombie.get_node("CollisionShape3D") as CollisionShape3D
	var capsule := collision.shape as CapsuleShape3D
	if capsule == null or capsule.height > 0.90:
		_cleanup_fixture(fixture)
		return _fail("Crawler collision profile was not reduced")
	_cleanup_fixture(fixture)
	return true

func _test_head_destruction_is_lethal() -> bool:
	var fixture := _spawn_authoritative_zombie(3301)
	if fixture.is_empty():
		return false
	var authority = fixture.get("authority")
	var zombie = fixture.get("zombie")
	var health = fixture.get("health")
	var gore = fixture.get("gore")
	var head = _make_event(3301, 19.0, DamageEventScript.BodyPart.HEAD)
	if not authority.resolve_damage(head):
		_cleanup_fixture(fixture)
		return _fail("Head damage event was rejected")
	if not bool(gore.call("is_limb_destroyed", DamageEventScript.BodyPart.HEAD)):
		_cleanup_fixture(fixture)
		return _fail("Head did not detach at configured threshold")
	if not bool(health.call("is_dead")):
		_cleanup_fixture(fixture)
		return _fail("Head destruction did not force authoritative death")
	if int(zombie.get("state")) != ZombieControllerScript.State.DEAD:
		_cleanup_fixture(fixture)
		return _fail("Head destruction did not enter DEAD state")
	_cleanup_fixture(fixture)
	return true

func _spawn_authoritative_zombie(entity_id: int) -> Dictionary:
	var authority = LocalAuthorityScript.new()
	authority.start()
	var zombie := ZombieScene.instantiate() as Node3D
	if zombie == null:
		authority.stop()
		_fail("Zombie fixture could not be instantiated")
		return {}
	zombie.set("entity_id", entity_id)
	root.add_child(zombie)
	zombie.call("set_authority_override", authority)
	var health := zombie.get_node_or_null("Health")
	var gore := zombie.get_node_or_null("Gore")
	if health == null or gore == null:
		zombie.free()
		authority.stop()
		_fail("Zombie gore fixture missing Health or Gore component")
		return {}
	if health.has_method("configure_entity"):
		health.call("configure_entity", entity_id, 100.0)
	if not authority.register_damageable(entity_id, health):
		zombie.free()
		authority.stop()
		_fail("Gore fixture could not register zombie health")
		return {}
	for hitbox in zombie.get_node("Hitboxes").get_children():
		hitbox.set("victim_id", entity_id)
	return {"authority": authority, "zombie": zombie, "health": health, "gore": gore}

func _cleanup_fixture(fixture: Dictionary) -> void:
	var zombie = fixture.get("zombie")
	var authority = fixture.get("authority")
	if zombie != null and is_instance_valid(zombie):
		zombie.free()
	if authority != null:
		authority.stop()

func _make_event(victim_id: int, amount: float, body_part: int):
	var event = DamageEventScript.new()
	event.attacker_id = 1
	event.victim_id = victim_id
	event.weapon_id = &"gore_smoke_rifle"
	event.amount = amount
	event.damage_type = DamageEventScript.DamageType.BULLET
	event.body_part = body_part
	event.hit_position = Vector3(0, 1, 0)
	event.hit_direction = Vector3(0, 0, -1)
	event.hit_normal = Vector3(0, 0, 1)
	return event

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
