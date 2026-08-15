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

enum State { DISABLED, COUNTDOWN, SPAWNING, ACTIVE, INTERMISSION, GAME_OVER }

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

var _spawn_root: Node3D
var _zombie_parent: Node3D
var _players: Dictionary = {}
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
	if auto_start:
		call_deferred("start_run")

func _process(delta: float) -> void:
	if not has_simulation_authority():
		return
	_prune_invalid_active()
	_prune_invalid_players()
	if state != State.DISABLED and state != State.GAME_OVER and not _players.is_empty() and get_recoverable_player_count() == 0:
		_enter_game_over("squad_not_recoverable")
		return
	match state:
		State.COUNTDOWN: _tick_countdown(delta, true)
		State.SPAWNING: _tick_spawning(delta)
		State.ACTIVE: _check_wave_complete()
		State.INTERMISSION: _tick_countdown(delta, false)

func set_authority_override(value: RefCounted) -> void:
	authority_override = value

func has_simulation_authority() -> bool:
	if authority_override != null:
		return true
	if get_tree() == null:
		return false
	var game := get_tree().root.get_node_or_null("Game")
	return game != null and game.has_method("is_simulation_authority") and bool(game.call("is_simulation_authority"))

func register_player(player: Node3D) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var health := player.get_node_or_null("Health")
	if health == null:
		return false
	var life := player.get_node_or_null("LifeState")
	var key := player.get_instance_id()
	if _players.has(key):
		return true
	_players[key] = {"node": player, "health": health, "life": life, "start_transform": player.global_transform}
	if health.has_signal("died"):
		var died_callable := Callable(self, "_on_registered_player_died").bind(key)
		if not health.is_connected("died", died_callable):
			health.connect("died", died_callable)
	if life != null and life.has_signal("state_changed"):
		var life_callable := Callable(self, "_on_registered_life_state_changed").bind(key)
		if not life.is_connected("state_changed", life_callable):
			life.connect("state_changed", life_callable)
	return true

func unregister_player(player: Node3D) -> void:
	if player == null:
		return
	_players.erase(player.get_instance_id())

func get_registered_player_count() -> int:
	_prune_invalid_players()
	return _players.size()

func get_alive_player_count() -> int:
	var count := 0
	for record in _players.values():
		if _record_player_alive(record):
			count += 1
	return count

func get_downed_player_count() -> int:
	var count := 0
	for record in _players.values():
		var life = record.get("life")
		if life != null and is_instance_valid(life) and life.has_method("is_downed") and bool(life.call("is_downed")):
			count += 1
	return count

func get_recoverable_player_count() -> int:
	var count := 0
	for record in _players.values():
		if _record_player_recoverable(record):
			count += 1
	return count

func get_scaling_squad_size() -> int:
	return clampi(maxi(1, get_registered_player_count()), 1, 4)

func start_run() -> bool:
	if not has_simulation_authority():
		_set_state(State.DISABLED, "no_simulation_authority")
		return false
	_resolve_runtime_nodes()
	if _players.is_empty() or _spawn_root == null or _zombie_parent == null:
		_set_state(State.DISABLED, "missing_runtime_nodes_or_players")
		return false
	_clear_active_zombies()
	_reset_players()
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

func stop_run(reason: String = "stopped") -> void:
	if not has_simulation_authority():
		return
	_clear_active_zombies()
	wave_total_enemies = 0
	wave_spawned = 0
	wave_killed = 0
	_set_state(State.DISABLED, reason)
	_emit_population()

func restart_run() -> bool:
	var started := start_run()
	if started:
		run_restarted.emit()
	return started

