class_name DeadfallDayNightCycle
extends Node

signal time_changed(normalized_time: float, daylight: float)

@export_range(120.0, 3600.0, 10.0) var full_cycle_seconds := 720.0
@export_range(0.0, 1.0, 0.01) var starting_time := 0.28
@export_range(0.05, 1.0, 0.05) var lighting_update_interval := 0.20

var normalized_time := 0.28
var _elapsed := 0.0
var _environment: Environment
var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _quality_tier := 1
var _dynamic_sun_shadows := true
var _dynamic_moon_shadows := false

func _ready() -> void:
	normalized_time = starting_time
	# Dedicated/headless instances run gameplay simulation only. OutbreakDistrict
	# deliberately skips WorldEnvironment/MoonLight creation there, so retrying
	# lighting initialization would enqueue one deferred call forever and can
	# exhaust Godot's MessageQueue. Rendering is disabled in headless mode anyway.
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		set_process(false)
		return
	set_process(false)
	call_deferred("_initialize_lighting")

func _process(delta: float) -> void:
	if _environment == null or _sun == null or _moon == null:
		return
	normalized_time = fposmod(normalized_time + delta / maxf(1.0, full_cycle_seconds), 1.0)
	_elapsed += delta
	if _elapsed < lighting_update_interval:
		return
	_elapsed = 0.0
	_apply_lighting()

func set_time(value: float) -> void:
	normalized_time = fposmod(value, 1.0)
	if _environment != null and _sun != null and _moon != null:
		_apply_lighting()

func _initialize_lighting() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		set_process(false)
		return
	var arena := get_parent()
	if arena == null:
		set_process(false)
		return
	var world := arena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_moon = arena.get_node_or_null("MoonLight") as DirectionalLight3D
	# This function is deferred until after the parent arena's _ready(), where
	# OutbreakDistrict builds both nodes. If they are still unavailable, stop
	# safely instead of recursively queueing deferred retries.
	if world == null or world.environment == null or _moon == null:
		push_warning("DEADFALL_DAY_NIGHT_DISABLED missing WorldEnvironment/MoonLight")
		set_process(false)
		return
	_environment = world.environment
	_sun = arena.get_node_or_null("SunLight") as DirectionalLight3D
	if _sun == null:
		_sun = DirectionalLight3D.new()
		_sun.name = "SunLight"
		_sun.light_color = Color(1.0, 0.91, 0.74)
		_sun.shadow_blur = 1.15
		arena.add_child(_sun)
	_bind_quality_profile()
	_apply_lighting()
	set_process(true)

func _bind_quality_profile() -> void:
	var settings := get_tree().root.get_node_or_null("Settings") if get_tree() != null else null
	if settings == null:
		_apply_quality_tier(1)
		return
	var tier_value = settings.get("quality_tier")
	_apply_quality_tier(int(tier_value) if tier_value != null else 1)
	if settings.has_signal("quality_profile_changed"):
		var callback := Callable(self, "_on_quality_profile_changed")
		if not settings.is_connected("quality_profile_changed", callback):
			settings.connect("quality_profile_changed", callback)

func _on_quality_profile_changed(tier: int, _profile: Dictionary) -> void:
	_apply_quality_tier(tier)
	_apply_lighting()

func _apply_quality_tier(tier: int) -> void:
	_quality_tier = clampi(tier, 0, 3)
	match _quality_tier:
		0:
			lighting_update_interval = maxf(lighting_update_interval, 0.35)
			_dynamic_sun_shadows = false
			_dynamic_moon_shadows = false
		1:
			lighting_update_interval = maxf(lighting_update_interval, 0.25)
			_dynamic_sun_shadows = true
			_dynamic_moon_shadows = false
		2:
			lighting_update_interval = minf(lighting_update_interval, 0.18)
			_dynamic_sun_shadows = true
			_dynamic_moon_shadows = true
		_:
			lighting_update_interval = minf(lighting_update_interval, 0.14)
			_dynamic_sun_shadows = true
			_dynamic_moon_shadows = true

func _apply_lighting() -> void:
	if _environment == null or _sun == null or _moon == null:
		return
	# 0.00 sunrise, 0.25 noon, 0.50 sunset, 0.75 midnight.
	var solar_height := sin(normalized_time * TAU)
	var daylight := smoothstep(-0.14, 0.20, solar_height)
	var sun_strength := clampf(maxf(0.0, solar_height) * 1.05 + daylight * 0.34, 0.0, 1.0)
	var moon_strength := clampf(1.0 - daylight, 0.0, 1.0)
	var horizon_factor := clampf(1.0 - absf(solar_height) * 3.0, 0.0, 1.0)

	_sun.rotation_degrees = Vector3(-normalized_time * 360.0, -28.0, 0.0)
	_sun.light_energy = 0.14 + sun_strength * 1.30
	_sun.light_color = Color(1.0, 0.70, 0.48).lerp(Color(1.0, 0.95, 0.84), sun_strength)
	_sun.shadow_enabled = _dynamic_sun_shadows and daylight > 0.18

	_moon.rotation_degrees = Vector3(180.0 - normalized_time * 360.0, 148.0, 0.0)
	_moon.light_energy = 0.04 + moon_strength * 0.55
	_moon.light_color = Color(0.56, 0.70, 1.0)
	_moon.shadow_enabled = _dynamic_moon_shadows and moon_strength > 0.34

	var night_bg := Color(0.055, 0.085, 0.125)
	var day_bg := Color(0.42, 0.64, 0.75)
	var sunset_bg := Color(0.58, 0.25, 0.16)
	var background := night_bg.lerp(day_bg, daylight)
	background = background.lerp(sunset_bg, horizon_factor * (1.0 - sun_strength) * 0.48)
	_environment.background_color = background
	if _environment.sky != null and _environment.sky.sky_material is ProceduralSkyMaterial:
		var sky := _environment.sky.sky_material as ProceduralSkyMaterial
		sky.sky_top_color = night_bg.lerp(Color(0.24, 0.46, 0.67), daylight)
		sky.sky_horizon_color = background.lightened(0.12)
		sky.ground_horizon_color = background
		_environment.fog_light_color = background.lightened(0.06)
	_environment.ambient_light_color = Color(0.38, 0.46, 0.60).lerp(Color(0.82, 0.86, 0.82), daylight)
	_environment.ambient_light_energy = lerpf(0.36, 0.60, daylight)
	_environment.tonemap_exposure = lerpf(1.15, 1.0, daylight)
	_environment.adjustment_brightness = lerpf(1.18, 1.07, daylight)
	time_changed.emit(normalized_time, daylight)
