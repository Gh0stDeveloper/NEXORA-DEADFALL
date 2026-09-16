extends SceneTree

const REQUIRED_SCRIPTS := [
	"res://src/main/Boot.gd",
	"res://src/audio/AudioDirector.gd",
	"res://src/audio/ActorAudio.gd",
	"res://src/assets/SkinnedOperatorRig.gd",
	"res://src/assets/SkinnedZombieRig.gd",
	"res://src/lobby/TacticalStage.gd",
	"res://src/main/Main.gd",
	"res://src/network/MtuSafeClosedBetaNetworkSession.gd",
	"res://src/network/LifecycleMtuSafeNetworkSession.gd",
	"res://src/server/MatchAdmission.gd",
	"res://src/server/MatchInstanceGuard.gd",
	"res://src/server/MatchOrchestrator.gd",
	"res://src/weapons/rifles/HitscanRifle.gd",
	"res://src/weapons/WeaponLoadout.gd",
	"res://src/weapons/melee/MacheteWeapon.gd",
	"res://src/horde/AmmoPickup.gd",
	"res://src/horde/AmmoDropDirector.gd",
	"res://src/mobile/TouchActionButton.gd",
	"res://src/mobile/TouchInputRouter.gd",
	"res://src/mobile/MobileHUD.gd",
	"res://src/mobile/MobilePerformanceTuner.gd",
	"res://src/lobby/LobbyVisualPolish.gd",
	"res://src/lobby/LobbyController.gd",
	"res://src/lobby/LobbyPartyAvatar.gd",
	"res://src/lobby/LobbyCharacterPreviewBridge.gd",
	"res://src/assets/ModelNormalizer.gd",
	"res://src/assets/ProceduralCharacterModel.gd",
	"res://src/assets/ProceduralWeaponModels.gd",
	"res://src/assets/ImportedAnimationDriver.gd",
	"res://src/player/PlayerModelPresenter.gd",
	"res://src/zombies/base/ZombieModelPresenter.gd",
	"res://src/ui/MatchLoadingOverlay.gd",
	"res://src/ui/MatchResultOverlay.gd",
	"res://src/maps/campaign/DayNightCycle.gd",
	"res://src/maps/campaign/ProceduralEnvironmentArt.gd",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for path in REQUIRED_SCRIPTS:
		var resource := load(path)
		if resource == null or not resource is Script:
			_fail("Gameplay compile gate could not load script: %s" % path)
			return
		var script := resource as Script
		if not script.can_instantiate():
			_fail("Gameplay compile gate found a non-instantiable script: %s" % path)
			return

	var player_scene := load("res://src/player/Player.tscn") as PackedScene
	if player_scene == null or not player_scene.can_instantiate():
		_fail("Player.tscn cannot be instantiated after weapon/loadout changes")
		return
	var campaign_scene := load("res://src/maps/campaign/OutbreakDistrict.tscn") as PackedScene
	if campaign_scene == null or not campaign_scene.can_instantiate():
		_fail("OutbreakDistrict.tscn cannot be instantiated after gameplay changes")
		return

	var animation_file := FileAccess.open("res://src/assets/ImportedAnimationDriver.gd", FileAccess.READ)
	var animation_text := animation_file.get_as_text() if animation_file != null else ""
	for contract in ["play_semantic", "play_named", "has_named_animation", "semantic_inventory", "capability_snapshot", "generic_fallback", "idle", "walk", "run", "attack", "death", "advance(0.0)"]:
		if not animation_text.contains(contract):
			_fail("Semantic imported animation contract missing: %s" % contract)
			return

	var catalog_file := FileAccess.open("res://src/assets/ExternalModelCatalog.gd", FileAccess.READ)
	var catalog_text := catalog_file.get_as_text() if catalog_file != null else ""
	for contract in ["generic_animation_fallback", "mixamo_com", "animation_semantics", "Zombie|ZombieIdle", "Zombie|ZombieWalk", "Zombie|ZombieRun", "Zombie|ZombieCrawl", "Zombie|ZombieBite"]:
		if not catalog_text.contains(contract):
			_fail("Verified external-model animation mapping contract missing: %s" % contract)
			return

	var player_presenter_file := FileAccess.open("res://src/player/PlayerModelPresenter.gd", FileAccess.READ)
	var player_presenter_text := player_presenter_file.get_as_text() if player_presenter_file != null else ""
	if not player_presenter_text.contains("_desired_semantic_state") or not player_presenter_text.contains("last_sequence") or not player_presenter_text.contains("dedicated_server") or not player_presenter_text.contains("USE_EXTERNAL_MODELS := false") or not player_presenter_text.contains("ProceduralCharacters.create_operator"):
		_fail("Player model semantic/headless presentation contract missing")
		return

	var zombie_presenter_file := FileAccess.open("res://src/zombies/base/ZombieModelPresenter.gd", FileAccess.READ)
	var zombie_presenter_text := zombie_presenter_file.get_as_text() if zombie_presenter_file != null else ""
	if not zombie_presenter_text.contains("_desired_semantic_state") or not zombie_presenter_text.contains("dedicated_server") or not zombie_presenter_text.contains("_animation_overrides") or not zombie_presenter_text.contains("play_named") or not zombie_presenter_text.contains("TARGET_VISUAL_HEIGHT := 1.64") or not zombie_presenter_text.contains("ProceduralCharacters.create_zombie"):
		_fail("Zombie model exact-semantic/headless presentation contract missing")
		return

	var rifle_file := FileAccess.open("res://src/weapons/rifles/HitscanRifle.gd", FileAccess.READ)
	var rifle_text := rifle_file.get_as_text() if rifle_file != null else ""
	var machete_file := FileAccess.open("res://src/weapons/melee/MacheteWeapon.gd", FileAccess.READ)
	var machete_text := machete_file.get_as_text() if machete_file != null else ""
	if not rifle_text.contains("last_sequence") or not machete_text.contains("last_sequence") or not rifle_text.contains("ProceduralWeapons.create_view_model") or not rifle_text.contains("shot_fired.connect") or not machete_text.contains("ProceduralWeapons.create_view_model"):
		_fail("Weapon action sequence/procedural view-model contract is incomplete")
		return

	var procedural_character_file := FileAccess.open("res://src/assets/ProceduralCharacterModel.gd", FileAccess.READ)
	var procedural_character_text := procedural_character_file.get_as_text() if procedural_character_file != null else ""
	for contract in ["create_operator", "ProceduralOperator", "create_zombie", "ProceduralZombie", "visual_height"]:
		if not procedural_character_text.contains(contract):
			_fail("Procedural character model contract missing: %s" % contract)
			return

	var procedural_weapon_file := FileAccess.open("res://src/assets/ProceduralWeaponModels.gd", FileAccess.READ)
	var procedural_weapon_text := procedural_weapon_file.get_as_text() if procedural_weapon_file != null else ""
	for contract in ["create_view_model", "ProceduralRifle", "ProceduralPistol", "ProceduralMachete", "weapon_id"]:
		if not procedural_weapon_text.contains(contract):
			_fail("Procedural weapon model contract missing: %s" % contract)
			return

	var party_avatar_file := FileAccess.open("res://src/lobby/LobbyPartyAvatar.gd", FileAccess.READ)
	var party_avatar_text := party_avatar_file.get_as_text() if party_avatar_file != null else ""
	for contract in ["SubViewport", "set_member", "set_empty", "AvatarTurntable", "ProceduralCharacters.create_operator"]:
		if not party_avatar_text.contains(contract):
			_fail("Party avatar presentation contract missing: %s" % contract)
			return


	var touch_router_file := FileAccess.open("res://src/mobile/TouchInputRouter.gd", FileAccess.READ)
	var touch_router_text := touch_router_file.get_as_text() if touch_router_file != null else ""
	for contract in ["register_action_button", "register_click_control", "register_passthrough_control", "router_touch_down", "router_touch_drag", "set_input_as_handled"]:
		if not touch_router_text.contains(contract):
			_fail("Explicit mobile touch router contract missing: %s" % contract)
			return

	var environment_art_file := FileAccess.open("res://src/maps/campaign/ProceduralEnvironmentArt.gd", FileAccess.READ)
	var environment_art_text := environment_art_file.get_as_text() if environment_art_file != null else ""
	for contract in ["ProceduralModel", "CornerPier", "WindowGlass", "Rubble", "StaticBody3D", "emission_enabled"]:
		if not environment_art_text.contains(contract):
			_fail("Procedural environment art contract missing: %s" % contract)
			return

	var performance_file := FileAccess.open("res://src/mobile/MobilePerformanceTuner.gd", FileAccess.READ)
	var performance_text := performance_file.get_as_text() if performance_file != null else ""
	for contract in ["scaling_3d_scale", "mesh_lod_threshold", "msaa_3d", "FPS_BY_TIER"]:
		if not performance_text.contains(contract):
			_fail("Mobile performance tuner contract missing: %s" % contract)
			return

	var performance_tuner := root.get_node_or_null("PerformanceTuner")
	if performance_tuner == null or not performance_tuner.has_method("get_status_snapshot"):
		_fail("Mobile performance tuner autoload is missing")
		return

	if DisplayServer.get_name() == "headless":
		var performance_status: Dictionary = performance_tuner.call("get_status_snapshot")
		if bool(performance_status.get("active", true)):
			_fail("Mobile performance tuner must remain dormant on headless/dedicated server")
			return
		var day_night_script := load("res://src/maps/campaign/DayNightCycle.gd") as Script
		var day_night := day_night_script.new() as Node
		root.add_child(day_night)
		await process_frame
		if day_night.is_processing():
			_fail("DayNightCycle must not process on a headless/dedicated server")
			return
		day_night.queue_free()
		await process_frame

	if not _run_child_smoke(
		"res://scripts/ci/login_loading_recovery_smoke.gd",
		"NEXORA: DEADFALL login/loading recovery smoke passed",
		"Login/loading recovery"
	):
		return
	if not _run_child_smoke(
		"res://scripts/ci/gameplay_features_smoke.gd",
		"NEXORA: DEADFALL gameplay features smoke passed",
		"Gameplay feature regression"
	):
		return
	if not _run_child_smoke(
		"res://scripts/ci/presentation_mobile_smoke.gd",
		"NEXORA: DEADFALL lobby/mobile presentation smoke passed",
		"Lobby/mobile presentation"
	):
		return
	if not _run_child_smoke(
		"res://scripts/ci/phase12_match_lifecycle_smoke.gd",
		"NEXORA: DEADFALL beta.5 match lifecycle smoke passed",
		"Beta.5 match lifecycle"
	):
		return

	if not _run_child_smoke("res://scripts/ci/presentation_assets_smoke.gd", "NEXORA: DEADFALL presentation assets smoke passed", "Presentation geometry/audio"):
		return
	print("NEXORA: DEADFALL presentation assets smoke passed")
	print("NEXORA: DEADFALL strict gameplay compile smoke passed")
	print("NEXORA: DEADFALL login/loading recovery smoke passed")
	print("NEXORA: DEADFALL gameplay features smoke passed")
	print("NEXORA: DEADFALL lobby/mobile presentation smoke passed")
	print("NEXORA: DEADFALL beta.5 match lifecycle smoke passed")
	quit(0)

func _run_child_smoke(script_path: String, success_marker: String, label: String) -> bool:
	var child_output: Array = []
	var project_root: String = ProjectSettings.globalize_path("res://")
	var child_script: String = ProjectSettings.globalize_path(script_path)
	var child_exit: int = OS.execute(
		OS.get_executable_path(),
		PackedStringArray(["--headless", "--path", project_root, "--script", child_script]),
		child_output,
		true,
		false
	)
	var child_text := ""
	for value in child_output:
		child_text += String(value)
	if child_exit != 0:
		_fail("%s smoke failed (exit=%d): %s" % [label, child_exit, child_text])
		return false
	for fatal_marker in ["SCRIPT ERROR:", "ERROR: Failed to load script", "Compile Error:", "Parse Error:"]:
		if child_text.contains(fatal_marker):
			_fail("%s smoke emitted a script/load error: %s" % [label, child_text])
			return false
	if not child_text.contains(success_marker):
		_fail("%s smoke did not emit its success marker: %s" % [label, child_text])
		return false
	return true

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
