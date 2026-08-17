extends SceneTree

const CampaignArenaScene = preload("res://src/maps/campaign/OutbreakDistrict.tscn")
const PROBE_TIMEOUT_SECONDS := 7.0

var _session: Node
var _arena: Node
var _finished := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var host := _arg_value(args, "--host=", "127.0.0.1")
	var port := int(_arg_value(args, "--port=", "0"))
	var ticket := _arg_value(args, "--ticket=")
	var player_name := _arg_value(args, "--name=", "LifecycleProbe")
	if port <= 0:
		_finish(2, "DEADFALL_PHASE12_PROBE_ERROR invalid_port")
		return

	_arena = CampaignArenaScene.instantiate()
	if _arena == null:
		_finish(2, "DEADFALL_PHASE12_PROBE_ERROR arena_instantiate_failed")
		return
	root.add_child(_arena)
	_session = _arena.get_node_or_null("NetworkSession")
	if _session == null or not _session.has_method("start_client"):
		_finish(2, "DEADFALL_PHASE12_PROBE_ERROR session_missing")
		return
	for signal_name in ["joined", "join_failed", "disconnected"]:
		if not _session.has_signal(signal_name):
			_finish(2, "DEADFALL_PHASE12_PROBE_ERROR signal_missing:%s" % signal_name)
			return
	_session.connect("joined", Callable(self, "_on_joined"), CONNECT_ONE_SHOT)
	_session.connect("join_failed", Callable(self, "_on_join_failed"), CONNECT_ONE_SHOT)
	_session.connect("disconnected", Callable(self, "_on_disconnected"), CONNECT_ONE_SHOT)
	var error := int(_session.call("start_client", host, port, player_name, "", ticket))
	if error != OK:
		_finish(2, "DEADFALL_PHASE12_PROBE_ERROR create_client:%s" % error_string(error))
		return
	var timer := create_timer(PROBE_TIMEOUT_SECONDS)
	timer.timeout.connect(_on_timeout, CONNECT_ONE_SHOT)

func _on_joined(entity_id: int, _resume_token: String, room_code: String) -> void:
	if _finished:
		return
	print("DEADFALL_PHASE12_PROBE_JOINED entity=%d room=%s" % [entity_id, room_code])
	_graceful_close()
	await create_timer(0.20).timeout
	_finish(0, "DEADFALL_PHASE12_PROBE_CLOSED entity=%d" % entity_id)

func _on_join_failed(reason: String) -> void:
	if _finished:
		return
	print("DEADFALL_PHASE12_PROBE_REJECTED reason=%s" % reason)
	_graceful_close()
	await create_timer(0.10).timeout
	_finish(0, "DEADFALL_PHASE12_PROBE_CLOSED rejected=%s" % reason)

func _on_disconnected(reason: String) -> void:
	if _finished:
		return
	_finish(3, "DEADFALL_PHASE12_PROBE_ERROR disconnected:%s" % reason)

func _on_timeout() -> void:
	if _finished:
		return
	_graceful_close()
	_finish(4, "DEADFALL_PHASE12_PROBE_ERROR timeout")

func _graceful_close() -> void:
	if _session != null:
		var client_peer := _session.get("_client_peer") as ENetMultiplayerPeer
		if client_peer != null:
			client_peer.close()
	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if Game.is_network_client():
		Game.stop_session()

func _finish(code: int, marker: String) -> void:
	if _finished:
		return
	_finished = true
	print(marker)
	quit(code)

func _arg_value(args: PackedStringArray, prefix: String, fallback: String = "") -> String:
	for arg in args:
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return fallback
