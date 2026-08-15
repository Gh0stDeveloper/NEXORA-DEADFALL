extends Node

signal quality_profile_changed(tier: int, profile: Dictionary)
signal gore_enabled_changed(enabled: bool)

enum QualityTier {
	SMOOTH,
	STANDARD,
	ULTRA,
	ULTRA_HD,
}

var quality_tier: QualityTier = QualityTier.STANDARD
var gore_enabled: bool = true
var target_fps: int = 60

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

func current_profile() -> Dictionary:
	return QUALITY_PROFILES[quality_tier].duplicate(true)

func set_quality_tier(value: int) -> void:
	var clamped := clampi(value, QualityTier.SMOOTH, QualityTier.ULTRA_HD)
	if int(quality_tier) == clamped:
		return
	quality_tier = clamped as QualityTier
	quality_profile_changed.emit(clamped, current_profile())

func set_gore_enabled(value: bool) -> void:
	if gore_enabled == value:
		return
	gore_enabled = value
	gore_enabled_changed.emit(gore_enabled)
