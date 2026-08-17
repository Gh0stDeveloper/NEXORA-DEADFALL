extends SceneTree

const BuildInfoScript = preload("res://src/release/BuildInfo.gd")
const AbuseGuardScript = preload("res://src/network/NetworkAbuseGuard.gd")
const PlayerCommandScript = preload("res://src/network/PlayerCommand.gd")
const SaveStoreScript = preload("res://src/campaign/CampaignSaveStore.gd")
const RoomCodeScript = preload("res://src/network/RoomCodeService.gd")
const SQUAD_ARENA_PATH := "res://src/maps/duo/DuoArena.tscn"
const CAMPAIGN_ARENA_PATH := "res://src/maps/campaign/OutbreakDistrict.tscn"
const HARDENED_SESSION_PATH := "res://src/network/ClosedBetaNetworkSession.gd"
const MTU_SAFE_SESSION_PATH := "res://src/network/MtuSafeClosedBetaNetworkSession.gd"
const MTU_SAFE_CHUNK_BYTES := 900

func _initialize() -> void:
	if not _test_build_compatibility(): return
	if not _test_abuse_guard(): return
	if not _test_command_shape(): return
	if not _test_save_recovery(): return
	if not _test_directory_build_contract(): return
	if not _test_scene_session_contract(): return
	if not _test_release_contract(): return
	if not _test_beta_runtime(): return
	print("NEXORA: DEADFALL closed beta hardening smoke passed")
	quit(0)

func _test_build_compatibility() -> bool:
	if BuildInfoScript.APP_VERSION.is_empty() or BuildInfoScript.VERSION_CODE <= 0:
		return _fail("Closed beta build identity is missing")
	if BuildInfoScript.VERSION_CODE < BuildInfoScript.MIN_CLIENT_VERSION_CODE or BuildInfoScript.VERSION_CODE > BuildInfoScript.MAX_CLIENT_VERSION_CODE:
		return _fail("Current build version is outside the accepted client range")
	if not bool(BuildInfoScript.validate_client(BuildInfoScript.NETWORK_PROTOCOL, BuildInfoScript.VERSION_CODE, BuildInfoScript.CONTENT_VERSION).get("compatible", false)):
		return _fail("Current closed beta client was rejected")
	if bool(BuildInfoScript.validate_client(BuildInfoScript.NETWORK_PROTOCOL + 1, BuildInfoScript.VERSION_CODE, BuildInfoScript.CONTENT_VERSION).get("compatible", true)):
		return _fail("Wrong network protocol was accepted")
	if bool(BuildInfoScript.validate_client(BuildInfoScript.NETWORK_PROTOCOL, BuildInfoScript.VERSION_CODE, BuildInfoScript.CONTENT_VERSION + 1).get("compatible", true)):
		return _fail("Wrong content version was accepted")
	if BuildInfoScript.MIN_CLIENT_VERSION_CODE > 0 and bool(BuildInfoScript.validate_client(BuildInfoScript.NETWORK_PROTOCOL, BuildInfoScript.MIN_CLIENT_VERSION_CODE - 1, BuildInfoScript.CONTENT_VERSION).get("compatible", true)):
		return _fail("Obsolete client version was accepted")
	if BuildInfoScript.VERSION_CODE != 900004 or BuildInfoScript.APP_VERSION != "0.9.0-beta.4":
		return _fail("Current feature candidate must remain 0.9.0-beta.4 / 900004")
	if BuildInfoScript.MIN_CLIENT_VERSION_CODE != BuildInfoScript.VERSION_CODE or BuildInfoScript.MIN_SERVER_VERSION_CODE != BuildInfoScript.VERSION_CODE:
		return _fail("Beta.4 compatibility floor must reject older beta.3 gameplay clients/servers")
	return true

