extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("City visual smoke requires a display")
		quit(1)
		return
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	var game := root.get_node("Game")
	game.call("start_local_session")
	var city: Node3D = load("res://src/maps/campaign/CityArena.gd").new()
	root.add_child(city)
	var camera := Camera3D.new()
	camera.fov = 68
	camera.far = 350
	root.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute("res://build/city-smoke")
	for view in [
		["city_overview", Vector3(17, 24, 88), Vector3(-7, 0, 28)],
		["city_street", Vector3(0.6, 1.7, 81), Vector3(-1.0, 1.5, 40)],
		["city_interior", Vector3(-27, 1.7, -21), Vector3(-32, 1.3, -33)],
		["city_wreck", Vector3(1, 2.3, -15), Vector3(-4, 1.0, -22)],
	]:
		camera.position = view[1]
		camera.look_at(view[2])
		for frame in range(12): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/city-smoke/%s.png" % view[0])
		print("DEADFALL_CITY_VIEW ", view[0], " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " objects=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	city.free()
	camera.free()
	game.call("stop_session")
	print("NEXORA: DEADFALL city visual smoke passed")
	quit(0)
