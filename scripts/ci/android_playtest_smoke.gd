extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(25).timeout.connect(func() -> void: quit(1))
	var game := root.get_node("Game")
	game.start_local_session()
	var arena := load("res://src/maps/test_range/TestRange.tscn").instantiate() as Node3D
	root.add_child(arena)
	await process_frame
	var player := arena.get_node("Player")
	player.set_physics_process(false)
	var input := player.get_node("PlayerInput")
	var hud := arena.get_node("MobileHUD")
	hud.show()
	assert(InputMap.has_action("aim"))
	var sprint := hud.get_node("SafeArea/GameplayControls/SprintButton")
	sprint.router_touch_down(7)
	sprint.router_touch_up(7)
	assert(input.get_move_vector() == Vector2.UP, "Auto-run must move without joystick input")
	input.add_mobile_look(Vector2(20, 4))
	assert(input.get_move_vector() == Vector2.UP, "Looking must not cancel auto-run")
	input.set_mobile_move(Vector2.DOWN)
	assert(not input.is_action_pressed(&"sprint"), "Moving back must cancel auto-run")
	input.clear_mobile_actions()
	input.set_mobile_action(&"sprint", true)
	input.set_mobile_action(&"crouch", true)
	assert(input.get_move_vector() == Vector2.ZERO, "Crouching must stop auto-run")
	input.clear_mobile_actions()
	input.set_mobile_action(&"sprint", true)
	hud._open_hud_editor()
	assert(input.get_move_vector() == Vector2.ZERO, "HUD editor must stop latched movement")
	hud._on_hud_editor_closed()
	var loadout := player.get_node("WeaponLoadout")
	for slot in [1, 2, 0]:
		hud._weapon_buttons[slot].pressed.emit()
		assert(loadout.active_slot == slot, "Direct weapon slot did not switch")
	var primary := player.get_node("PrimaryWeapon")
	var secondary := player.get_node("SecondaryWeapon")
	primary.apply_authoritative_state({"ammo": 0, "reserve": 0})
	loadout.force_active_slot(1)
	secondary.add_reserve_ammo(10000)
	assert(loadout.add_ammo(30) == 30 and primary.get_reserve_ammo() == 30,
		"Full active pistol must not prevent replenishing the rifle")
	var health := player.get_node("Health")
	var pickup := load("res://src/horde/AmmoPickup.tscn").instantiate() as Area3D
	pickup.configure(910001, 25, false, "health")
	arena.add_child(pickup)
	pickup.global_position = player.global_position
	await physics_frame
	await physics_frame
	await create_timer(0.25).timeout
	assert(is_instance_valid(pickup), "Full-health player consumed a medical drop")
	health.restore_authoritative_state(65, 100, false)
	await create_timer(0.35).timeout
	assert(is_equal_approx(health.current_health, 90), "Overlapping medical drop failed to heal after damage")
	assert(not is_instance_valid(pickup), "Collected medical drop was not removed")
	assert(health.heal_authoritative(90) == 10 and health.current_health == 100, "Healing exceeded maximum HP")
	game.start_network_client_session()
	assert(health.heal_authoritative(10) == 0 and loadout.add_ammo(30) == 0, "Replica mutated trusted inventory")
	var transport: Node = load("res://src/network/MtuSafeClosedBetaNetworkSession.gd").new()
	var replica_root := Node3D.new()
	replica_root.name = "WorldPickups"
	arena.add_child(replica_root)
	transport._pickups_root = replica_root
	transport._sync_pickups({"pickups": [{"pickup_id": 910002, "kind": "health", "amount": 25, "position": player.position}]})
	var replica := arena.get_node("WorldPickups/AmmoPickup_910002")
	assert(replica.pickup_kind == "health" and replica.replica_only and not replica.monitoring)
	assert(not replica.has_node("Visual"), "Headless must not instantiate pickup presentation")
	transport._sync_pickups({"pickups": []})
	await process_frame
	assert(not is_instance_valid(replica), "Consumed pickup remained on client")
	transport.free()
	var telemetry := root.get_node("NetworkTelemetry")
	telemetry.set_match_ping(120, 120, "MEDIO")
	assert(telemetry.get_display_ping_ms() == 120 and telemetry.get_source() == "match")
	telemetry._last_match_ping_usec = Time.get_ticks_usec() - 6000000
	telemetry._apply_effective_ping()
	assert(telemetry.get_display_ping_ms() == 999, "Stale game RTT must show connection loss")
	telemetry.clear_match_ping()
	game.start_local_session()
	arena.free()

	var gate: CanvasLayer = load("res://src/ui/UpdateGate.gd").new()
	root.add_child(gate)
	var accepted: Array = []
	gate.allowed.connect(func() -> void: accepted.append(true))
	var build: Dictionary = load("res://src/release/BuildInfo.gd").snapshot()
	var future := build.duplicate()
	future["version_code"] = int(build["version_code"]) + 1
	future["app_version"] = "next-build"
	gate._on_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"ok": true, "service": "deadfall-control", "build": future}).to_utf8_buffer())
	assert(gate.state == "required" and accepted.is_empty(), "New client update did not block entry")
	gate._on_response(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
	assert(gate.state == "unavailable" and accepted.is_empty(), "Connection failure bypassed update gate")
	gate._on_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"ok": true, "service": "deadfall-control", "build": build}).to_utf8_buffer())
	assert(gate.state == "allowed" and accepted.size() == 1, "Compatible build did not unlock login")
	gate.free()
	game.stop_session()
	await process_frame
	print("NEXORA: DEADFALL Android playtest controls/pickups/update smoke passed")
	quit(0)
