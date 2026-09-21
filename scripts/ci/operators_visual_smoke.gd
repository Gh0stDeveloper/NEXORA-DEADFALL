extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	Engine.max_fps = 60
	var telemetry := root.get_node("NetworkTelemetry")
	telemetry.set_process(false)
	telemetry.get_node("NetworkPingOverlay").hide()
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.045, 0.058, 0.066)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.80, 0.84, 0.89)
	environment.environment.ambient_light_energy = 0.65
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 155, 0)
	light.light_energy = 1.3
	world.add_child(light)
	var operators: Array[Node3D] = []
	for index in range(2):
		var actor: Node3D = load("res://src/assets/SkinnedOperatorRig.gd").new()
		actor.character_id = &"operator_01" if index == 0 else &"operator_02"
		actor.position.x = -0.65 if index == 0 else 0.65
		world.add_child(actor)
		operators.append(actor)
		if actor.get_meta("source", "") != "skinned_with_procedural_pose":
			push_error("Operator did not load its skinned body")
			quit(1)
			return
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	camera.fov = 43
	camera.position = Vector3(0, 1.3, -3.1)
	camera.look_at(Vector3(0, 0.95, 0))
	DirAccess.make_dir_recursive_absolute("res://build/city-smoke")
	for index in range(3):
		for actor in operators:
			actor.call("equip_visual", index)
			actor.call("animate_pose", 0.0, 0.0)
		for frame in range(5): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/city-smoke/operators_slot_%d.png" % index)
		for actor in operators:
			var weapon: Node3D = actor.get("_weapon")
			var bones: Dictionary = actor.get("_bones")
			for side in (["Left", "Right"] if index != 2 else ["Right"]):
				var hand: Transform3D = actor.call("_bone_transform", int(bones[side + "Hand"]))
				var grip: Node3D = weapon.get_node("Grip" + side)
				var error := (actor.global_transform * hand.origin).distance_to(grip.global_position)
				if error > 0.08:
					push_error("Operator grip is detached: %s %s %s" % [actor.character_id, side, error])
					quit(1)
					return
	camera.position = Vector3(-0.65, 1.62, -0.75)
	camera.look_at(Vector3(-0.65, 1.57, 0))
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/city-smoke/valeria_closeup.png")
	world.free()
	print("NEXORA: DEADFALL Valeria/Dante rendered grips smoke passed")
	quit(0)
