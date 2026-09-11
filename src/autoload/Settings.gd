extends Node

signal quality_profile_changed(tier: int, profile: Dictionary)
signal gore_enabled_changed(enabled: bool)
signal camera_sensitivity_changed(value: float)
signal master_volume_changed(value: float)
signal music_volume_changed(value: float)
signal hud_layout_changed(element_id: StringName, value: Dictionary)

enum QualityTier {
	SMOOTH,
	STANDARD,
	ULTRA,
	ULTRA_HD,
}

const SETTINGS_SCHEMA_VERSION := 1
const SETTINGS_PATH := "user://deadfall_settings_v1.json"
const CAMERA_SENSITIVITY_MIN := 0.10
const CAMERA_SENSITIVITY_MAX := 1.00
const CAMERA_SENSITIVITY_DEFAULT := 0.50

var quality_tier: QualityTier = QualityTier.STANDARD
var gore_enabled: bool = true
var target_fps: int = 60
var camera_sensitivity: float = CAMERA_SENSITIVITY_DEFAULT
var master_volume: float = 1.0
var music_volume: float = 0.75
var hud_layout: Dictionary = {}

# Android remains the limiting renderer/device class. Phase 7 extends each
# profile with Squad/Horde and replication budgets so four-player networking
# scales without sending the complete zombie population every snapshot.
const QUALITY_PROFILES := {
	QualityTier.SMOOTH: {
		"render_scale": 0.65,
		"gore_parts": 4,
		"blood_emitters": 2,
		"blood_particles": 10,
		"decals": 4,
		"limb_lifetime": 5.0,
		"decal_lifetime": 12.0,
		"horde_population": 8,
		"horde_spawn_rate": 0.85,
		"horde_squad_population_bonus": 2,
		"network_zombie_snapshots": 12,
		"network_snapshot_hz": 12.0,
		"network_max_payload_bytes": 24000,
	},
	QualityTier.STANDARD: {
		"render_scale": 0.90,
		"gore_parts": 8,
		"blood_emitters": 4,
		"blood_particles": 18,
		"decals": 6,
		"limb_lifetime": 8.0,
		"decal_lifetime": 20.0,
		"horde_population": 14,
		"horde_spawn_rate": 1.0,
		"horde_squad_population_bonus": 3,
		"network_zombie_snapshots": 18,
		"network_snapshot_hz": 15.0,
		"network_max_payload_bytes": 32000,
	},
	QualityTier.ULTRA: {
		"render_scale": 1.0,
		"gore_parts": 16,
		"blood_emitters": 6,
		"blood_particles": 28,
		"decals": 8,
		"limb_lifetime": 12.0,
		"decal_lifetime": 35.0,
		"horde_population": 20,
		"horde_spawn_rate": 1.15,
		"horde_squad_population_bonus": 4,
		"network_zombie_snapshots": 24,
		"network_snapshot_hz": 18.0,
		"network_max_payload_bytes": 40000,
	},
	QualityTier.ULTRA_HD: {
		"render_scale": 1.0,
		"gore_parts": 32,
		"blood_emitters": 8,
		"blood_particles": 40,
		"decals": 8,
		"limb_lifetime": 16.0,
		"decal_lifetime": 50.0,
		"horde_population": 28,
		"horde_spawn_rate": 1.30,
		"horde_squad_population_bonus": 5,
		"network_zombie_snapshots": 32,
		"network_snapshot_hz": 20.0,
		"network_max_payload_bytes": 48000,
	},
}

func _ready() -> void:
	_load_settings()
	_apply_audio_settings()

func current_profile() -> Dictionary:
	return QUALITY_PROFILES[quality_tier].duplicate(true)

func set_quality_tier(value: int) -> void:
	var clamped := clampi(value, QualityTier.SMOOTH, QualityTier.ULTRA_HD)
	if int(quality_tier) == clamped:
		return
	quality_tier = clamped as QualityTier
	quality_profile_changed.emit(clamped, current_profile())
	_save_settings()

