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
		"CharacterPreviewBridge",
		"VisualPolish",
	]:
		if lobby.get_node_or_null(node_path) == null:
			lobby.free()
			_fail("Lobby 2.0 runtime contract missing: %s" % node_path)
			return

	var viewport := lobby.get_node_or_null("SafeArea/OperatorStage/CharacterViewportContainer/CharacterViewport") as SubViewport
	if viewport == null or viewport.size.x < 640 or viewport.size.y < 720:
		lobby.free()
		_fail("Lobby character viewport is below the beta.4 presentation budget")
		return

	var preview_source := _read_text("res://src/lobby/LobbyCharacterPreviewBridge.gd")
	for token in ["LobbyCharacterTurntable", "AnimationDriver.play_semantic", "rotation.y", "ModelNormalizer.normalize_visual"]:
		if not preview_source.contains(token):
			lobby.free()
			_fail("Lobby animated preview contract missing: %s" % token)
			return

	var polish_source := _read_text("res://src/lobby/LobbyVisualPolish.gd")
	for token in ["OUTBREAK RESPONSE  //  ACTIVE", "TealFill", "COLOR_CYAN", "custom_minimum_size"]:
		if not polish_source.contains(token):
			lobby.free()
			_fail("Lobby 2.0 visual polish contract missing: %s" % token)
			return

	var tuner_source := _read_text("res://src/mobile/MobilePerformanceTuner.gd")
	for token in ["FPS_BY_TIER", "MESH_LOD_THRESHOLD_BY_TIER", "MSAA_BY_TIER", "scaling_3d_scale", "mesh_lod_threshold", "msaa_3d"]:
		if not tuner_source.contains(token):
			lobby.free()
			_fail("Android performance contract missing: %s" % token)
			return

	var settings_source := _read_text("res://src/autoload/Settings.gd")
	for token in ["\"render_scale\": 0.65", "\"render_scale\": 0.90", "QualityTier.ULTRA", "QualityTier.ULTRA_HD"]:
		if not settings_source.contains(token):
			lobby.free()
			_fail("Android quality profile contract missing: %s" % token)
			return

	var zombie_source := _read_text("res://src/zombies/base/ZombieModelPresenter.gd")
	for token in ["VISIBILITY_RANGE_BY_TIER", "visibility_range_end", "play_named", "_desired_semantic_state"]:
		if not zombie_source.contains(token):
			lobby.free()
			_fail("Zombie presentation/culling contract missing: %s" % token)
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
	print("NEXORA: DEADFALL beta.4 lobby/mobile presentation smoke passed")
	quit(0)

func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
