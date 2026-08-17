class_name DeadfallBuildInfo
extends RefCounted

const APP_VERSION := "0.9.0-beta.4"
const VERSION_CODE := 900004
const BUILD_CHANNEL := "closed_beta"
const NETWORK_PROTOCOL := 2
const CONTENT_VERSION := 1
const MIN_CLIENT_VERSION_CODE := 900004
const MAX_CLIENT_VERSION_CODE := 900999
const MIN_SERVER_VERSION_CODE := 900004
const MAX_SERVER_VERSION_CODE := 900999
const TARGET_ANDROID_API := 36
const MAX_PLAYERS := 4

static func validate_client(protocol: int, version_code: int, content_version: int) -> Dictionary:
	if protocol != NETWORK_PROTOCOL:
		return _result(false, "protocol_mismatch")
	if content_version != CONTENT_VERSION:
		return _result(false, "content_mismatch")
	if version_code < MIN_CLIENT_VERSION_CODE:
		return _result(false, "client_update_required")
	if version_code > MAX_CLIENT_VERSION_CODE:
		return _result(false, "server_update_required")
	return _result(true, "ok")

static func validate_server_snapshot(server: Dictionary) -> Dictionary:
	if int(server.get("protocol", 0)) != NETWORK_PROTOCOL:
		return _result(false, "protocol_mismatch")
	if int(server.get("content_version", 0)) != CONTENT_VERSION:
		return _result(false, "content_mismatch")
	var server_version := int(server.get("version_code", 0))
	if server_version < MIN_SERVER_VERSION_CODE:
		return _result(false, "server_update_required")
	if server_version > MAX_SERVER_VERSION_CODE:
		return _result(false, "client_update_required")
	var minimum := int(server.get("min_client_version_code", server_version))
	var maximum := int(server.get("max_client_version_code", server_version))
	if VERSION_CODE < minimum:
		return _result(false, "client_update_required")
	if VERSION_CODE > maximum:
		return _result(false, "server_update_required")
	return _result(true, "ok")

static func snapshot() -> Dictionary:
	return {
		"app_version": APP_VERSION,
		"version_code": VERSION_CODE,
		"build_channel": BUILD_CHANNEL,
		"protocol": NETWORK_PROTOCOL,
		"content_version": CONTENT_VERSION,
		"min_client_version_code": MIN_CLIENT_VERSION_CODE,
		"max_client_version_code": MAX_CLIENT_VERSION_CODE,
		"target_android_api": TARGET_ANDROID_API,
		"max_players": MAX_PLAYERS,
	}

static func _result(compatible: bool, reason: String) -> Dictionary:
	return {"compatible": compatible, "reason": reason}
