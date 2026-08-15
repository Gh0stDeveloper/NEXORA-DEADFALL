extends Node

enum QualityTier {
	SMOOTH,
	STANDARD,
	ULTRA,
	ULTRA_HD,
}

var quality_tier: QualityTier = QualityTier.STANDARD
var gore_enabled: bool = true
var target_fps: int = 60

const QUALITY_PROFILES := {
	QualityTier.SMOOTH: {"render_scale": 0.65, "gore_parts": 4, "decals": 8},
	QualityTier.STANDARD: {"render_scale": 0.90, "gore_parts": 8, "decals": 20},
	QualityTier.ULTRA: {"render_scale": 1.0, "gore_parts": 16, "decals": 40},
	QualityTier.ULTRA_HD: {"render_scale": 1.0, "gore_parts": 32, "decals": 80},
}

func current_profile() -> Dictionary:
	return QUALITY_PROFILES[quality_tier].duplicate(true)
