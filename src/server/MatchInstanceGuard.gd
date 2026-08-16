class_name DeadfallMatchInstanceGuard
extends Node

const STARTUP_GRACE_SECONDS := 90.0
const EMPTY_GRACE_SECONDS := 75.0
const MAX_MATCH_SECONDS := 60.0 * 60.0 * 2.0

var network_session: Node
var match_id := ""
var _started_usec := 0
var _ever_had_player := false
var _empty_since_usec := 0

func configure(session: Node, configured_match_id: String) -> void:
	network_session = session
	match_id = configured_match_id
	_started_usec = Time.get_ticks_usec()
	set_process(true)

func _process(_delta: float) -> void:
	if network_session == null or not is_instance_valid(network_session):
		return
	var now := Time.get_ticks_usec()
	var elapsed := float(now - _started_usec) / 1_000_000.0
	if elapsed >= MAX_MATCH_SECONDS:
		_shutdown("absolute_timeout")
		return
	var connected := 0
	if network_session.has_method("get_status_snapshot"):
		connected = int(Dictionary(network_session.call("get_status_snapshot")).get("connected_players", 0))
	if connected > 0:
		_ever_had_player = true
		_empty_since_usec = 0
		return
	if not _ever_had_player:
		if elapsed >= STARTUP_GRACE_SECONDS:
			_shutdown("startup_timeout")
		return
	if _empty_since_usec == 0:
		_empty_since_usec = now
		return
	if float(now - _empty_since_usec) / 1_000_000.0 >= EMPTY_GRACE_SECONDS:
		_shutdown("empty_timeout")

func _shutdown(reason: String) -> void:
	print("DEADFALL_MATCH_INSTANCE_EXIT match=%s reason=%s" % [match_id, reason])
	get_tree().quit(0)