func apply_replica_snapshot(snapshot: Dictionary) -> void:
	if has_simulation_authority() or snapshot.is_empty():
		return
	var previous := state
	state = int(snapshot.get("state", state))
	wave_number = int(snapshot.get("wave", wave_number))
	score = int(snapshot.get("score", score))
	kills = int(snapshot.get("kills", kills))
	wave_total_enemies = int(snapshot.get("wave_total", wave_total_enemies))
	wave_spawned = int(snapshot.get("wave_spawned", wave_spawned))
	wave_killed = int(snapshot.get("wave_killed", wave_killed))
	_current_population_cost = int(snapshot.get("active_population_cost", _current_population_cost))
	_phase_time_remaining = float(snapshot.get("countdown", 0))
	if previous != state:
		state_changed.emit(previous, state, "network_snapshot")
	_emit_score()
	population_changed.emit(int(snapshot.get("active_zombies", 0)), _current_population_cost, int(snapshot.get("population_budget", get_population_budget())), int(snapshot.get("enemies_remaining", 0)))
	countdown_changed.emit(int(snapshot.get("countdown", 0)), 1 if state == State.COUNTDOWN else wave_number + 1)
	if state == State.GAME_OVER:
		game_over.emit(wave_number, score, kills)

func get_state_name() -> String:
	return State.keys()[state]

func get_population_budget() -> int:
	return HordeRulesScript.population_budget(_current_quality_profile(), get_scaling_squad_size())

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
		"players": get_registered_player_count(),
		"alive_players": get_alive_player_count(),
		"downed_players": get_downed_player_count(),
		"recoverable_players": get_recoverable_player_count(),
		"scaling_squad_size": get_scaling_squad_size(),
	}

func debug_spawn_archetype(archetype_id: StringName) -> Node3D:
	var data := _find_archetype(archetype_id)
	return _spawn_zombie(data) if data != null else null

func _resolve_runtime_nodes() -> void:
	_spawn_root = get_node_or_null(spawn_points_path) as Node3D
	_zombie_parent = get_node_or_null(zombie_parent_path) as Node3D
	if not player_path.is_empty():
		var legacy_player := get_node_or_null(player_path) as Node3D
		if legacy_player != null:
			register_player(legacy_player)

func _seed_rng() -> void:
	if deterministic_seed != 0:
		_rng.seed = deterministic_seed
	else:
		_rng.randomize()

func _tick_countdown(delta: float, initial: bool) -> void:
	_phase_time_remaining = maxf(0.0, _phase_time_remaining - delta)
	_emit_countdown(1 if initial else wave_number + 1)
	if _phase_time_remaining <= 0.0:
		_begin_next_wave()

func _begin_next_wave() -> void:
	wave_number += 1
	var squad_size := get_scaling_squad_size()
	wave_total_enemies = HordeRulesScript.wave_total(wave_number, squad_size)
	wave_spawned = 0
	wave_killed = 0
	_spawn_elapsed = HordeRulesScript.spawn_interval(_current_quality_profile(), spawn_interval_seconds, squad_size)
	_set_state(State.SPAWNING, "wave_started")
	wave_started.emit(wave_number, wave_total_enemies)
	_emit_population()
	if OS.is_debug_build():
		print("DEADFALL_HORDE_WAVE_START wave=%d total=%d budget=%d squad=%d alive=%d downed=%d" % [wave_number, wave_total_enemies, get_population_budget(), squad_size, get_alive_player_count(), get_downed_player_count()])

func _tick_spawning(delta: float) -> void:
	if wave_spawned >= wave_total_enemies:
		_set_state(State.ACTIVE, "wave_fully_spawned")
		_check_wave_complete()
		return
	_spawn_elapsed += delta
	var interval := HordeRulesScript.spawn_interval(_current_quality_profile(), spawn_interval_seconds, get_scaling_squad_size())
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
		if not HordeRulesScript.is_unlocked(data, for_wave) or HordeRulesScript.population_cost(data) > remaining_budget:
			continue
		var weight := HordeRulesScript.spawn_weight(data, for_wave)
		if weight > 0.0:
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
	zombie.name = "%s_%d" % [String(data.get("display_name")).replace(" ", ""), entity_id]
	_zombie_parent.add_child(zombie)
	zombie.global_position = spawn_point.global_position
	var health := zombie.get_node_or_null("Health")
	if health == null:
		zombie.queue_free()
		return null
	if authority_override != null and authority_override.has_method("register_damageable"):
		authority_override.call("register_damageable", entity_id, health)
	health.connect("died", Callable(self, "_on_zombie_died").bind(zombie))
	var archetype_id := StringName(data.get("archetype_id"))
	_active_zombies[zombie.get_instance_id()] = {"node": zombie, "cost": cost, "score": maxi(0, int(data.get("score_value"))), "archetype_id": archetype_id}
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
		if _spawn_is_safe(point.global_position):
			safe_points.append(point)
	var pool: Array[Node3D] = safe_points if not safe_points.is_empty() else all_points
	return null if pool.is_empty() else pool[_rng.randi_range(0, pool.size() - 1)]

