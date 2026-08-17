class_name DeadfallMobilePerformanceTuner
extends Node

const FPS_BY_TIER := {
	0: 30,
	1: 45,
	2: 60,
	3: 60,
}

var _settings: Node
var _applied_scale := 1.0
var _applied_fps := 0
var _active := false

func _ready() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		set_process(false)
		return
	call_deferred("_initialize_tuner")

func _initialize_tuner() -> void:
	_settings = get_tree().root.get_node_or_null("Settings") if get_tree() != null else null
	if _settings == null:
		push_warning("DEADFALL_PERFORMANCE_TUNER Settings autoload missing")
		return
	if _settings.has_signal("quality_profile_changed"):
		var callback := Callable(self, "_on_quality_profile_changed")
		if not _settings.is_connected("quality_profile_changed", callback):
			_settings.connect("quality_profile_changed", callback)
	_apply_current_profile()
	_active = true

func _on_quality_profile_changed(_tier: int, _profile: Dictionary) -> void:
	_apply_current_profile()

func _apply_current_profile() -> void:
	if _settings == null or not _settings.has_method("current_profile"):
		return
	var profile: Dictionary = _settings.call("current_profile")
	var viewport := get_viewport()
	if viewport == null:
		return
	_applied_scale = clampf(float(profile.get("render_scale", 1.0)), 0.50, 1.0)
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = _applied_scale

	var tier_value = _settings.get("quality_tier")
	var tier := int(tier_value) if tier_value != null else 1
	var requested_fps := int(FPS_BY_TIER.get(tier, 60))
	if OS.has_feature("mobile"):
		var refresh_rate := DisplayServer.screen_get_refresh_rate()
		if refresh_rate > 1.0:
			requested_fps = mini(requested_fps, maxi(30, int(round(refresh_rate))))
		Engine.max_fps = requested_fps
		_applied_fps = requested_fps
	else:
		_applied_fps = Engine.max_fps

func get_status_snapshot() -> Dictionary:
	return {
		"active": _active,
		"mobile": OS.has_feature("mobile"),
		"render_scale": _applied_scale,
		"max_fps": _applied_fps,
	}
