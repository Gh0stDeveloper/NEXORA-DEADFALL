extends SceneTree

const BuildInfoScript = preload("res://src/release/BuildInfo.gd")
const MatchAdmissionScript = preload("res://src/server/MatchAdmission.gd")
const MatchGuardScript = preload("res://src/server/MatchInstanceGuard.gd")
const MatchOrchestratorScript = preload("res://src/server/MatchOrchestrator.gd")
const LifecycleSessionScript = preload("res://src/network/LifecycleMtuSafeNetworkSession.gd")
const LifecycleControlApiScript = preload("res://src/server/LifecycleControlApiServer.gd")
const ResultOverlayScript = preload("res://src/ui/MatchResultOverlay.gd")

class FakeLifecycleSession:
	extends Node
	var published_result: Dictionary = {}
	var connected_players := 2
	var reconnects := 3

	func get_status_snapshot() -> Dictionary:
		return {
			"connected_players": connected_players,
			"reserved_slots": 1,
			"match_lifecycle": {"orchestrated_reconnects": reconnects},
		}

	func publish_match_result(result: Dictionary) -> bool:
		published_result = result.duplicate(true)
		return true

class FakeLifecycleOrchestrator:
	extends Node

	func get_status_snapshot() -> Dictionary:
		return {
			"active_count": 2,
			"heartbeat_stale_seconds": 12,
			"max_match_runtime_seconds": 7230,
			"active_matches": [{"match_id": "private", "pid": 12345}],
			"metrics": {
				"started_total": 7,
				"completed_total": 2,
				"defeated_total": 1,
				"failed_total": 1,
				"frozen_total": 1,
				"crashed_total": 0,
				"reaped_total": 2,
				"reconnects_total": 4,
			},
		}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if BuildInfoScript.APP_VERSION != "0.9.0-beta.5" or BuildInfoScript.VERSION_CODE != 900005:
		_fail("Phase 12 requires beta.5 / 900005")
		return
	if BuildInfoScript.MIN_CLIENT_VERSION_CODE != 900005 or BuildInfoScript.MIN_SERVER_VERSION_CODE != 900005:
		_fail("Phase 12 compatibility floor must reject beta.4")
		return

	var lifecycle_script: Script = LifecycleSessionScript as Script
	if lifecycle_script == null or not lifecycle_script.can_instantiate():
		_fail("Lifecycle MTU-safe session cannot be instantiated")
		return
	var lifecycle_session: Node = lifecycle_script.new() as Node
	if lifecycle_session == null:
		_fail("Lifecycle MTU-safe session instance is not a Node")
		return
	if not lifecycle_session.has_signal("match_finished") or not lifecycle_session.has_method("publish_match_result"):
		_fail("Lifecycle session lost authoritative result signal/method")
		return
	var lifecycle_status: Dictionary = Dictionary(lifecycle_session.call("get_status_snapshot"))
	var lifecycle_contract: Dictionary = Dictionary(lifecycle_status.get("match_lifecycle", {}))
	if not bool(lifecycle_contract.get("authoritative_result_rpc", false)):
		_fail("Lifecycle session does not advertise authoritative result RPC")
		return
	lifecycle_session.free()

	var temp_dir: String = ProjectSettings.globalize_path("user://ci_phase12")
	DirAccess.make_dir_recursive_absolute(temp_dir)
	var match_id := "mtc_phase12_ci"
	var config_path := "%s/%s.json" % [temp_dir, match_id]
	var ready_path := "%s.ready" % config_path
	var heartbeat_path := "%s.heartbeat" % config_path
	var result_path := "%s.result" % config_path
	var ticket := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	_cleanup([config_path, ready_path, heartbeat_path, result_path, heartbeat_path + ".tmp", result_path + ".tmp"])
	var config: Dictionary = {
		"schema_version": 2,
		"match_id": match_id,
		"party_code": "ABC234",
		"public_host": "203.0.113.10",
		"port": 24642,
		"mission_id": "mission_01_first_signal",
		"created_unix": int(Time.get_unix_time_from_system()),
		"ready_path": ready_path,
		"heartbeat_path": heartbeat_path,
		"result_path": result_path,
		"members": [{
			"guest_id": "guest_phase12",
			"public_id": "NXR-PHASE12",
			"username": "Phase12",
			"selected_character": "operator_01",
			"ticket": ticket,
		}],
	}
	var config_file: FileAccess = FileAccess.open(config_path, FileAccess.WRITE)
	if config_file == null:
		_fail("Unable to create Phase 12 admission config")
		return
	config_file.store_string(JSON.stringify(config, "\t"))
	config_file.close()

	var admission: RefCounted = MatchAdmissionScript.new() as RefCounted
	if admission == null or not admission.has_method("load_from_file") or not bool(admission.call("load_from_file", config_path)):
		_fail("MatchAdmission rejected schema v2 lifecycle config")
		return
	var admitted: Dictionary = Dictionary(admission.call("validate_ticket", ticket))
	if String(admitted.get("guest_id", "")) != "guest_phase12":
		_fail("Identity-bound ticket was not resolved")
		return
	var admission_snapshot: Dictionary = Dictionary(admission.call("snapshot"))
	if String(admission_snapshot.get("heartbeat_path", "")) != heartbeat_path or String(admission_snapshot.get("result_path", "")) != result_path:
		_fail("Admission snapshot lost heartbeat/result IPC paths")
		return

	var fake: FakeLifecycleSession = FakeLifecycleSession.new()
	root.add_child(fake)
	var guard: Node = MatchGuardScript.new() as Node
	if guard == null:
		_fail("Match guard could not instantiate")
		return
	root.add_child(guard)
	guard.call("configure", fake, match_id, heartbeat_path, result_path, null, null)
	guard.call("_write_heartbeat", "RUNNING")
	var heartbeat: Dictionary = _read_json(heartbeat_path)
	if String(heartbeat.get("match_id", "")) != match_id or int(heartbeat.get("connected_players", 0)) != 2:
		_fail("Match heartbeat does not contain authoritative runtime state")
		return
	if int(heartbeat.get("orchestrated_reconnects", -1)) != 3:
		_fail("Match heartbeat does not export reconnect telemetry")
		return
	guard.call("_finalize_result", "VICTORY", "phase12_ci", "mission_01_first_signal", 5, 1234, 27)
	var result: Dictionary = _read_json(result_path)
	if String(result.get("outcome", "")) != "VICTORY" or int(result.get("score", 0)) != 1234 or not bool(result.get("server_authoritative", false)):
		_fail("Authoritative result IPC payload is invalid")
		return
	if String(fake.published_result.get("match_id", "")) != match_id or String(fake.published_result.get("outcome", "")) != "VICTORY":
		_fail("Match guard did not publish the same authoritative result to the network session")
		return
	guard.queue_free()
	fake.queue_free()
	await process_frame

	var orchestrator: Node = MatchOrchestratorScript.new() as Node
	if orchestrator == null:
		_fail("Match orchestrator could not instantiate")
		return
	var orchestrator_status: Dictionary = Dictionary(orchestrator.call("get_status_snapshot"))
	var metrics: Dictionary = Dictionary(orchestrator_status.get("metrics", {}))
	for key in ["started_total", "completed_total", "defeated_total", "failed_total", "frozen_total", "crashed_total", "reaped_total", "reconnects_total"]:
		if not metrics.has(key):
			_fail("Lifecycle metric missing: %s" % key)
			return
	if int(orchestrator_status.get("heartbeat_stale_seconds", 0)) <= 0 or int(orchestrator_status.get("max_match_runtime_seconds", 0)) <= 0:
		_fail("Orchestrator watchdog/TTL status contract missing")
		return
	orchestrator.free()

	var fake_orchestrator: FakeLifecycleOrchestrator = FakeLifecycleOrchestrator.new()
	var control_api: Node = LifecycleControlApiScript.new() as Node
	if control_api == null:
		_fail("Lifecycle control API could not instantiate")
		return
	control_api.call("configure", null, null, fake_orchestrator)
	var health: Dictionary = Dictionary(control_api.call("_route", "GET", "/v1/health", "", {}))
	var public_lifecycle: Dictionary = Dictionary(health.get("match_lifecycle", {}))
	if not bool(health.get("ok", false)) or int(public_lifecycle.get("active_count", -1)) != 2:
		_fail("Lifecycle health endpoint did not expose aggregate state")
		return
	if not public_lifecycle.has("metrics") or public_lifecycle.has("active_matches") or public_lifecycle.has("pid"):
		_fail("Lifecycle health endpoint exposed unsafe per-match internals or lost aggregate metrics")
		return
	var health_text: String = JSON.stringify(health)
	if health_text.contains("\"match_id\"") or health_text.contains("12345"):
		_fail("Lifecycle public health leaked match ID/PID details")
		return
	control_api.free()
	fake_orchestrator.free()

	var result_overlay_script: Script = ResultOverlayScript as Script
	if result_overlay_script == null or not result_overlay_script.can_instantiate():
		_fail("Match result overlay cannot compile")
		return
	var campaign_scene: PackedScene = load("res://src/maps/campaign/OutbreakDistrict.tscn") as PackedScene
	if campaign_scene == null:
		_fail("Campaign scene missing for lifecycle smoke")
		return
	var campaign: Node = campaign_scene.instantiate()
	root.add_child(campaign)
	var campaign_session: Node = campaign.get_node_or_null("NetworkSession")
	if campaign_session == null:
		_fail("Campaign NetworkSession is missing")
		return
	var campaign_session_script: Script = campaign_session.get_script() as Script
	if campaign_session_script == null or String(campaign_session_script.resource_path) != "res://src/network/LifecycleMtuSafeNetworkSession.gd":
		_fail("Campaign is not bound to lifecycle network session")
		return
	campaign.queue_free()
	await process_frame

	var main_file: FileAccess = FileAccess.open("res://src/main/Main.gd", FileAccess.READ)
	var main_source: String = main_file.get_as_text() if main_file != null else ""
	for contract in ["MATCH_RECONNECT_WINDOW_SECONDS := 42.0", "MATCH_RECONNECT_MAX_ATTEMPTS := 10", "_on_authoritative_match_finished", "_finish_reconnect_failure", "_refresh_returned_lobby"]:
		if not main_source.contains(contract):
			_fail("Client lifecycle contract missing: %s" % contract)
			return

	_cleanup([config_path, ready_path, heartbeat_path, result_path, heartbeat_path + ".tmp", result_path + ".tmp"])
	print("NEXORA: DEADFALL beta.5 match lifecycle smoke passed")
	quit(0)

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return Dictionary(parsed) if typeof(parsed) == TYPE_DICTIONARY else {}

func _cleanup(paths: Array) -> void:
	for value in paths:
		var path := String(value)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
