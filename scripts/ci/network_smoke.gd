extends SceneTree

const NetworkAuthorityScript = preload("res://src/core/authority/NetworkAuthority.gd")
const HealthScript = preload("res://src/core/health/HealthComponent.gd")
const DamageEventScript = preload("res://src/core/damage/DamageEvent.gd")
const PlayerCommandScript = preload("res://src/network/PlayerCommand.gd")
const RoomCodeScript = preload("res://src/network/RoomCodeService.gd")
const DuoSessionScript = preload("res://src/network/DuoNetworkSession.gd")
const DedicatedServerScript = preload("res://src/server/DedicatedServer.gd")
const PlayerScene = preload("res://src/player/Player.tscn")
const PlayerControllerScript = preload("res://src/player/PlayerController.gd")
const DuoArenaScene = preload("res://src/maps/duo/DuoArena.tscn")

func _initialize() -> void:
	if not _test_network_authority(): return
	if not _test_command_validation(): return
	if not _test_room_codes(): return
	if not _test_duo_capacity_contract(): return
	if not _test_player_command_and_weapon_sequence(): return
	if not _test_duo_arena_contract(): return
	print("NEXORA: DEADFALL network smoke test passed")
	quit(0)

func _test_network_authority() -> bool:
	var authority = NetworkAuthorityScript.new()
	authority.start()
	var health = HealthScript.new()
	health.entity_id = 77
	health.max_health = 100.0
	health.reset_health()
	if not authority.register_damageable(77, health): return _fail("NetworkAuthority failed to register replica health")
	var event = DamageEventScript.new()
	event.attacker_id = 1
	event.victim_id = 77
	event.weapon_id = &"test"
	event.amount = 50.0
	if authority.resolve_damage(event): return _fail("NetworkAuthority resolved client-side damage")
	if absf(float(health.current_health) - 100.0) > 0.001: return _fail("Client-side damage changed health")
	if not authority.apply_health_snapshot(77, 63.0, 100.0, false): return _fail("Network health snapshot was rejected")
	if absf(float(health.current_health) - 63.0) > 0.001: return _fail("Network health snapshot did not apply")
	authority.stop()
	health.free()
	return true

func _test_command_validation() -> bool:
	var raw := {"sequence": 8, "client_tick": 12, "move": Vector2(4, 0), "yaw": 20.0, "pitch": 8.0, "sprint": true, "jump_serial": 2}
	var command := PlayerCommandScript.sanitize(raw, 7)
	if command.is_empty(): return _fail("Valid player command rejected")
	if Vector2(command.get("move")).length() > 1.001: return _fail("Move vector was not clamped")
	if absf(float(command.get("pitch"))) > deg_to_rad(80.0) + 0.001: return _fail("Pitch was not clamped")
	if not PlayerCommandScript.sanitize(raw, 8).is_empty(): return _fail("Stale command sequence accepted")
	return true

func _test_room_codes() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var code := RoomCodeScript.generate_code(rng)
	if not RoomCodeScript.is_valid(code): return _fail("Generated room code invalid")
	var payload := JSON.stringify({"ok": true, "room_code": code, "host": "127.0.0.1", "port": 24560, "protocol": 1})
	var endpoint := RoomCodeScript.parse_resolution_payload(payload)
	if endpoint.is_empty() or int(endpoint.get("port")) != 24560: return _fail("Room directory payload parse failed")
	return true

func _test_duo_capacity_contract() -> bool:
	if int(DuoSessionScript.MAX_PLAYERS) != 2:
		return _fail("Duo session gameplay capacity must remain two players")
	if int(DedicatedServerScript.DEFAULT_MAX_CLIENTS) != 2:
		return _fail("Dedicated ENet transport must cap Duo at two clients")
	return true

func _test_player_command_and_weapon_sequence() -> bool:
	Game.start_dedicated_server_session()
	var player := PlayerScene.instantiate()
	player.set("control_mode", PlayerControllerScript.ControlMode.SERVER_REMOTE)
	player.set("player_entity_id", 101)
	var weapon := player.get_node_or_null("PrimaryWeapon")
	if weapon != null:
		weapon.set("shooter_entity_id", 101)
	root.add_child(player)
	player.call("configure_network_identity", 101, PlayerControllerScript.ControlMode.SERVER_REMOTE)
	var command := PlayerCommandScript.sanitize({"sequence": 1, "move": Vector2(0.5, -1), "yaw": 0.4, "pitch": 0.2, "sprint": true, "jump_serial": 0, "crouch_serial": 0, "prone_serial": 0}, -1)
	if not bool(player.call("push_server_command", command)): return _fail("Server player rejected first command")
	if bool(player.call("push_server_command", command)): return _fail("Server player accepted duplicate command")
	if weapon == null: return _fail("Server player weapon missing")
	var starting_ammo := int(weapon.call("get_ammo_in_mag"))
	if not bool(weapon.call("server_try_fire", 1, 1)): return _fail("Server rejected first valid fire request")
	if bool(weapon.call("server_try_fire", 1, 1)): return _fail("Server accepted duplicate fire request sequence")
	if bool(weapon.call("server_try_fire", 2, 1)): return _fail("Server fire cadence was bypassed")
	if int(weapon.call("get_ammo_in_mag")) != starting_ammo - 1: return _fail("Rejected fire request changed authoritative ammo")
	if not bool(weapon.call("server_try_reload", 1)): return _fail("Server rejected valid reload request")
	if bool(weapon.call("server_try_reload", 1)): return _fail("Server accepted duplicate reload request sequence")
	if bool(weapon.call("server_try_fire", 3, 1)): return _fail("Server allowed fire while authoritative reload is active")
	player.free()
	Game.stop_session()
	return true

func _test_duo_arena_contract() -> bool:
	var arena := DuoArenaScene.instantiate()
	root.add_child(arena)
	for path in ["NetworkSession", "NetworkPlayers", "PlayerSpawnPoints/SpawnA", "PlayerSpawnPoints/SpawnB", "HordeDirector", "HordeZombies"]:
		if arena.get_node_or_null(path) == null: return _fail("DuoArena missing %s" % path)
	arena.free()
	return true

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
