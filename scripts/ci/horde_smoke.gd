extends SceneTree

const DamageEventScript = preload("res://src/core/damage/DamageEvent.gd")
const LocalAuthorityScript = preload("res://src/core/authority/LocalAuthority.gd")
const HordeRulesScript = preload("res://src/horde/HordeRules.gd")
const HordeDirectorScript = preload("res://src/horde/HordeDirector.gd")
const SettingsScript = preload("res://src/autoload/Settings.gd")
const PlayerScene = preload("res://src/player/Player.tscn")
const WalkerData = preload("res://src/zombies/data/walker_01.tres")
const ScreamerData = preload("res://src/zombies/data/screamer_01.tres")
const CrawlerData = preload("res://src/zombies/data/crawler_01.tres")

func _initialize() -> void:
	if not _test_rules_and_unlocks():
		return
	if not _test_director_runtime():
		return
	print("NEXORA: DEADFALL horde smoke test passed")
	quit(0)

func _test_rules_and_unlocks() -> bool:
	if HordeRulesScript.wave_total(1) != 6 or HordeRulesScript.wave_total(2) != 9:
		return _fail("Horde wave growth formula mismatch")
	if HordeRulesScript.wave_total(6) != 25:
		return _fail("Horde milestone wave bonus mismatch")
	var expected_budgets := [8, 14, 20, 28]
	for tier in range(4):
		var profile: Dictionary = SettingsScript.QUALITY_PROFILES[tier]
		if HordeRulesScript.population_budget(profile) != expected_budgets[tier]:
			return _fail("Horde population budget mismatch for quality tier %d" % tier)
		if HordeRulesScript.spawn_interval(profile, 0.55) <= 0.0:
			return _fail("Horde spawn interval must remain positive")

	var director = HordeDirectorScript.new()
	director.auto_start = false
	if director.get_available_archetype_ids(1) != [&"walker"]:
		return _fail("Wave 1 must unlock only Walker")
	if &"runner" not in director.get_available_archetype_ids(2):
		return _fail("Runner must unlock on wave 2")
	if &"crawler" not in director.get_available_archetype_ids(3):
		return _fail("Crawler must unlock on wave 3")
	if &"tank" not in director.get_available_archetype_ids(4):
		return _fail("Tank must unlock on wave 4")
	if &"screamer" not in director.get_available_archetype_ids(5):
		return _fail("Screamer must unlock on wave 5")
	if not bool(CrawlerData.get("native_crawler")) or not bool(ScreamerData.get("screamer_enabled")):
		return _fail("Crawler/Screamer special archetype flags missing")
	director.free()
	return true

