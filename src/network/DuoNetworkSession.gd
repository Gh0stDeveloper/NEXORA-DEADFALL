class_name DeadfallDuoNetworkSession
extends Node

signal joined(entity_id: int, resume_token: String, room_code: String)
signal join_failed(reason: String)
signal disconnected(reason: String)

const PROTOCOL_VERSION := 1
const MAX_PLAYERS := 2
const SNAPSHOT_HZ := 15.0
const RECONNECT_GRACE_SECONDS := 20.0
const SERVER_PEER_ID := 1

const PlayerScene = preload("res://src/player/Player.tscn")
const ZombieScene = preload("res://src/zombies/base/Zombie.tscn")
const MobileHUDScene = preload("res://src/mobile/MobileHUD.tscn")
const HordeHUDScene = preload("res://src/horde/HordeHUD.tscn")
const PlayerControllerScript = preload("res://src/player/PlayerController.gd")
const PlayerCommandScript = preload("res://src/network/PlayerCommand.gd")
const InterpolatorScript = preload("res://src/network/NetworkReplicaInterpolator.gd")
const WalkerData = preload("res://src/zombies/data/walker_01.tres")
const RunnerData = preload("res://src/zombies/data/runner_01.tres")
const TankData = preload("res://src/zombies/data/tank_01.tres")
const ScreamerData = preload("res://src/zombies/data/screamer_01.tres")
const CrawlerData = preload("res://src/zombies/data/crawler_01.tres")

const ARCHETYPE_DATA := {
	&"walker": WalkerData,
	&"runner": RunnerData,
	&"tank": TankData,
	&"screamer": ScreamerData,
	&"crawler": CrawlerData,
}

enum Role { NONE, SERVER, CLIENT }

@export var players_root_path := NodePath("../NetworkPlayers")
@export var player_spawn_points_path := NodePath("../PlayerSpawnPoints")
@export var zombies_root_path := NodePath("../HordeZombies")
@export var horde_director_path := NodePath("../HordeDirector")

var role: int = Role.NONE
var room_code := ""
var local_entity_id := 0
var resume_token := ""
var display_name := "Player"
var server_host := ""
var server_port := 24560

var _client_peer: ENetMultiplayerPeer
var _players_root: Node3D
var _spawn_root: Node3D
var _zombies_root: Node3D
var _horde: Node
var _peers: Dictionary = {}
var _resume_records: Dictionary = {}
var _next_entity_id := 101
var _snapshot_elapsed := 0.0
var _server_tick := 0
var _reload_request_sequence := 0
var _snapshot_two_players_logged := false
var _network_smoke := false

func _ready() -> void:
	_resolve_nodes()
	_network_smoke = "--network-smoke" in OS.get_cmdline_user_args()

func _physics_process(delta: float) -> void:
	if role != Role.SERVER:
		return
	_server_tick += 1
	_cleanup_expired_resume_records()
	_snapshot_elapsed += delta
	if _snapshot_elapsed < 1.0 / SNAPSHOT_HZ:
		return
	_snapshot_elapsed = 0.0
	rpc("_client_receive_snapshot", _build_server_snapshot())

func configure_server(code: String) -> void:
	role = Role.SERVER
	room_code = code
	_resolve_nodes()
	if not multiplayer.peer_disconnected.is_connected(_on_server_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_server_peer_disconnected)
	if _horde != null and Game.authority != null and _horde.has_method("set_authority_override"):
		_horde.call("set_authority_override", Game.authority)

func start_client(host: String, port: int = 24560, requested_name: String = "Player", requested_resume_token: String = "") -> Error:
	role = Role.CLIENT
	server_host = host.strip_edges()
	server_port = port
	display_name = requested_name.left(24) if not requested_name.strip_edges().is_empty() else "Player"
	resume_token = requested_resume_token.strip_edges()
	if resume_token.is_empty():
		resume_token = _load_resume_token()
	Game.start_network_client_session()
	_client_peer = ENetMultiplayerPeer.new()
	var error := _client_peer.create_client(server_host, server_port)
	if error != OK:
		join_failed.emit("create_client:%s" % error_string(error))
		return error
	multiplayer.multiplayer_peer = _client_peer
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	return OK

