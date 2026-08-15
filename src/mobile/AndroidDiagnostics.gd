class_name DeadfallAndroidDiagnostics
extends Node

func _ready() -> void:
	if not OS.has_feature("android"): return
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	_emit_report()
	await get_tree().create_timer(4.5).timeout
	_emit_runtime_reports()

func _emit_report() -> void:
	var window_size := DisplayServer.window_get_size()
	var viewport_size := get_viewport().get_visible_rect().size
	var safe_area := DisplayServer.get_display_safe_area()
	var cutouts := DisplayServer.get_display_cutouts()
	var orientation := DisplayServer.screen_get_orientation()
	var landscape := window_size.x >= window_size.y
	var safe_area_valid := safe_area.size.x > 0 and safe_area.size.y > 0
	var gore_manager := get_tree().root.get_node_or_null("Gore")
	var network := get_tree().root.get_node_or_null("Main/DuoArena/NetworkSession")
	var report := {
		"android": true,
		"mobile": OS.has_feature("mobile"),
		"debug": OS.is_debug_build(),
		"landscape": landscape,
		"orientation": int(orientation),
		"window_width": window_size.x,
		"window_height": window_size.y,
		"viewport_width": int(viewport_size.x),
		"viewport_height": int(viewport_size.y),
		"safe_x": safe_area.position.x,
		"safe_y": safe_area.position.y,
		"safe_width": safe_area.size.x,
		"safe_height": safe_area.size.y,
		"safe_area_valid": safe_area_valid,
		"cutout_count": cutouts.size(),
		"dpi": DisplayServer.screen_get_dpi(),
		"touchscreen": DisplayServer.has_feature(DisplayServer.FEATURE_TOUCHSCREEN),
		"gore_budget": gore_manager.call("get_budget_limits") if gore_manager != null else {},
		"network": network.call("get_status_snapshot") if network != null else {},
	}
	print("DEADFALL_ANDROID_READY %s" % JSON.stringify(report))
	if not landscape: push_error("Android runtime validation: landscape orientation was not applied")
	if not safe_area_valid: push_error("Android runtime validation: display safe area is invalid")

func _emit_runtime_reports() -> void:
	var gore_manager := get_tree().root.get_node_or_null("Gore")
	if gore_manager != null: print("DEADFALL_GORE_STATS %s" % JSON.stringify(gore_manager.call("get_runtime_stats")))
	var horde := get_tree().root.get_node_or_null("Main/TestRange/HordeDirector")
	if horde == null: horde = get_tree().root.get_node_or_null("Main/DuoArena/HordeDirector")
	if horde != null: print("DEADFALL_HORDE_STATS %s" % JSON.stringify(horde.call("get_status_snapshot")))
	var network := get_tree().root.get_node_or_null("Main/DuoArena/NetworkSession")
	if network != null: print("DEADFALL_NETWORK_STATS %s" % JSON.stringify(network.call("get_status_snapshot")))