func _spawn_is_safe(position: Vector3) -> bool:
	for record in _players.values():
		if not _record_player_recoverable(record):
			continue
		var player := record.get("node") as Node3D
		if player != null and position.distance_to(player.global_position) < spawn_safety_radius:
			return false
	return true

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
	zombie_killed.emit(StringName(record.get("archetype_id", &"walker")), awarded)
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

func _on_registered_player_died(_event, _player_instance_id: int) -> void:
	if get_recoverable_player_count() == 0:
		_enter_game_over("squad_not_recoverable")

func _on_registered_life_state_changed(_previous: int, _current: int, _reason: String, _player_instance_id: int) -> void:
	if state != State.DISABLED and state != State.GAME_OVER and get_recoverable_player_count() == 0:
		_enter_game_over("squad_not_recoverable")

func _enter_game_over(reason: String) -> void:
	if state == State.GAME_OVER:
		return
	_set_state(State.GAME_OVER, reason)
	for record in _active_zombies.values():
		var zombie = record.get("node")
		if zombie != null and is_instance_valid(zombie):
			zombie.set_physics_process(false)
	game_over.emit(wave_number, score, kills)

func _reset_players() -> void:
	for record in _players.values():
		var player := record.get("node") as Node3D
		var health = record.get("health")
		var life = record.get("life")
		if player == null or not is_instance_valid(player):
			continue
		if health != null and is_instance_valid(health) and health.has_method("reset_health"):
			health.call("reset_health")
		if life != null and is_instance_valid(life) and life.has_method("reset_authoritative_life"):
			life.call("reset_authoritative_life")
		player.global_transform = Transform3D(record.get("start_transform", player.global_transform))
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
		player.set_physics_process(true)

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

func _prune_invalid_players() -> void:
	for key in _players.keys():
		var record: Dictionary = _players[key]
		var player = record.get("node")
		if player == null or not is_instance_valid(player):
			_players.erase(key)

func _record_player_alive(record: Dictionary) -> bool:
	var player = record.get("node")
	var health = record.get("health")
	var life = record.get("life")
	if player == null or not is_instance_valid(player) or health == null or not is_instance_valid(health):
		return false
	if life != null and is_instance_valid(life) and life.has_method("is_alive"):
		return bool(life.call("is_alive"))
	return not health.has_method("is_dead") or not bool(health.call("is_dead"))

func _record_player_recoverable(record: Dictionary) -> bool:
	var player = record.get("node")
	var health = record.get("health")
	var life = record.get("life")
	if player == null or not is_instance_valid(player) or health == null or not is_instance_valid(health):
		return false
	if life != null and is_instance_valid(life) and life.has_method("is_recoverable"):
		return bool(life.call("is_recoverable"))
	return _record_player_alive(record)

func _find_archetype(archetype_id: StringName) -> Resource:
	for data in ARCHETYPES:
		if StringName(data.get("archetype_id")) == archetype_id:
			return data
	return null

func _current_quality_profile() -> Dictionary:
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.has_method("current_profile"):
		return settings.call("current_profile")
	return {"horde_population": 10, "horde_spawn_rate": 1.0, "horde_squad_population_bonus": 2}

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
