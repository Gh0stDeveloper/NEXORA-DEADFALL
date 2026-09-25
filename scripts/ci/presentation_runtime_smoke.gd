extends SceneTree

var _main: Node
var _social: Node
var _audio: Node
var _api: Node
var _store: Node
var _service: Node
var _output := "res://build/presentation-smoke"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_environment("DEADFALL_PRESENTATION_TEST") != "1":
		_fail("Run with a display and DEADFALL_PRESENTATION_TEST=1 in an isolated XDG_DATA_HOME")
		return
	create_timer(80).timeout.connect(func() -> void: _fail("Rendered presentation test timed out"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	var identity := root.get_node("GuestIdentity")
	identity.username = ""
	_social = root.get_node("SocialClient")
	_audio = root.get_node("AudioDirector")
	_store = load("res://src/server/GuestAccountStore.gd").new()
	_service = load("res://src/server/SocialService.gd").new()
	_service.account_store = _store
	root.add_child(_store)
	root.add_child(_service)
	_api = load("res://src/server/ControlApiServer.gd").new()
	root.add_child(_api)
	_api.configure(_store, _service)
	if _api.start(24862) != OK:
		_fail("Cannot start isolated control API")
		return
	_social.api_base = "http://127.0.0.1:24862/v1"
	var started := Time.get_ticks_msec()
	change_scene_to_file("res://src/main/Boot.tscn")
	await process_frame
	await _capture("01-boot")
	if not await _until(func() -> bool: return current_scene != null and current_scene.has_node("LoginGate")):
		return
	_main = current_scene
	print("DEADFALL_RENDER_BOOT_TO_LOGIN_MS=", Time.get_ticks_msec() - started)
	var gate: Node = _main.get_node("LoginGate")
	await _capture("02-login")
	_social.api_base = "http://127.0.0.1:1/v1"
	_press_text(gate, "TOCA PARA INICIAR")
	_press_text(gate, "CREAR CUENTA DE INVITADO")
	_main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	if quit_on_go_back or gate._stage != gate.Stage.ACCOUNT_CHOICE:
		_fail("Android Back must return to account choice without quitting")
		return
	_press_text(gate, "CREAR CUENTA DE INVITADO")
	gate._username_edit.text = "GhostDev"
	_press_text(gate, "CONFIRMAR IDENTIDAD")
	print("DEADFALL_RENDER_ACCOUNT_RETRY_STARTED")
	if not await _until(func() -> bool: return not gate._busy):
		return
	if gate._stage != gate.Stage.ERROR:
		_fail("Connection failure must return to a usable retry screen")
		return
	await _capture("03-account-retry")
	print("DEADFALL_RENDER_ACCOUNT_RETRY_SCREEN")
	_social.api_base = "http://127.0.0.1:24862/v1"
	gate._on_guest_account_pressed()
	if gate._username_edit.text != "GhostDev":
		_fail("Retry lost the typed account name")
		return
	gate._submit_username()
	if not await _until(func() -> bool: return _main.has_node("Lobby")):
		return
	if not _social.has_session():
		_fail("Lobby opened before a real HTTP account session was validated")
		return
	# Existing credentials whose server record is missing must register once,
	# preserving the device identity and returning through the real HTTP flow.
	var original_guest: String = identity.guest_id
	print("DEADFALL_RENDER_FRESH_ACCOUNT_VERIFIED")
	_store._accounts.erase(original_guest)
	_store._username_index.erase("ghostdev")
	_social.session_token = ""
	_main.get_node("Lobby").queue_free()
	await process_frame
	_main._boot_login_gate(&"mission_01_first_signal")
	gate = _main.get_node("LoginGate")
	_press_text(gate, "TOCA PARA INICIAR")
	if not await _until(func() -> bool: return _main.has_node("Lobby") and _social.has_session()):
		return
	if identity.guest_id != original_guest or _store.public_account(original_guest).is_empty():
		_fail("Missing-account recovery lost the existing device identity")
		return
	print("DEADFALL_RENDER_MISSING_ACCOUNT_RECOVERED")
	var update: CanvasLayer = load("res://src/ui/UpdateGate.gd").new()
	root.add_child(update)
	var next_build: Dictionary = load("res://src/release/BuildInfo.gd").snapshot()
	next_build["version_code"] += 1
	next_build["app_version"] = "SIGUIENTE VERSIÓN"
	update._on_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"ok": true, "service": "deadfall-control", "build": next_build}).to_utf8_buffer())
	await _capture("03a-update-required")
	update.queue_free()
	await process_frame
	var lobby := _main.get_node("Lobby")
	await _capture("04-lobby-solo")
	for capacity in [2, 4]:
		lobby._set_mode(capacity)
		await _capture("05-formation-%d" % capacity)
	lobby._open_armory()
	await _capture("06-armory")
	if lobby._stage_view.is_processing():
		_fail("Covered lobby stage keeps spending animation frames")
		return
	lobby._open_character_panel()
	await _capture("07-operators")
	lobby._select_character(&"operator_02")
	if not await _until(func() -> bool: return String(_store.public_account(identity.guest_id).get("selected_character", "")) == "operator_02"):
		return
	lobby._select_character(&"operator_01")
	if not await _until(func() -> bool: return String(_store.public_account(identity.guest_id).get("selected_character", "")) == "operator_01"):
		return
	await _capture("07-valeria-selected")
	lobby._open_settings()
	var settings := root.get_node("Settings")
	settings.set_audio_volume(0.0, "SFX")
	if not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")):
		_fail("Combat volume zero must mute the bus")
		return
	settings.set_audio_volume(0.42, "SFX")
	settings._load_settings()
	if not is_equal_approx(settings.get_audio_volume("SFX"), 0.42):
		_fail("Audio setting did not persist")
		return
	await _capture("08-settings")
	lobby._close_character_panel()
	lobby._set_mode(1)
	_main._on_lobby_start_requested(1, lobby, &"mission_01_first_signal")
	if not await _until(func() -> bool: return _main.has_node("CampaignArena/NetworkPlayers/Player_1") and not is_instance_valid(_main._match_loading)):
		return
	var player := _main.get_node("CampaignArena/NetworkPlayers/Player_1")
	_main.get_node("CampaignArena/MobileHUD").show()
	var horde := _main.get_node("CampaignArena/HordeDirector")
	for index in range(2):
		var zombie: Node3D = horde.debug_spawn_archetype(&"walker" if index == 0 else &"tank")
		if zombie != null:
			zombie.global_position = player.global_position + Vector3(float(index) * 1.4, 0, -5)
	await create_timer(0.6).timeout
	await _capture("09-gameplay-rifle")
	var loadout := player.get_node("WeaponLoadout")
	var hud := _main.get_node("CampaignArena/MobileHUD")
	for slot in [1, 2, 0]:
		hud._weapon_buttons[slot].pressed.emit()
		await process_frame
		var weapon: Node = loadout.get_active_weapon()
		if weapon._view_model == null or not weapon._view_model.visible:
			_fail("Selected first-person weapon is invisible")
			return
		await _capture("10-weapon-%d" % slot)
	var input := player.get_node("PlayerInput")
	var start_position: Vector3 = player.global_position
	var sprint := hud.get_node("SafeArea/GameplayControls/SprintButton")
	sprint.router_touch_down(8)
	sprint.router_touch_up(8)
	await create_timer(0.3).timeout
	if player.global_position.distance_to(start_position) < 0.2:
		_fail("Latched sprint did not move the player without a joystick")
		return
	sprint.router_touch_down(8)
	sprint.router_touch_up(8)
	input.clear_mobile_actions()
	var rifle: Node = loadout.get_active_weapon()
	var before: Dictionary = rifle.get_authoritative_state()
	input.set_mobile_action(&"fire", true)
	await create_timer(0.15).timeout
	input.set_mobile_action(&"fire", false)
	var after: Dictionary = rifle.get_authoritative_state()
	if int(after.get("last_sequence", 0)) <= int(before.get("last_sequence", 0)):
		_fail("Fire input failed to drive the real weapon")
		return
	if _audio._context != &"gameplay" or _audio._world_voices.size() != _audio.MAX_WORLD_VOICES:
		_fail("Gameplay audio context or bounded voice pool is missing")
		return
	_audio._pause(true)
	if not _audio._music.stream_paused:
		_fail("Backgrounding must pause the soundtrack")
		return
	_audio._pause(false)
	await _capture("11-combat")
	for zombie in _main.get_node("CampaignArena/HordeZombies").get_children():
		zombie.queue_free()
	horde.set_process(false)
	var drops := _main.get_node("CampaignArena/AmmoDropDirector")
	drops._spawn_ammo(player.global_position + Vector3(-0.6, 0, -2), 30, "ammo")
	drops._spawn_ammo(player.global_position + Vector3(0.6, 0, -2), 25, "health")
	await _capture("12-pickups")
	var telemetry := root.get_node("NetworkTelemetry")
	root.get_node("Game").start_network_client_session()
	telemetry.set_match_ping(120, 120, "MEDIO")
	await _capture("13-match-ping")
	telemetry._last_match_ping_usec = Time.get_ticks_usec() - 6000000
	telemetry._apply_effective_ping()
	await _capture("14-match-disconnected")
	root.get_node("Game").start_local_session()
	hud.get_node("SafeArea/ExitMatchButton").pressed.emit()
	if not hud._leave_dialog.visible or input.get_move_vector() != Vector2.ZERO:
		_fail("Exit did not show confirmation and neutralize input")
		return
	await _capture("15-leave-confirmation")
	hud._leave_dialog.get_ok_button().pressed.emit()
	if not await _until(func() -> bool: return _main.has_node("Lobby") and not _main.has_node("CampaignArena")):
		return
	if root.get_node("Game").is_network_client() or is_instance_valid(_main._active_network_session):
		_fail("Leaving match retained the old network transport")
		return
	await _capture("16-returned-lobby")
	print("DEADFALL_RENDER_RETURNED_LOBBY")
	# Leave the frame_post_draw callback before releasing rendered scenes.
	await process_frame
	_main.queue_free()
	current_scene = null
	_api.queue_free()
	_service.queue_free()
	_store.queue_free()
	await process_frame
	_audio.stop_all()
	print("DEADFALL_RENDER_SCENES_RELEASED")
	await create_timer(0.3).timeout
	print("NEXORA: DEADFALL rendered presentation runtime smoke passed")
	quit(0)

func _press_text(node: Node, text: String) -> bool:
	if node is Button and node.text == text:
		node.pressed.emit()
		return true
	for child in node.get_children():
		if _press_text(child, text):
			return true
	return false

func _capture(name_value: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(_output.path_join(name_value + ".png"))
	if error != OK:
		_fail("Unable to save presentation capture")

func _until(check: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 15000
	while not check.call() and Time.get_ticks_msec() < deadline:
		await create_timer(0.03).timeout
	if not check.call():
		_fail("Presentation flow did not reach the expected state")
		return false
	return true

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
