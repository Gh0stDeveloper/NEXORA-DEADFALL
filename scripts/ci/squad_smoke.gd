extends SceneTree

var _game: Node

const DamageEventScript = preload("res://src/core/damage/DamageEvent.gd")
const HordeRulesScript = preload("res://src/horde/HordeRules.gd")
var SessionScript: Script
var DedicatedServerScript: Script
var PlayerControllerScript: Script
var PlayerScene: PackedScene
var ArenaScene: PackedScene

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_game = root.get_node("Game")
	SessionScript = load("res://src/network/DuoNetworkSession.gd")
	DedicatedServerScript = load("res://src/server/DedicatedServer.gd")
	PlayerControllerScript = load("res://src/player/PlayerController.gd")
	PlayerScene = load("res://src/player/Player.tscn")
	ArenaScene = load("res://src/maps/duo/DuoArena.tscn")
	_game.start_dedicated_server_session()
	if not _test_capacity_and_budgets(): return
	if not _test_downed_revive_and_weapon_lock(): return
	if not _test_bleedout(): return
	if not _test_server_revive_hold(): return
	_game.stop_session()
	print("NEXORA: DEADFALL Squad smoke test passed")
	quit(0)

func _test_capacity_and_budgets() -> bool:
	if int(SessionScript.MAX_PLAYERS) != 4:
		return _fail("Squad session capacity must be four")
	if int(DedicatedServerScript.DEFAULT_MAX_CLIENTS) != 4:
		return _fail("Dedicated transport capacity must be four")
	var standard: Dictionary = Settings.QUALITY_PROFILES[Settings.QualityTier.STANDARD]
	if HordeRulesScript.population_budget(standard, 4) != 23:
		return _fail("Standard four-player Horde population budget mismatch")
	if HordeRulesScript.wave_total(1, 4) <= HordeRulesScript.wave_total(1, 1):
		return _fail("Four-player wave did not scale above solo")
	for key in ["network_zombie_snapshots", "network_snapshot_hz", "network_max_payload_bytes", "horde_squad_population_bonus"]:
		if not standard.has(key):
			return _fail("Standard profile missing Squad budget: %s" % key)

	var capacity_session = SessionScript.new()
	root.add_child(capacity_session)
	var expires := Time.get_ticks_usec() + 30_000_000
	capacity_session.set("_resume_records", {
		"a": {"slot": 0, "expires_usec": expires},
		"b": {"slot": 1, "expires_usec": expires},
		"c": {"slot": 2, "expires_usec": expires},
		"d": {"slot": 3, "expires_usec": expires},
	})
	if int(capacity_session.call("_reserved_slot_count")) != 4:
		return _fail("Reconnect reservations did not preserve all four Squad slots")
	if int(capacity_session.call("_first_free_slot")) != -1:
		return _fail("A fifth gameplay slot remained available while four reconnect slots were reserved")
	if int(capacity_session.call("_zombie_detail_budget")) != int(standard.get("network_zombie_snapshots")):
		return _fail("Session zombie replication budget did not come from quality profile")
	if int(capacity_session.call("_max_payload_bytes")) != int(standard.get("network_max_payload_bytes")):
		return _fail("Session payload budget did not come from quality profile")
	capacity_session.free()

	var arena := ArenaScene.instantiate()
	root.add_child(arena)
	for path in ["PlayerSpawnPoints/SpawnA", "PlayerSpawnPoints/SpawnB", "PlayerSpawnPoints/SpawnC", "PlayerSpawnPoints/SpawnD"]:
		if arena.get_node_or_null(path) == null:
			return _fail("Squad arena missing %s" % path)
	arena.free()
	return true