func _test_director_runtime() -> bool:
	var authority = LocalAuthorityScript.new()
	authority.start()

	var arena := Node3D.new()
	arena.name = "HordeTestArena"
	root.add_child(arena)
	var player := PlayerScene.instantiate() as Node3D
	player.name = "Player"
	arena.add_child(player)
	player.global_position = Vector3.ZERO
	var player_health := player.get_node_or_null("Health")
	if player_health == null:
		return _fail("Horde test player Health missing")
	authority.register_damageable(int(player_health.get("entity_id")), player_health)

	var spawn_root := Node3D.new()
	spawn_root.name = "HordeSpawnPoints"
	arena.add_child(spawn_root)
	var near_spawn := Marker3D.new()
	near_spawn.name = "Near"
	near_spawn.position = Vector3(2, 0, 0)
	spawn_root.add_child(near_spawn)
	var far_spawn := Marker3D.new()
	far_spawn.name = "Far"
	far_spawn.position = Vector3(12, 0, 0)
	spawn_root.add_child(far_spawn)

	var zombie_parent := Node3D.new()
	zombie_parent.name = "HordeZombies"
	arena.add_child(zombie_parent)

	var director = HordeDirectorScript.new()
	director.name = "HordeDirector"
	director.auto_start = false
	director.deterministic_seed = 777
	director.spawn_safety_radius = 8.0
	director.set_authority_override(authority)
	arena.add_child(director)
	if not director.start_run():
		return _fail("Authoritative HordeDirector failed to start")
	if int(director.get("state")) != HordeDirectorScript.State.COUNTDOWN:
		return _fail("Horde run must start in COUNTDOWN")

	var chosen_spawn := director.call("_choose_spawn_point") as Node3D
	if chosen_spawn != far_spawn:
		return _fail("Spawn safety did not prefer the point outside player safety radius")

	var spawned_tanks: Array[Node3D] = []
	for _index in range(4):
		var tank := director.debug_spawn_archetype(&"tank")
		if tank == null:
			return _fail("Tank should fit inside Standard population budget")
		spawned_tanks.append(tank)
	if director.get_active_population_cost() != 12:
		return _fail("Tank population cost accounting mismatch")
	if director.debug_spawn_archetype(&"tank") != null:
		return _fail("HordeDirector exceeded current population budget")
	if director.get_active_population_cost() > director.get_population_budget():
		return _fail("Active population escaped quality budget")

	var first_tank := spawned_tanks[0]
	var tank_health := first_tank.get_node_or_null("Health")
	var lethal_tank := _make_damage_event(int(tank_health.get("entity_id")), 999.0)
	if not authority.resolve_damage(lethal_tank):
		return _fail("Authority rejected lethal Tank damage")
	if int(director.get("kills")) != 1 or int(director.get("score")) != 350:
		return _fail("Horde kill/score accounting mismatch")
	director.call("_on_zombie_died", null, first_tank)
	if int(director.get("kills")) != 1 or int(director.get("score")) != 350:
		return _fail("Zombie death awarded score more than once")

	var player_lethal := _make_damage_event(int(player_health.get("entity_id")), 999.0)
	if not authority.resolve_damage(player_lethal):
		return _fail("Authority rejected lethal player damage")
	if int(director.get("state")) != HordeDirectorScript.State.GAME_OVER:
		return _fail("Player death did not enter Horde GAME_OVER")
	if not director.restart_run():
		return _fail("Horde restart failed")
	if int(director.get("state")) != HordeDirectorScript.State.COUNTDOWN or int(director.get("score")) != 0 or int(director.get("kills")) != 0:
		return _fail("Horde restart did not reset run counters")
	if bool(player_health.call("is_dead")) or absf(float(player_health.get("current_health")) - float(player_health.get("max_health"))) > 0.001:
		return _fail("Horde restart did not reset player health")

	director.call("_begin_next_wave")
	var total := int(director.get("wave_total_enemies"))
	director.set("wave_spawned", total)
	director.call("_set_state", HordeDirectorScript.State.ACTIVE, "smoke_wave_active")
	director.call("_check_wave_complete")
	if int(director.get("state")) != HordeDirectorScript.State.INTERMISSION:
		return _fail("Empty fully-spawned wave did not transition to INTERMISSION")

	director.call("_clear_active_zombies")
	var screamer := director.debug_spawn_archetype(&"screamer")
	var walker := director.debug_spawn_archetype(&"walker")
	if screamer == null or walker == null:
		return _fail("Screamer/Walker debug spawn failed")
	screamer.global_position = Vector3(10, 0, 0)
	walker.global_position = Vector3(10.5, 0, 0)
	var screamer_behavior := screamer.get_node_or_null("ArchetypeBehavior")
	var walker_behavior := walker.get_node_or_null("ArchetypeBehavior")
	if screamer_behavior == null or walker_behavior == null:
		return _fail("Zombie ArchetypeBehavior missing")
	screamer_behavior.call("_emit_scream")
	if not bool(walker_behavior.call("is_raged")):
		return _fail("Screamer did not apply rage to a nearby zombie")
	if absf(float(WalkerData.get("move_speed")) - 3.2) > 0.001:
		return _fail("Runtime rage mutated shared Walker resource")

	director.call("_clear_active_zombies")
	var crawler := director.debug_spawn_archetype(&"crawler")
	if crawler == null:
		return _fail("Native Crawler spawn failed")
	var crawler_behavior := crawler.get_node_or_null("ArchetypeBehavior")
	crawler_behavior.call("_activate_native_crawler")
	if not bool(crawler.call("is_crawler")):
		return _fail("Native Crawler did not enter crawler locomotion")

	authority.stop()
	arena.free()
	return true

func _make_damage_event(victim_id: int, amount: float):
	var event = DamageEventScript.new()
	event.attacker_id = 1
	event.victim_id = victim_id
	event.weapon_id = &"horde_smoke"
	event.amount = amount
	event.damage_type = DamageEventScript.DamageType.BULLET
	event.body_part = DamageEventScript.BodyPart.CHEST
	event.hit_direction = Vector3(0, 0, -1)
	event.hit_normal = Vector3(0, 0, 1)
	return event

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
