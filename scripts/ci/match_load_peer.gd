extends SceneTree

var _server := false

func _initialize() -> void:
	_server = "--server" in OS.get_cmdline_user_args()
	call_deferred("_run")

func _run() -> void:
	Engine.max_fps = 60
	change_scene_to_file("res://src/main/Main.tscn")
	var session: Node
	for frame in range(1200):
		await process_frame
		session = root.get_node_or_null("Main/CampaignArena/NetworkSession")
		if session != null and int(session.call("get_status_snapshot").get("connected_players", 0)) == 4:
			break
	if session == null or int(session.call("get_status_snapshot").get("connected_players", 0)) != 4:
		_fail("Four peers did not join")
		return
	var arena := session.get_parent()
	if _server:
		arena.get_node("AmmoDropDirector")._spawn_ammo(Vector3(2, 0.1, 20), 30, "ammo")
		arena.get_node("AmmoDropDirector")._spawn_ammo(Vector3(-2, 0.1, 20), 25, "health")
		var horde := arena.get_node("HordeDirector")
		horde.set_process(false)
		for index in range(int(horde.call("get_population_budget"))):
			if horde.call("debug_spawn_archetype", &"walker") == null: break
		var visual_nodes: Array[String] = []
		_find_visuals(root, visual_nodes)
		if not visual_nodes.is_empty():
			_fail("Dedicated contains presentation nodes: %s" % [visual_nodes])
			return
		print("DEADFALL_LOAD_SERVER_READY zombies=", horde.call("get_active_zombie_count"), " presentation_nodes=0")
		await create_timer(25).timeout
		quit(0)
		return
	var pings: Array[int] = []
	var seen_positions: Dictionary = {}
	var moving_zombies: Dictionary = {}
	var max_zombies := 0
	var seen_pickup_kinds: Dictionary = {}
	print("DEADFALL_LOAD_SAMPLING_STARTED")
	for second in range(20):
		var player := arena.get_node_or_null("NetworkPlayers/Player_%d" % int(session.get("local_entity_id"))) as Node3D
		if player != null:
			var input := player.get_node("PlayerInput")
			input.call("set_mobile_action", &"sprint", true)
			input.call("set_mobile_move", Vector2(clampf(-player.position.x * 0.4, -0.8, 0.8), -1).normalized())
		await create_timer(1.0).timeout
		var status: Dictionary = session.call("get_status_snapshot")
		var ping := int(status.get("raw_ping_ms", 999))
		if ping < 999: pings.append(ping)
		if second % 5 == 0:
			print("DEADFALL_LOAD_SAMPLE second=", second, " ping=", ping)
		var zombies := arena.get_node("HordeZombies")
		for pickup in arena.get_node("WorldPickups").get_children():
			seen_pickup_kinds[String(pickup.pickup_kind)] = true
		max_zombies = maxi(max_zombies, zombies.get_child_count())
		for zombie: Node3D in zombies.get_children():
			var id := int(zombie.get("entity_id"))
			if seen_positions.has(id) and zombie.global_position.distance_to(seen_positions[id]) > 0.5:
				moving_zombies[id] = true
			else:
				seen_positions[id] = zombie.global_position
	if pings.size() < 12 or moving_zombies.size() < 3:
		_fail("Missing ping/moving replicated zombies: samples=%d moving=%d" % [pings.size(), moving_zombies.size()])
		return
	pings.sort()
	if not seen_pickup_kinds.has("ammo") or not seen_pickup_kinds.has("health"):
		_fail("ENet clients did not receive both medical and ammunition drops")
		return
	var p95 := pings[int(floor(float(pings.size() - 1) * 0.95))]
	if p95 > 300:
		_fail("Loopback RTT regressed above 300 ms under four-peer load")
		return
	print("DEADFALL_LOAD_CLIENT_RESULT ", JSON.stringify({"samples": pings.size(), "rtt_p50_ms": pings[int(pings.size() / 2)], "rtt_p95_ms": p95, "rtt_max_ms": pings.back(), "moving_zombies": moving_zombies.size(), "max_replicated_zombies": max_zombies}))
	quit(0)

func _find_visuals(node: Node, output: Array[String]) -> void:
	if node is VisualInstance3D or node is Camera3D or node is WorldEnvironment or node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		output.append(str(node.get_path()))
	for child in node.get_children(): _find_visuals(child, output)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