func request_restart() -> void:
	if role == Role.CLIENT and local_entity_id != 0:
		rpc_id(SERVER_PEER_ID, "_server_restart_request")

func get_status_snapshot() -> Dictionary:
	return {
		"role": role,
		"room_code": room_code,
		"local_entity_id": local_entity_id,
		"server_host": server_host,
		"server_port": server_port,
		"connected_players": _peers.size() if role == Role.SERVER else _players_root.get_child_count() if _players_root != null else 0,
		"protocol": PROTOCOL_VERSION,
	}

func _resolve_nodes() -> void:
	_players_root = get_node_or_null(players_root_path) as Node3D
	_spawn_root = get_node_or_null(player_spawn_points_path) as Node3D
	_zombies_root = get_node_or_null(zombies_root_path) as Node3D
	_horde = get_node_or_null(horde_director_path)

func _on_connected_to_server() -> void:
	rpc_id(SERVER_PEER_ID, "_server_join_request", PROTOCOL_VERSION, resume_token, display_name)

func _on_connection_failed() -> void:
	join_failed.emit("connection_failed")
	Game.stop_session()

func _on_server_disconnected() -> void:
	disconnected.emit("server_disconnected")
	Game.stop_session()

@rpc("any_peer", "call_remote", "reliable", 0)
func _server_join_request(protocol: int, requested_token: String, requested_name: String) -> void:
	if role != Role.SERVER:
		return
	var sender := multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL_VERSION:
		rpc_id(sender, "_client_join_rejected", "protocol_mismatch")
		return
	if _peers.has(sender):
		var current: Dictionary = _peers[sender]
		rpc_id(sender, "_client_join_accepted", int(current.get("entity_id", 0)), String(current.get("token", "")), room_code)
		return

	var normalized_token := requested_token.strip_edges()
	var resume: Dictionary = {}
	if not normalized_token.is_empty() and _resume_records.has(normalized_token):
		var candidate: Dictionary = _resume_records[normalized_token]
		if int(candidate.get("expires_usec", 0)) > Time.get_ticks_usec():
			resume = candidate
		else:
			_resume_records.erase(normalized_token)

	if resume.is_empty() and _peers.size() >= MAX_PLAYERS:
		rpc_id(sender, "_client_join_rejected", "room_full")
		return

	var entity_id := int(resume.get("entity_id", 0))
	if entity_id == 0:
		entity_id = _allocate_entity_id()
	var token := normalized_token if not resume.is_empty() else _generate_resume_token()
	var slot := _first_free_slot()
	var player := _spawn_player(entity_id, PlayerControllerScript.ControlMode.SERVER_REMOTE, slot)
	if player == null:
		rpc_id(sender, "_client_join_rejected", "server_spawn_failed")
		return
	if not resume.is_empty():
		_restore_server_player(player, Dictionary(resume.get("snapshot", {})))
		_resume_records.erase(token)

	_peers[sender] = {
		"entity_id": entity_id,
		"token": token,
		"name": requested_name.left(24),
		"player": player,
		"last_command_seq": -1,
		"last_fire_seq": 0,
		"last_reload_seq": 0,
		"slot": slot,
	}
	if _horde != null and _horde.has_method("register_player"):
		_horde.call("register_player", player)
		if int(_horde.get("state")) == 0 and _horde.has_method("start_run"):
			_horde.call("start_run")
	rpc_id(sender, "_client_join_accepted", entity_id, token, room_code)
	print("DEADFALL_DUO_SERVER_JOIN peer=%d entity=%d players=%d" % [sender, entity_id, _peers.size()])

@rpc("authority", "call_remote", "reliable", 0)
func _client_join_accepted(entity_id: int, token: String, code: String) -> void:
	if role != Role.CLIENT:
		return
	local_entity_id = entity_id
	resume_token = token
	room_code = code
	_save_resume_token(token)
	var player := _ensure_client_player(entity_id, true)
	_bind_local_player(player)
	_build_client_huds(player)
	joined.emit(entity_id, token, code)
	print("DEADFALL_DUO_JOIN_ACCEPTED entity=%d room=%s" % [entity_id, code])