func set_gore_enabled(value: bool) -> void:
	if gore_enabled == value:
		return
	gore_enabled = value
	gore_enabled_changed.emit(gore_enabled)
	_save_settings()

func set_camera_sensitivity(value: float) -> void:
	var clamped := clampf(value, CAMERA_SENSITIVITY_MIN, CAMERA_SENSITIVITY_MAX)
	if is_equal_approx(camera_sensitivity, clamped):
		return
	camera_sensitivity = clamped
	camera_sensitivity_changed.emit(camera_sensitivity)
	_save_settings()

func get_look_radians_per_pixel() -> float:
	# The original controller used 0.0025 rad/pixel. A user-facing value of
	# 0.25 maps exactly to that baseline: 0.25 * 0.01 = 0.0025.
	return camera_sensitivity * 0.01

func set_master_volume(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(master_volume, clamped):
		return
	master_volume = clamped
	_apply_bus_volume("Master", master_volume)
	master_volume_changed.emit(master_volume)
	_save_settings()

func set_music_volume(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(music_volume, clamped):
		return
	music_volume = clamped
	_apply_bus_volume("Music", music_volume)
	music_volume_changed.emit(music_volume)
	_save_settings()

func get_hud_element(element_id: StringName, fallback: Dictionary = {}) -> Dictionary:
	var stored: Variant = hud_layout.get(String(element_id), fallback)
	return stored.duplicate(true) if typeof(stored) == TYPE_DICTIONARY else fallback.duplicate(true)

func set_hud_element(element_id: StringName, value: Dictionary) -> void:
	hud_layout[String(element_id)] = _sanitize_hud_entry(value)
	hud_layout_changed.emit(element_id, get_hud_element(element_id))
	_save_settings()

func reset_hud_layout() -> void:
	hud_layout.clear()
	hud_layout_changed.emit(&"*", {})
	_save_settings()

func save_configuration() -> void:
	_save_settings()

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_warning("Ignoring invalid DEADFALL settings file")
		return
	var data: Dictionary = json.data
	quality_tier = clampi(int(data.get("quality_tier", int(quality_tier))), QualityTier.SMOOTH, QualityTier.ULTRA_HD) as QualityTier
	gore_enabled = bool(data.get("gore_enabled", gore_enabled))
	camera_sensitivity = clampf(float(data.get("camera_sensitivity", CAMERA_SENSITIVITY_DEFAULT)), CAMERA_SENSITIVITY_MIN, CAMERA_SENSITIVITY_MAX)
	master_volume = clampf(float(data.get("master_volume", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(data.get("music_volume", music_volume)), 0.0, 1.0)
	var stored_hud: Variant = data.get("hud_layout", {})
	if typeof(stored_hud) == TYPE_DICTIONARY:
		hud_layout = stored_hud.duplicate(true)

func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Unable to persist DEADFALL settings")
		return
	file.store_string(JSON.stringify({
		"schema_version": SETTINGS_SCHEMA_VERSION,
		"quality_tier": int(quality_tier),
		"gore_enabled": gore_enabled,
		"camera_sensitivity": camera_sensitivity,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"hud_layout": hud_layout,
	}, "\t"))

func _apply_audio_settings() -> void:
	_apply_bus_volume("Master", master_volume)
	_apply_bus_volume("Music", music_volume)

func _apply_bus_volume(bus_name: String, linear_value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(linear_value, 0.0001)))
	AudioServer.set_bus_mute(bus_index, linear_value <= 0.0001)

func _sanitize_hud_entry(raw: Dictionary) -> Dictionary:
	return {
		"x": clampf(float(raw.get("x", 0.5)), 0.0, 1.0),
		"y": clampf(float(raw.get("y", 0.5)), 0.0, 1.0),
		"scale": clampf(float(raw.get("scale", 1.0)), 0.55, 1.75),
		"opacity": clampf(float(raw.get("opacity", 0.82)), 0.15, 1.0),
		"visible": bool(raw.get("visible", true)),
	}
