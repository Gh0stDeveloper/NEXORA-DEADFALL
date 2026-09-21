class_name DeadfallZombieController
extends CharacterBody3D

signal state_changed(previous_state: int, current_state: int, reason: String)
signal target_changed(target)
signal melee_attack_resolved(event)
signal navigation_fallback_used()
signal crawler_mode_changed(enabled: bool)

enum State { IDLE, SEARCH, CHASE, ATTACK, STAGGER, DEAD }
const DamageEventScript = preload("res://src/core/damage/DamageEvent.gd")

@export var entity_id := 2001
@export var zombie_data: Resource
@export var target_group: StringName = &"deadfall_player"
@export_flags_3d_physics var visibility_mask: int = 1
@export var debug_state_logs := false

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var health: Node = $Health
@onready var gore: Node = $Gore
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var hitboxes: Node3D = $Hitboxes
@onready var visual_root: Node3D = $VisualRoot
@onready var state_label: Label3D = get_node_or_null("VisualRoot/StateLabel")

var state: int = State.IDLE
var authority_override: RefCounted
var _target: Node3D
var _gravity := 9.8
var _state_elapsed := 0.0
var _scan_elapsed := 0.0
var _repath_elapsed := 0.0
var _sight_lost_elapsed := 0.0
var _next_attack_usec: int = 0
var _last_known_position := Vector3.ZERO
var _has_last_known_position := false
var _navigation_fallback_announced := false
var _death_hit_direction := Vector3.ZERO
var _crawler_mode := false
var _attack_damage_multiplier := 1.0
var _attack_cooldown_multiplier := 1.0
var _horde_pursuit := false
var _path_requested := false
var _sight_elapsed := 0.0
var _cached_sight := false

func _enter_tree() -> void:
	preload("res://src/core/PresentationRuntime.gd").attach_actor(self, "res://src/zombies/base/ZombiePresentation.tscn", true)

func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	# Crawling changes this shape. Each zombie must own its capsule.
	if collision_shape.shape != null:
		collision_shape.shape = collision_shape.shape.duplicate(true)
	_scan_elapsed = -float(entity_id % 11) * 0.02
	_repath_elapsed = -float(entity_id % 7) * 0.035
	if health.has_method("configure_entity"): health.call("configure_entity", entity_id, _cfg_float(&"max_health", 100.0))
	for child in hitboxes.get_children(): child.set("victim_id", entity_id)
	if health.has_signal("health_changed"): health.connect("health_changed", Callable(self, "_on_health_changed"))
	if health.has_signal("died"): health.connect("died", Callable(self, "_on_died"))
	if gore != null:
		gore.set("zombie_data", zombie_data)
		if gore.has_signal("crawler_required"): gore.connect("crawler_required", Callable(self, "_on_crawler_required"))
		if gore.has_signal("attack_capability_changed"): gore.connect("attack_capability_changed", Callable(self, "_on_attack_capability_changed"))
		if gore.has_signal("head_destroyed"): gore.connect("head_destroyed", Callable(self, "_on_head_destroyed"))
	navigation_agent.path_desired_distance = 0.35
	# Recast's 0.25 m voxel bake places the walkable surface about 0.5 m
	# above the collider floor. Without this offset the first waypoint is
	# vertically farther than path_desired_distance, so its XZ never advances.
	navigation_agent.path_height_offset = 0.5
	navigation_agent.target_desired_distance = maxf(0.45, _effective_attack_range() * 0.55)
	navigation_agent.radius = 0.45
	navigation_agent.avoidance_enabled = false
	if state_label != null:
		state_label.visible = "--show-ai-debug" in OS.get_cmdline_user_args()
	_update_debug_label()

func _physics_process(delta: float) -> void:
	if not has_simulation_authority() or state == State.DEAD: return
	_state_elapsed += delta; _scan_elapsed += delta; _repath_elapsed += delta
	_sight_elapsed += delta
	_process_vertical_velocity(delta)
	match state:
		State.IDLE: _process_idle()
		State.SEARCH: _process_search()
		State.CHASE: _process_chase(delta)
		State.ATTACK: _process_attack()
		State.STAGGER: _process_stagger()
	preload("res://src/core/CharacterMovement.gd").move(self, delta)