func _test_downed_revive_and_weapon_lock() -> bool:
	var player := _spawn_server_player(501)
	if player == null:
		return _fail("Unable to spawn Squad life-state test player")
	var health := player.get_node("Health")
	var life := player.get_node("LifeState")
	var weapon := player.get_node("PrimaryWeapon")
	var lethal = _damage_event(501, 999.0)
	if not _game.authority.resolve_damage(lethal):
		return _fail("Authority rejected Squad lethal damage")
	if not bool(life.call("is_downed")) or bool(health.call("is_dead")) or float(health.get("current_health")) <= 0.0:
		return _fail("Eligible lethal damage did not enter DOWNED")
	var ammo := int(weapon.call("get_ammo_in_mag"))
	if bool(weapon.call("server_try_fire", 1, 1)):
		return _fail("DOWNED player fired a server-authoritative weapon")
	if int(weapon.call("get_ammo_in_mag")) != ammo:
		return _fail("Rejected DOWNED fire changed ammo")
	if not bool(life.call("revive_authoritative", 777)):
		return _fail("Authoritative revive failed")
	if not bool(life.call("is_alive")) or float(health.get("current_health")) < 30.0:
		return _fail("Revive did not restore ALIVE state and health")
	if not _game.authority.resolve_damage(_damage_event(501, 999.0)):
		return _fail("Second lethal damage failed to down player")
	if not _game.authority.resolve_damage(_damage_event(501, 20.0)):
		return _fail("Damage to DOWNED player was rejected")
	if not bool(life.call("is_dead")) or not bool(health.call("is_dead")):
		return _fail("DOWNED player did not transition to DEAD after lethal follow-up")
	player.free()
	return true

func _test_bleedout() -> bool:
	var player := _spawn_server_player(502)
	if player == null:
		return _fail("Unable to spawn bleedout player")
	var life := player.get_node("LifeState")
	if not _game.authority.resolve_damage(_damage_event(502, 999.0)):
		return _fail("Bleedout setup damage failed")
	if not bool(life.call("is_downed")):
		return _fail("Bleedout player did not enter DOWNED")
	life.call("_process", 31.0)
	if not bool(life.call("is_dead")):
		return _fail("Bleedout did not transition DOWNED to DEAD")
	player.free()
	return true

func _test_server_revive_hold() -> bool:
	var arena := ArenaScene.instantiate()
	root.add_child(arena)
	var session := arena.get_node("NetworkSession")
	session.set("role", SessionScript.Role.SERVER)
	var reviver := session.call("_spawn_player", 601, PlayerControllerScript.ControlMode.SERVER_REMOTE, 0) as Node3D
	var target := session.call("_spawn_player", 602, PlayerControllerScript.ControlMode.SERVER_REMOTE, 1) as Node3D
	if reviver == null or target == null:
		return _fail("Squad server revive test could not spawn players")
	var target_health := target.get_node("Health")
	var target_life := target.get_node("LifeState")
	if not _game.authority.resolve_damage(_damage_event(602, 999.0)):
		return _fail("Server revive target could not be downed")
	if not bool(target_life.call("is_downed")):
		return _fail("Server revive target is not DOWNED")
	reviver.global_position = Vector3.ZERO
	target.global_position = Vector3(1.0, 0.0, 0.0)
	session.set("_peers", {
		2: {"entity_id": 601, "player": reviver, "slot": 0, "interact": true, "revive_target_id": 0, "revive_elapsed": 0.0},
		3: {"entity_id": 602, "player": target, "slot": 1, "interact": false, "revive_target_id": 0, "revive_elapsed": 0.0},
	})
	session.call("_process_revives", 2.0)
	if not bool(target_life.call("is_downed")):
		return _fail("Revive completed before required hold duration")
	session.call("_process_revives", 1.2)
	if not bool(target_life.call("is_alive")) or float(target_health.get("current_health")) < 30.0:
		return _fail("Server hold did not revive nearby teammate")
	arena.free()
	return true

func _spawn_server_player(entity_id: int) -> Node3D:
	var player := PlayerScene.instantiate() as Node3D
	player.set("player_entity_id", entity_id)
	player.set("control_mode", PlayerControllerScript.ControlMode.SERVER_REMOTE)
	player.get_node("Health").set("entity_id", entity_id)
	player.get_node("PrimaryWeapon").set("shooter_entity_id", entity_id)
	root.add_child(player)
	return player

func _damage_event(victim_id: int, amount: float):
	var event = DamageEventScript.new()
	event.attacker_id = 900
	event.victim_id = victim_id
	event.weapon_id = &"squad_smoke"
	event.amount = amount
	event.damage_type = DamageEventScript.DamageType.BULLET
	event.body_part = DamageEventScript.BodyPart.CHEST
	event.hit_direction = Vector3(0, 0, -1)
	event.hit_normal = Vector3(0, 0, 1)
	return event

func _fail(message: String) -> bool:
	push_error(message)
	_game.stop_session()
	quit(1)
	return false
