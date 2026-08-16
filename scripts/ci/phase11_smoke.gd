extends SceneTree

const REQUIRED_FILES := [
	"res://src/identity/GuestIdentity.gd",
	"res://src/social/SocialClient.gd",
	"res://src/server/GuestAccountStore.gd",
	"res://src/server/SocialService.gd",
	"res://src/server/ControlApiServer.gd",
	"res://src/server/MatchAdmission.gd",
	"res://src/server/MatchOrchestrator.gd",
	"res://src/server/MatchInstanceGuard.gd",
	"res://src/network/NetworkTelemetry.gd",
	"res://src/network/ClosedBetaNetworkSession.gd",
	"res://src/assets/ExternalModelCatalog.gd",
	"res://src/player/PlayerModelPresenter.gd",
	"res://src/zombies/base/ZombieModelPresenter.gd",
	"res://scripts/assets/sync_objetos3d.sh",
	"res://scripts/build/build_android_vps.sh",
	"res://scripts/ci/phase11_orchestration_smoke.gd",
	"res://src/login/LoginGate.gd",
	"res://src/login/LoginGate.tscn",
	"res://src/lobby/CharacterCatalog.gd",
	"res://src/lobby/LobbyController.gd",
	"res://src/lobby/LobbySocialOverlay.gd",
	"res://src/lobby/LobbyMatchBridge.gd",
	"res://src/lobby/PublicPlayerIdBadge.gd",
	"res://src/lobby/LobbyCharacterSync.gd",
	"res://src/lobby/Lobby.tscn",
	"res://src/player/FlashlightController.gd",
	"res://src/mobile/TouchActionButton.gd",
	"res://deploy/nginx/nexora-deadfall.conf.template",
	"res://deploy/systemd/nexora-deadfall.service",
]