func set_authority_override(value: RefCounted) -> void: authority_override = value
func has_simulation_authority() -> bool:
	if authority_override != null: return true
	if get_tree() == null: return false
	var game := get_tree().root.get_node_or_null("Game")
	return game != null and game.has_method("is_simulation_authority") and bool(game.call("is_simulation_authority"))
func get_state_name() -> String: return State.keys()[state]
func get_target() -> Node3D:
	return _target if is_instance_valid(_target) else null
func is_crawler() -> bool: return _crawler_mode
func get_attack_damage_multiplier() -> float: return _attack_damage_multiplier
func get_attack_cooldown_multiplier() -> float: return _attack_cooldown_multiplier

func enable_horde_pursuit() -> void:
	# Horde members are dispatched toward the survivors, including around corners.
	# Ambient zombies retain their normal sight/range acquisition behavior.
	_horde_pursuit = true
	var candidate := _find_horde_target()
	if candidate != null:
		_set_target(candidate)
		_transition_to(State.CHASE, "horde_dispatched")

func _find_horde_target() -> Node3D:
	var best: Node3D
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(target_group):
		var candidate := node as Node3D
		if not _target_is_alive(candidate):
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best

func perform_melee_attack(target: Node3D) -> bool:
	if not has_simulation_authority() or state != State.ATTACK: return false
	if target == null or not _target_is_alive(target): return false
	if not _is_target_in_attack_range(target, 1.25): return false
	var target_health := target.get_node_or_null("Health")
	if target_health == null: return false
	var victim_id := int(target_health.get("entity_id"))
	if victim_id == 0: return false
	var active_authority = _get_active_authority()
	if active_authority == null or not active_authority.has_method("resolve_damage"): return false
	var event = DamageEventScript.new()
	event.attacker_id = entity_id; event.victim_id = victim_id; event.weapon_id = &"zombie_melee"
	event.amount = _cfg_float(&"attack_damage", 12.0) * _attack_damage_multiplier
	event.damage_type = DamageEventScript.DamageType.MELEE; event.body_part = DamageEventScript.BodyPart.CHEST
	event.hit_position = target.global_position + Vector3.UP; event.hit_direction = (target.global_position - global_position).normalized(); event.hit_normal = -event.hit_direction
	event.simulation_tick = Engine.get_physics_frames()
	if not active_authority.resolve_damage(event): return false
	melee_attack_resolved.emit(event); return true

func _process_idle() -> void:
	_stop_horizontal()
	if _scan_elapsed < _cfg_float(&"scan_interval_seconds", 0.2): return
	_scan_elapsed = 0.0
	var candidate := _find_horde_target() if _horde_pursuit else _find_visible_target()
	if candidate != null: _set_target(candidate); _transition_to(State.CHASE, "target_acquired")

func _process_search() -> void:
	if _scan_elapsed >= _cfg_float(&"scan_interval_seconds", 0.2):
		_scan_elapsed = 0.0
		var candidate := _find_visible_target()
		if candidate != null: _set_target(candidate); _transition_to(State.CHASE, "target_reacquired"); return
	if _state_elapsed >= _cfg_float(&"search_seconds", 4.0):
		_set_target(null); _has_last_known_position = false; _transition_to(State.IDLE, "search_timeout"); return
	if _has_last_known_position:
		if global_position.distance_to(_last_known_position) <= 0.8: _stop_horizontal()
		else: _move_towards_destination(_last_known_position)
	else: _stop_horizontal()

func _process_chase(delta: float) -> void:
	if not _target_is_alive(_target): _set_target(null); _transition_to(State.IDLE, "target_invalid"); return
	var distance := global_position.distance_to(_target.global_position)
	if _horde_pursuit:
		if _scan_elapsed >= 1.0:
			_scan_elapsed = 0.0
			var candidate := _find_horde_target()
			if candidate != null:
				_set_target(candidate)
		_last_known_position = _target.global_position
		_has_last_known_position = true
		if _is_target_in_attack_range(_target, 1.0) and _can_see_target(_target):
			_transition_to(State.ATTACK, "horde_in_attack_range")
			return
		_move_towards_destination(_target.global_position)
		return
	if distance > _cfg_float(&"lose_target_range", 30.0):
		_last_known_position = _target.global_position; _has_last_known_position = true; _set_target(null); _transition_to(State.SEARCH, "target_out_of_range"); return
	if _sight_elapsed >= 0.2:
		_sight_elapsed = 0.0
		_cached_sight = _can_see_target(_target)
	if _cached_sight:
		_sight_lost_elapsed = 0.0; _last_known_position = _target.global_position; _has_last_known_position = true
	else:
		_sight_lost_elapsed += delta
		if _sight_lost_elapsed >= _cfg_float(&"sight_memory_seconds", 1.0): _transition_to(State.SEARCH, "line_of_sight_lost"); return
	if _is_target_in_attack_range(_target, 1.0) and _can_see_target(_target): _transition_to(State.ATTACK, "target_in_attack_range"); return
	_move_towards_destination(_target.global_position)

