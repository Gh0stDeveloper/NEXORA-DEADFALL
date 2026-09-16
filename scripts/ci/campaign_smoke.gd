extends SceneTree

var _game: Node

var CampaignDirectorScript: Script
const SaveStoreScript = preload("res://src/campaign/CampaignSaveStore.gd")
const Mission1 = preload("res://src/campaign/data/mission_01_first_signal.tres")
const Mission2 = preload("res://src/campaign/data/mission_02_last_broadcast.tres")
var CampaignArenaScene: PackedScene
var PlayerScene: PackedScene
var PlayerControllerScript: Script

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_game = root.get_node("Game")
	CampaignDirectorScript = load("res://src/campaign/CampaignDirector.gd")
	CampaignArenaScene = load("res://src/maps/campaign/OutbreakDistrict.tscn")
	PlayerScene = load("res://src/player/Player.tscn")
	PlayerControllerScript = load("res://src/player/PlayerController.gd")
	_game.start_local_session()
	if not _test_mission_one(): return
	if not _test_mission_two(): return
	if not _test_failure_checkpoint_restart(): return
	if not _test_checkpoint_store(): return
	if not _test_campaign_scene_contract(): return
	_game.stop_session()
	if not _test_client_authority_rejection(): return
	print("NEXORA: DEADFALL campaign smoke test passed")
	quit(0)

func _test_mission_one() -> bool:
	var fixture := _make_fixture(Mission1, 9001)
	var director: Node = fixture["director"]
	var player: Node3D = fixture["player"]
	var targets: Node3D = fixture["targets"]
	if not bool(director.call("start_mission", Mission1, false)): return _fail("Mission 01 failed to start")
	player.global_position = targets.get_node("StreetGate").global_position
	director.call("_process", 0.1)
	if int(director.get("objective_index")) != 1: return _fail("Mission 01 reach objective did not complete")
	for _i in range(8): director.call("report_zombie_kill", 1)
	if int(director.get("objective_index")) != 2: return _fail("Mission 01 kill objective did not complete")
	director.call("_process", 18.1)
	if int(director.get("objective_index")) != 3: return _fail("Mission 01 survive objective did not complete")
	player.global_position = targets.get_node("EvacPoint").global_position
	director.call("_process", 0.1)
	if String(director.call("get_status_snapshot").get("state_name")) != "COMPLETED": return _fail("Mission 01 did not complete")
	fixture["root"].free()
	return true

func _test_mission_two() -> bool:
	var fixture := _make_fixture(Mission2, 9002)
	var director: Node = fixture["director"]
	var player: Node3D = fixture["player"]
	var targets: Node3D = fixture["targets"]
	if not bool(director.call("start_mission", Mission2, false)): return _fail("Mission 02 failed to start")
	player.global_position = targets.get_node("RadioYard").global_position
	director.call("_process", 0.1)
	if int(director.get("objective_index")) != 1: return _fail("Mission 02 reach objective did not complete")
	player.global_position = targets.get_node("RadioConsole").global_position
	var input_source := player.get_node("PlayerInput")
	input_source.call("set_mobile_action", &"interact", true)
	director.call("_process", 1.0)
	if int(director.get("objective_index")) != 1: return _fail("Mission 02 interaction completed before hold duration")
	director.call("_process", 1.1)
	input_source.call("set_mobile_action", &"interact", false)
	if int(director.get("objective_index")) != 2: return _fail("Mission 02 held interaction did not complete")
	for _i in range(12): director.call("report_zombie_kill", 1)
	if int(director.get("objective_index")) != 3: return _fail("Mission 02 kill objective did not complete")
	director.call("_process", 22.1)
	if int(director.get("objective_index")) != 4: return _fail("Mission 02 broadcast objective did not complete")
	player.global_position = targets.get_node("ServiceTunnel").global_position
	director.call("_process", 0.1)
	if String(director.call("get_status_snapshot").get("state_name")) != "COMPLETED": return _fail("Mission 02 did not complete")
	fixture["root"].free()
	return true

func _test_failure_checkpoint_restart() -> bool:
	var fixture := _make_fixture(Mission1, 9003)
	var director: Node = fixture["director"]
	var player: Node3D = fixture["player"]
	var targets: Node3D = fixture["targets"]
	if not bool(director.call("start_mission", Mission1, false)): return _fail("Checkpoint restart mission failed to start")
	player.global_position = targets.get_node("StreetGate").global_position
	director.call("_process", 0.1)
	if int(director.get("objective_index")) != 1 or String(director.get("checkpoint_id")) != "StreetGate": return _fail("Checkpoint was not recorded after objective completion")
	director.call("_on_horde_game_over", 2, 0, 0)
	if String(director.call("get_status_snapshot").get("state_name")) != "FAILED": return _fail("Campaign did not fail when squad was eliminated")
	director.call("_on_horde_run_restarted")
	if String(director.call("get_status_snapshot").get("state_name")) != "RUNNING" or int(director.get("objective_index")) != 1: return _fail("Campaign restart did not preserve checkpoint objective")
	fixture["root"].free()
	return true