func _test_abuse_guard() -> bool:
	var guard = AbuseGuardScript.new()
	var peer := 44
	for index in range(180):
		if not guard.allow(peer, &"command", 1_000_000 + index):
			return _fail("Normal command burst was rejected before configured limit")
	var rejected := 0
	for index in range(12):
		if not guard.allow(peer, &"command", 1_000_500 + index):
			rejected += 1
	if rejected == 0:
		return _fail("Command flood was not rate-limited")
	if not guard.should_disconnect(peer):
		return _fail("Sustained abuse did not reach disconnect threshold")
	guard.forget_peer(peer)
	if int(guard.get_peer_snapshot(peer).get("strikes", -1)) != 0:
		return _fail("Peer abuse state was not cleared on disconnect")
	return true

func _test_command_shape() -> bool:
	var valid := {"sequence": 10, "client_tick": 20, "move": Vector2(0.4, -1.0), "yaw": 0.2, "pitch": 0.1, "sprint": true, "interact": false, "jump_serial": 1, "crouch_serial": 0, "prone_serial": 0}
	if not PlayerCommandScript.validate_shape(valid, 9):
		return _fail("Valid command shape rejected")
	if PlayerCommandScript.validate_shape({"sequence": 11, "move": "not-a-vector"}, 10):
		return _fail("Malformed move payload accepted")
	if PlayerCommandScript.validate_shape({"sequence": 11, "move": Vector2.ZERO, "admin": true}, 10):
		return _fail("Unknown command field accepted")
	if PlayerCommandScript.validate_shape({"sequence": 10, "move": Vector2.ZERO}, 10):
		return _fail("Duplicate command sequence accepted")
	if PlayerCommandScript.validate_shape({"sequence": 2000, "move": Vector2.ZERO}, 10):
		return _fail("Implausible sequence jump accepted")
	return true