func _initialize() -> void:
	for path in REQUIRED_FILES:
		if not FileAccess.file_exists(path):
			_fail("Phase 11 missing required file: %s" % path)
			return

	for autoload_name in ["Settings", "GuestIdentity", "SocialClient", "NetworkTelemetry"]:
		if root.get_node_or_null(autoload_name) == null:
			_fail("Phase 11 autoload missing: %s" % autoload_name)
			return
	if Settings.CAMERA_SENSITIVITY_MIN > 0.10 or Settings.CAMERA_SENSITIVITY_MAX < 1.00:
		_fail("Phase 11 camera sensitivity range is incomplete")
		return
	if Settings.camera_sensitivity < Settings.CAMERA_SENSITIVITY_MIN or Settings.camera_sensitivity > Settings.CAMERA_SENSITIVITY_MAX:
		_fail("Phase 11 camera sensitivity value is invalid")
		return
	if Settings.get_look_radians_per_pixel() <= 0.0:
		_fail("Phase 11 camera sensitivity conversion is invalid")
		return

	var scripts := [
		"res://src/identity/GuestIdentity.gd",
		"res://src/server/GuestAccountStore.gd",
		"res://src/server/SocialService.gd",
		"res://src/server/ControlApiServer.gd",
		"res://src/server/MatchAdmission.gd",
		"res://src/server/MatchOrchestrator.gd",
		"res://src/server/MatchInstanceGuard.gd",
		"res://src/network/NetworkTelemetry.gd",
		"res://src/network/ClosedBetaNetworkSession.gd",
		"res://src/assets/ExternalModelCatalog.gd",
		"res://src/player/PlayerModelPresenter.gd",
		"res://src/zombies/base/ZombieModelPresenter.gd",
		"res://src/lobby/LobbyController.gd",
		"res://src/lobby/LobbySocialOverlay.gd",
		"res://src/lobby/LobbyMatchBridge.gd",
		"res://src/lobby/PublicPlayerIdBadge.gd",
		"res://src/lobby/LobbyCharacterSync.gd",
		"res://src/login/LoginGate.gd",
	]
	for path in scripts:
		var script := load(path) as Script
		if script == null or not script.can_instantiate():
			_fail("Phase 11 script could not compile: %s" % path)
			return

	var account_store_script := load("res://src/server/GuestAccountStore.gd") as Script
	var account_store: Node = account_store_script.new()
	for method in ["register_claim", "issue_challenge", "verify_challenge", "username_available", "public_account", "public_account_by_lookup", "resolve_guest_id", "update_character"]:
		if not account_store.has_method(method):
			_fail("Guest account store missing method: %s" % method)
			return
	account_store.free()

	var social_service_script := load("res://src/server/SocialService.gd") as Script
	var social_service: Node = social_service_script.new()
	for method in ["issue_session", "update_presence", "create_party", "join_party", "leave_party", "kick_member", "current_party", "party_snapshot_for_token", "server_party_record_for_guest", "set_party_match_assignment", "update_party_match_status", "clear_party_match_assignment", "request_friend", "accept_friend", "friends_snapshot", "send_party_message", "send_friend_message"]:
		if not social_service.has_method(method):
			_fail("Social service missing method: %s" % method)
			return
	social_service.free()

	var orchestrator_script := load("res://src/server/MatchOrchestrator.gd") as Script
	var orchestrator: Node = orchestrator_script.new()
	for method in ["configure", "configure_validation_port_range", "start_party_match", "cancel_party_match", "get_status_snapshot"]:
		if not orchestrator.has_method(method):
			_fail("Match orchestrator missing method: %s" % method)
			return
	orchestrator.free()

	var admission_script := load("res://src/server/MatchAdmission.gd") as Script
	var admission = admission_script.new()
	for method in ["load_from_file", "validate_ticket", "ticket_for_guest", "snapshot"]:
		if not admission.has_method(method):
			_fail("Match admission missing method: %s" % method)
			return
	admission = null

	var control_api_script := load("res://src/server/ControlApiServer.gd") as Script
	var control_api: Node = control_api_script.new()
	for method in ["configure", "start", "stop"]:
		if not control_api.has_method(method):
			_fail("Control API missing method: %s" % method)
			return
	control_api.free()

	for client_method in ["report_presence", "start_party_match", "cancel_party_match", "refresh_match_status"]:
		if not SocialClient.has_method(client_method):
			_fail("SocialClient missing Phase 11.3 method: %s" % client_method)
			return
	if not SocialClient.has_signal("match_ready"):
		_fail("SocialClient match_ready signal missing")
		return

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
	if player.get_node_or_null("FlashlightController") == null or player.get_node_or_null("VisualRoot/ModelPresenter") == null:
		_fail("Phase 11 Player flashlight/model presenter contract missing")
		return
	var flashlight := player.get_node_or_null("CameraRig/Pitch/FirstPerson/Flashlight") as SpotLight3D
	if flashlight == null or flashlight.spot_range < 10.0 or flashlight.spot_angle <= 0.0:
		_fail("Phase 11 flashlight SpotLight3D is not configured")
		return
	if not InputMap.has_action(&"flashlight"):
		_fail("Phase 11 flashlight input action missing")
		return
	player.free()

	var zombie_scene := load("res://src/zombies/base/Zombie.tscn") as PackedScene
	var zombie := zombie_scene.instantiate() if zombie_scene != null else null
	if zombie == null or zombie.get_node_or_null("VisualRoot/ModelPresenter") == null:
		_fail("Phase 11 zombie external model presenter missing")
		return
	if zombie.get_node_or_null("VisualRoot/PreparedRig") == null or zombie.get_node_or_null("Gore") == null:
		_fail("Phase 11 gore-ready zombie fallback missing")
		return
	zombie.free()

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
	for node_path in ["SafeArea/OperatorStage", "SafeArea/PartyRail", "SafeArea/MatchControls", "SafeArea/CharacterSelection", "SocialOverlay", "PublicPlayerId", "CharacterSync", "MatchBridge"]:
		if lobby.get_node_or_null(node_path) == null:
			_fail("Phase 11 Lobby missing UI contract: %s" % node_path)
			return
	var overlay := lobby.get_node_or_null("SocialOverlay")
	if overlay == null or not overlay.has_signal("online_match_ready") or not overlay.has_method("request_start_match"):
		_fail("Phase 11 squad matchmaking UI contract missing")
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

	var updater_file := FileAccess.open("res://deploy/vps/update.sh", FileAccess.READ)
	var updater_text := updater_file.get_as_text() if updater_file != null else ""
	if not updater_text.contains("24600:24749/udp") or not updater_text.contains("sync_objetos3d.sh"):
		_fail("Phase 11.3 VPS dynamic match/model deployment contract missing")
		return

	var service_file := FileAccess.open("res://deploy/systemd/nexora-deadfall.service", FileAccess.READ)
	var service_text := service_file.get_as_text() if service_file != null else ""
	if not service_text.contains("UMask=0077"):
		_fail("Phase 11.3 match ticket/state files are not protected by the service umask")
		return

	var model_sync_file := FileAccess.open("res://scripts/assets/sync_objetos3d.sh", FileAccess.READ)
	var model_sync_text := model_sync_file.get_as_text() if model_sync_file != null else ""
	if not model_sync_text.contains("validate_glb") or not model_sync_text.contains("Invalid GLB magic") or not model_sync_text.contains("destination_path"):
		_fail("Phase 11.3 external GLB staging is not deterministic/validated")
		return

	var android_build_file := FileAccess.open("res://scripts/build/build_android_vps.sh", FileAccess.READ)
	var android_build_text := android_build_file.get_as_text() if android_build_file != null else ""
	if not android_build_text.contains("--install-android-build-template") or not android_build_text.contains("--export-release") or android_build_text.contains("INSTALL_TEMPLATE_ARGS"):
		_fail("Phase 11.3 Android template/export ordering contract missing")
		return

	var network_file := FileAccess.open("res://src/network/ClosedBetaNetworkSession.gd", FileAccess.READ)
	var network_text := network_file.get_as_text() if network_file != null else ""
	if not network_text.contains("MATCH_RESUME_PLACEHOLDER") or not network_text.contains("resume_for_join"):
		_fail("Phase 11.3 ticketed matches still risk legacy resume-state mixing")
		return

	var orchestration_output: Array = []
	var orchestration_args := PackedStringArray([
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", ProjectSettings.globalize_path("res://scripts/ci/phase11_orchestration_smoke.gd"),
	])
	var orchestration_exit := OS.execute(OS.get_executable_path(), orchestration_args, orchestration_output, true)
	if orchestration_exit != 0:
		_fail("Phase 11.3 real match orchestration smoke failed (exit=%d): %s" % [orchestration_exit, str(orchestration_output)])
		return
	if orchestration_output.is_empty() or not String(orchestration_output[0]).contains("Phase 11.3 real child-process orchestration smoke passed"):
		_fail("Phase 11.3 real match orchestration smoke returned no success marker: %s" % str(orchestration_output))
		return

	print("NEXORA: DEADFALL Phase 11.3 matchmaking/authority/ping/model smoke passed")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
