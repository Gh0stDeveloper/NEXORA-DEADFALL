class_name DeadfallPlayerLifeState
extends Node

signal state_changed(previous_state: int, current_state: int, reason: String)
signal downed(event)
signal revived(reviver_entity_id: int)
signal fully_dead(event)
signal bleedout_changed(seconds_remaining: float)
signal revive_progress_changed(progress: float, reviver_entity_id: int)

enum LifeState {
	ALIVE,
	DOWNED,
	DEAD,
}

@export var health_path := NodePath("../Health")
@export var downed_enabled := false
@export var bleedout_seconds := 30.0
@export var revive_hold_seconds := 3.0
@export var revive_distance := 2.4
@export_range(0.05, 1.0, 0.05) var revive_health_fraction := 0.35
@export_range(0.05, 1.0, 0.05) var downed_move_multiplier := 0.35

var state: int = LifeState.ALIVE
var bleedout_remaining := 0.0
var revive_progress := 0.0
var reviver_entity_id := 0
var _health: Node

func _ready() -> void:
	_health = get_node_or_null(health_path)
	if _health != null:
		if _health.has_method("set_lethal_handler"):
			_health.call("set_lethal_handler", self)
		if _health.has_signal("died"):
			_health.connect("died", Callable(self, "_on_health_died"))

func _process(delta: float) -> void:
	if state != LifeState.DOWNED or not _has_simulation_authority():
		return
	bleedout_remaining = maxf(0.0, bleedout_remaining - delta)
	bleedout_changed.emit(bleedout_remaining)
	if bleedout_remaining <= 0.0 and _health != null and _health.has_method("force_authoritative_death"):
		_health.call("force_authoritative_death", null)

func configure_squad_mode(enabled: bool) -> void:
	downed_enabled = enabled

func intercept_lethal_damage(event) -> float:
	if not downed_enabled or state != LifeState.ALIVE or not _has_simulation_authority():
		return 0.0
	bleedout_remaining = maxf(1.0, bleedout_seconds)
	revive_progress = 0.0
	reviver_entity_id = 0
	_set_state(LifeState.DOWNED, "lethal_damage")
	downed.emit(event)
	var maximum := float(_health.get("max_health")) if _health != null else 100.0
	return maxf(1.0, maximum * 0.01)

func revive_authoritative(reviver_id: int) -> bool:
	if state != LifeState.DOWNED or not _has_simulation_authority() or _health == null:
		return false
	var maximum := maxf(1.0, float(_health.get("max_health")))
	var restored := maxf(1.0, maximum * clampf(revive_health_fraction, 0.05, 1.0))
	if not _health.has_method("restore_authoritative_state") or not bool(_health.call("restore_authoritative_state", restored, maximum, false)):
		return false
	bleedout_remaining = 0.0
	revive_progress = 0.0
	reviver_entity_id = 0
	_set_state(LifeState.ALIVE, "revived")
	revived.emit(reviver_id)
	return true

func reset_authoritative_life() -> void:
	if not _has_simulation_authority():
		return
	bleedout_remaining = 0.0
	revive_progress = 0.0
	reviver_entity_id = 0
	_set_state(LifeState.ALIVE, "run_reset")

func set_replica_revive_progress(progress: float, reviver_id: int) -> void:
	var next_progress := clampf(progress, 0.0, 1.0)
	if is_equal_approx(next_progress, revive_progress) and reviver_entity_id == reviver_id:
		return
	revive_progress = next_progress
	reviver_entity_id = reviver_id
	revive_progress_changed.emit(revive_progress, reviver_entity_id)

func get_network_snapshot(progress_override: float = -1.0, reviver_override: int = -1) -> Dictionary:
	return {
		"state": state,
		"state_name": get_state_name(),
		"bleedout": maxf(0.0, bleedout_remaining),
		"revive_progress": revive_progress if progress_override < 0.0 else clampf(progress_override, 0.0, 1.0),
		"reviver_entity_id": reviver_entity_id if reviver_override < 0 else reviver_override,
		"bleedout_seconds": bleedout_seconds,
		"revive_seconds": revive_hold_seconds,
	}

func apply_network_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	var next_state := clampi(int(snapshot.get("state", state)), LifeState.ALIVE, LifeState.DEAD)
	var previous := state
	state = next_state
	bleedout_remaining = maxf(0.0, float(snapshot.get("bleedout", bleedout_remaining)))
	revive_progress = clampf(float(snapshot.get("revive_progress", 0.0)), 0.0, 1.0)
	reviver_entity_id = maxi(0, int(snapshot.get("reviver_entity_id", 0)))
	if previous != state:
		state_changed.emit(previous, state, "network_snapshot")
	bleedout_changed.emit(bleedout_remaining)
	revive_progress_changed.emit(revive_progress, reviver_entity_id)

func restore_authoritative_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty() or not _has_simulation_authority():
		return
	state = clampi(int(snapshot.get("state", LifeState.ALIVE)), LifeState.ALIVE, LifeState.DEAD)
	bleedout_remaining = maxf(0.0, float(snapshot.get("bleedout", 0.0)))
	revive_progress = 0.0
	reviver_entity_id = 0

func is_alive() -> bool:
	return state == LifeState.ALIVE

func is_downed() -> bool:
	return state == LifeState.DOWNED

func is_dead() -> bool:
	return state == LifeState.DEAD

func is_recoverable() -> bool:
	return state != LifeState.DEAD

func can_use_weapon() -> bool:
	return state == LifeState.ALIVE

func get_movement_multiplier() -> float:
	if state == LifeState.DOWNED:
		return clampf(downed_move_multiplier, 0.05, 1.0)
	return 1.0 if state == LifeState.ALIVE else 0.0

func get_state_name() -> String:
	return LifeState.keys()[state]

func get_revive_distance() -> float:
	return maxf(0.5, revive_distance)

func get_revive_hold_seconds() -> float:
	return maxf(0.25, revive_hold_seconds)

func _on_health_died(event) -> void:
	bleedout_remaining = 0.0
	revive_progress = 0.0
	reviver_entity_id = 0
	_set_state(LifeState.DEAD, "health_depleted")
	fully_dead.emit(event)

func _set_state(next_state: int, reason: String) -> void:
	if state == next_state:
		return
	var previous := state
	state = next_state
	state_changed.emit(previous, state, reason)

func _has_simulation_authority() -> bool:
	if get_tree() == null:
		return false
	var game := get_tree().root.get_node_or_null("Game")
	return game != null and game.has_method("is_simulation_authority") and bool(game.call("is_simulation_authority"))
