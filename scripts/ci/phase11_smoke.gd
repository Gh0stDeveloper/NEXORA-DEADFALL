extends SceneTree

const REQUIRED_FILES := [
	"res://src/identity/GuestIdentity.gd",
	"res://src/social/SocialClient.gd",
	"res://src/server/GuestAccountStore.gd",
	"res://src/server/SocialService.gd",
	"res://src/server/ControlApiServer.gd",
	"res://src/login/LoginGate.gd",
	"res://src/login/LoginGate.tscn",
	"res://src/lobby/CharacterCatalog.gd",
	"res://src/lobby/LobbyController.gd",
	"res://src/lobby/LobbySocialOverlay.gd",
	"res://src/lobby/Lobby.tscn",
	"res://src/player/FlashlightController.gd",
	"res://src/mobile/TouchActionButton.gd",
	"res://deploy/nginx/nexora-deadfall.conf.template",
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
	if root.get_node_or_null("SocialClient") == null:
		_fail("Phase 11 SocialClient autoload missing")
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
	var social_service_script := load("res://src/server/SocialService.gd") as Script
	var control_api_script := load("res://src/server/ControlApiServer.gd") as Script
	var lobby_script := load("res://src/lobby/LobbyController.gd") as Script
	var social_overlay_script := load("res://src/lobby/LobbySocialOverlay.gd") as Script
	var login_script := load("res://src/login/LoginGate.gd") as Script
	for script_value in [identity_script, account_store_script, social_service_script, control_api_script, lobby_script, social_overlay_script, login_script]:
		var script: Script = script_value as Script
		if script == null or not script.can_instantiate():
			_fail("Phase 11 guest/social script could not compile")
			return

	var account_store: Node = account_store_script.new()
	for method in ["register_claim", "issue_challenge", "verify_challenge", "username_available", "public_account"]:
		if not account_store.has_method(method):
			_fail("Guest account store missing method: %s" % method)
			return
	account_store.free()

	var social_service: Node = social_service_script.new()
	for method in ["issue_session", "create_party", "join_party", "leave_party", "kick_member", "current_party", "request_friend", "accept_friend", "friends_snapshot", "send_party_message", "send_friend_message"]:
		if not social_service.has_method(method):
			_fail("Social service missing method: %s" % method)
			return
	social_service.free()

	var control_api: Node = control_api_script.new()
	for method in ["configure", "start", "stop"]:
		if not control_api.has_method(method):
			_fail("Control API missing method: %s" % method)
			return
	control_api.free()

	var login_scene := load("res://src/login/LoginGate.tscn") as PackedScene
	if login_scene == null:
		_fail("Phase 11 login gate scene could not load")
		return
	var login_gate := login_scene.instantiate()
	if login_gate == null or not login_gate.has_signal("login_complete"):
		_fail("Phase 11 login gate contract incomplete")
		return
	login_gate.free()

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
	for node_path in ["SafeArea/OperatorStage", "SafeArea/PartyRail", "SafeArea/MatchControls", "SafeArea/CharacterSelection", "SocialOverlay"]:
		if lobby.get_node_or_null(node_path) == null:
			_fail("Phase 11 Lobby missing UI contract: %s" % node_path)
			return
	lobby.free()

	var district_script := load("res://src/maps/campaign/OutbreakDistrict.gd") as Script
	if district_script == null or not district_script.can_instantiate():
		_fail("Phase 11 night environment script could not compile")
		return

	var nginx_file := FileAccess.open("res://deploy/nginx/nexora-deadfall.conf.template", FileAccess.READ)
	var nginx_text := nginx_file.get_as_text() if nginx_file != null else ""
	if not nginx_text.contains("location /api/deadfall/") or not nginx_text.contains("127.0.0.1:24562"):
		_fail("Phase 11 social API is not proxied by Nginx")
		return

	print("NEXORA: DEADFALL Phase 11 mobile/lobby/social smoke passed")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
