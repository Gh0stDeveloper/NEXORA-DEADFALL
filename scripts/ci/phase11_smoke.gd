extends SceneTree

const REQUIRED_FILES := [
	"res://src/identity/GuestIdentity.gd",
	"res://src/server/GuestAccountStore.gd",
	"res://src/lobby/CharacterCatalog.gd",
	"res://src/lobby/LobbyController.gd",
	"res://src/lobby/Lobby.tscn",
	"res://src/player/FlashlightController.gd",
	"res://src/mobile/TouchActionButton.gd",
]

func _initialize() -> void:
	for path in REQUIRED_FILES:
		if not FileAccess.file_exists(path):
			_fail("Phase 11 missing required file: %s" % path)
			return

	if root.get_node_or_null("Settings") == null:
		_fail("Phase 11 Settings autoload missing")
		return
	if root.get_node_or_null("GuestIdentity") == null:
		_fail("Phase 11 GuestIdentity autoload missing")
		return
	if Settings.CAMERA_SENSITIVITY_MIN > 0.10 or Settings.CAMERA_SENSITIVITY_MAX < 1.00:
		_fail("Phase 11 camera sensitivity range is incomplete")
		return
	if Settings.camera_sensitivity < Settings.CAMERA_SENSITIVITY_MIN or Settings.camera_sensitivity > Settings.CAMERA_SENSITIVITY_MAX:
		_fail("Phase 11 camera sensitivity default/persisted value is invalid")
		return
	if Settings.get_look_radians_per_pixel() <= 0.0:
		_fail("Phase 11 camera sensitivity conversion is invalid")
		return

	var identity_script := load("res://src/identity/GuestIdentity.gd") as Script
	var account_store_script := load("res://src/server/GuestAccountStore.gd") as Script
	var lobby_script := load("res://src/lobby/LobbyController.gd") as Script
	if identity_script == null or not identity_script.can_instantiate():
		_fail("Phase 11 GuestIdentity script could not compile")
		return
	if account_store_script == null or not account_store_script.can_instantiate():
		_fail("Phase 11 GuestAccountStore script could not compile")
		return
	if lobby_script == null or not lobby_script.can_instantiate():
		_fail("Phase 11 lobby controller could not compile")
		return

	var account_store: Node = account_store_script.new()
	for method in ["register_claim", "issue_challenge", "verify_challenge", "username_available", "public_account"]:
		if not account_store.has_method(method):
			_fail("Guest account store missing method: %s" % method)
			return
	account_store.free()

	var player_scene := load("res://src/player/Player.tscn") as PackedScene
	if player_scene == null:
		_fail("Phase 11 Player scene could not load")
		return
	var player := player_scene.instantiate()
	if player == null:
		_fail("Phase 11 Player scene could not instantiate")
		return
	if player.get_node_or_null("FlashlightController") == null:
		_fail("Phase 11 flashlight controller missing from Player")
		return
	var flashlight := player.get_node_or_null("CameraRig/Pitch/FirstPerson/Flashlight") as SpotLight3D
	if flashlight == null or flashlight.spot_range < 10.0 or flashlight.spot_angle <= 0.0:
		_fail("Phase 11 flashlight SpotLight3D is not configured")
		return
	if not InputMap.has_action(&"flashlight"):
		_fail("Phase 11 flashlight input action missing")
		return
	player.free()

	var horde_scene := load("res://src/horde/HordeHUD.tscn") as PackedScene
	var horde_hud := horde_scene.instantiate() if horde_scene != null else null
	if horde_hud == null:
		_fail("Phase 11 Horde HUD could not instantiate")
		return
	var stats := horde_hud.get_node_or_null("SafeArea/StatsPanel") as Control
	if stats == null or stats.anchor_left < 0.90:
		_fail("Phase 11 Horde stats are not separated to the right side")
		return
	horde_hud.free()

	var lobby_scene := load("res://src/lobby/Lobby.tscn") as PackedScene
	if lobby_scene == null:
		_fail("Phase 11 Lobby scene could not load")
		return
	var lobby := lobby_scene.instantiate()
	if lobby == null:
		_fail("Phase 11 Lobby scene could not instantiate")
		return
	root.add_child(lobby)
	for node_path in ["SafeArea/OperatorStage", "SafeArea/PartyRail", "SafeArea/MatchControls", "SafeArea/CharacterSelection"]:
		if lobby.get_node_or_null(node_path) == null:
			_fail("Phase 11 Lobby missing UI contract: %s" % node_path)
			return
	lobby.free()

	var district_script := load("res://src/maps/campaign/OutbreakDistrict.gd") as Script
	if district_script == null or not district_script.can_instantiate():
		_fail("Phase 11 night environment script could not compile")
		return

	print("NEXORA: DEADFALL Phase 11 mobile/lobby smoke passed")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