func _test_save_recovery() -> bool:
	var slot := "phase9_hardening_ci"
	SaveStoreScript.clear_progress(slot)
	if not SaveStoreScript.save_progress(slot, {"checkpoint_id": "alpha", "objective_index": 1}):
		return _fail("Unable to write first hardened campaign save")
	if not SaveStoreScript.save_progress(slot, {"checkpoint_id": "bravo", "objective_index": 2}):
		return _fail("Unable to write second hardened campaign save")
	var path := SaveStoreScript.get_path_for_slot(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _fail("Unable to corrupt save for recovery test")
	file.store_string("{corrupt")
	file.close()
	var recovered := SaveStoreScript.load_progress(slot)
	if String(recovered.get("checkpoint_id", "")) != "alpha" or int(recovered.get("objective_index", -1)) != 1:
		return _fail("Corrupt primary save did not recover from last valid backup")
	SaveStoreScript.clear_progress(slot)
	return true

func _test_directory_build_contract() -> bool:
	var payload := BuildInfoScript.snapshot()
	payload.merge({"ok": true, "room_code": "ABC234", "host": "127.0.0.1", "port": 24560}, true)
	var endpoint := RoomCodeScript.parse_resolution_payload(JSON.stringify(payload))
	if endpoint.is_empty() or int(endpoint.get("version_code", 0)) != BuildInfoScript.VERSION_CODE:
		return _fail("Compatible directory build metadata was rejected")
	payload["version_code"] = BuildInfoScript.MIN_SERVER_VERSION_CODE - 1
	if not RoomCodeScript.parse_resolution_payload(JSON.stringify(payload)).is_empty():
		return _fail("Obsolete directory/server build metadata was accepted")
	return true

func _test_scene_session_contract() -> bool:
	var hardened_script := load(HARDENED_SESSION_PATH) as Script
	if hardened_script == null or not hardened_script.can_instantiate():
		return _fail("Closed Beta hardened base session could not compile")
	var mtu_script := load(MTU_SAFE_SESSION_PATH) as Script
	if mtu_script == null or not mtu_script.can_instantiate():
		return _fail("MTU-safe Closed Beta session could not compile")
	var mtu_file := FileAccess.open(MTU_SAFE_SESSION_PATH, FileAccess.READ)
	var mtu_source := mtu_file.get_as_text() if mtu_file != null else ""
	if not mtu_source.contains("extends \"%s\"" % HARDENED_SESSION_PATH):
		return _fail("MTU-safe session no longer inherits the Closed Beta hardened session")
	if not mtu_source.contains("const SNAPSHOT_CHUNK_BYTES := %d" % MTU_SAFE_CHUNK_BYTES):
		return _fail("MTU-safe session chunk budget changed unexpectedly")
	if not mtu_source.contains("\"encoding\": \"variant_fastlz_chunks\"") or not mtu_source.contains("\"chunk_bytes\": SNAPSHOT_CHUNK_BYTES"):
		return _fail("MTU-safe Closed Beta transport status contract is missing")

	for scene_path in [SQUAD_ARENA_PATH, CAMPAIGN_ARENA_PATH]:
		var scene: PackedScene = load(scene_path) as PackedScene
		if scene == null:
			return _fail("Network arena could not be loaded: %s" % scene_path)
		var instance: Node = scene.instantiate()
		if instance == null:
			return _fail("Network arena could not be instantiated: %s" % scene_path)
		root.add_child(instance)
		var session: Node = instance.get_node_or_null("NetworkSession")
		if session == null or session.get_script() == null or String(session.get_script().resource_path) != MTU_SAFE_SESSION_PATH:
			instance.free()
			return _fail("Network arena is not using the MTU-safe Closed Beta hardened session: %s" % scene_path)
		for method in ["configure_server", "start_client", "get_status_snapshot"]:
			if not session.has_method(method):
				instance.free()
				return _fail("MTU-safe Closed Beta session missing hardened method: %s" % method)
		instance.free()
	return true

func _test_release_contract() -> bool:
	var required := [
		"res://.github/workflows/closed-beta-release.yml",
		"res://docs/BETA_HARDENING.md",
		"res://docs/beta/COMPATIBILITY_MATRIX.md",
		"res://docs/beta/TESTER_GUIDE.md",
		"res://docs/beta/RELEASE_CHECKLIST.md",
		"res://docs/legal/PRIVACY_POLICY.md",
		"res://docs/legal/TERMS_OF_BETA.md",
		"res://docs/legal/CODE_OF_CONDUCT.md",
		"res://docs/store/PLAY_LISTING.md",
		"res://docs/store/CONTENT_RATING_NOTES.md",
	]
	for path in required:
		if not FileAccess.file_exists(path):
			return _fail("Closed beta release asset missing: %s" % path)
	var preset_file := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
	if preset_file == null:
		return _fail("export_presets.cfg missing")
	var presets := preset_file.get_as_text()
	var required_tokens := [
		"Android Closed Beta",
		"Android Closed Beta APK",
		"gradle_build/target_sdk=\"%d\"" % BuildInfoScript.TARGET_ANDROID_API,
		"version/code=%d" % BuildInfoScript.VERSION_CODE,
		"version/name=\"%s\"" % BuildInfoScript.APP_VERSION,
	]
	for token in required_tokens:
		if presets.find(token) < 0:
			return _fail("Closed beta export preset missing token: %s" % token)
	return true

func _test_beta_runtime() -> bool:
	var runtime := root.get_node_or_null("BetaRuntime")
	if runtime == null or not runtime.has_method("get_status_snapshot"):
		return _fail("BetaRuntime autoload missing")
	var snapshot: Dictionary = runtime.call("get_status_snapshot")
	var build: Dictionary = snapshot.get("build", {})
	if String(build.get("app_version", "")) != BuildInfoScript.APP_VERSION or int(build.get("version_code", 0)) != BuildInfoScript.VERSION_CODE or int(build.get("target_android_api", 0)) != BuildInfoScript.TARGET_ANDROID_API:
		return _fail("BetaRuntime build/device snapshot mismatch")
	return true

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
