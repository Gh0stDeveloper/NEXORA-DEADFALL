class_name DeadfallCityArena
extends Node3D

signal navigation_ready
const Layout = preload("res://src/maps/campaign/CityLayout.gd")
var _navigation_region: NavigationRegion3D
var city_layout: Dictionary
var navigation_is_ready := false

func _ready() -> void:
	city_layout = Layout.describe()
	Layout.build_collision(self, city_layout)
	_configure_markers()
	if preload("res://src/core/PresentationRuntime.gd").enabled():
		_build_environment()
		var art: Node3D = load("res://src/maps/campaign/CityPresentation.gd").new()
		art.name = "CityPresentation"
		add_child(art)
		art.call("build", city_layout)
		if not has_node("DayNightCycle"):
			var cycle := preload("res://src/maps/campaign/DayNightCycle.gd").new()
			cycle.name = "DayNightCycle"
			add_child(cycle)
	if not Game.is_network_client():
		call_deferred("_build_navigation")

func _configure_markers() -> void:
	var players := get_node_or_null("PlayerSpawnPoints")
	if players != null:
		for index in range(players.get_child_count()):
			(players.get_child(index) as Node3D).position = Vector3(-3.0 + float(index) * 2.0, 0.15, 83)
	var spawns := get_node_or_null("HordeSpawnPoints")
	if spawns != null:
		for child in spawns.get_children():
			child.free()
		for index in range(city_layout.spawns.size()):
			var marker := Marker3D.new()
			marker.name = "StreetSpawn_%02d" % index
			marker.position = city_layout.spawns[index]
			spawns.add_child(marker)
	var targets := {"StreetGate": Vector3(0, 0.1, 48), "HoldPoint": Vector3(0, 0.1, 18), "EvacPoint": Vector3(-80, 0.12, -80), "RadioYard": Vector3(28, 0.1, 44), "RadioConsole": Vector3(28, 0.12, 28), "ServiceTunnel": Vector3(0, 0.1, 91)}
	for key: String in targets:
		var marker := get_node_or_null("CampaignTargets/" + key) as Node3D
		if marker != null: marker.position = targets[key]

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.24, 0.46, 0.67)
	sky_material.sky_horizon_color = Color(0.70, 0.75, 0.75)
	sky_material.ground_bottom_color = Color(0.28, 0.27, 0.23)
	sky_material.ground_horizon_color = Color(0.70, 0.73, 0.71)
	sky_material.sun_angle_max = 4.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.78, 0.83, 0.86)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.64, 0.70, 0.71)
	environment.fog_density = 0.0015
	world.environment = environment
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.name = "MoonLight"
	moon.light_energy = 0.08
	add_child(moon)

func _build_navigation() -> void:
	if _navigation_region != null:
		return
	_navigation_region = NavigationRegion3D.new()
	_navigation_region.name = "NavigationRegion"
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	mesh.geometry_source_group_name = Layout.NAV_SOURCE_GROUP
	mesh.geometry_collision_mask = 1
	mesh.agent_radius = 0.5
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.25
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.filter_walkable_low_height_spans = true
	_navigation_region.navigation_mesh = mesh
	add_child(_navigation_region)
	_navigation_region.bake_finished.connect(_on_navigation_baked)
	_navigation_region.bake_navigation_mesh(true)

func _on_navigation_baked() -> void:
	# Wait for the asynchronous map publication, not just completion of Recast.
	for frame in range(120):
		await get_tree().physics_frame
		var map := get_world_3d().navigation_map
		var route := NavigationServer3D.map_get_path(map, Vector3(0, 0.1, 83), Vector3(0, 0.1, 48), true)
		if route.size() >= 2:
			navigation_is_ready = true
			navigation_ready.emit()
			print("DEADFALL_CITY_NAV_READY size=192 polygons=", _navigation_region.navigation_mesh.get_polygon_count())
			return
	push_error("DEADFALL city navigation did not synchronize")
