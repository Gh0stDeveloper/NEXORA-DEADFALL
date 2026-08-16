class_name DeadfallCampaignDirector
extends Node

signal state_changed(previous_state: int, current_state: int, reason: String)
signal mission_started(mission_id: StringName, title: String)
signal objective_started(index: int, objective_id: StringName, title: String)
signal objective_progress_changed(index: int, current: float, required: float)
signal objective_completed(index: int, objective_id: StringName)
signal checkpoint_saved(checkpoint_id: StringName)
signal mission_completed(mission_id: StringName)

const ObjectiveDataScript = preload("res://src/campaign/CampaignObjectiveData.gd")
const SaveStoreScript = preload("res://src/campaign/CampaignSaveStore.gd")

enum State {
	DISABLED,
	RUNNING,
	COMPLETED,
	FAILED,
}

@export var mission: Resource
@export var auto_start := false
@export var target_root_path := NodePath("../CampaignTargets")
@export var horde_director_path := NodePath("../HordeDirector")
@export var persistence_enabled := true
@export var persistence_slot := "default"

var state: int = State.DISABLED
var objective_index := 0
var objective_progress := 0.0
var checkpoint_id: StringName = &""
var authority_override: RefCounted

var _target_root: Node3D
var _horde: Node
var _interaction_progress: Dictionary = {}
var _replica_status: Dictionary = {}

func _ready() -> void:
	_resolve_nodes()
	_bind_horde()
	if auto_start:
		call_deferred("start_mission", mission, true)

func _process(delta: float) -> void:
	if not has_simulation_authority() or state != State.RUNNING:
		return
	var objective := get_current_objective()
	if objective == null:
		_finish_mission()
		return
	match int(objective.get("objective_type")):
		ObjectiveDataScript.ObjectiveType.REACH, ObjectiveDataScript.ObjectiveType.EXTRACT:
			_tick_position_objective(objective)
		ObjectiveDataScript.ObjectiveType.SURVIVE:
			_tick_survive_objective(objective, delta)
		ObjectiveDataScript.ObjectiveType.INTERACT:
			_tick_interact_objective(objective, delta)

func set_authority_override(value: RefCounted) -> void:
	authority_override = value

func has_simulation_authority() -> bool:
	if authority_override != null:
		return true
	if get_tree() == null:
		return false
	var game := get_tree().root.get_node_or_null("Game")
	return game != null and game.has_method("is_simulation_authority") and bool(game.call("is_simulation_authority"))

func start_mission(new_mission: Resource = null, restore_from_checkpoint: bool = true) -> bool:
	if not has_simulation_authority():
		return false
	if new_mission != null:
		mission = new_mission
	if mission == null or not mission.has_method("is_valid_definition") or not bool(mission.call("is_valid_definition")):
		_set_state(State.DISABLED, "invalid_mission")
		return false
	objective_index = 0
	objective_progress = 0.0
	checkpoint_id = &""
	_interaction_progress.clear()
	_replica_status.clear()
	var restored_completed := false
	if restore_from_checkpoint and _can_persist():
		restored_completed = _restore_progress()
	if restored_completed:
		_set_state(State.COMPLETED, "restored_completed")
		mission_completed.emit(StringName(mission.get("mission_id")))
		return true
	_set_state(State.RUNNING, "mission_started")
	mission_started.emit(StringName(mission.get("mission_id")), String(mission.get("title")))
	_emit_objective_started()
	if checkpoint_id != &"":
		call_deferred("_teleport_recoverable_players_to_checkpoint", checkpoint_id)
	return true

func restart_mission(clear_checkpoint: bool = true) -> bool:
	if clear_checkpoint and _can_persist():
		SaveStoreScript.clear_progress(persistence_slot)
	return start_mission(mission, false)

func get_current_objective() -> Resource:
	if mission == null or not mission.has_method("objective_at"):
		return null
	return mission.call("objective_at", objective_index)

func report_zombie_kill(count: int = 1) -> bool:
	if not has_simulation_authority() or state != State.RUNNING:
		return false
	var objective := get_current_objective()
	if objective == null or int(objective.get("objective_type")) != ObjectiveDataScript.ObjectiveType.KILL:
		return false
	objective_progress += float(maxi(1, count))
	var required := float(objective.call("required_value"))
	objective_progress_changed.emit(objective_index, objective_progress, required)
	if objective_progress >= required:
		_complete_current_objective()
	return true