@rpc("authority", "call_remote", "reliable", 0)
func _client_join_rejected(reason: String) -> void:
	join_failed.emit(reason)
	push_error("Duo join rejected: %s" % reason)

@rpc("any_peer", "call_remote", "unreliable_ordered", 0)
func _server_submit_command(raw_command: Dictionary) -> void:
	if role != Role.SERVER:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _peers.has(sender):
		return
	var record: Dictionary = _peers[sender]
	var command := PlayerCommandScript.sanitize(raw_command, int(record.get("last_command_seq", -1)))
	if command.is_empty():
		return
	record["last_command_seq"] = int(command.get("sequence", -1))
	_peers[sender] = record
	var player = record.get("player")
	if player != null and is_instance_valid(player) and player.has_method("push_server_command"):
		player.call("push_server_command", command)

@rpc("any_peer", "call_remote", "reliable", 2)
func _server_fire_request(request_sequence: int, client_tick: int) -> void:
	if role != Role.SERVER:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _peers.has(sender):
		return
	var record: Dictionary = _peers[sender]
	if request_sequence <= int(record.get("last_fire_seq", 0)):
		return
	record["last_fire_seq"] = request_sequence
	_peers[sender] = record
	var player = record.get("player")
	if player == null or not is_instance_valid(player):
		return
	var weapon := player.get_node_or_null("PrimaryWeapon")
	if weapon != null and weapon.has_method("server_try_fire"):
		weapon.call("server_try_fire", request_sequence, client_tick)

@rpc("any_peer", "call_remote", "reliable", 2)
func _server_reload_request(request_sequence: int) -> void:
	if role != Role.SERVER:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _peers.has(sender):
		return
	var record: Dictionary = _peers[sender]
	if request_sequence <= int(record.get("last_reload_seq", 0)):
		return
	record["last_reload_seq"] = request_sequence
	_peers[sender] = record
	var player = record.get("player")
	if player == null or not is_instance_valid(player):
		return
	var weapon := player.get_node_or_null("PrimaryWeapon")
	if weapon != null and weapon.has_method("server_try_reload"):
		weapon.call("server_try_reload", request_sequence)

@rpc("any_peer", "call_remote", "reliable", 2)
func _server_restart_request() -> void:
	if role != Role.SERVER or not _peers.has(multiplayer.get_remote_sender_id()):
		return
	if _horde != null and _horde.has_method("restart_run") and int(_horde.get("state")) == 5:
		_horde.call("restart_run")

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _client_receive_snapshot(snapshot: Dictionary) -> void:
	if role != Role.CLIENT or int(snapshot.get("protocol", 0)) != PROTOCOL_VERSION:
		return
	var seen_players: Dictionary = {}
	var player_snapshots: Array = snapshot.get("players", [])
	for item in player_snapshots:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var player_snapshot: Dictionary = item
		var entity_id := int(player_snapshot.get("entity_id", 0))
		if entity_id == 0:
			continue
		seen_players[entity_id] = true
		var player := _ensure_client_player(entity_id, entity_id == local_entity_id)
		_apply_client_player_snapshot(player, player_snapshot, entity_id == local_entity_id)
	_prune_client_players(seen_players)

	var seen_zombies: Dictionary = {}
	var zombie_snapshots: Array = snapshot.get("zombies", [])
	for item in zombie_snapshots:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var zombie_snapshot: Dictionary = item
		var zombie_id := int(zombie_snapshot.get("entity_id", 0))
		if zombie_id == 0:
			continue
		seen_zombies[zombie_id] = true
		var zombie := _ensure_client_zombie(zombie_snapshot)
		if zombie != null:
			if zombie.has_method("apply_network_snapshot"):
				zombie.call("apply_network_snapshot", zombie_snapshot)
			var interpolator := zombie.get_node_or_null("NetworkInterpolator")
			if interpolator != null:
				interpolator.call("push_snapshot", zombie_snapshot)
	_prune_client_zombies(seen_zombies)

	if _horde != null and _horde.has_method("apply_replica_snapshot"):
		_horde.call("apply_replica_snapshot", Dictionary(snapshot.get("horde", {})))
	if player_snapshots.size() >= 2 and not _snapshot_two_players_logged:
		_snapshot_two_players_logged = true
		print("DEADFALL_DUO_SNAPSHOT players=%d zombies=%d" % [player_snapshots.size(), zombie_snapshots.size()])

