class_name DeadfallLifecycleControlApiServer
extends "res://src/server/ControlApiServer.gd"

func _route(method: String, path: String, token: String, payload: Dictionary) -> Dictionary:
	var response: Dictionary = super._route(method, path, token, payload)
	if method != "GET" or path != "/v1/health" or not bool(response.get("ok", false)):
		return response
	if _match_orchestrator == null or not _match_orchestrator.has_method("get_status_snapshot"):
		return response
	var status: Dictionary = Dictionary(_match_orchestrator.call("get_status_snapshot"))
	response["match_lifecycle"] = {
		"active_count": int(status.get("active_count", 0)),
		"heartbeat_stale_seconds": int(status.get("heartbeat_stale_seconds", 0)),
		"max_match_runtime_seconds": int(status.get("max_match_runtime_seconds", 0)),
		"metrics": Dictionary(status.get("metrics", {})).duplicate(true),
	}
	return response
