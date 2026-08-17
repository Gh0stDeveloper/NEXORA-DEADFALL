extends SceneTree

const TRANSPORT_PATH := "res://src/network/MtuSafeClosedBetaNetworkSession.gd"
const CAMPAIGN_SCENE_PATH := "res://src/maps/campaign/OutbreakDistrict.tscn"
const EXPECTED_CHUNK_BYTES := 900

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var transport_script := load(TRANSPORT_PATH) as Script
	if transport_script == null or not transport_script.can_instantiate():
		_fail("MTU-safe Closed Beta transport could not compile/instantiate")
		return
	if int(transport_script.get("SNAPSHOT_CHUNK_BYTES")) != EXPECTED_CHUNK_BYTES:
		_fail("MTU-safe transport chunk contract changed")
		return

	var campaign_scene := load(CAMPAIGN_SCENE_PATH) as PackedScene
	if campaign_scene == null:
		_fail("Campaign arena could not load with MTU-safe transport")
		return
	var arena := campaign_scene.instantiate()
	if arena == null:
		_fail("Campaign arena could not instantiate with MTU-safe transport")
		return
	root.add_child(arena)
	var session := arena.get_node_or_null("NetworkSession")
	if session == null:
		_fail("Campaign arena NetworkSession missing")
		return
	var script := session.get_script() as Script
	if script == null or script.resource_path != TRANSPORT_PATH:
		_fail("Campaign arena is not wired to MTU-safe Closed Beta transport")
		return
	for method in ["start_client", "configure_server", "get_status_snapshot"]:
		if not session.has_method(method):
			_fail("MTU-safe transport missing method: %s" % method)
			return

	# Validate the exact serialization/compression/decompression primitive used
	# by the wire path against the Godot runtime installed on the VPS.
	var sample := {
		"server_tick": 123,
		"players": [{"entity_id": 101, "position": Vector3(1, 2, 3)}],
		"zombies": [],
	}
	var raw := var_to_bytes(sample)
	var compressed := raw.compress(FileAccess.COMPRESSION_FASTLZ)
	var restored := compressed.decompress(raw.size(), FileAccess.COMPRESSION_FASTLZ)
	if restored != raw:
		_fail("FastLZ snapshot round-trip failed")
		return
	var decoded: Variant = bytes_to_var(restored)
	if typeof(decoded) != TYPE_DICTIONARY or int(Dictionary(decoded).get("server_tick", 0)) != 123:
		_fail("Godot 4.6 snapshot bytes_to_var round-trip failed")
		return

	arena.free()
	print("NEXORA: DEADFALL Phase 11.3 MTU-safe network transport smoke passed")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
