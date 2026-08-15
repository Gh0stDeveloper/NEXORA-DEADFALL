class_name DeadfallHordeDirector
extends Node

signal state_changed(previous_state: int, current_state: int, reason: String)
signal wave_started(wave_number: int, total_enemies: int)
signal wave_completed(wave_number: int, completion_bonus: int)
signal countdown_changed(seconds_remaining: int, target_wave: int)
signal zombie_spawned(zombie, archetype_id: StringName, population_cost: int)
signal zombie_killed(archetype_id: StringName, score_awarded: int)
signal score_changed(score: int, kills: int)
signal population_changed(active_count: int, active_cost: int, budget: int, enemies_remaining: int)
signal game_over(wave_number: int, score: int, kills: int)
signal run_restarted()

const HordeRulesScript = preload("res://src/horde/HordeRules.gd")
const ZombieScene = preload("res://src/zombies/base/Zombie.tscn")
const WalkerData = preload("res://src/zombies/data/walker_01.tres")
const RunnerData = preload("res://src/zombies/data/runner_01.tres")
const TankData = preload("res://src/zombies/data/tank_01.tres")
const ScreamerData = preload("res://src/zombies/data/screamer_01.tres")
const CrawlerData = preload("res://src/zombies/data/crawler_01.tres")

const ARCHETYPES := [WalkerData, RunnerData, CrawlerData, TankData, ScreamerData]

enum State {
	DISABLED,
	COUNTDOWN,
	SPAWNING,
	ACTIVE,
	INTERMISSION,
	GAME_OVER,
}

@export var auto_start := true
@export var player_path := NodePath("../Player")
@export var spawn_points_path := NodePath("../HordeSpawnPoints")
@export var zombie_parent_path := NodePath("../HordeZombies")
@export var initial_countdown_seconds := 3.0
@export var intermission_seconds := 6.0
@export var spawn_interval_seconds := 0.55
@export var spawn_safety_radius := 8.0
@export var deterministic_seed: int = 0

var state: int = State.DISABLED
var wave_number := 0
var score := 0
var kills := 0
var wave_total_enemies := 0
var wave_spawned := 0
var wave_killed := 0
var authority_override: RefCounted

var _player: Node3D
var _player_health: Node
var _spawn_root: Node3D
var _zombie_parent: Node3D
var _player_start_transform := Transform3D.IDENTITY
var _player_start_transform_captured := false
var _phase_time_remaining := 0.0
var _spawn_elapsed := 0.0
var _last_countdown_value := -1
var _next_entity_id := 10_000
var _current_population_cost := 0
var _active_zombies: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_resolve_runtime_nodes()
	_seed_rng()
	_bind_player_health()
	if auto_start:
		call_deferred("start_run")

func _process(delta: float) -> void:
	if not has_simulation_authority():
		return
	_prune_invalid_active()
	if state != State.DISABLED and state != State.GAME_OVER and not _player_is_alive():
		_enter_game_over("player_dead")
		return

	match state:
		State.COUNTDOWN:
			_tick_countdown(delta, true)
		State.SPAWNING:
			_tick_spawning(delta)
		State.ACTIVE:
			_check_wave_complete()
		State.INTERMISSION:
			_tick_countdown(delta, false)

func set_authority_override(value: RefCounted) -> void:
	authority_override = value

func has_simulation_authority() -> bool:
	if authority_override != null:
		return true
	if get_tree() == null:
		return false
	var game := get_tree().root.get_node_or_null("Game")
	return game != null and game.has_method("is_simulation_authority") and bool(game.call("is_simulation_authority"))

