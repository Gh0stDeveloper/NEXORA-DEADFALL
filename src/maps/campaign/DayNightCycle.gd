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

func _ready() -> void:
	normalized_time = starting_time
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
	_apply_lighting()

func _initialize_lighting() -> void:
	var arena := get_parent()
	if arena == null:
		return
	var world := arena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_moon = arena.get_node_or_null("MoonLight") as DirectionalLight3D
	if world == null or world.environment == null or _moon == null:
		call_deferred("_initialize_lighting")
		return
	_environment = world.environment
	_sun = arena.get_node_or_null("SunLight") as DirectionalLight3D
	if _sun == null:
		_sun = DirectionalLight3D.new()
		_sun.name = "SunLight"
		_sun.light_color = Color(1.0, 0.91, 0.74)
		_sun.shadow_enabled = true
		_sun.shadow_blur = 1.15
		arena.add_child(_sun)
	_apply_lighting()

func _apply_lighting() -> void:
	if _environment == null or _sun == null or _moon == null:
		return
	# 0.00 sunrise, 0.25 noon, 0.50 sunset, 0.75 midnight.
	var solar_height := sin(normalized_time * TAU)
	var daylight := smoothstep(-0.14, 0.20, solar_height)
	var sun_strength := clampf(maxf(0.0, solar_height) * 0.92 + daylight * 0.30, 0.0, 1.0)
	var moon_strength := clampf(1.0 - daylight, 0.0, 1.0)
	var horizon_factor := clampf(1.0 - absf(solar_height) * 3.0, 0.0, 1.0)

	_sun.rotation_degrees = Vector3(normalized_time * 360.0 - 105.0, -28.0, 0.0)
	_sun.light_energy = 0.05 + sun_strength * 1.18
	_sun.light_color = Color(1.0, 0.66, 0.42).lerp(Color(1.0, 0.94, 0.80), sun_strength)
	_sun.shadow_enabled = daylight > 0.18

	_moon.rotation_degrees = Vector3(normalized_time * 360.0 + 75.0, 148.0, 0.0)
	_moon.light_energy = 0.10 + moon_strength * 0.48
	_moon.light_color = Color(0.48, 0.64, 0.94)
	_moon.shadow_enabled = moon_strength > 0.34

	var night_bg := Color(0.018, 0.030, 0.052)
	var day_bg := Color(0.33, 0.55, 0.66)
	var sunset_bg := Color(0.52, 0.20, 0.13)
	var background := night_bg.lerp(day_bg, daylight)
	background = background.lerp(sunset_bg, horizon_factor * (1.0 - sun_strength) * 0.48)
	_environment.background_color = background
	_environment.ambient_light_color = Color(0.22, 0.31, 0.48).lerp(Color(0.72, 0.78, 0.74), daylight)
	_environment.ambient_light_energy = lerpf(0.46, 0.92, daylight)
	_environment.tonemap_exposure = lerpf(1.18, 1.05, daylight)
	_environment.adjustment_brightness = lerpf(1.12, 1.04, daylight)
	time_changed.emit(normalized_time, daylight)
