extends SceneTree

var _directory := ""
var _session: Node
var _arena: Node
var _player: Node3D
var _result := false
var _attacker := false
var _saw_reload := false
var _finished_reload := false
var _target_alive := false
var _diagnostic_usec := 0
var _target_ready_usec := 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	Engine.max_fps = 60
	var args := OS.get_cmdline_user_args()
	_directory = _argument(args, "--test-dir=")
	if "--control-test" in args:
		await _control()
		return
	var assignment: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_argument(args, "--assignment=")))
	_attacker = "--attacker" in args
	var wrapper := Node.new()
	wrapper.name = "Main"
	root.add_child(wrapper)
	_arena = load("res://src/maps/campaign/OutbreakDistrict.tscn").instantiate()
	_arena.name = "CampaignArena"
	_arena.game_mode = String(assignment.game_mode)
	wrapper.add_child(_arena)
	_session = _arena.get_node("NetworkSession")
	_session.match_finished.connect(_on_result)
	_session.join_failed.connect(func(reason: String) -> void: _fail("Admission failed: " + reason))
	_session.disconnected.connect(func(reason: String) -> void:
		if not _result: _fail("Unexpected disconnect: " + reason))
	assert(_session.start_client("127.0.0.1", int(assignment.port), _argument(args, "--name="), "", String(assignment.join_ticket)) == OK)
	create_timer(110).timeout.connect(func() -> void: _fail("No authoritative result before deadline"))
	while not _result:
		await physics_frame
		_player = _arena.get_node_or_null("NetworkPlayers/Player_%d" % int(_session.local_entity_id))
		if _player != null and _attacker: _play()

func _play() -> void:
	var input := _player.get_node("PlayerInput")
	var rifle := _player.get_node("PrimaryWeapon")
	var state: Dictionary = rifle.get_authoritative_state()
	if Time.get_ticks_usec() >= _diagnostic_usec:
		_diagnostic_usec = Time.get_ticks_usec() + 5_000_000
		print("DEADFALL_COMBAT_PROBE ", JSON.stringify({"ammo": state, "position": str(_player.position), "input": rifle.input_enabled, "mode": _arena.get_node("MatchModeDirector").get_status_snapshot()}))
	if bool(state.get("reloading", false)): _saw_reload = true
	if _saw_reload and not bool(state.get("reloading", false)) and int(state.get("ammo", 0)) > 0:
		_finished_reload = true
	# Empty a magazine via ordinary input before combat. Only the dedicated
	# server may reload it; the replica must observe that replenished magazine.
	if not _finished_reload:
		_player.get_node("CameraRig").set_pitch(1.2)
		input.set_mobile_action(&"fire", true)
		return
	var enemy: Node3D
	for candidate in _arena.get_node("NetworkPlayers").get_children():
		if candidate != _player and candidate.get_meta("team_id", -1) != _player.get_meta("team_id", -1):
			if enemy == null or int(candidate.player_entity_id) < int(enemy.player_entity_id): enemy = candidate
	if enemy == null: return
	var alive := not bool(enemy.get_node("Health").is_dead())
	if alive and not _target_alive: _target_ready_usec = Time.get_ticks_usec() + 2_200_000
	_target_alive = alive
	var rig := _player.get_node("CameraRig")
	var direction: Vector3 = (enemy.global_position + Vector3(0, 1.64, 0)) - rig.get_aim_camera().global_position
	_player.rotation.y = atan2(-direction.x, -direction.z)
	rig.set_pitch(atan2(direction.y, Vector2(direction.x, direction.z).length()))
	input.set_mobile_action(&"fire", alive and Time.get_ticks_usec() >= _target_ready_usec)

func _on_result(result: Dictionary) -> void:
	if _result: return
	_result = true
	if _player != null: _player.get_node("PlayerInput").set_mobile_action(&"fire", false)
	if _attacker and not _finished_reload:
		_fail("Client did not observe automatic reload")
		return
	result["observed_automatic_reload"] = _finished_reload
	var file := FileAccess.open(_argument(OS.get_cmdline_user_args(), "--result="), FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	file.close()
	_arena.process_mode = Node.PROCESS_MODE_DISABLED
	_session._client_peer.close()
	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	root.get_node("Game").stop_session()
	await create_timer(0.25).timeout
	print("DEADFALL_SOCIAL_MATCH_PEER_PASSED")
	quit(0)

func _control() -> void:
	var store: Node = load("res://src/server/GuestAccountStore.gd").new()
	root.add_child(store)
	var social: Node = load("res://src/server/SocialService.gd").new()
	root.add_child(social)
	social.configure(store)
	var orchestrator: Node = load("res://src/server/MatchOrchestrator.gd").new()
	root.add_child(orchestrator)
	assert(orchestrator.configure_validation_port_range(24640, 24643))
	orchestrator.configure(store, social, "127.0.0.1")
	var api: Node = load("res://src/server/ControlApiServer.gd").new()
	root.add_child(api)
	api.configure(store, social, orchestrator)
	assert(api.start(24865) == OK)
	print("DEADFALL_SOCIAL_CONTROL_READY")
	var deadline := Time.get_ticks_usec() + 150_000_000
	while not FileAccess.file_exists(_directory.path_join("stop")) and Time.get_ticks_usec() < deadline:
		await create_timer(0.2).timeout
	api.free()
	orchestrator.free()
	social.free()
	store.free()
	quit(0)

func _argument(args: PackedStringArray, prefix: String) -> String:
	for arg in args:
		if arg.begins_with(prefix): return arg.trim_prefix(prefix)
	return ""

func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
