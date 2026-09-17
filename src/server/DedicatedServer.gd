class_name DeadfallDedicatedServer
extends Node

const DEFAULT_MAX_CLIENTS := 4
const SquadArenaScene = preload("res://src/maps/duo/DuoArena.tscn")
const CampaignArenaScene = preload("res://src/maps/campaign/OutbreakDistrict.tscn")
const RoomCodeScript = preload("res://src/network/RoomCodeService.gd")
const DirectoryServerScript = preload("res://src/network/RoomDirectoryServer.gd")
const GuestAccountStoreScript = preload("res://src/server/GuestAccountStore.gd")
const SocialServiceScript = preload("res://src/server/SocialService.gd")
const ControlApiServerScript = preload("res://src/server/LifecycleControlApiServer.gd")
const MatchOrchestratorScript = preload("res://src/server/MatchOrchestrator.gd")
const MatchAdmissionScript = preload("res://src/server/MatchAdmission.gd")
const MatchInstanceGuardScript = preload("res://src/server/MatchInstanceGuard.gd")

var peer := ENetMultiplayerPeer.new()
var listen_port := 24560
var room_code := ""
var _arena: Node3D
var _directory: Node
var _guest_accounts: Node
var _social_service: Node
var _control_api: Node
var _match_orchestrator: Node
var _match_admission: RefCounted
var _match_guard: Node
var _campaign_mode := false
var _is_match_instance := false

func start(
	port: int = 24560,
	max_clients: int = DEFAULT_MAX_CLIENTS,
	directory_port: int = 24561,
	public_host: String = "127.0.0.1",
	requested_room_code: String = "",
	campaign_mode: bool = false,
	mission_id: StringName = &"mission_01_first_signal",
	match_instance: bool = false,
	match_config_path: String = ""
) -> Error:
	listen_port = port
	# Headless rendering has no vsync. Bound idle polling while retaining 60 Hz
	# physics/ENet processing; avoid an unbounded loop competing with match workers.
	Engine.max_fps = 60
	var performance := preload("res://src/server/ServerPerformance.gd").new()
	performance.name = "SimulationPerformance"
	add_child(performance)
	_campaign_mode = campaign_mode
	_is_match_instance = match_instance
	room_code = RoomCodeScript.normalize(requested_room_code)
	if _is_match_instance:
		_match_admission = MatchAdmissionScript.new()
		if not bool(_match_admission.call("load_from_file", match_config_path)):
			push_error("Unable to load DEADFALL match admission config: %s" % match_config_path)
			return ERR_INVALID_DATA
		var admission_snapshot: Dictionary = Dictionary(_match_admission.call("snapshot"))
		room_code = RoomCodeScript.normalize(String(admission_snapshot.get("party_code", room_code)))
		listen_port = int(admission_snapshot.get("port", listen_port))
		mission_id = StringName(String(admission_snapshot.get("mission_id", String(mission_id))))
	if not RoomCodeScript.is_valid(room_code):
		room_code = RoomCodeScript.generate_code()
	var error := peer.create_server(listen_port, mini(DEFAULT_MAX_CLIENTS, max_clients))
	if error != OK:
		push_error("Unable to start ENet server on UDP %d: %s" % [listen_port, error_string(error)])
		return error
	multiplayer.multiplayer_peer = peer
	Game.start_dedicated_server_session()

	if _is_match_instance:
		_boot_network_arena(campaign_mode, mission_id)
		_configure_match_instance_guard()
		var match_snapshot: Dictionary = Dictionary(_match_admission.call("snapshot"))
		if not _write_match_ready_marker(match_snapshot):
			push_error("Unable to publish DEADFALL match ready marker")
			stop()
			return ERR_CANT_CREATE
		print("DEADFALL_MATCH_INSTANCE_READY match=%s party=%s port=%d members=%d" % [
			String(match_snapshot.get("match_id", "")),
			room_code,
			listen_port,
			int(match_snapshot.get("expected_members", 0)),
		])
		return OK

	_boot_guest_accounts()
	_boot_social_services(public_host)
	_boot_network_arena(campaign_mode, mission_id)
	_directory = DirectoryServerScript.new()
	_directory.name = "RoomDirectoryServer"
	add_child(_directory)
	var directory_error := int(_directory.call("start", directory_port, room_code, public_host, listen_port))
	if directory_error != OK:
		push_error("Unable to start room directory on TCP %d: %s" % [directory_port, error_string(directory_error)])
		stop()
		return directory_error
	print("NEXORA: DEADFALL dedicated server listening on UDP %d" % listen_port)
	print("DEADFALL_SQUAD_ROOM code=%s directory_port=%d public_host=%s max_players=%d" % [room_code, directory_port, public_host, DEFAULT_MAX_CLIENTS])
	if campaign_mode:
		print("DEADFALL_CAMPAIGN_SERVER mission=%s" % String(mission_id))
	return OK

