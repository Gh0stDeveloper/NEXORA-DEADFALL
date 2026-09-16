class_name DeadfallHordeRules
extends RefCounted

const BASE_WAVE_SIZE := 6
const WAVE_GROWTH := 3
const MILESTONE_BONUS := 4
const SQUAD_WAVE_MULTIPLIERS := [1.0, 1.35, 1.65, 1.90]

static func wave_total(wave_number: int, squad_size: int = 1) -> int:
	var wave := maxi(1, wave_number)
	var milestone_count := int((wave - 1) / 5)
	var base_total := BASE_WAVE_SIZE + (wave - 1) * WAVE_GROWTH + milestone_count * MILESTONE_BONUS
	var index := clampi(maxi(1, squad_size) - 1, 0, SQUAD_WAVE_MULTIPLIERS.size() - 1)
	return maxi(BASE_WAVE_SIZE, int(ceil(float(base_total) * float(SQUAD_WAVE_MULTIPLIERS[index]))))

static func wave_completion_bonus(wave_number: int) -> int:
	var wave := maxi(1, wave_number)
	return 100 + wave * 75

static func effective_intermission_seconds(wave_number: int, base_seconds: float) -> float:
	var reduction := minf(2.5, float(maxi(0, wave_number - 1)) * 0.12)
	return maxf(2.5, base_seconds - reduction)

static func population_budget(profile: Dictionary, squad_size: int = 1) -> int:
	var base_budget := maxi(1, int(profile.get("horde_population", 10)))
	var bonus_per_member := maxi(0, int(profile.get("horde_squad_population_bonus", 0)))
	return base_budget + bonus_per_member * maxi(0, clampi(squad_size, 1, 4) - 1)

static func spawn_interval(profile: Dictionary, base_seconds: float, squad_size: int = 1) -> float:
	var quality_multiplier := maxf(0.25, float(profile.get("horde_spawn_rate", 1.0)))
	var squad_multiplier := 1.0 + 0.08 * float(maxi(0, clampi(squad_size, 1, 4) - 1))
	return maxf(0.10, base_seconds / (quality_multiplier * squad_multiplier))

static func is_unlocked(archetype: Resource, wave_number: int) -> bool:
	if archetype == null:
		return false
	return wave_number >= maxi(1, int(archetype.get("unlock_wave")))

static func population_cost(archetype: Resource) -> int:
	if archetype == null:
		return 1
	return maxi(1, int(archetype.get("population_cost")))

static func spawn_weight(archetype: Resource, wave_number: int) -> float:
	if archetype == null or not is_unlocked(archetype, wave_number):
		return 0.0
	var base_weight := maxf(0.0, float(archetype.get("spawn_weight")))
	var unlock_wave := maxi(1, int(archetype.get("unlock_wave")))
	var maturity := 1.0 + minf(0.60, float(maxi(0, wave_number - unlock_wave)) * 0.06)
	return base_weight * maturity
