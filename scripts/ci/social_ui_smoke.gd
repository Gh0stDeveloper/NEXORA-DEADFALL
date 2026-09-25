extends SceneTree
var _api: Node
var _store: Node
var _service: Node
var _social: Node
var _hub: Control
var _lobby: Control
var _failed := false

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_environment("DEADFALL_PRESENTATION_TEST") != "1":
		_fail("Requires display and isolated presentation test profile")
		return
	create_timer(60).timeout.connect(func() -> void: _fail("Social UI timed out"))
	_store = load("res://src/server/GuestAccountStore.gd").new()
	root.add_child(_store)
	_service = load("res://src/server/SocialService.gd").new()
	root.add_child(_service)
	_service.configure(_store)
	_api = load("res://src/server/ControlApiServer.gd").new()
	root.add_child(_api)
	_api.configure(_store, _service)
	assert(_api.start(24863) == OK)
	_social = root.get_node("SocialClient")
	_social.api_base = "http://127.0.0.1:24863/v1"
	_social.register_guest("GhostDev")
	assert(await _until(func() -> bool: return _social.has_session()))
	var peer := "gst_render_social_peer_0000000000000000"
	assert(_store.register_claim({"guest_id": peer, "username": "Valeria", "secret_verifier": "b".repeat(64), "selected_character": "operator_01"}).ok)
	var peer_token: String = _service.issue_session(peer).session_token
	_lobby = load("res://src/lobby/Lobby.tscn").instantiate() as Control
	root.add_child(_lobby)
	await process_frame
	await _capture("lobby")
	_lobby._open_mode_picker()
	await _capture("modes")
	_lobby._select_game_mode("endless")
	assert(_lobby.selected_game_mode == "endless")
	var overlay := _lobby.get_node("SocialOverlay")
	overlay._open_profile()
	_hub = _lobby.get_node("SafeArea/SocialHub")
	assert(await _until(func() -> bool: return _hub._profile.has("stats")))
	await _capture("profile")
	_hub.show_section("search")
	_hub._search.text = "Vale"
	_hub._submit_search()
	assert(await _until(func() -> bool: return _hub._search_results.size() == 1))
	await _capture("search")
	_press_text(_hub, "AÑADIR", true)
	assert(await _until(func() -> bool: return Array(_service.friends_snapshot(peer_token).friends.incoming).size() == 1))
	assert(_service.accept_friend(peer_token, root.get_node("GuestIdentity").guest_id).ok)
	_hub.show_section("friends")
	assert(await _until(func() -> bool: return Array(_hub._friends.get("accepted", [])).size() == 1))
	await _capture("friends")
	var requester := "gst_render_requester_00000000000000000"
	assert(_store.register_claim({"guest_id": requester, "username": "Dante", "secret_verifier": "c".repeat(64)}).ok)
	var request_token: String = _service.issue_session(requester).session_token
	assert(_service.request_friend(request_token, root.get_node("GuestIdentity").guest_id).ok)
	_hub.show_section("requests")
	assert(await _until(func() -> bool: return Array(_hub._friends.get("incoming", [])).size() == 1))
	await _capture("requests")
	_press_text(_hub, "ACEPTAR")
	assert(await _until(func() -> bool: return Array(_hub._friends.get("incoming", [])).is_empty()))
	var guest: String = root.get_node("GuestIdentity").guest_id
	_service.record_match_result([guest], {"match_id": "render-fixture", "server_authoritative": true, "outcome": "VICTORY", "kills": 37, "score": 2460, "wave": 10, "uptime_seconds": 760, "completed_unix": int(Time.get_unix_time_from_system()), "player_stats": {guest: {"kills": 37, "damage": 2300}}}, "waves")
	_hub.show_section("history")
	assert(await _until(func() -> bool: return _hub._history.size() == 1))
	await _capture("history")
	_hub.show_section("profile")
	assert(await _until(func() -> bool: return int(_hub._profile.get("stats", {}).get("matches", 0)) == 1))
	await _capture("profile-history")
	_hub._close()
	await process_frame
	_lobby.queue_free()
	await process_frame
	_api.free()
	_service.free()
	_store.free()
	root.get_node("AudioDirector").stop_all()
	await create_timer(0.3).timeout
	if not _failed: print("NEXORA: DEADFALL rendered social and mode selection smoke passed")
	quit(1 if _failed else 0)

func _press_text(node: Node, text: String, last: bool = false) -> void:
	var matches: Array[Button] = []
	for child in node.find_children("*", "Button", true, false):
		if child.text == text and child.is_visible_in_tree(): matches.append(child)
	assert(not matches.is_empty(), "Missing button: " + text)
	(matches.back() if last else matches.front()).pressed.emit()

func _until(condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		if condition.call(): return true
		await process_frame
	_fail("Timed out waiting for HTTP/UI state")
	return false

func _capture(name: String) -> void:
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var path := "res://build/social-smoke/" + name + ".png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/social-smoke"))
	root.get_texture().get_image().save_png(path)
	print("DEADFALL_SOCIAL_CAPTURE ", name)

func _fail(reason: String) -> void:
	_failed = true
	push_error(reason)
	quit(1)