func apply_replica_snapshot(snapshot: Dictionary) -> void:
	if has_simulation_authority() or snapshot.is_empty():
		return
	var previous := state
	_replica_status = snapshot.duplicate(true)
	state = int(snapshot.get("state", state))
	objective_index = int(snapshot.get("objective_index", objective_index))
	objective_progress = float(snapshot.get("progress", objective_progress))
	checkpoint_id = StringName(snapshot.get("checkpoint_id", checkpoint_id))
	if previous != state:
		state_changed.emit(previous, state, "network_snapshot")
	objective_progress_changed.emit(objective_index, objective_progress, float(snapshot.get("required", 1.0)))

func get_status_snapshot() -> Dictionary:
	if not has_simulation_authority() and not _replica_status.is_empty():
		return _replica_status.duplicate(true)
	var objective := get_current_objective()
	var required := float(objective.call("required_value")) if objective != null and objective.has_method("required_value") else 1.0
	var current_id: StringName = StringName(objective.get("objective_id")) if objective != null else &""
	var objective_title := String(objective.get("title")) if objective != null else ""
	var objective_type := int(objective.get("objective_type")) if objective != null else -1
	return {
		"state": state,
		"state_name": State.keys()[clampi(state, State.DISABLED, State.FAILED)],
		"campaign_id": StringName(mission.get("campaign_id")) if mission != null else &"",
		"mission_id": StringName(mission.get("mission_id")) if mission != null else &"",
		"mission_title": String(mission.get("title")) if mission != null else "",
		"objective_index": objective_index,
		"objective_count": int(mission.call("objective_count")) if mission != null and mission.has_method("objective_count") else 0,
		"objective_id": current_id,
		"objective_title": objective_title,
		"objective_type": objective_type,
		"progress": objective_progress,
		"required": required,
		"progress_ratio": clampf(objective_progress / required, 0.0, 1.0) if required > 0.0 else 0.0,
		"checkpoint_id": checkpoint_id,
	}

func _resolve_nodes() -> void:
	_target_root = get_node_or_null(target_root_path) as Node3D
	_horde = get_node_or_null(horde_director_path)

func _bind_horde() -> void:
	if _horde == null:
		return
	if _horde.has_signal("zombie_killed"):
		var callable := Callable(self, "_on_horde_zombie_killed")
		if not _horde.is_connected("zombie_killed", callable):
			_horde.connect("zombie_killed", callable)

func _on_horde_zombie_killed(_archetype_id: StringName, _score_awarded: int) -> void:
	report_zombie_kill(1)

func _tick_position_objective(objective: Resource) -> void:
	var target := _resolve_target(StringName(objective.get("target_id")))
	if target == null:
		return
	var radius := maxf(0.5, float(objective.get("radius")))
	for player in _recoverable_players():
		if player.global_position.distance_to(target.global_position) <= radius:
			objective_progress = 1.0
			objective_progress_changed.emit(objective_index, 1.0, 1.0)
			_complete_current_objective()
			return

func _tick_survive_objective(objective: Resource, delta: float) -> void:
	if _recoverable_players().is_empty():
		return
	var required := float(objective.call("required_value"))
	objective_progress = minf(required, objective_progress + delta)
	objective_progress_changed.emit(objective_index, objective_progress, required)
	if objective_progress >= required:
		_complete_current_objective()

func _tick_interact_objective(objective: Resource, delta: float) -> void:
	var target := _resolve_target(StringName(objective.get("target_id")))
	if target == null:
		return
	var radius := maxf(0.5, float(objective.get("radius")))
	var required := float(objective.call("required_value"))
	var active: Dictionary = {}
	var best := 0.0
	for player in _recoverable_players():
		if not _player_wants_interact(player) or player.global_position.distance_to(target.global_position) > radius:
			continue
		var entity_id := _player_entity_id(player)
		var elapsed := float(_interaction_progress.get(entity_id, 0.0)) + delta
		active[entity_id] = elapsed
		best = maxf(best, elapsed)
	_interaction_progress = active
	objective_progress = minf(required, best)
	objective_progress_changed.emit(objective_index, objective_progress, required)
	if objective_progress >= required:
		_complete_current_objective()