func get_guest_account_store() -> Node:
	return _guest_accounts

func get_social_service() -> Node:
	return _social_service

func get_match_orchestrator() -> Node:
	return _match_orchestrator

func _boot_guest_accounts() -> void:
	if _guest_accounts != null and is_instance_valid(_guest_accounts):
		return
	_guest_accounts = GuestAccountStoreScript.new()
	_guest_accounts.name = "GuestAccountStore"
	add_child(_guest_accounts)

func _boot_social_services(public_host: String) -> void:
	if _social_service == null or not is_instance_valid(_social_service):
		_social_service = SocialServiceScript.new()
		_social_service.name = "SocialService"
		add_child(_social_service)
		_social_service.call("configure", _guest_accounts)
	if _match_orchestrator == null or not is_instance_valid(_match_orchestrator):
		_match_orchestrator = MatchOrchestratorScript.new()
		_match_orchestrator.name = "MatchOrchestrator"
		add_child(_match_orchestrator)
		_match_orchestrator.call("configure", _guest_accounts, _social_service, public_host)
	if _control_api == null or not is_instance_valid(_control_api):
		_control_api = ControlApiServerScript.new()
		_control_api.name = "ControlApiServer"
		add_child(_control_api)
		_control_api.call("configure", _guest_accounts, _social_service, _match_orchestrator)
		var control_error := int(_control_api.call("start", 24562))
		if control_error != OK:
			push_error("Unable to start DEADFALL control API: %s" % error_string(control_error))

func _boot_network_arena(campaign_mode: bool, mission_id: StringName) -> void:
	_arena = (CampaignArenaScene.instantiate() if campaign_mode else SquadArenaScene.instantiate()) as Node3D
	_arena.name = "CampaignArena" if campaign_mode else "DuoArena"
	if campaign_mode:
		_arena.set("mission_id", mission_id)
	get_parent().add_child(_arena)
	var session := _arena.get_node_or_null("NetworkSession")
	if session != null and session.has_method("configure_server"):
		session.call("configure_server", room_code)
	if _is_match_instance and session != null and session.has_method("configure_match_admission"):
		session.call("configure_match_admission", _match_admission)

func _configure_match_instance_guard() -> void:
	if _arena == null or _match_admission == null:
		return
	var session := _arena.get_node_or_null("NetworkSession")
	if session == null:
		return
	var admission_snapshot: Dictionary = Dictionary(_match_admission.call("snapshot"))
	_match_guard = MatchInstanceGuardScript.new()
	_match_guard.name = "MatchInstanceGuard"
	add_child(_match_guard)
	_match_guard.call(
		"configure",
		session,
		String(admission_snapshot.get("match_id", "")),
		String(admission_snapshot.get("heartbeat_path", "")),
		String(admission_snapshot.get("result_path", "")),
		_arena.get_node_or_null("CampaignDirector"),
		_arena.get_node_or_null("HordeDirector")
	)

func _write_match_ready_marker(snapshot: Dictionary) -> bool:
	var path := String(snapshot.get("ready_path", "")).strip_edges()
	if path.is_empty():
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"match_id": String(snapshot.get("match_id", "")),
		"party_code": String(snapshot.get("party_code", "")),
		"port": int(snapshot.get("port", 0)),
		"ready_unix": int(Time.get_unix_time_from_system()),
	}))
	file.close()
	return true

func stop() -> void:
	if _control_api != null and is_instance_valid(_control_api) and _control_api.has_method("stop"):
		_control_api.call("stop")
	if _directory != null and is_instance_valid(_directory) and _directory.has_method("stop"):
		_directory.call("stop")
	if _arena != null and is_instance_valid(_arena):
		_arena.queue_free()
	if peer != null:
		peer.close()
	if Game.session_mode == Game.SessionMode.DEDICATED_SERVER:
		Game.stop_session()

func _exit_tree() -> void:
	if Game.session_mode == Game.SessionMode.DEDICATED_SERVER:
		Game.stop_session()