func _test_checkpoint_store() -> bool:
	var slot := "campaign_ci_smoke"
	SaveStoreScript.clear_progress(slot)
	if not SaveStoreScript.save_progress(slot, {"campaign_id":"deadfall_outbreak","mission_id":"mission_01_first_signal","objective_index":2,"checkpoint_id":"HoldPoint","completed":false}):
		return _fail("Campaign checkpoint save failed")
	var loaded: Dictionary = SaveStoreScript.load_progress(slot)
	if int(loaded.get("objective_index", -1)) != 2 or String(loaded.get("checkpoint_id", "")) != "HoldPoint": return _fail("Campaign checkpoint restore mismatch")
	if not SaveStoreScript.clear_progress(slot): return _fail("Campaign checkpoint cleanup failed")
	return true

func _test_campaign_scene_contract() -> bool:
	var arena := CampaignArenaScene.instantiate()
	arena.set("mission_id", &"mission_01_first_signal")
	root.add_child(arena)
	for path in ["CampaignDirector", "CampaignNetworkBridge", "CampaignHUD", "NetworkSession", "NetworkPlayers", "HordeDirector", "HordeZombies", "CampaignTargets/StreetGate", "CampaignTargets/RadioConsole", "PlayerSpawnPoints/SpawnA", "PlayerSpawnPoints/SpawnD"]:
		if arena.get_node_or_null(path) == null: return _fail("Campaign arena missing %s" % path)
	arena.free()
	return true

func _test_client_authority_rejection() -> bool:
	_game.start_network_client_session()
	var director = CampaignDirectorScript.new()
	director.set("mission", Mission1)
	root.add_child(director)
	if bool(director.call("start_mission", Mission1, false)): return _fail("Network client started authoritative campaign")
	director.call("apply_replica_snapshot", {"state":1,"state_name":"RUNNING","mission_id":"mission_01_first_signal","mission_title":"Mission 01 — First Signal","objective_index":2,"objective_count":4,"objective_title":"Hold the street","progress":5.0,"required":18.0,"checkpoint_id":"HoldPoint"})
	var status: Dictionary = director.call("get_status_snapshot")
	if int(status.get("objective_index", -1)) != 2 or String(status.get("mission_id", "")) != "mission_01_first_signal": return _fail("Campaign replica snapshot did not apply")
	director.free()
	_game.stop_session()
	return true

func _make_fixture(mission: Resource, entity_id: int) -> Dictionary:
	var fixture_root := Node3D.new()
	root.add_child(fixture_root)
	var targets := Node3D.new()
	targets.name = "Targets"
	fixture_root.add_child(targets)
	var positions := {"StreetGate":Vector3(2,0,0),"HoldPoint":Vector3(4,0,0),"EvacPoint":Vector3(6,0,0),"RadioYard":Vector3(8,0,0),"RadioConsole":Vector3(10,0,0),"ServiceTunnel":Vector3(12,0,0)}
	for target_name in positions:
		var marker := Marker3D.new()
		marker.name = target_name
		marker.position = positions[target_name]
		targets.add_child(marker)
	var player := PlayerScene.instantiate() as Node3D
	player.name = "CampaignTestPlayer_%d" % entity_id
	player.set("player_entity_id", entity_id)
	player.set("control_mode", PlayerControllerScript.ControlMode.OFFLINE_LOCAL)
	player.get_node("Health").set("entity_id", entity_id)
	player.get_node("PrimaryWeapon").set("shooter_entity_id", entity_id)
	fixture_root.add_child(player)
	var director = CampaignDirectorScript.new()
	director.name = "Director"
	director.set("mission", mission)
	director.set("target_root_path", NodePath("../Targets"))
	director.set("horde_director_path", NodePath(""))
	director.set("persistence_enabled", false)
	fixture_root.add_child(director)
	return {"root":fixture_root,"targets":targets,"player":player,"director":director}

func _fail(message: String) -> bool:
	push_error(message)
	if _game.session_mode != _game.SessionMode.NONE: _game.stop_session()
	quit(1)
	return false
