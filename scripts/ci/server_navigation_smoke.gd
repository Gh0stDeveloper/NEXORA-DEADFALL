extends SceneTree

var _failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.max_fps = 120
	var game := root.get_node("Game")
	game.call("start_dedicated_server_session")
	var arena := (load("res://src/maps/campaign/OutbreakDistrict.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(arena)
	var player := (load("res://src/player/Player.tscn") as PackedScene).instantiate() as Node3D
	player.set("control_mode", 2)
	arena.get_node("NetworkPlayers").add_child(player)
	player.position = Vector3(-14, 0.05, 4)
	var zombie := (load("res://src/zombies/base/Zombie.tscn") as PackedScene).instantiate() as Node3D
	arena.get_node("HordeZombies").add_child(zombie)
	zombie.position = Vector3(-14, 0.05, -25)
	var other := (load("res://src/zombies/base/Zombie.tscn") as PackedScene).instantiate() as Node3D
	arena.add_child(other)
	other.set_physics_process(false)
	other.position = Vector3(28, 0.05, 24)
	var original_height := float(other.get_node("CollisionShape3D").shape.height)
	zombie.call("_on_crawler_required", null)
	_check(is_equal_approx(other.get_node("CollisionShape3D").shape.height, original_height), "Crawling must not resize another zombie")
	zombie.free()
	zombie = (load("res://src/zombies/base/Zombie.tscn") as PackedScene).instantiate() as Node3D
	arena.get_node("HordeZombies").add_child(zombie)
	zombie.position = Vector3(-14, 0.05, -25)
	var pickup := (load("res://src/horde/AmmoPickup.tscn") as PackedScene).instantiate()
	pickup.position = Vector3(25, 0.05, 25)
	arena.add_child(pickup)
	_check_no_presentation(arena)
	_check(player.get_node("CameraRig").call("get_aim_camera") is Node3D, "Server must retain authoritative aim transform")
	_check(not player.get_node("CameraRig").call("get_aim_camera") is Camera3D, "Server aim must not allocate a camera")
	for frame in range(600):
		await physics_frame
		if arena.has_node("NavigationRegion") and arena.get_node("NavigationRegion").navigation_mesh.get_polygon_count() > 0 and NavigationServer3D.map_get_iteration_id(arena.get_world_3d().navigation_map) > 1:
			break
	print("NAV_DIAGNOSTIC regions=", NavigationServer3D.map_get_regions(arena.get_world_3d().navigation_map).size(), " polys=", arena.get_node("NavigationRegion").navigation_mesh.get_polygon_count(), " sources=", get_nodes_in_group("deadfall_nav_source").size(), " authority=", zombie.call("has_simulation_authority"), " physics=", zombie.is_physics_processing())
	# Mesh publication and the NavigationServer map synchronization are separate.
	await physics_frame
	await physics_frame
	var map := arena.get_world_3d().navigation_map
	_check(NavigationServer3D.map_get_iteration_id(map) > 0, "Dedicated navigation did not become ready")
	var route := PackedVector3Array()
	for attempt in range(60):
		route = NavigationServer3D.map_get_path(map, zombie.global_position, player.global_position, true)
		if route.size() >= 3: break
		await physics_frame
	_check(route.size() >= 3, "Route must go around the clinic, not through a solid building")
	_check(zombie.call("_find_visible_target") == null, "Regression fixture must begin out of sight/range")
	zombie.call("enable_horde_pursuit")
	var start := zombie.global_position
	var closest := 1000.0
	for frame in range(1500):
		await physics_frame
		closest = minf(closest, zombie.global_position.distance_to(player.global_position))
		if closest < 1.8:
			break
	_check(start.distance_to(zombie.global_position) > 20.0, "Horde zombie remained near its distant spawn")
	_check(closest < 1.8, "Horde zombie failed to navigate around the obstacle to its target: distance=%s position=%s" % [closest, zombie.global_position])
	print("DEADFALL_NAVIGATION_RESULT distance=", closest, " path_points=", route.size())
	arena.free()
	game.call("stop_session")
	if not _failed: print("NEXORA: DEADFALL dedicated presentation/navigation smoke passed")
	quit(1 if _failed else 0)

func _check_no_presentation(node: Node) -> void:
	_check(not (node is VisualInstance3D or node is Camera3D or node is WorldEnvironment or node is AudioStreamPlayer or node is AudioStreamPlayer3D), "Dedicated allocated a presentation node: %s (%s)" % [node.name, node.get_class()])
	for child in node.get_children():
		_check_no_presentation(child)

func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		push_error(message)
