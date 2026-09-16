extends SceneTree

var SocialClientScript: Script
var LoginGateScript: Script
var LoadingOverlayScript: Script

var _identity: Node
var _social: Node
var _client: Node
var _login: Control
var _overlay: CanvasLayer
var _login_errors: Array[String] = []
var _request_errors: Array[String] = []
var _successes: Array[Dictionary] = []
var _identity_before: Dictionary = {}
var _api_before := ""
var _restoring := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() != "headless":
		_fail("Run the login/loading regression with --headless")
		return
	_identity = root.get_node("GuestIdentity")
	_social = root.get_node("SocialClient")
	SocialClientScript = load("res://src/social/SocialClient.gd")
	LoginGateScript = load("res://src/login/LoginGate.gd")
	LoadingOverlayScript = load("res://src/ui/MatchLoadingOverlay.gd")
	# Assign an in-memory fixture only. No account creation or persistence.
	_identity_before = {
		"guest_id": _identity.guest_id,
		"username": _identity.username,
		"auth_secret": _identity.auth_secret,
	}
	_api_before = _social.api_base
	_restoring = true
	_identity.guest_id = "gst_login_loading_regression"
	_identity.username = "AccessSmoke"
	_identity.auth_secret = "a".repeat(64)
	_social.api_base = ""

	_client = SocialClientScript.new()
	root.add_child(_client)
	_client.api_base = ""
	_client.login_failed.connect(func(reason: String) -> void: _login_errors.append(reason))
	_client.request_failed.connect(func(operation: String, _reason: String) -> void: _request_errors.append(operation))
	_client.login_succeeded.connect(func(account: Dictionary) -> void: _successes.append(account))
	if not _test_request_start_failures():
		return
	if not _test_session_validation():
		return
	if not _test_login_recovery():
		return
	if not _test_loading_timing():
		return

	_cleanup()
	await process_frame
	print("NEXORA: DEADFALL login/loading recovery smoke passed")
	quit(0)

func _test_request_start_failures() -> bool:
	# A relative URL fails synchronously in HTTPRequest; no network is contacted.
	# Exercise the actual start path instead of only calling _fail_operation.
	for operation in ["register", "auth_challenge", "auth_verify"]:
		var before := _login_errors.size()
		var started: bool = _client._request_json(operation, HTTPClient.METHOD_POST, "/offline-regression", {}, false)
		if not _check(not started and _login_errors.size() == before + 1, "Login request start failure did not emit login_failed exactly once"):
			return false
		if not _check(_login_errors.back().begins_with("request_start_failed:"), "Unexpected immediate login failure reason"):
			return false
		if not _check(not _client._pending_operations.has(operation), "Failed login request left a pending operation"):
			return false
	if not _check(_request_errors.is_empty(), "Login errors were routed to the social request signal"):
		return false
	_client._request_json("profile", HTTPClient.METHOD_GET, "/offline-regression", {}, false)
	if not _check(_request_errors == ["profile"], "Non-login failures lost their operation-specific signal"):
		return false
	# Retry the same failed operation; a stale pending flag must not suppress it.
	var before := _login_errors.size()
	_client._request_json("auth_verify", HTTPClient.METHOD_POST, "/offline-regression", {}, false)
	return _check(_login_errors.size() == before + 1, "Failed login cannot be retried")

func _test_session_validation() -> bool:
	var future := int(Time.get_unix_time_from_system()) + 3600
	var account := {"guest_id": _identity.guest_id, "username": "AccessSmoke", "public_id": "3333333333"}
	var valid := {"ok": true, "session_token": "b".repeat(64), "expires_unix": future, "account": account}
	var invalid: Array[Dictionary] = [
		{"ok": true},
		{"ok": true, "session_token": "", "expires_unix": future, "account": account},
		{"ok": true, "session_token": " ", "expires_unix": future, "account": account},
		{"ok": true, "session_token": 42, "expires_unix": future, "account": account},
		{"ok": true, "session_token": "b".repeat(64), "expires_unix": 1, "account": account},
		{"ok": true, "session_token": "b".repeat(64), "expires_unix": "tomorrow", "account": account},
		{"ok": true, "session_token": "b".repeat(64), "expires_unix": future, "account": []},
		{"ok": true, "session_token": "b".repeat(64), "expires_unix": future, "account": {"guest_id": "gst_someone_else"}},
	]
	for operation in ["register", "auth_verify"]:
		for response in invalid:
			var before := _login_errors.size()
			_client._on_request_completed(
				HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(),
				JSON.stringify(response).to_utf8_buffer(), null, operation, {"username": "AccessSmoke"}
			)
			if not _check(_login_errors.size() == before + 1 and _login_errors.back() == "invalid_session", "Malformed session did not produce a recoverable login error"):
				return false
			if not _check(_successes.is_empty() and not _client.has_session(), "Malformed session was reported as a verified account"):
				return false

	_client._handle_success("auth_verify", valid, {})
	if not _check(_client.has_session() and _successes.size() == 1, "Valid verification response was rejected"):
		return false
	if not _check(_client.current_account == account, "Verified account was not adopted"):
		return false
	_client._handle_success("register", valid, {"username": "AccessSmoke"})
	if not _check(_successes.size() == 2, "Valid registration response was rejected"):
		return false
	var previous_token: String = _client.session_token
	_client._handle_success("auth_verify", invalid[0], {})
	return _check(_successes.size() == 2 and _client.session_token == previous_token, "Invalid response partially replaced the existing session")

