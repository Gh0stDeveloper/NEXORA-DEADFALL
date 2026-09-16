extends SceneTree

var _game: Node

const NetworkAuthorityScript = preload("res://src/core/authority/NetworkAuthority.gd")
const HealthScript = preload("res://src/core/health/HealthComponent.gd")
const DamageEventScript = preload("res://src/core/damage/DamageEvent.gd")
const PlayerCommandScript = preload("res://src/network/PlayerCommand.gd")
const RoomCodeScript = preload("res://src/network/RoomCodeService.gd")
const BuildInfoScript = preload("res://src/release/BuildInfo.gd")
var SessionScript: Script
var DedicatedServerScript: Script
var PlayerScene: PackedScene
var PlayerControllerScript: Script
var SquadArenaScene: PackedScene
var MtuSafeSessionScript: Script

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_game = root.get_node("Game")
	SessionScript = load("res://src/network/DuoNetworkSession.gd")
	DedicatedServerScript = load("res://src/server/DedicatedServer.gd")
	PlayerScene = load("res://src/player/Player.tscn")
	PlayerControllerScript = load("res://src/player/PlayerController.gd")
	SquadArenaScene = load("res://src/maps/duo/DuoArena.tscn")
	MtuSafeSessionScript = load("res://src/network/MtuSafeClosedBetaNetworkSession.gd")
	if not _test_network_authority(): return
	if not _test_command_validation(): return
	if not _test_room_codes(): return
	if not _test_squad_capacity_contract(): return
	if not _test_player_command_and_weapon_sequence(): return
	if not _test_squad_arena_contract(): return
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
	var raw := {"sequence": 8, "client_tick": 12, "move": Vector2(4, 0), "yaw": 20.0, "pitch": 8.0, "sprint": true, "interact": true, "jump_serial": 2}
	var command := PlayerCommandScript.sanitize(raw, 7)
	if command.is_empty(): return _fail("Valid player command rejected")
	if Vector2(command.get("move")).length() > 1.001: return _fail("Move vector was not clamped")
	if absf(float(command.get("pitch"))) > 1.397: return _fail("Pitch was not clamped")
	if not bool(command.get("interact", false)): return _fail("Revive hold intent was dropped during command sanitation")
	if not PlayerCommandScript.sanitize(raw, 8).is_empty(): return _fail("Stale command sequence accepted")
	if not PlayerCommandScript.sanitize({"sequence": 9, "move": "malformed"}, 8).is_empty(): return _fail("Malformed command Variant accepted")
	return true

func _test_room_codes() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var code := RoomCodeScript.generate_code(rng)
	if not RoomCodeScript.is_valid(code): return _fail("Generated room code invalid")
	var payload := BuildInfoScript.snapshot()
	payload.merge({"ok": true, "room_code": code, "host": "127.0.0.1", "port": 24560, "max_players": 4}, true)
	var endpoint := RoomCodeScript.parse_resolution_payload(JSON.stringify(payload))
	if endpoint.is_empty() or int(endpoint.get("port")) != 24560: return _fail("Room directory payload parse failed")
	if int(endpoint.get("protocol")) != 2: return _fail("Squad protocol version mismatch")
	if int(endpoint.get("max_players")) != 4: return _fail("Squad directory did not advertise four-player capacity")
	if int(endpoint.get("version_code")) != BuildInfoScript.VERSION_CODE: return _fail("Closed beta directory build version missing")
	return true

func _test_squad_capacity_contract() -> bool:
	if int(SessionScript.MAX_PLAYERS) != 4:
		return _fail("Squad session gameplay capacity must be four players")
	if int(DedicatedServerScript.DEFAULT_MAX_CLIENTS) != 4:
		return _fail("Dedicated ENet transport must cap Squad at four clients")
	if int(MtuSafeSessionScript.SNAPSHOT_CHUNK_BYTES) >= 1392:
		return _fail("Closed Beta snapshot chunk budget must stay below observed ENet MTU")
	if int(MtuSafeSessionScript.SNAPSHOT_MAX_RAW_BYTES) > 65536:
		return _fail("Closed Beta snapshot decoder raw-size guard is too large")
	return true

func _test_player_command_and_weapon_sequence() -> bool:
	_game.start_dedicated_server_session()
	var player := PlayerScene.instantiate()
	player.set("control_mode", PlayerControllerScript.ControlMode.SERVER_REMOTE)
	player.set("player_entity_id", 101)
	var weapon := player.get_node_or_null("PrimaryWeapon")
	if weapon != null:
		weapon.set("shooter_entity_id", 101)
	player.get_node("Health").set("entity_id", 101)
	root.add_child(player)
	player.call("configure_network_identity", 101, PlayerControllerScript.ControlMode.SERVER_REMOTE)
	var command := PlayerCommandScript.sanitize({"sequence": 1, "move": Vector2(0.5, -1), "yaw": 0.4, "pitch": 0.2, "sprint": true, "interact": false, "jump_serial": 0, "crouch_serial": 0, "prone_serial": 0}, -1)
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
	_game.stop_session()
	return true

func _test_squad_arena_contract() -> bool:
	var arena := SquadArenaScene.instantiate()
	root.add_child(arena)
	for path in ["NetworkSession", "NetworkPlayers", "PlayerSpawnPoints/SpawnA", "PlayerSpawnPoints/SpawnB", "PlayerSpawnPoints/SpawnC", "PlayerSpawnPoints/SpawnD", "HordeDirector", "HordeZombies"]:
		if arena.get_node_or_null(path) == null: return _fail("Squad arena missing %s" % path)
	var session := arena.get_node("NetworkSession")
	if String(session.get_script().resource_path) != "res://src/network/MtuSafeClosedBetaNetworkSession.gd": return _fail("Squad arena is not using MTU-safe hardened Closed Beta session")
	arena.free()
	return true

func _fail(message: String) -> bool:
	push_error(message)
	if _game.session_mode != _game.SessionMode.NONE:
		_game.stop_session()
	quit(1)
	return false