func _complete_current_objective() -> void:
	var objective := get_current_objective()
	if objective == null:
		_finish_mission()
		return
	var completed_index := objective_index
	var completed_id := StringName(objective.get("objective_id"))
	var next_checkpoint := StringName(objective.get("checkpoint_id"))
	objective_completed.emit(completed_index, completed_id)
	objective_index += 1
	objective_progress = 0.0
	_interaction_progress.clear()
	if next_checkpoint != &"":
		checkpoint_id = next_checkpoint
		_save_progress(false)
		checkpoint_saved.emit(checkpoint_id)
	if mission != null and objective_index >= int(mission.call("objective_count")):
		_finish_mission()
	else:
		_emit_objective_started()

func _finish_mission() -> void:
	if state == State.COMPLETED:
		return
	_set_state(State.COMPLETED, "all_objectives_complete")
	_save_progress(true)
	mission_completed.emit(StringName(mission.get("mission_id")) if mission != null else &"")

func _emit_objective_started() -> void:
	var objective := get_current_objective()
	if objective == null:
		return
	objective_started.emit(objective_index, StringName(objective.get("objective_id")), String(objective.get("title")))
	objective_progress_changed.emit(objective_index, objective_progress, float(objective.call("required_value")))

func _resolve_target(target_id: StringName) -> Node3D:
	if _target_root == null or target_id == &"":
		return null
	return _target_root.get_node_or_null(NodePath(String(target_id))) as Node3D

func _recoverable_players() -> Array[Node3D]:
	var result: Array[Node3D] = []
	if get_tree() == null:
		return result
	for candidate in get_tree().get_nodes_in_group("deadfall_player"):
		var player := candidate as Node3D
		if player == null or not is_instance_valid(player):
			continue
		var life := player.get_node_or_null("LifeState")
		if life != null and life.has_method("is_recoverable") and not bool(life.call("is_recoverable")):
			continue
		var health := player.get_node_or_null("Health")
		if life == null and health != null and health.has_method("is_dead") and bool(health.call("is_dead")):
			continue
		result.append(player)
	return result

func _player_entity_id(player: Node3D) -> int:
	if player == null:
		return 0
	var value = player.get("player_entity_id")
	return int(value) if value != null else int(player.get_instance_id())

func _player_wants_interact(player: Node3D) -> bool:
	if player == null:
		return false
	var mode_value = player.get("control_mode")
	if mode_value != null and int(mode_value) == 2:
		var server_command = player.get("_server_command")
		if typeof(server_command) == TYPE_DICTIONARY:
			return bool(Dictionary(server_command).get("interact", false))
	var input_source := player.get_node_or_null("PlayerInput")
	return input_source != null and input_source.has_method("is_action_pressed") and bool(input_source.call("is_action_pressed", &"interact"))

func _can_persist() -> bool:
	if not persistence_enabled or get_tree() == null:
		return false
	var game := get_tree().root.get_node_or_null("Game")
	return game != null and game.has_method("is_local_session") and bool(game.call("is_local_session"))

func _save_progress(completed: bool) -> void:
	if not _can_persist() or mission == null:
		return
	SaveStoreScript.save_progress(persistence_slot, {
		"campaign_id": String(mission.get("campaign_id")),
		"mission_id": String(mission.get("mission_id")),
		"objective_index": objective_index,
		"checkpoint_id": String(checkpoint_id),
		"completed": completed,
	})

func _restore_progress() -> bool:
	var data := SaveStoreScript.load_progress(persistence_slot)
	if data.is_empty() or mission == null:
		return false
	if String(data.get("campaign_id", "")) != String(mission.get("campaign_id")) or String(data.get("mission_id", "")) != String(mission.get("mission_id")):
		return false
	objective_index = clampi(int(data.get("objective_index", 0)), 0, int(mission.call("objective_count")))
	checkpoint_id = StringName(data.get("checkpoint_id", ""))
	return bool(data.get("completed", false)) or objective_index >= int(mission.call("objective_count"))

func _teleport_recoverable_players_to_checkpoint(target_id: StringName) -> void:
	var target := _resolve_target(target_id)
	if target == null:
		return
	var players := _recoverable_players()
	for index in range(players.size()):
		players[index].global_position = target.global_position + Vector3(float(index) * 0.8, 0.0, 0.0)
		if players[index] is CharacterBody3D:
			(players[index] as CharacterBody3D).velocity = Vector3.ZERO

func _set_state(next_state: int, reason: String) -> void:
	if state == next_state:
		return
	var previous := state
	state = next_state
	state_changed.emit(previous, state, reason)
