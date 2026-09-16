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
	_social.api_base = "http://127.0.0.1:1/v1"
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
	gate._begin_login_flow()
	gate._on_guest_account_pressed()
	gate._username_edit.text = "GhostDev"
	gate._submit_username()
	if not await _until(func() -> bool: return not gate._busy):
		return
	if gate._stage != gate.Stage.ERROR:
		_fail("Connection failure must return to a usable retry screen")
		return
	await _capture("03-account-retry")
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
	lobby._on_start_pressed()
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
	for slot in [1, 2, 0]:
		loadout.request_slot(slot)
		await process_frame
		var weapon: Node = loadout.get_active_weapon()
		if weapon._view_model == null or not weapon._view_model.visible:
			_fail("Selected first-person weapon is invisible")
			return
		await _capture("10-weapon-%d" % slot)
	var input := player.get_node("PlayerInput")
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
	_main.free()
	current_scene = null
	_api.free()
	_service.free()
	_store.free()
	_audio.stop_all()
	await create_timer(0.15).timeout
	print("NEXORA: DEADFALL rendered presentation runtime smoke passed")
	quit(0)

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
