extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(15).timeout.connect(func() -> void: quit(1))
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
	var router := hud.get("_touch_router") as Node
	assert(router != null)
	var fire := hud.get_node("SafeArea/GameplayControls/FireButton") as Control
	var down := InputEventScreenTouch.new()
	down.index = 5
	down.position = fire.get_global_rect().get_center()
	down.pressed = true
	router._input(down)
	assert(input.is_action_pressed(&"fire"))
	input.set_mobile_move(Vector2.LEFT)
	var drag := InputEventScreenDrag.new()
	drag.index = 5
	drag.position = Vector2(0, 0)
	drag.screen_relative = Vector2(80, -40)
	drag.relative = Vector2(20, -10)
	router._input(drag)
	assert(input.is_action_pressed(&"fire"), "Leaving fire bounds must keep firing")
	assert(input.consume_look_delta() == Vector2(80, -40), "Fire drag must use unscaled camera pixels")
	assert(input.get_move_vector() == Vector2.LEFT, "Fire finger stole joystick movement")
	drag.index = 9
	router._input(drag)
	assert(input.consume_look_delta() == Vector2.ZERO, "Unowned finger moved camera")
	var primary := player.get_node("PrimaryWeapon")
	var before: int = primary.get_ammo_in_mag()
	await create_timer(0.25).timeout
	assert(primary.get_ammo_in_mag() < before, "Held drag did not continue shooting")
	router.set_enabled(false)
	assert(not input.is_action_pressed(&"fire"), "Cancelled touch left weapon firing")
	input.clear_mobile_actions()
	var loadout := player.get_node("WeaponLoadout")
	var secondary := player.get_node("SecondaryWeapon")
	primary.apply_authoritative_state({"ammo": 0, "reserve": 5, "reloading": false})
	loadout.maintain_ammunition()
	assert(primary.is_reloading() and loadout.active_slot == 0)
	primary._state.reload_end_usec = Time.get_ticks_usec() - 1
	primary._process(0)
	assert(primary.get_ammo_in_mag() == 5 and primary.get_reserve_ammo() == 0)
	primary.apply_authoritative_state({"ammo": 0, "reserve": 0, "reloading": false})
	secondary.apply_authoritative_state({"ammo": 3, "reserve": 0, "reloading": false})
	loadout.maintain_ammunition()
	assert(loadout.active_slot == 1, "Empty rifle must switch to loaded pistol")
	input.set_mobile_action(&"fire", true)
	await create_timer(0.45).timeout
	assert(secondary.get_ammo_in_mag() < 2, "Holding the touch trigger stopped after switching to pistol")
	input.set_mobile_action(&"fire", false)
	loadout.force_active_slot(1)
	secondary.apply_authoritative_state({"ammo": 0, "reserve": 2, "reloading": false})
	loadout.maintain_ammunition()
	assert(secondary.is_reloading())
	secondary.apply_authoritative_state({"ammo": 0, "reserve": 0, "reloading": false})
	loadout.maintain_ammunition()
	assert(loadout.active_slot == 2, "Both guns exhausted must select melee")
	game.start_network_client_session()
	loadout.force_active_slot(0)
	primary.apply_authoritative_state({"ammo": 0, "reserve": 5, "reloading": false})
	loadout.maintain_ammunition()
	assert(not primary.is_reloading() and loadout.active_slot == 0, "Replica performed authoritative reload")
	arena.free()
	game.stop_session()
	await process_frame
	print("NEXORA: DEADFALL fire drag and automatic ammunition smoke passed")
	quit(0)