func _process_attack() -> void:
	_stop_horizontal()
	if not _target_is_alive(_target): _set_target(null); _transition_to(State.IDLE, "target_invalid"); return
	_face_position(_target.global_position)
	if not _is_target_in_attack_range(_target, 1.25): _transition_to(State.CHASE, "target_left_attack_range"); return
	if not _can_see_target(_target): _transition_to(State.CHASE, "attack_line_of_sight_lost"); return
	var now_usec := Time.get_ticks_usec()
	if now_usec >= _next_attack_usec:
		perform_melee_attack(_target)
		_next_attack_usec = now_usec + int(_cfg_float(&"attack_cooldown_seconds", 1.1) * _attack_cooldown_multiplier * 1_000_000.0)

func _process_stagger() -> void:
	_stop_horizontal()
	if _state_elapsed < _cfg_float(&"stagger_seconds", 0.35): return
	if _target_is_alive(_target): _transition_to(State.CHASE, "stagger_recovered")
	elif _has_last_known_position: _transition_to(State.SEARCH, "stagger_recovered_search")
	else: _transition_to(State.IDLE, "stagger_recovered_idle")

func _process_vertical_velocity(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0: velocity.y = -0.1
	else: velocity.y -= _gravity * delta

func _move_towards_destination(destination: Vector3) -> void:
	var repath_interval := maxf(0.35, _cfg_float(&"repath_interval_seconds", 0.25))
	var map := navigation_agent.get_navigation_map()
	var map_ready := map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0
	var changed := navigation_agent.target_position.distance_squared_to(destination) > 0.36
	var requested_now := false
	if map_ready and (not _path_requested or (_repath_elapsed >= repath_interval and (changed or navigation_agent.is_navigation_finished()))):
		navigation_agent.target_position = destination
		_repath_elapsed = 0.0
		_path_requested = true
		requested_now = true
	var movement_target := destination
	var used_navigation := false
	if map_ready and (requested_now or not navigation_agent.is_navigation_finished()):
		var next_position := navigation_agent.get_next_path_position()
		if navigation_agent.get_current_navigation_path().size() > 0:
			movement_target = next_position
			used_navigation = true
	if not used_navigation:
		# Direct movement is only safe along an unobstructed segment. Never push
		# forever against a wall when a map is baking or a route is unavailable.
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.8, destination + Vector3.UP * 0.8, visibility_mask)
		query.exclude = [get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			_stop_horizontal()
			return
	if not used_navigation and not _navigation_fallback_announced:
		_navigation_fallback_announced = true; navigation_fallback_used.emit()
		if debug_state_logs and OS.is_debug_build(): print("DEADFALL_ZOMBIE_NAV_FALLBACK entity=%d" % entity_id)
	elif used_navigation: _navigation_fallback_announced = false
	var direction := movement_target - global_position; direction.y = 0.0
	if direction.length_squared() <= 0.0001: _stop_horizontal(); return
	direction = direction.normalized()
	var speed := _cfg_float(&"move_speed", 3.2)
	if _crawler_mode: speed *= _cfg_float(&"crawler_speed_multiplier", 0.42)
	velocity.x = direction.x * speed; velocity.z = direction.z * speed; _face_direction(direction)

func _find_visible_target() -> Node3D:
	if get_tree() == null: return null
	var best: Node3D = null; var best_distance := INF; var detection_range := _cfg_float(&"detection_range", 20.0)
	for node in get_tree().get_nodes_in_group(target_group):
		var candidate := node as Node3D
		if candidate == null or not _target_is_alive(candidate): continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance > detection_range or distance >= best_distance or not _can_see_target(candidate): continue
		best = candidate; best_distance = distance
	return best

func _target_is_alive(target: Variant) -> bool:
	# A disconnected player can already be freed before the next AI tick. A
	# Node3D argument would fail type validation before this guard could run.
	if not is_instance_valid(target) or not target is Node3D or not target.is_inside_tree(): return false
	var target_health: Node = target.get_node_or_null("Health")
	if target_health == null: return false
	return not target_health.has_method("is_dead") or not bool(target_health.call("is_dead"))

func _can_see_target(target: Node3D) -> bool:
	if target == null or get_world_3d() == null: return false
	var origin := global_position + Vector3.UP * (0.55 if _crawler_mode else 1.35)
	var destination := target.global_position + Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(origin, destination, visibility_mask)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Node = hit.get("collider") as Node
	return _is_target_collider(collider, target)

func _is_target_collider(collider: Node, target: Node3D) -> bool:
	var current: Node = collider
	while current != null:
		if current == target:
			return true
		current = current.get_parent()
	return false

func _set_target(value: Node3D) -> void:
	if _target == value: return
	_target = value
	_sight_elapsed = 1.0
	_path_requested = false
	if _target != null: _last_known_position = _target.global_position; _has_last_known_position = true
	target_changed.emit(_target)

func _transition_to(next_state: int, reason: String) -> void:
	if state == next_state: return
	var previous := state; state = next_state; _state_elapsed = 0.0
	if state == State.ATTACK: _next_attack_usec = Time.get_ticks_usec() + int(_cfg_float(&"attack_windup_seconds", 0.3) * 1_000_000.0)
	elif state == State.DEAD: _disable_after_death()
	_update_debug_label()
	if debug_state_logs and OS.is_debug_build(): print("DEADFALL_ZOMBIE_STATE entity=%d %s -> %s reason=%s" % [entity_id, State.keys()[previous], State.keys()[state], reason])
	state_changed.emit(previous, state, reason)

func _on_health_changed(_current: float, _maximum: float, event) -> void:
	if event == null or state == State.DEAD: return
	if health.has_method("is_dead") and bool(health.call("is_dead")): return
	_transition_to(State.STAGGER, "damage_received")
func _on_died(event) -> void:
	if event != null: _death_hit_direction = Vector3(event.hit_direction)
	_transition_to(State.DEAD, "health_depleted")

func _on_crawler_required(_event) -> void:
	if _crawler_mode or state == State.DEAD: return
	_crawler_mode = true
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule != null:
		var crawler_height := maxf(capsule.radius * 2.0, _cfg_float(&"crawler_height", 0.85)); capsule.height = crawler_height; collision_shape.position.y = crawler_height * 0.5
	navigation_agent.radius = 0.35; navigation_agent.target_desired_distance = maxf(0.40, _effective_attack_range() * 0.55)
	visual_root.rotation_degrees.x = -58.0; visual_root.position.y = 0.58
	if state_label != null: state_label.position.y = 1.35
	crawler_mode_changed.emit(true); _update_debug_label()

func _on_attack_capability_changed(damage_multiplier: float, cooldown_multiplier: float) -> void:
	_attack_damage_multiplier = clampf(damage_multiplier, 0.1, 1.0); _attack_cooldown_multiplier = maxf(1.0, cooldown_multiplier); _update_debug_label()

func _on_head_destroyed(source_event) -> void:
	if state == State.DEAD or (health.has_method("is_dead") and bool(health.call("is_dead"))): return
	var active_authority = _get_active_authority()
	if active_authority == null or not active_authority.has_method("resolve_damage"): return
	var lethal = DamageEventScript.new(); lethal.attacker_id = int(source_event.attacker_id) if source_event != null else 0; lethal.victim_id = entity_id; lethal.weapon_id = &"gore_head_destroy"
	lethal.amount = maxf(1.0, float(health.get("max_health"))); lethal.damage_type = DamageEventScript.DamageType.BULLET; lethal.body_part = DamageEventScript.BodyPart.HEAD
	lethal.hit_position = Vector3(source_event.hit_position) if source_event != null else global_position + Vector3.UP * 1.5; lethal.hit_direction = Vector3(source_event.hit_direction) if source_event != null else -global_basis.z; lethal.hit_normal = Vector3(source_event.hit_normal) if source_event != null else Vector3.UP; lethal.critical = true; lethal.simulation_tick = Engine.get_physics_frames()
	active_authority.resolve_damage(lethal)

func _disable_after_death() -> void:
	velocity = Vector3.ZERO; navigation_agent.avoidance_enabled = false; navigation_agent.target_position = global_position; collision_layer = 0; collision_mask = 0; collision_shape.set_deferred("disabled", true)
	for child in hitboxes.get_children():
		var area := child as Area3D
		if area != null: area.collision_layer = 0; area.collision_mask = 0; area.set_deferred("monitoring", false); area.set_deferred("monitorable", false)
	if state_label != null: state_label.visible = false
	visual_root.rotation_degrees.z = 82.0
	var manager := get_tree().root.get_node_or_null("Gore") if get_tree() != null else null
	if manager != null:
		var corpse_slot := int(manager.call("spawn_corpse", global_transform, _death_hit_direction))
		if corpse_slot >= 0: visual_root.visible = false

func get_network_snapshot() -> Dictionary:
	return {
		"entity_id": entity_id,
		"archetype_id": StringName(zombie_data.get("archetype_id")) if zombie_data != null else &"walker",
		"position": global_position,
		"yaw": rotation.y,
		"velocity": velocity,
		"state": state,
		"crawler": _crawler_mode,
		"health": float(health.get("current_health")) if health != null else 0.0,
		"max_health": float(health.get("max_health")) if health != null else 100.0,
		"dead": bool(health.call("is_dead")) if health != null and health.has_method("is_dead") else state == State.DEAD,
		"destroyed_parts": gore.call("get_destroyed_parts") if gore != null and gore.has_method("get_destroyed_parts") else [],
	}

func apply_network_snapshot(snapshot: Dictionary) -> void:
	if has_simulation_authority(): return
	state = int(snapshot.get("state", state))
	if bool(snapshot.get("crawler", false)) and not _crawler_mode: _on_crawler_required(null)
	var network_authority = Game.authority if get_tree() != null else null
	if network_authority != null and network_authority.has_method("apply_health_snapshot"):
		network_authority.call("apply_health_snapshot", entity_id, float(snapshot.get("health", 100.0)), float(snapshot.get("max_health", 100.0)), bool(snapshot.get("dead", false)))
	if gore != null and gore.has_method("apply_replica_destroyed_parts"): gore.call("apply_replica_destroyed_parts", Array(snapshot.get("destroyed_parts", [])))
	if state == State.DEAD:
		collision_layer = 0; collision_mask = 0; visual_root.rotation_degrees.z = 82.0
	_update_debug_label()

func apply_replica_presentation(snapshot: Dictionary) -> void:
	state = int(snapshot.get("state", state))
	if bool(snapshot.get("crawler", false)) and not _crawler_mode: _on_crawler_required(null)
	_update_debug_label()

func _stop_horizontal() -> void: velocity.x = move_toward(velocity.x, 0.0, 0.8); velocity.z = move_toward(velocity.z, 0.0, 0.8)
func _face_position(position_value: Vector3) -> void:
	var direction := position_value - global_position; direction.y = 0.0
	if direction.length_squared() > 0.0001: _face_direction(direction.normalized())
func _face_direction(direction: Vector3) -> void: look_at(global_position + direction, Vector3.UP, true)
func _effective_attack_range() -> float:
	var result := _cfg_float(&"attack_range", 1.55)
	if _crawler_mode: result *= _cfg_float(&"crawler_attack_range_multiplier", 0.82)
	return result

func _is_target_in_attack_range(target: Node3D, multiplier: float = 1.0) -> bool:
	if target == null:
		return false
	var offset: Vector3 = target.global_position - global_position
	var vertical_distance: float = absf(offset.y)
	offset.y = 0.0
	var horizontal_range: float = _effective_attack_range() * maxf(0.5, multiplier)
	return vertical_distance <= 2.2 and offset.length() <= horizontal_range
func _get_active_authority():
	if authority_override != null: return authority_override
	if get_tree() == null: return null
	var game := get_tree().root.get_node_or_null("Game"); return game.get("authority") if game != null else null
func _cfg_float(property_name: StringName, fallback: float) -> float:
	if zombie_data == null: return fallback
	var value = zombie_data.get(property_name); return fallback if value == null else float(value)
func _update_debug_label() -> void:
	if state_label == null: return
	var mobility := " CRAWLER" if _crawler_mode else ""; var arm_penalty := " x%.2f" % _attack_damage_multiplier if _attack_damage_multiplier < 0.999 else ""
	state_label.text = "%s%s%s\nHP %.0f" % [get_state_name(), mobility, arm_penalty, float(health.get("current_health")) if health != null else 0.0]
