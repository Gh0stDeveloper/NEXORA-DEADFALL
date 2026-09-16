extends SceneTree

const DamageEventScript = preload("res://src/core/damage/DamageEvent.gd")
const LocalAuthorityScript = preload("res://src/core/authority/LocalAuthority.gd")
const DedicatedAuthorityScript = preload("res://src/core/authority/DedicatedAuthority.gd")
var ZombieControllerScript: Script
var PlayerScene: PackedScene
var ZombieScene: PackedScene

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	ZombieControllerScript = load("res://src/zombies/base/ZombieController.gd")
	PlayerScene = load("res://src/player/Player.tscn")
	ZombieScene = load("res://src/zombies/base/Zombie.tscn")
	var dedicated_authority = DedicatedAuthorityScript.new()
	dedicated_authority.start()
	if not bool(dedicated_authority.get("active")):
		_fail("Dedicated authority did not enter active simulation state")
		return
	dedicated_authority.stop()

	var authority = LocalAuthorityScript.new()
	authority.start()
	var player := PlayerScene.instantiate() as Node3D
	var zombie := ZombieScene.instantiate() as Node3D
	if player == null or zombie == null:
		_fail("Player or zombie scene could not be instantiated")
		return
	root.add_child(player)
	root.add_child(zombie)
	player.global_position = Vector3.ZERO
	zombie.global_position = Vector3(0, 0, 1.0)

	var player_health := player.get_node_or_null("Health")
	var zombie_health := zombie.get_node_or_null("Health")
	if player_health == null or zombie_health == null:
		_fail("Health components missing from player/zombie")
		return
	authority.register_damageable(int(player_health.get("entity_id")), player_health)
	authority.register_damageable(int(zombie_health.get("entity_id")), zombie_health)
	zombie.call("set_authority_override", authority)

	if zombie.get_node_or_null("NavigationAgent3D") == null:
		_fail("Zombie NavigationAgent3D missing")
		return
	if zombie.get_node_or_null("Hitboxes/Head") == null or zombie.get_node_or_null("Hitboxes/LeftLeg") == null or zombie.get_node_or_null("Hitboxes/RightLeg") == null:
		_fail("Zombie body-part hitboxes missing")
		return
	if int(zombie.get("state")) != ZombieControllerScript.State.IDLE:
		_fail("Zombie must start in IDLE")
		return

	var detected = zombie.call("_find_visible_target")
	if detected != player:
		_fail("Zombie perception did not acquire the visible player")
		return
	zombie.call("_set_target", player)
	zombie.call("_transition_to", ZombieControllerScript.State.CHASE, "smoke_target")
	zombie.call("_process_chase", 0.0)
	if int(zombie.get("state")) != ZombieControllerScript.State.ATTACK:
		_fail("Zombie did not transition CHASE -> ATTACK at melee range")
		return

	var player_before := float(player_health.get("current_health"))
	if not bool(zombie.call("perform_melee_attack", player)):
		_fail("Authoritative zombie melee attack was rejected")
		return
	if absf(float(player_health.get("current_health")) - (player_before - 12.0)) > 0.001:
		_fail("Zombie melee damage did not pass through authority")
		return

	var stagger_event = _make_damage_event(int(zombie_health.get("entity_id")), 20.0, DamageEventScript.BodyPart.CHEST)
	if not authority.resolve_damage(stagger_event):
		_fail("Zombie chest damage was rejected")
		return
	if absf(float(zombie_health.get("current_health")) - 80.0) > 0.001:
		_fail("Zombie health did not receive authoritative damage")
		return
	if int(zombie.get("state")) != ZombieControllerScript.State.STAGGER:
		_fail("Non-lethal zombie hit did not enter STAGGER")
		return

	var lethal_event = _make_damage_event(int(zombie_health.get("entity_id")), 100.0, DamageEventScript.BodyPart.HEAD)
	if not authority.resolve_damage(lethal_event):
		_fail("Lethal zombie headshot was rejected")
		return
	if int(zombie.get("state")) != ZombieControllerScript.State.DEAD:
		_fail("Lethal zombie headshot did not enter DEAD")
		return
	if not bool(zombie_health.call("is_dead")):
		_fail("Zombie HealthComponent did not mark death")
		return
	if int(zombie.get("collision_layer")) != 0 or int(zombie.get("collision_mask")) != 0:
		_fail("Zombie body collision remained active after death")
		return

	zombie.call("set_authority_override", null)
	if bool(zombie.call("has_simulation_authority")):
		_fail("Zombie AI incorrectly considers a non-authoritative client authoritative")
		return

	authority.stop()
	player.free()
	zombie.free()
	print("NEXORA: DEADFALL zombie smoke test passed")
	quit(0)

func _make_damage_event(victim_id: int, amount: float, body_part: int):
	var event = DamageEventScript.new()
	event.attacker_id = 1
	event.victim_id = victim_id
	event.weapon_id = &"test_rifle"
	event.amount = amount
	event.damage_type = DamageEventScript.DamageType.BULLET
	event.body_part = body_part
	event.hit_direction = Vector3(0, 0, -1)
	return event

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
