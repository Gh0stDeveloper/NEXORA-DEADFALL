class_name DeadfallZombieData
extends Resource

@export var display_name := "Walker"
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