func start_run() -> bool:
	if not has_simulation_authority():
		_set_state(State.DISABLED, "no_simulation_authority")
		return false
	_resolve_runtime_nodes()
	if _player == null or _spawn_root == null or _zombie_parent == null:
		_set_state(State.DISABLED, "missing_runtime_nodes")
		return false
	_clear_active_zombies()
	_reset_player()
	wave_number = 0
	score = 0
	kills = 0
	wave_total_enemies = 0
	wave_spawned = 0
	wave_killed = 0
	_next_entity_id = 10_000
	_phase_time_remaining = maxf(0.0, initial_countdown_seconds)
	_spawn_elapsed = 0.0
	_last_countdown_value = -1
	_seed_rng()
	_set_state(State.COUNTDOWN, "run_started")
	_emit_score()
	_emit_population()
	_emit_countdown(1)
	return true

func restart_run() -> bool:
	var started := start_run()
	if started:
		run_restarted.emit()
	return started

func get_state_name() -> String:
	return State.keys()[state]

func get_population_budget() -> int:
	return HordeRulesScript.population_budget(_current_quality_profile())

func get_active_zombie_count() -> int:
	return _active_zombies.size()

func get_active_population_cost() -> int:
	return _current_population_cost

func get_enemies_remaining() -> int:
	return maxi(0, wave_total_enemies - wave_killed)

