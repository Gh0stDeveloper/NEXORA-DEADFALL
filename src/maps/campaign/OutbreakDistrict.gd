class_name DeadfallOutbreakDistrict
extends Node3D

const PlayerScene = preload("res://src/player/Player.tscn")
const PlayerControllerScript = preload("res://src/player/PlayerController.gd")
const MobileHUDScene = preload("res://src/mobile/MobileHUD.tscn")
const HordeHUDScene = preload("res://src/horde/HordeHUD.tscn")
const Mission1 = preload("res://src/campaign/data/mission_01_first_signal.tres")
const Mission2 = preload("res://src/campaign/data/mission_02_last_broadcast.tres")
const NAV_SOURCE_GROUP: StringName = &"deadfall_nav_source"

@export var mission_id: StringName = &"mission_01_first_signal"

@onready var players_root: Node3D = $NetworkPlayers
@onready var player_spawns: Node3D = $PlayerSpawnPoints
@onready var horde: Node = $HordeDirector
@onready var campaign: Node = $CampaignDirector

func _ready() -> void:
	_build_environment()
	_build_geometry()
	var selected := Mission2 if mission_id == &"mission_02_last_broadcast" else Mission1
	campaign.set("mission", selected)
	if Game.is_local_session():
		_spawn_local_player()
	campaign.call_deferred("start_mission", selected, true)
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

func _build_local_huds(player: Node3D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if get_node_or_null("MobileHUD") == null:
		var mobile := MobileHUDScene.instantiate()
		mobile.name = "MobileHUD"
		add_child(mobile)
		if mobile.has_method("bind_player"):
			mobile.call("bind_player", player)
	if get_node_or_null("HordeHUD") == null:
		var horde_hud := HordeHUDScene.instantiate()
		horde_hud.name = "HordeHUD"
		horde_hud.set("director_path", NodePath("../HordeDirector"))
		add_child(horde_hud)

func _build_environment() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var environment_node := WorldEnvironment.new()
	environment_node.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.045, 0.055)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.38, 0.42, 0.48)
	environment.ambient_light_energy = 0.58
	environment_node.environment = environment
	add_child(environment_node)
	var moon := DirectionalLight3D.new()
	moon.name = "DistrictLight"
	moon.rotation_degrees = Vector3(-48, -32, 0)
	moon.light_energy = 1.15
	moon.shadow_enabled = true
	add_child(moon)

func _build_geometry() -> void:
	_create_box("DistrictFloor", Vector3(0, -0.25, 0), Vector3(72, 0.5, 72), Color(0.10, 0.11, 0.12))
	_create_box("NorthBlock", Vector3(0, 4.0, -31), Vector3(54, 8, 5), Color(0.12, 0.14, 0.16))
	_create_box("WestBlock", Vector3(-31, 3.0, -2), Vector3(5, 6, 46), Color(0.13, 0.14, 0.16))
	_create_box("EastBlock", Vector3(31, 3.5, 2), Vector3(5, 7, 46), Color(0.13, 0.14, 0.16))
	_create_box("Clinic", Vector3(-14, 2.5, -12), Vector3(10, 5, 8), Color(0.16, 0.18, 0.19))
	_create_box("Market", Vector3(14, 2.0, -8), Vector3(11, 4, 9), Color(0.17, 0.16, 0.15))
	_create_box("QuarantineBarrierLeft", Vector3(-6, 1.25, 2), Vector3(9, 2.5, 0.8), Color(0.24, 0.24, 0.20))
	_create_box("QuarantineBarrierRight", Vector3(6, 1.25, 2), Vector3(9, 2.5, 0.8), Color(0.24, 0.24, 0.20))
	_create_box("RadioBase", Vector3(14, 1.0, 14), Vector3(8, 2, 8), Color(0.20, 0.22, 0.23))
	_create_box("TunnelWallLeft", Vector3(-8, 1.5, 29), Vector3(12, 3, 2), Color(0.16, 0.17, 0.18))
	_create_box("TunnelWallRight", Vector3(8, 1.5, 29), Vector3(12, 3, 2), Color(0.16, 0.17, 0.18))
	for position in [Vector3(-9, 0.75, 9), Vector3(8, 0.75, 7), Vector3(-16, 0.75, 18), Vector3(20, 0.75, 22)]:
		_create_box("StreetCover_%d" % int(abs(position.x * 10.0 + position.z)), position, Vector3(2.4, 1.5, 1.2), Color(0.20, 0.21, 0.22))

func _create_box(node_name: String, position_value: Vector3, size_value: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.collision_layer = 1
	body.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	shape_node.shape = shape
	body.add_child(shape_node)
	if DisplayServer.get_name() != "headless":
		var mesh_node := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size_value
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.9
		mesh.material = material
		mesh_node.mesh = mesh
		body.add_child(mesh_node)
	add_child(body)
	body.add_to_group(NAV_SOURCE_GROUP)