func _test_login_recovery() -> bool:
	_login = LoginGateScript.new()
	root.add_child(_login)
	_login._begin_login_flow()
	if not _check(not _login._busy and _login._stage == LoginGateScript.Stage.ERROR, "Login UI stayed busy after HTTPRequest failed to start"):
		return false
	_login._begin_login_flow()
	if not _check(not _login._busy, "Login UI stayed busy after retry"):
		return false

	_login._on_guest_account_pressed()
	_login._username_edit.text = "NewCandidate"
	_login._busy = true
	_login._show_stage(LoginGateScript.Stage.CONNECTING)
	_login._on_login_failed("username_taken")
	if not _check(_login._stage == LoginGateScript.Stage.USERNAME and _login._username_edit.text == "NewCandidate", "Taken username did not return to the existing editable name"):
		return false
	if not _check(_identity.username == "AccessSmoke", "Rejected username changed the local identity"):
		return false

	_login._registration_recovery_attempted = false
	_login._busy = true
	_login._on_login_failed("unknown_guest")
	if not _check(_login._registration_recovery_attempted and not _login._busy, "Missing-account recovery did not stop on transport failure"):
		return false
	_login._busy = true
	_login._on_login_failed("unknown_guest")
	if not _check(not _login._busy and _login._stage == LoginGateScript.Stage.ERROR, "Missing-account recovery entered an automatic retry loop"):
		return false
	return true

func _test_loading_timing() -> bool:
	_overlay = LoadingOverlayScript.new()
	root.add_child(_overlay)
	_overlay.set_process(false)
	var samples: Array[float] = []
	for fps in [30, 60, 120]:
		_overlay.begin("203.0.113.77:24642")
		_overlay.set_stage("Preparando escenario", 0.9)
		# After half a second, animation must have the same position at
		# different rendering rates, without jumping straight to the target.
		var steps: int = int(fps * 0.5)
		for _frame in range(steps):
			_overlay._process(1.0 / float(fps))
		samples.append(_overlay._progress_value)
	if not _check(absf(samples[0] - samples[1]) < 0.001 and absf(samples[1] - samples[2]) < 0.001, "Loading animation depends on rendering FPS"):
		return false
	if not _check(samples[0] > 0.04 and samples[0] < 0.5, "Loading animation jumps immediately to the target"):
		return false
	_overlay.set_stage("Preparando conexión", 0.4)
	_overlay._process(2.0)
	if not _check(is_equal_approx(_overlay._progress_value, 0.9), "Out-of-order loading stages moved progress backwards"):
		return false
	_overlay.set_stage("Esperando acceso", 1.0)
	_overlay._process(2.0)
	if not _check(_overlay._progress.value < 100.0, "Loading showed completion before explicit admission"):
		return false
	_overlay.complete()
	_overlay._process(2.0)
	if not _check(is_equal_approx(_overlay._progress.value, 100.0), "Explicit completion did not reach 100 percent"):
		return false
	_overlay.show_error("Se perdió la conexión")
	if not _check(_overlay._return_button.visible, "Loading failure has no return action"):
		return false
	_overlay.begin("203.0.113.77:24642")
	if not _check(not _overlay._return_button.visible and _overlay._progress.value < 100.0, "Retry retained the failed/completed loading UI"):
		return false
	return _check(not _overlay._detail_label.text.contains("203.0.113.77"), "Loading exposes a server endpoint in player-facing text")

func _check(condition: bool, message: String) -> bool:
	if not condition:
		_fail(message)
	return condition

func _cleanup() -> void:
	for node in [_client, _login, _overlay]:
		if is_instance_valid(node):
			node.free()
	_client = null
	_login = null
	_overlay = null
	if _restoring:
		_identity.guest_id = String(_identity_before["guest_id"])
		_identity.username = String(_identity_before["username"])
		_identity.auth_secret = String(_identity_before["auth_secret"])
		_social.api_base = _api_before
		_restoring = false

func _fail(message: String) -> void:
	push_error(message)
	_cleanup()
	quit(1)
