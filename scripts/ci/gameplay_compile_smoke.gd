extends SceneTree

const REQUIRED_SCRIPTS := [
	"res://src/main/Main.gd",
	"res://src/network/MtuSafeClosedBetaNetworkSession.gd",
	"res://src/weapons/rifles/HitscanRifle.gd",
	"res://src/weapons/WeaponLoadout.gd",
	"res://src/weapons/melee/MacheteWeapon.gd",
	"res://src/horde/AmmoPickup.gd",
	"res://src/horde/AmmoDropDirector.gd",
	"res://src/mobile/TouchActionButton.gd",
	"res://src/mobile/MobileHUD.gd",
	"res://src/lobby/LobbyVisualPolish.gd",
	"res://src/assets/ModelNormalizer.gd",
	"res://src/ui/MatchLoadingOverlay.gd",
	"res://src/maps/campaign/DayNightCycle.gd",
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

	if DisplayServer.get_name() == "headless":
		var day_night_script := load("res://src/maps/campaign/DayNightCycle.gd") as Script
		var day_night := day_night_script.new() as Node
		root.add_child(day_night)
		await process_frame
		if day_night.is_processing():
			_fail("DayNightCycle must not process on a headless/dedicated server")
			return
		day_night.queue_free()
		await process_frame

	var child_output: Array = []
	var project_root: String = ProjectSettings.globalize_path("res://")
	var feature_script: String = ProjectSettings.globalize_path("res://scripts/ci/gameplay_features_smoke.gd")
	var child_exit: int = OS.execute(
		OS.get_executable_path(),
		PackedStringArray(["--headless", "--path", project_root, "--script", feature_script]),
		child_output,
		true,
		false
	)
	var child_text := ""
	for value in child_output:
		child_text += String(value)
	if child_exit != 0:
		_fail("Gameplay feature regression smoke failed (exit=%d): %s" % [child_exit, child_text])
		return
	for fatal_marker in ["SCRIPT ERROR:", "ERROR: Failed to load script", "Compile Error:", "Parse Error:"]:
		if child_text.contains(fatal_marker):
			_fail("Gameplay feature regression smoke emitted a script/load error: %s" % child_text)
			return
	if not child_text.contains("NEXORA: DEADFALL gameplay features smoke passed"):
		_fail("Gameplay feature regression smoke did not emit its success marker: %s" % child_text)
		return

	print("NEXORA: DEADFALL strict gameplay compile smoke passed")
	print("NEXORA: DEADFALL gameplay features smoke passed")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
