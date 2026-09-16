extends SceneTree

const LOBBY_SCENE_PATH := "res://src/lobby/Lobby.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var lobby_scene := load(LOBBY_SCENE_PATH) as PackedScene
	if lobby_scene == null or not lobby_scene.can_instantiate():
		_fail("Lobby 2.0 scene could not load/instantiate")
		return
	var lobby := lobby_scene.instantiate()
	if lobby == null:
		_fail("Lobby 2.0 instance could not be created")
		return
	root.add_child(lobby)
	await process_frame
	await process_frame

	for node_path in [
		"SafeArea/OperatorStage",
		"SafeArea/OperatorStage/CharacterViewportContainer/CharacterViewport",
		"SafeArea/PartyRail",
		"SafeArea/MatchControls",
	]:
		if lobby.get_node_or_null(node_path) == null:
			lobby.free()
			_fail("Lobby 2.0 runtime contract missing: %s" % node_path)
			return

	var viewport := lobby.get_node_or_null("SafeArea/OperatorStage/CharacterViewportContainer/CharacterViewport") as SubViewport
	if viewport == null or viewport.size.x < 640 or viewport.size.y < 720:
		lobby.free()
		_fail("Lobby character viewport is below the presentation budget")
		return

	if not viewport.own_world_3d:
		_fail("Lobby stage must isolate its 3D world")
		return
	var stage := lobby.get_node("SafeArea/OperatorStage")
	var members := [{"guest_id": "preview_a", "selected_character": "operator_01"}, {"guest_id": "preview_b", "selected_character": "operator_02"}]
	stage.call("set_members", members, 2)
	var models: Array = stage.get("_models")
	if models.size() != 2:
		_fail("Duo must show both members together")
		return
	var first_id: int = models[0].get_instance_id()
	members[0]["ping_ms"] = 82
	stage.call("set_members", members, 2)
	if stage.get("_models")[0].get_instance_id() != first_id:
		_fail("Presence refresh must reuse existing geometry")
		return
	stage.call("set_members", members, 4)
	if stage.get("_models").size() != 4:
		_fail("Squad must display four slots")
		return
	stage.hide()
	if viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED:
		_fail("Hidden stages must stop rendering")
		return
	stage.show()
	lobby.call("_open_settings")
	lobby.call("_close_character_panel")
	lobby.call("_open_armory")
	lobby.call("_close_character_panel")
	lobby.call("_open_character_panel")
	lobby.call("_close_character_panel")
	var tuner_source := _read_text("res://src/mobile/MobilePerformanceTuner.gd")
	for token in ["FPS_BY_TIER", "MESH_LOD_THRESHOLD_BY_TIER", "MSAA_BY_TIER", "scaling_3d_scale", "mesh_lod_threshold", "msaa_3d"]:
		if not tuner_source.contains(token):
			lobby.free()
			_fail("Android performance contract missing: %s" % token)
			return

	var hud_source := _read_text("res://src/mobile/MobileHUD.gd")
	for token in ["CrosshairScript", "HUDLayoutEditorScript", "player_status", "move_hud_element", "EDITAR HUD Y GUARDAR"]:
		if not hud_source.contains(token):
			lobby.free()
			_fail("Mobile HUD customization/aim contract missing: %s" % token)
			return

	var settings_source := _read_text("res://src/autoload/Settings.gd")
	for token in ["\"render_scale\": 0.65", "\"render_scale\": 0.90", "QualityTier.ULTRA", "QualityTier.ULTRA_HD"]:
		if not settings_source.contains(token):
			lobby.free()
			_fail("Android quality profile contract missing: %s" % token)
			return

	var party_avatar_source := _read_text("res://src/lobby/LobbyPartyAvatar.gd")
	for token in ["SubViewport", "set_member", "set_empty", "AvatarTurntable", "ProceduralCharacters.create_operator"]:
		if not party_avatar_source.contains(token):
			lobby.free()
			_fail("Party avatar procedural presentation contract missing: %s" % token)
			return

	var lobby_controller_source := _read_text("res://src/lobby/LobbyController.gd")
	for token in ["PartyAvatarScript", "_party_avatars", "update_party_members", "INICIAR %s"]:
		if not lobby_controller_source.contains(token):
			lobby.free()
			_fail("Party lobby formation contract missing: %s" % token)
			return

	var zombie_source := _read_text("res://src/zombies/base/ZombieModelPresenter.gd")
	for token in ["VISIBILITY_RANGE_BY_TIER", "visibility_range_end", "play_named", "_desired_semantic_state", "TARGET_VISUAL_HEIGHT := 1.64", "ProceduralCharacters.create_zombie"]:
		if not zombie_source.contains(token):
			lobby.free()
			_fail("Zombie presentation/culling/procedural contract missing: %s" % token)
			return


	var catalog_source := _read_text("res://src/assets/ExternalModelCatalog.gd")
	for token in ["Zombie|ZombieIdle", "Zombie|ZombieWalk", "Zombie|ZombieRun", "Zombie|ZombieCrawl", "Zombie|ZombieBite"]:
		if not catalog_source.contains(token):
			lobby.free()
			_fail("Pinned Quaternius animation mapping missing: %s" % token)
			return

	var tuner := root.get_node_or_null("PerformanceTuner")
	if tuner == null or not tuner.has_method("get_status_snapshot"):
		lobby.free()
		_fail("PerformanceTuner autoload missing")
		return
	if DisplayServer.get_name() == "headless":
		var status: Dictionary = tuner.call("get_status_snapshot")
		if bool(status.get("active", true)):
			lobby.free()
			_fail("PerformanceTuner must remain dormant in headless validation")
			return

	lobby.free()
	await process_frame
	print("NEXORA: DEADFALL lobby/mobile presentation smoke passed")
	quit(0)

func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
