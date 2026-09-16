extends SceneTree

const BASE_TRANSPORT_PATH := "res://src/network/MtuSafeClosedBetaNetworkSession.gd"
const LIFECYCLE_SESSION_PATH := "res://src/network/LifecycleMtuSafeNetworkSession.gd"
const CAMPAIGN_SCENE_PATH := "res://src/maps/campaign/OutbreakDistrict.tscn"
const EXPECTED_CHUNK_BYTES := 900

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var transport_script := load(BASE_TRANSPORT_PATH) as Script
	if transport_script == null or not transport_script.can_instantiate():
		_fail("MTU-safe Closed Beta transport could not compile/instantiate")
		return
	var lifecycle_script := load(LIFECYCLE_SESSION_PATH) as Script
	if lifecycle_script == null or not lifecycle_script.can_instantiate():
		_fail("Beta.5 lifecycle transport could not compile/instantiate")
		return

	var transport_file := FileAccess.open(BASE_TRANSPORT_PATH, FileAccess.READ)
	var transport_text := transport_file.get_as_text() if transport_file != null else ""
	if not transport_text.contains("const SNAPSHOT_CHUNK_BYTES := %d" % EXPECTED_CHUNK_BYTES):
		_fail("MTU-safe transport chunk contract changed")
		return
	for required_token in [
		"_build_server_snapshot_with_pickups",
		"snapshot[\"pickups\"]",
		"_sync_pickups(snapshot)",
		"state[\"loadout\"]",
		"apply_authoritative_state",
		"_server_loadout_fire",
		"_server_loadout_reload",
		"_server_loadout_melee",
		"_server_loadout_switch",
	]:
		if not transport_text.contains(required_token):
			_fail("MTU-safe online weapon/pickup replication contract missing token: %s" % required_token)
			return

	var lifecycle_file := FileAccess.open(LIFECYCLE_SESSION_PATH, FileAccess.READ)
	var lifecycle_text := lifecycle_file.get_as_text() if lifecycle_file != null else ""
	if not lifecycle_text.contains("extends \"%s\"" % BASE_TRANSPORT_PATH):
		_fail("Beta.5 lifecycle session no longer layers on MTU-safe transport")
		return
	for lifecycle_token in ["match_finished", "publish_match_result", "match_ticket", "orchestrated_reconnects"]:
		if not lifecycle_text.contains(lifecycle_token):
			_fail("Beta.5 lifecycle transport contract missing token: %s" % lifecycle_token)
			return

	var campaign_scene := load(CAMPAIGN_SCENE_PATH) as PackedScene
	if campaign_scene == null:
		_fail("Campaign arena could not load with lifecycle MTU-safe transport")
		return
	var arena := campaign_scene.instantiate()
	if arena == null:
		_fail("Campaign arena could not instantiate with lifecycle MTU-safe transport")
		return
	root.add_child(arena)
	await process_frame
	var session := arena.get_node_or_null("NetworkSession")
	if session == null:
		_fail("Campaign arena NetworkSession missing")
		return
	var script := session.get_script() as Script
	if script == null or script.resource_path != LIFECYCLE_SESSION_PATH:
		_fail("Campaign arena is not wired to beta.5 lifecycle MTU-safe transport")
		return
	for method in ["start_client", "configure_server", "get_status_snapshot", "publish_match_result"]:
		if not session.has_method(method):
			_fail("Lifecycle MTU-safe transport missing method: %s" % method)
			return
	if not session.has_signal("match_finished"):
		_fail("Lifecycle MTU-safe transport missing match_finished signal")
		return
	var status_value = session.call("get_status_snapshot")
	var status: Dictionary = status_value if typeof(status_value) == TYPE_DICTIONARY else {}
	var transport_status: Dictionary = Dictionary(status.get("transport", {}))
	if String(transport_status.get("encoding", "")) != "variant_fastlz_chunks" or int(transport_status.get("chunk_bytes", 0)) != EXPECTED_CHUNK_BYTES:
		_fail("MTU-safe transport runtime status mismatch through lifecycle layer")
		return
	if not bool(transport_status.get("pickup_replication", false)) or not bool(transport_status.get("weapon_loadout_authoritative", false)):
		_fail("Online weapon/pickup replication flags are not active through lifecycle layer")
		return
	var lifecycle_status: Dictionary = Dictionary(status.get("match_lifecycle", {}))
	if not bool(lifecycle_status.get("authoritative_result_rpc", false)):
		_fail("Lifecycle transport status does not advertise authoritative result RPC")
		return

	# Validate the exact serialization/compression/decompression primitive used
	# by the inherited wire path against the Godot runtime installed on the VPS.
	var sample := {
		"server_tick": 123,
		"players": [{
			"entity_id": 101,
			"position": Vector3(1, 2, 3),
			"loadout": {
				"active_slot": 1,
				"primary": {"ammo": 24, "reserve": 96, "last_sequence": 7},
				"secondary": {"ammo": 12, "reserve": 45, "last_sequence": 11},
				"melee": {"weapon_id": "machete", "infinite": true, "last_sequence": 3},
			},
		}],
		"zombies": [],
		"pickups": [{"pickup_id": 700001, "kind": "ammo", "position": Vector3(4, 0.1, -2), "amount": 30}],
	}
	var raw := var_to_bytes(sample)
	var compressed := raw.compress(FileAccess.COMPRESSION_FASTLZ)
	var restored := compressed.decompress(raw.size(), FileAccess.COMPRESSION_FASTLZ)
	if restored != raw:
		_fail("FastLZ snapshot round-trip failed")
		return
	var decoded: Variant = bytes_to_var(restored)
	if typeof(decoded) != TYPE_DICTIONARY:
		_fail("Godot 4.6 snapshot bytes_to_var round-trip failed")
		return
	var decoded_snapshot: Dictionary = Dictionary(decoded)
	if int(decoded_snapshot.get("server_tick", 0)) != 123 or Array(decoded_snapshot.get("pickups", [])).size() != 1:
		_fail("Weapon/pickup snapshot fields were lost during MTU-safe round-trip")
		return
	var decoded_players: Array = Array(decoded_snapshot.get("players", []))
	if decoded_players.is_empty() or typeof(decoded_players[0]) != TYPE_DICTIONARY:
		_fail("Loadout snapshot player payload missing after round-trip")
		return
	var decoded_player: Dictionary = decoded_players[0]
	var decoded_loadout: Dictionary = Dictionary(decoded_player.get("loadout", {}))
	if int(decoded_loadout.get("active_slot", -1)) != 1:
		_fail("Loadout active slot did not survive MTU-safe round-trip")
		return
	var decoded_secondary: Dictionary = Dictionary(decoded_loadout.get("secondary", {}))
	var decoded_melee: Dictionary = Dictionary(decoded_loadout.get("melee", {}))
	if int(decoded_secondary.get("last_sequence", 0)) != 11 or int(decoded_melee.get("last_sequence", 0)) != 3:
		_fail("Authoritative weapon action sequence was lost during MTU-safe round-trip")
		return

	arena.free()
	print("NEXORA: DEADFALL Phase 11.3 MTU-safe network transport smoke passed")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