func get_available_archetype_ids(for_wave: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for data in ARCHETYPES:
		if HordeRulesScript.is_unlocked(data, for_wave):
			result.append(StringName(data.get("archetype_id")))
	return result

func get_status_snapshot() -> Dictionary:
	return {
		"state": state,
		"state_name": get_state_name(),
		"wave": wave_number,
		"score": score,
		"kills": kills,
		"wave_total": wave_total_enemies,
		"wave_spawned": wave_spawned,
		"wave_killed": wave_killed,
		"enemies_remaining": get_enemies_remaining(),
		"active_zombies": get_active_zombie_count(),
		"active_population_cost": _current_population_cost,
		"population_budget": get_population_budget(),
		"countdown": maxi(0, int(ceil(_phase_time_remaining))),
	}

func debug_spawn_archetype(archetype_id: StringName) -> Node3D:
	var data := _find_archetype(archetype_id)
	if data == null:
		return null
	return _spawn_zombie(data)

func _resolve_runtime_nodes() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_spawn_root = get_node_or_null(spawn_points_path) as Node3D
	_zombie_parent = get_node_or_null(zombie_parent_path) as Node3D
	if _player != null:
		if not _player_start_transform_captured:
			_player_start_transform = _player.global_transform
			_player_start_transform_captured = true
		_player_health = _player.get_node_or_null("Health")

func _bind_player_health() -> void:
	if _player_health == null or not _player_health.has_signal("died"):
		return
	var callable := Callable(self, "_on_player_died")
	if not _player_health.is_connected("died", callable):
		_player_health.connect("died", callable)

func _seed_rng() -> void:
	if deterministic_seed != 0:
		_rng.seed = deterministic_seed
	else:
		_rng.randomize()

func _tick_countdown(delta: float, initial: bool) -> void:
	_phase_time_remaining = maxf(0.0, _phase_time_remaining - delta)
	_emit_countdown(1 if initial else wave_number + 1)
	if _phase_time_remaining > 0.0:
		return
	_begin_next_wave()

func _begin_next_wave() -> void:
	wave_number += 1
	wave_total_enemies = HordeRulesScript.wave_total(wave_number)
	wave_spawned = 0
	wave_killed = 0
	_spawn_elapsed = HordeRulesScript.spawn_interval(_current_quality_profile(), spawn_interval_seconds)
	_set_state(State.SPAWNING, "wave_started")
	wave_started.emit(wave_number, wave_total_enemies)
	_emit_population()
	if OS.is_debug_build():
		print("DEADFALL_HORDE_WAVE_START wave=%d total=%d budget=%d" % [wave_number, wave_total_enemies, get_population_budget()])

func _tick_spawning(delta: float) -> void:
	if wave_spawned >= wave_total_enemies:
		_set_state(State.ACTIVE, "wave_fully_spawned")
		_check_wave_complete()
		return

	_spawn_elapsed += delta
	var interval := HordeRulesScript.spawn_interval(_current_quality_profile(), spawn_interval_seconds)
	if _spawn_elapsed < interval:
		return
	var remaining_budget := get_population_budget() - _current_population_cost
	var data := _choose_archetype(wave_number, remaining_budget)
	if data == null:
		return
	_spawn_elapsed = 0.0
	if _spawn_zombie(data) == null:
		return
	wave_spawned += 1
	_emit_population()
	if wave_spawned >= wave_total_enemies:
		_set_state(State.ACTIVE, "wave_fully_spawned")

func _choose_archetype(for_wave: int, remaining_budget: int) -> Resource:
	var candidates: Array[Resource] = []
	var total_weight := 0.0
	for data in ARCHETYPES:
		if not HordeRulesScript.is_unlocked(data, for_wave):
			continue
		if HordeRulesScript.population_cost(data) > remaining_budget:
			continue
		var weight := HordeRulesScript.spawn_weight(data, for_wave)
		if weight <= 0.0:
			continue
		candidates.append(data)
		total_weight += weight
	if candidates.is_empty() or total_weight <= 0.0:
		return null
	var roll := _rng.randf() * total_weight
	for data in candidates:
		roll -= HordeRulesScript.spawn_weight(data, for_wave)
		if roll <= 0.0:
			return data
	return candidates.back()

func _spawn_zombie(data: Resource) -> Node3D:
	if data == null or _zombie_parent == null:
		return null
	var cost := HordeRulesScript.population_cost(data)
	if _current_population_cost + cost > get_population_budget():
		return null
	var spawn_point := _choose_spawn_point()
	if spawn_point == null:
		return null
	var zombie := ZombieScene.instantiate() as Node3D
	if zombie == null:
		return null
	var entity_id := _next_entity_id
	_next_entity_id += 1
	zombie.set("entity_id", entity_id)
	zombie.set("zombie_data", data)
	if authority_override != null and zombie.has_method("set_authority_override"):
		zombie.call("set_authority_override", authority_override)
	var display_name := String(data.get("display_name"))
	zombie.name = "%s_%d" % [display_name.replace(" ", ""), entity_id]
	_zombie_parent.add_child(zombie)
	zombie.global_position = spawn_point.global_position
	var health := zombie.get_node_or_null("Health")
	if health == null:
		zombie.queue_free()
		return null
	if authority_override != null and authority_override.has_method("register_damageable"):
		authority_override.call("register_damageable", entity_id, health)
	var died_callable := Callable(self, "_on_zombie_died").bind(zombie)
	health.connect("died", died_callable)
	var archetype_id := StringName(data.get("archetype_id"))
	var score_value := maxi(0, int(data.get("score_value")))
	_active_zombies[zombie.get_instance_id()] = {
		"node": zombie,
		"cost": cost,
		"score": score_value,
		"archetype_id": archetype_id,
	}
	_current_population_cost += cost
	zombie_spawned.emit(zombie, archetype_id, cost)
	return zombie

func _choose_spawn_point() -> Node3D:
	if _spawn_root == null:
		return null
	var all_points: Array[Node3D] = []
	var safe_points: Array[Node3D] = []
	for child in _spawn_root.get_children():
		var point := child as Node3D
		if point == null:
			continue
		all_points.append(point)
		if _player == null or point.global_position.distance_to(_player.global_position) >= spawn_safety_radius:
			safe_points.append(point)
	var pool: Array[Node3D] = safe_points if not safe_points.is_empty() else all_points
	if pool.is_empty():
		return null
	return pool[_rng.randi_range(0, pool.size() - 1)]

func _on_zombie_died(_event, zombie: Node3D) -> void:
	if zombie == null:
		return
	var instance_id := zombie.get_instance_id()
	if not _active_zombies.has(instance_id):
		return
	var record: Dictionary = _active_zombies[instance_id]
	_active_zombies.erase(instance_id)
	_current_population_cost = maxi(0, _current_population_cost - int(record.get("cost", 1)))
	wave_killed += 1
	kills += 1
	var awarded := maxi(0, int(record.get("score", 0)))
	score += awarded
	var archetype_id := StringName(record.get("archetype_id", &"walker"))
	zombie_killed.emit(archetype_id, awarded)
	_emit_score()
	_emit_population()
	zombie.call_deferred("queue_free")
	_check_wave_complete()

func _check_wave_complete() -> void:
	if wave_total_enemies <= 0 or wave_spawned < wave_total_enemies or not _active_zombies.is_empty():
		return
	var bonus := HordeRulesScript.wave_completion_bonus(wave_number)
	score += bonus
	_emit_score()
	wave_completed.emit(wave_number, bonus)
	_phase_time_remaining = HordeRulesScript.effective_intermission_seconds(wave_number, intermission_seconds)
	_last_countdown_value = -1
	_set_state(State.INTERMISSION, "wave_cleared")
	_emit_countdown(wave_number + 1)
	if OS.is_debug_build():
		print("DEADFALL_HORDE_WAVE_COMPLETE wave=%d score=%d kills=%d" % [wave_number, score, kills])

func _on_player_died(_event) -> void:
	_enter_game_over("player_health_depleted")

func _enter_game_over(reason: String) -> void:
	if state == State.GAME_OVER:
		return
	_set_state(State.GAME_OVER, reason)
	for record in _active_zombies.values():
		var zombie = record.get("node")
		if zombie != null and is_instance_valid(zombie):
			zombie.set_physics_process(false)
	game_over.emit(wave_number, score, kills)
	if OS.is_debug_build():
		print("DEADFALL_HORDE_GAME_OVER wave=%d score=%d kills=%d" % [wave_number, score, kills])

func _reset_player() -> void:
	if _player == null:
		return
	if _player_health == null:
		_player_health = _player.get_node_or_null("Health")
	if _player_health != null and _player_health.has_method("reset_health"):
		_player_health.call("reset_health")
	_player.global_transform = _player_start_transform
	var body := _player as CharacterBody3D
	if body != null:
		body.velocity = Vector3.ZERO

func _clear_active_zombies() -> void:
	if _zombie_parent != null:
		for child in _zombie_parent.get_children():
			child.queue_free()
	_active_zombies.clear()
	_current_population_cost = 0

func _prune_invalid_active() -> void:
	for key in _active_zombies.keys():
		var record: Dictionary = _active_zombies[key]
		var zombie = record.get("node")
		if zombie != null and is_instance_valid(zombie):
			continue
		_current_population_cost = maxi(0, _current_population_cost - int(record.get("cost", 1)))
		_active_zombies.erase(key)

func _player_is_alive() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if _player_health == null:
		_player_health = _player.get_node_or_null("Health")
	if _player_health == null:
		return false
	return not _player_health.has_method("is_dead") or not bool(_player_health.call("is_dead"))

func _find_archetype(archetype_id: StringName) -> Resource:
	for data in ARCHETYPES:
		if StringName(data.get("archetype_id")) == archetype_id:
			return data
	return null

func _current_quality_profile() -> Dictionary:
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.has_method("current_profile"):
		return settings.call("current_profile")
	return {"horde_population": 10, "horde_spawn_rate": 1.0}

func _emit_score() -> void:
	score_changed.emit(score, kills)

func _emit_population() -> void:
	population_changed.emit(get_active_zombie_count(), _current_population_cost, get_population_budget(), get_enemies_remaining())

func _emit_countdown(target_wave: int) -> void:
	var value := maxi(0, int(ceil(_phase_time_remaining)))
	if value == _last_countdown_value:
		return
	_last_countdown_value = value
	countdown_changed.emit(value, target_wave)

func _set_state(next_state: int, reason: String) -> void:
	if state == next_state:
		return
	var previous := state
	state = next_state
	state_changed.emit(previous, state, reason)
