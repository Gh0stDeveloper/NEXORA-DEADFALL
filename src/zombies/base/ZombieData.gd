class_name DeadfallZombieData
extends Resource

@export_category("Identity / Horde")
@export var archetype_id: StringName = &"walker"
@export var display_name := "Walker"
@export var prototype_color := Color(0.28, 0.34, 0.27, 1.0)
@export var population_cost := 1
@export var score_value := 100
@export var unlock_wave := 1
@export var spawn_weight := 1.0
@export var native_crawler := false
@export var screamer_enabled := false
@export var scream_radius := 11.0
@export var scream_cooldown_seconds := 8.0
@export var scream_rage_seconds := 4.0
@export var scream_speed_multiplier := 1.30
@export var scream_damage_multiplier := 1.20

@export_category("Combat / AI")
@export var max_health := 100.0
@export var move_speed := 3.2
@export var detection_range := 20.0
@export var lose_target_range := 30.0
@export var attack_range := 1.55
@export var attack_damage := 12.0
@export var attack_cooldown_seconds := 1.10
@export var attack_windup_seconds := 0.30
@export var stagger_seconds := 0.35
@export var search_seconds := 4.0
@export var scan_interval_seconds := 0.20
@export var repath_interval_seconds := 0.25
@export var sight_memory_seconds := 1.0

@export_category("Gore")
@export var head_dismember_damage := 42.0
@export var arm_dismember_damage := 36.0
@export var leg_dismember_damage := 38.0
@export var crawler_speed_multiplier := 0.42
@export var crawler_attack_range_multiplier := 0.82
@export var crawler_height := 0.85
@export var one_arm_damage_multiplier := 0.72
@export var two_arm_damage_multiplier := 0.45
@export var one_arm_cooldown_multiplier := 1.25
@export var two_arm_cooldown_multiplier := 1.65
