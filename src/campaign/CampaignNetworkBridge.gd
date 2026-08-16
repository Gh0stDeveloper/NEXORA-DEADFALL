class_name DeadfallCampaignNetworkBridge
extends Node

@export var director_path := NodePath("../CampaignDirector")
@export var snapshot_hz := 8.0

var _director: Node
var _elapsed := 0.0
var _client_snapshot_logged := false

func _ready() -> void:
	_director = get_node_or_null(director_path)

func _physics_process(delta: float) -> void:
	if not Game.is_dedicated_server() or _director == null or not _director.has_method("get_status_snapshot"):
		return
	_elapsed += delta
	var interval := 1.0 / maxf(1.0, snapshot_hz)
	if _elapsed < interval:
		return
	_elapsed = 0.0
	rpc("_client_campaign_snapshot", _director.call("get_status_snapshot"))

@rpc("authority", "call_remote", "unreliable_ordered", 3)
func _client_campaign_snapshot(snapshot: Dictionary) -> void:
	if not Game.is_network_client() or _director == null or not _director.has_method("apply_replica_snapshot"):
		return
	_director.call("apply_replica_snapshot", snapshot)
	if not _client_snapshot_logged:
		_client_snapshot_logged = true
		print("DEADFALL_CAMPAIGN_SNAPSHOT mission=%s objective=%d state=%s" % [String(snapshot.get("mission_id", "")), int(snapshot.get("objective_index", 0)), String(snapshot.get("state_name", ""))])