func _on_local_command(command: Dictionary) -> void:
	if role == Role.CLIENT and local_entity_id != 0:
		rpc_id(SERVER_PEER_ID, "_server_submit_command", command)

func _on_local_shot_intent(intent) -> void:
	if role != Role.CLIENT or local_entity_id == 0 or intent == null:
		return
	rpc_id(SERVER_PEER_ID, "_server_fire_request", int(intent.sequence), int(intent.simulation_tick))

func _on_local_reload_started() -> void:
	if role != Role.CLIENT or local_entity_id == 0:
		return
	_reload_request_sequence += 1
	rpc_id(SERVER_PEER_ID, "_server_reload_request", _reload_request_sequence)

func _build_server_snapshot() -> Dictionary:
	var players: Array = []
	for peer_id in _peers.keys():
		var record: Dictionary = _peers[peer_id]
		var player = record.get("player")
		if player == null or not is_instance_valid(player):
			continue
		var state: Dictionary = player.call("get_network_snapshot") if player.has_method("get_network_snapshot") else {}
		state["entity_id"] = int(record.get("entity_id", 0))
		state["peer_id"] = int(peer_id)
		state["name"] = String(record.get("name", "Player"))
		var health := player.get_node_or_null("Health")
		if health != null:
			state["health"] = float(health.get("current_health"))
			state["max_health"] = float(health.get("max_health"))
			state["dead"] = bool(health.call("is_dead")) if health.has_method("is_dead") else false
		var weapon := player.get_node_or_null("PrimaryWeapon")
		if weapon != null and weapon.has_method("get_authoritative_state"):
			state["weapon"] = weapon.call("get_authoritative_state")
		players.append(state)

	var zombies: Array = []
	if _zombies_root != null:
		for child in _zombies_root.get_children():
			if child.has_method("get_network_snapshot"):
				zombies.append(child.call("get_network_snapshot"))
	return {
		"protocol": PROTOCOL_VERSION,
		"server_tick": _server_tick,
		"room_code": room_code,
		"players": players,
		"zombies": zombies,
		"horde": _horde.call("get_status_snapshot") if _horde != null and _horde.has_method("get_status_snapshot") else {},
	}

func _ensure_client_player(entity_id: int, local_player: bool) -> Node3D:
	if _players_root == null:
		return null
	var existing := _players_root.get_node_or_null("Player_%d" % entity_id) as Node3D
	if existing != null:
		return existing
	var mode := PlayerControllerScript.ControlMode.NETWORK_PREDICTED if local_player else PlayerControllerScript.ControlMode.REMOTE_PROXY
	var player := _spawn_player(entity_id, mode, 0)
	if player != null and not local_player:
		_attach_interpolator(player)
	return player

func _spawn_player(entity_id: int, control_mode: int, slot: int) -> Node3D:
	if _players_root == null:
		return null
	var player := PlayerScene.instantiate() as Node3D
	if player == null:
		return null
	player.name = "Player_%d" % entity_id
	player.set("player_entity_id", entity_id)
	player.set("control_mode", control_mode)
	var health := player.get_node_or_null("Health")
	if health != null:
		health.set("entity_id", entity_id)
	var weapon := player.get_node_or_null("PrimaryWeapon")
	if weapon != null:
		weapon.set("shooter_entity_id", entity_id)
	_players_root.add_child(player)
	var spawn := _spawn_for_slot(slot)
	if spawn != null:
		player.global_transform = spawn.global_transform
	if player.has_method("configure_network_identity"):
		player.call("configure_network_identity", entity_id, control_mode)
	return player

