extends SceneTree

const TestRangeScene := preload("res://src/maps/test_range/TestRange.tscn")
const AmmoPickupScene := preload("res://src/horde/AmmoPickup.tscn")
const LoadingOverlayScript := preload("res://src/ui/MatchLoadingOverlay.gd")
const HordeDirectorScript := preload("res://src/horde/HordeDirector.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = root.get_node_or_null("Game")
	if game == null or not game.has_method("start_local_session"):
		_fail("Game autoload/local authority missing")
		return
	game.call("start_local_session")

	var arena: Node = TestRangeScene.instantiate()
	if arena == null:
		_fail("TestRange could not be instantiated")
		return
	root.add_child(arena)
	await process_frame
	await process_frame

	var player: Node = arena.get_node_or_null("Player")
	if player == null:
		_fail("Feature smoke missing Player")
		return
	var primary: Node = player.get_node_or_null("PrimaryWeapon")
	var secondary: Node = player.get_node_or_null("SecondaryWeapon")
	var machete: Node = player.get_node_or_null("MacheteWeapon")
	var loadout: Node = player.get_node_or_null("WeaponLoadout")
	if primary == null or secondary == null or machete == null or loadout == null:
		_fail("Rifle/pistol/machete/loadout components are incomplete")
		return

	var primary_data: Resource = primary.get("weapon_data") as Resource
	var secondary_data: Resource = secondary.get("weapon_data") as Resource
	if primary_data == null or StringName(primary_data.get("weapon_id")) != &"nxr_rifle_01":
		_fail("Primary rifle identity is invalid")
		return
	if secondary_data == null or StringName(secondary_data.get("weapon_id")) != &"nxr_pistol_01":
		_fail("Secondary pistol identity is invalid")
		return
	if int(primary.call("get_ammo_in_mag")) <= 0 or int(primary.call("get_reserve_ammo")) <= 0:
		_fail("Primary weapon did not initialize with magazine/reserve ammo")
		return

	# Empty magazines must never create a shot intent or consume hidden ammo.
	primary.call("apply_authoritative_state", {"ammo": 0, "reserve": 0, "reloading": false, "reload_remaining_usec": 0})
	if bool(primary.call("_try_fire", Time.get_ticks_usec())):
		_fail("Primary weapon fired with an empty magazine")
		return
	if int(primary.call("get_ammo_in_mag")) != 0:
		_fail("Empty-magazine dry fire mutated ammo")
		return

	# Authoritative ammo pickups must replenish reserve ammo through WeaponLoadout.
	primary.call("apply_authoritative_state", {"ammo": 30, "reserve": 100, "reloading": false, "reload_remaining_usec": 0})
	loadout.call("force_active_slot", 0)
	var reserve_before: int = int(primary.call("get_reserve_ammo"))
	var pickup: Area3D = AmmoPickupScene.instantiate() as Area3D
	if pickup == null:
		_fail("AmmoPickup could not be instantiated")
		return
	pickup.call("configure", 990001, 24, false)
	arena.add_child(pickup)
	await process_frame
	pickup.call("_on_body_entered", player)
	await process_frame
	var reserve_after: int = int(primary.call("get_reserve_ammo"))
	if reserve_after <= reserve_before:
		_fail("Authoritative ammo pickup did not replenish reserve ammo")
		return

	loadout.call("force_active_slot", 1)
	if int(loadout.get("active_slot")) != 1 or StringName(loadout.call("get_active_weapon_id")) != &"nxr_pistol_01":
		_fail("Pistol slot cannot become active")
		return
	loadout.call("force_active_slot", 2)
	if int(loadout.get("active_slot")) != 2 or StringName(loadout.call("get_active_weapon_id")) != &"machete":
		_fail("Machete slot cannot become active")
		return
	var machete_state: Dictionary = Dictionary(machete.call("get_authoritative_state"))
	if not bool(machete_state.get("infinite", false)) or String(machete_state.get("weapon_id", "")) != "machete":
		_fail("Machete infinite-ammo contract is missing")
		return

	var mobile_hud: Node = arena.get_node_or_null("MobileHUD")
	if mobile_hud == null:
		_fail("Mobile HUD missing from feature smoke")
		return
	var player_status: Node = mobile_hud.get_node_or_null("SafeArea/PlayerStatus")
	var selector: Node = mobile_hud.get_node_or_null("SafeArea/GameplayControls/WeaponSelector")
	var sprint_button: Node = mobile_hud.get_node_or_null("SafeArea/GameplayControls/SprintButton")
	if player_status == null or selector == null:
		_fail("HP/ammo status or weapon selector is missing from MobileHUD")
		return
	if sprint_button == null or not bool(sprint_button.get("toggle_action")):
		_fail("Sprint mobile control is not configured as a toggle")
		return
	sprint_button.call("set_latched", true)
	if not bool(sprint_button.call("is_latched")):
		_fail("Sprint toggle did not remain latched after activation")
		return
	sprint_button.call("set_latched", false)

	# Game Over must cover mobile controls and restart the authoritative Horde run.
	var director: Node = arena.get_node_or_null("HordeDirector")
	var horde_hud: Node = arena.get_node_or_null("HordeHUD")
	if director == null or horde_hud == null:
		_fail("Horde director/HUD missing for restart regression")
		return
	director.set("state", HordeDirectorScript.State.GAME_OVER)
	horde_hud.call("_refresh")
	await process_frame
	if bool(mobile_hud.call("are_gameplay_controls_enabled")):
		_fail("Mobile gameplay controls remain enabled behind Game Over")
		return
	var game_over_panel: Control = horde_hud.get_node_or_null("SafeArea/GameOverCenter/GameOverPanel") as Control
	if game_over_panel == null or not game_over_panel.visible or int(horde_hud.get("layer")) <= int(mobile_hud.get("layer")):
		_fail("Game Over modal is not visible above MobileHUD")
		return
	horde_hud.call("_on_restart_pressed")
	await process_frame
	await process_frame
	if int(director.get("state")) == HordeDirectorScript.State.GAME_OVER:
		_fail("Game Over restart button did not restart the Horde run")
		return
	if not bool(mobile_hud.call("are_gameplay_controls_enabled")):
		_fail("Mobile controls were not restored after Horde restart")
		return

	# Match loading must expose a real error/return path instead of infinite loading.
	var loading: CanvasLayer = LoadingOverlayScript.new() as CanvasLayer
	root.add_child(loading)
	await process_frame
	loading.call("begin", "203.0.113.10:24600")
	loading.call("set_stage", "Validando ticket privado…", 0.58)
	loading.call("show_error", "connection_failed")
	var return_button: Button = loading.get("_return_button") as Button
	if int(loading.layer) != 90 or return_button == null or not return_button.visible:
		_fail("Match loading overlay has no visible recovery path after connection failure")
		return
	loading.queue_free()

	arena.queue_free()
	if game.has_method("stop_session"):
		game.call("stop_session")
	await process_frame
	print("NEXORA: DEADFALL gameplay features smoke passed")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
