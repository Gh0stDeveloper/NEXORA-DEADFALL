class_name DeadfallOutbreakDistrict
extends "res://src/maps/campaign/CityArena.gd"

const PlayerScene = preload("res://src/player/Player.tscn")
const PlayerControllerScript = preload("res://src/player/PlayerController.gd")
const MobileHUDScene = preload("res://src/mobile/MobileHUD.tscn")
const HordeHUDScene = preload("res://src/horde/HordeHUD.tscn")
const Mission1 = preload("res://src/campaign/data/mission_01_first_signal.tres")
const Mission2 = preload("res://src/campaign/data/mission_02_last_broadcast.tres")

@export var game_mode := "campaign"
@export var mission_id: StringName = &"mission_01_first_signal"

@onready var players_root: Node3D = $NetworkPlayers
@onready var player_spawns: Node3D = $PlayerSpawnPoints
@onready var horde: Node = $HordeDirector
@onready var campaign: Node = $CampaignDirector

func _ready() -> void:
	super._ready()
	var selected := Mission2 if mission_id == &"mission_02_last_broadcast" else Mission1
	campaign.set("mission", selected)
	if Game.is_local_session():
		_spawn_local_player()
	var mode := preload("res://src/modes/MatchModeDirector.gd").new()
	mode.name = "MatchModeDirector"
	mode.game_mode = game_mode
	add_child(mode)
	if game_mode == "campaign":
		campaign.call_deferred("start_mission", selected, true)
	else:
		campaign.set_process(false)
		get_node("CampaignNetworkBridge").set_physics_process(false)
		get_node("CampaignHUD").hide()
	if preload("res://src/modes/ModeCatalog.gd").is_pvp(game_mode):
		horde.enabled = false
	print("DEADFALL_CAMPAIGN_ARENA_READY mission=%s" % String(selected.get("mission_id")))

func _spawn_local_player() -> void:
	if players_root.get_child_count() > 0:
		return
	var player := PlayerScene.instantiate() as Node3D
	if player == null:
		return
	player.name = "Player_1"
	player.set("player_entity_id", 1)
	player.set("control_mode", PlayerControllerScript.ControlMode.OFFLINE_LOCAL)
	player.get_node("Health").set("entity_id", 1)
	player.get_node("PrimaryWeapon").set("shooter_entity_id", 1)
	players_root.add_child(player)
	if player_spawns.get_child_count() > 0:
		player.global_transform = (player_spawns.get_child(0) as Node3D).global_transform
	if horde.has_method("register_player"):
		horde.call("register_player", player)
	if horde.has_method("start_run"):
		horde.call("start_run")
	_build_local_huds(player)

func _build_local_huds(_player: Node3D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if get_node_or_null("MobileHUD") == null:
		var mobile := MobileHUDScene.instantiate()
		mobile.name = "MobileHUD"
		mobile.set("player_path", NodePath("../NetworkPlayers/Player_1"))
		add_child(mobile)
	if get_node_or_null("HordeHUD") == null:
		var horde_hud := HordeHUDScene.instantiate()
		horde_hud.name = "HordeHUD"
		horde_hud.set("director_path", NodePath("../HordeDirector"))
		add_child(horde_hud)