func _apply_client_player_snapshot(player: Node3D, snapshot: Dictionary, local_player: bool) -> void:
	if player == null:
		return
	if local_player and player.has_method("apply_authoritative_snapshot"):
		player.call("apply_authoritative_snapshot", snapshot)
	elif not local_player:
		var interpolator := player.get_node_or_null("NetworkInterpolator")
		if interpolator != null:
			interpolator.call("push_snapshot", snapshot)
	var network_authority = Game.authority
	if network_authority != null and network_authority.has_method("apply_health_snapshot"):
		network_authority.call("apply_health_snapshot", int(snapshot.get("entity_id", 0)), float(snapshot.get("health", 100.0)), float(snapshot.get("max_health", 100.0)), bool(snapshot.get("dead", false)))
	var weapon := player.get_node_or_null("PrimaryWeapon")
	if weapon != null and weapon.has_method("apply_authoritative_state"):
		weapon.call("apply_authoritative_state", Dictionary(snapshot.get("weapon", {})))

func _ensure_client_zombie(snapshot: Dictionary) -> Node3D:
	if _zombies_root == null:
		return null
	var entity_id := int(snapshot.get("entity_id", 0))
	var existing := _zombies_root.get_node_or_null("Zombie_%d" % entity_id) as Node3D
	if existing != null:
		return existing
	var zombie := ZombieScene.instantiate() as Node3D
	if zombie == null:
		return null
	zombie.name = "Zombie_%d" % entity_id
	zombie.set("entity_id", entity_id)
	var archetype_id := StringName(snapshot.get("archetype_id", &"walker"))
	zombie.set("zombie_data", ARCHETYPE_DATA.get(archetype_id, WalkerData))
	var health := zombie.get_node_or_null("Health")
	if health != null:
		health.set("entity_id", entity_id)
	_zombies_root.add_child(zombie)
	_attach_interpolator(zombie)
	return zombie

func _attach_interpolator(target: Node3D) -> void:
	if target.get_node_or_null("NetworkInterpolator") != null:
		return
	var interpolator := InterpolatorScript.new()
	interpolator.name = "NetworkInterpolator"
	target.add_child(interpolator)
	interpolator.call("bind_target", target)

func _bind_local_player(player: Node3D) -> void:
	if player == null:
		return
	if player.has_signal("local_command_generated"):
		var command_callable := Callable(self, "_on_local_command")
		if not player.is_connected("local_command_generated", command_callable):
			player.connect("local_command_generated", command_callable)
	var weapon := player.get_node_or_null("PrimaryWeapon")
	if weapon != null:
		var shot_callable := Callable(self, "_on_local_shot_intent")
		if weapon.has_signal("shot_intent_created") and not weapon.is_connected("shot_intent_created", shot_callable):
			weapon.connect("shot_intent_created", shot_callable)
		var reload_callable := Callable(self, "_on_local_reload_started")
		if weapon.has_signal("reload_started") and not weapon.is_connected("reload_started", reload_callable):
			weapon.connect("reload_started", reload_callable)

func _build_client_huds(player: Node3D) -> void:
	if DisplayServer.get_name() == "headless" or player == null:
		return
	var arena := get_parent()
	if arena.get_node_or_null("MobileHUD") == null:
		var mobile := MobileHUDScene.instantiate()
		mobile.name = "MobileHUD"
		mobile.set("player_path", NodePath("../NetworkPlayers/%s" % player.name))
		arena.add_child(mobile)
	if arena.get_node_or_null("HordeHUD") == null:
		var horde_hud := HordeHUDScene.instantiate()
		horde_hud.name = "HordeHUD"
		horde_hud.set("director_path", NodePath("../HordeDirector"))
		horde_hud.set("restart_handler_path", NodePath("../NetworkSession"))
		arena.add_child(horde_hud)

func _restore_server_player(player: Node3D, snapshot: Dictionary) -> void:
	if player == null or snapshot.is_empty():
		return
	if player.has_method("restore_authoritative_snapshot"):
		player.call("restore_authoritative_snapshot", snapshot)
	var health := player.get_node_or_null("Health")
	if health != null and health.has_method("restore_authoritative_state"):
		health.call("restore_authoritative_state", float(snapshot.get("health", 100.0)), float(snapshot.get("max_health", 100.0)), bool(snapshot.get("dead", false)))
	var weapon := player.get_node_or_null("PrimaryWeapon")
	if weapon != null and weapon.has_method("restore_authoritative_state"):
		weapon.call("restore_authoritative_state", Dictionary(snapshot.get("weapon", {})))

func _capture_server_player(player: Node3D) -> Dictionary:
	if player == null or not is_instance_valid(player):
		return {}
	var snapshot: Dictionary = player.call("get_network_snapshot") if player.has_method("get_network_snapshot") else {}
	var health := player.get_node_or_null("Health")
	if health != null:
		snapshot["health"] = float(health.get("current_health"))
		snapshot["max_health"] = float(health.get("max_health"))
		snapshot["dead"] = bool(health.call("is_dead")) if health.has_method("is_dead") else false
	var weapon := player.get_node_or_null("PrimaryWeapon")
	if weapon != null and weapon.has_method("get_authoritative_state"):
		snapshot["weapon"] = weapon.call("get_authoritative_state")
	return snapshot

func _on_server_peer_disconnected(peer_id: int) -> void:
	if role != Role.SERVER or not _peers.has(peer_id):
		return
	var record: Dictionary = _peers[peer_id]
	_peers.erase(peer_id)
	var player = record.get("player")
	var token := String(record.get("token", ""))
	if not token.is_empty():
		_resume_records[token] = {
			"entity_id": int(record.get("entity_id", 0)),
			"expires_usec": Time.get_ticks_usec() + int(RECONNECT_GRACE_SECONDS * 1_000_000.0),
			"snapshot": _capture_server_player(player),
		}
	if _horde != null and player != null and _horde.has_method("unregister_player"):
		_horde.call("unregister_player", player)
	if player != null and is_instance_valid(player):
		player.queue_free()
	if _peers.is_empty() and _horde != null and _horde.has_method("stop_run"):
		_horde.call("stop_run", "empty_room")
	print("DEADFALL_DUO_SERVER_LEAVE peer=%d players=%d" % [peer_id, _peers.size()])

func _cleanup_expired_resume_records() -> void:
	var now := Time.get_ticks_usec()
	for token in _resume_records.keys():
		var record: Dictionary = _resume_records[token]
		if int(record.get("expires_usec", 0)) <= now:
			_resume_records.erase(token)

func _prune_client_players(seen: Dictionary) -> void:
	if _players_root == null:
		return
	for child in _players_root.get_children():
		var entity_id := int(child.get("player_entity_id"))
		if entity_id != local_entity_id and not seen.has(entity_id):
			child.queue_free()

func _prune_client_zombies(seen: Dictionary) -> void:
	if _zombies_root == null:
		return
	for child in _zombies_root.get_children():
		var entity_id := int(child.get("entity_id"))
		if entity_id != 0 and not seen.has(entity_id):
			child.queue_free()

func _spawn_for_slot(slot: int) -> Node3D:
	if _spawn_root == null or _spawn_root.get_child_count() == 0:
		return null
	return _spawn_root.get_child(clampi(slot, 0, _spawn_root.get_child_count() - 1)) as Node3D

func _first_free_slot() -> int:
	var used: Dictionary = {}
	for record in _peers.values():
		used[int(record.get("slot", 0))] = true
	for slot in range(MAX_PLAYERS):
		if not used.has(slot):
			return slot
	return 0

func _allocate_entity_id() -> int:
	var result := _next_entity_id
	_next_entity_id += 1
	return result

func _generate_resume_token() -> String:
	var crypto := Crypto.new()
	return crypto.generate_random_bytes(18).hex_encode()

func _resume_token_path() -> String:
	return "user://duo_resume_token.txt"

func _save_resume_token(token: String) -> void:
	var file := FileAccess.open(_resume_token_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(token)

func _load_resume_token() -> String:
	if not FileAccess.file_exists(_resume_token_path()):
		return ""
	var file := FileAccess.open(_resume_token_path(), FileAccess.READ)
	return file.get_as_text().strip_edges() if file != null else ""
