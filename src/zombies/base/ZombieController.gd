class_name DeadfallZombieController
extends CharacterBody3D

signal state_changed(previous_state: int, current_state: int, reason: String)
signal target_changed(target)
signal melee_attack_resolved(event)
signal navigation_fallback_used()

enum State {
	IDLE,
	SEARCH,
	CHASE,
	ATTACK,
	STAGGER,
	DEAD,
}

const DamageEventScript = preload("res://src/core/damage/DamageEvent.gd")

@export var entity_id := 2001
@export var zombie_data: Resource
@export var target_group: StringName = &"deadfall_player"
@export_flags_3d_physics var visibility_mask: int = 1
@export var debug_state_logs := true

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var health: Node = $Health
@onready var hitboxes: Node3D = $Hitboxes
@onready var visual_root: Node3D = $VisualRoot
@onready var state_label: Label3D = $StateLabel

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

func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	if health.has_method("configure_entity"):
		health.call("configure_entity", entity_id, _cfg_float(&"max_health", 100.0))
	for child in hitboxes.get_children():
		if child.has_method("set"):
			child.set("victim_id", entity_id)
	if health.has_signal("health_changed"):
		health.connect("health_changed", Callable(self, "_on_health_changed"))
	if health.has_signal("died"):
		health.connect("died", Callable(self, "_on_died"))

	navigation_agent.path_desired_distance = 0.35
	navigation_agent.target_desired_distance = maxf(0.8, _cfg_float(&"attack_range", 1.55) * 0.75)
	navigation_agent.radius = 0.45
	navigation_agent.avoidance_enabled = false
	state_label.visible = OS.is_debug_build() and DisplayServer.get_name() != "headless"
	_update_debug_label()

func _physics_process(delta: float) -> void:
	if not has_simulation_authority():
		return
	if state == State.DEAD:
		return

	_state_elapsed += delta
	_scan_elapsed += delta
	_repath_elapsed += delta
	_process_vertical_velocity(delta)

	match state:
		State.IDLE:
			_process_idle()
		State.SEARCH:
			_process_search()
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack()
		State.STAGGER:
			_process_stagger()

	move_and_slide()

func set_authority_override(value: RefCounted) -> void:
	authority_override = value

func has_simulation_authority() -> bool:
	if authority_override != null:
		return true
	if get_tree() == null:
		return false
	var game := get_tree().root.get_node_or_null("Game")
	return game != null and game.has_method("is_simulation_authority") and bool(game.call("is_simulation_authority"))

func get_state_name() -> String:
	return State.keys()[state]

func get_target() -> Node3D:
	return _target

func perform_melee_attack(target: Node3D) -> bool:
	if not has_simulation_authority() or state == State.DEAD:
		return false
	if target == null or not _target_is_alive(target):
		return false
	if global_position.distance_to(target.global_position) > _cfg_float(&"attack_range", 1.55) * 1.15:
		return false
	var target_health := target.get_node_or_null("Health")
	if target_health == null:
		return false
	var victim_id := int(target_health.get("entity_id"))
	if victim_id == 0:
		return false
	var active_authority = _get_active_authority()
	if active_authority == null or not active_authority.has_method("resolve_damage"):
		return false

	var event = DamageEventScript.new()
	event.attacker_id = entity_id
	event.victim_id = victim_id
	event.weapon_id = &"zombie_melee"
	event.amount = _cfg_float(&"attack_damage", 12.0)
	event.damage_type = DamageEventScript.DamageType.MELEE
	event.body_part = DamageEventScript.BodyPart.CHEST
	event.hit_position = target.global_position + Vector3.UP
	event.hit_direction = (target.global_position - global_position).normalized()
	event.simulation_tick = Engine.get_physics_frames()
	if not active_authority.resolve_damage(event):
		return false
	melee_attack_resolved.emit(event)
	return true

func _process_idle() -> void:
	_stop_horizontal()
	if _scan_elapsed < _cfg_float(&"scan_interval_seconds", 0.2):
		return
	_scan_elapsed = 0.0
	var candidate := _find_visible_target()
	if candidate != null:
		_set_target(candidate)
		_transition_to(State.CHASE, "target_acquired")

func _process_search() -> void:
	if _scan_elapsed >= _cfg_float(&"scan_interval_seconds", 0.2):
		_scan_elapsed = 0.0
		var candidate := _find_visible_target()
		if candidate != null:
			_set_target(candidate)
			_transition_to(State.CHASE, "target_reacquired")
			return

	if _state_elapsed >= _cfg_float(&"search_seconds", 4.0):
		_set_target(null)
		_has_last_known_position = false
		_transition_to(State.IDLE, "search_timeout")
		return
	if _has_last_known_position:
		if global_position.distance_to(_last_known_position) <= 0.8:
			_stop_horizontal()
		else:
			_move_towards_destination(_last_known_position)
	else:
		_stop_horizontal()

func _process_chase(delta: float) -> void:
	if not _target_is_alive(_target):
		_set_target(null)
		_transition_to(State.IDLE, "target_invalid")
		return

	var distance := global_position.distance_to(_target.global_position)
	if distance > _cfg_float(&"lose_target_range", 30.0):
		_last_known_position = _target.global_position
		_has_last_known_position = true
		_set_target(null)
		_transition_to(State.SEARCH, "target_out_of_range")
		return

	if _can_see_target(_target):
		_sight_lost_elapsed = 0.0
		_last_known_position = _target.global_position
		_has_last_known_position = true
	else:
		_sight_lost_elapsed += delta
		if _sight_lost_elapsed >= _cfg_float(&"sight_memory_seconds", 1.0):
			_transition_to(State.SEARCH, "line_of_sight_lost")
			return

	if distance <= _cfg_float(&"attack_range", 1.55) and _can_see_target(_target):
		_transition_to(State.ATTACK, "target_in_attack_range")
		return
	_move_towards_destination(_target.global_position)

func _process_attack() -> void:
	_stop_horizontal()
	if not _target_is_alive(_target):
		_set_target(null)
		_transition_to(State.IDLE, "target_invalid")
		return
	_face_position(_target.global_position)
	if global_position.distance_to(_target.global_position) > _cfg_float(&"attack_range", 1.55) * 1.15:
		_transition_to(State.CHASE, "target_left_attack_range")
		return
	if not _can_see_target(_target):
		_transition_to(State.CHASE, "attack_line_of_sight_lost")
		return
	var now_usec := Time.get_ticks_usec()
	if now_usec >= _next_attack_usec:
		perform_melee_attack(_target)
		_next_attack_usec = now_usec + int(_cfg_float(&"attack_cooldown_seconds", 1.1) * 1_000_000.0)

func _process_stagger() -> void:
	_stop_horizontal()
	if _state_elapsed < _cfg_float(&"stagger_seconds", 0.35):
		return
	if _target_is_alive(_target):
		_transition_to(State.CHASE, "stagger_recovered")
	elif _has_last_known_position:
		_transition_to(State.SEARCH, "stagger_recovered_search")
	else:
		_transition_to(State.IDLE, "stagger_recovered_idle")

func _process_vertical_velocity(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -0.1
	else:
		velocity.y -= _gravity * delta

func _move_towards_destination(destination: Vector3) -> void:
	var repath_interval := _cfg_float(&"repath_interval_seconds", 0.25)
	if _repath_elapsed >= repath_interval or navigation_agent.target_position.distance_squared_to(destination) > 0.25:
		navigation_agent.target_position = destination
		_repath_elapsed = 0.0

	var movement_target := destination
	var used_navigation := false
	if navigation_agent.get_navigation_map().is_valid() and not navigation_agent.is_navigation_finished():
		var next_position := navigation_agent.get_next_path_position()
		if next_position.distance_squared_to(global_position) > 0.01:
			movement_target = next_position
			used_navigation = true

	if not used_navigation and not _navigation_fallback_announced:
		_navigation_fallback_announced = true
		navigation_fallback_used.emit()
		if debug_state_logs and OS.is_debug_build():
			print("DEADFALL_ZOMBIE_NAV_FALLBACK entity=%d" % entity_id)
	elif used_navigation:
		_navigation_fallback_announced = false

	var direction := movement_target - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		_stop_horizontal()
		return
	direction = direction.normalized()
	velocity.x = direction.x * _cfg_float(&"move_speed", 3.2)
	velocity.z = direction.z * _cfg_float(&"move_speed", 3.2)
	_face_direction(direction)

func _find_visible_target() -> Node3D:
	if get_tree() == null:
		return null
	var best: Node3D = null
	var best_distance := INF
	var detection_range := _cfg_float(&"detection_range", 20.0)
	for node in get_tree().get_nodes_in_group(target_group):
		var candidate := node as Node3D
		if candidate == null or not _target_is_alive(candidate):
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance > detection_range or distance >= best_distance:
			continue
		if not _can_see_target(candidate):
			continue
		best = candidate
		best_distance = distance
	return best

func _target_is_alive(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return false
	var target_health := target.get_node_or_null("Health")
	if target_health == null:
		return false
	return not target_health.has_method("is_dead") or not bool(target_health.call("is_dead"))

func _can_see_target(target: Node3D) -> bool:
	if target == null or get_world_3d() == null:
		return false
	var origin := global_position + Vector3.UP * 1.35
	var destination := target.global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(origin, destination, visibility_mask)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _set_target(value: Node3D) -> void:
	if _target == value:
		return
	_target = value
	if _target != null:
		_last_known_position = _target.global_position
		_has_last_known_position = true
	target_changed.emit(_target)

func _transition_to(next_state: int, reason: String) -> void:
	if state == next_state:
		return
	var previous := state
	state = next_state
	_state_elapsed = 0.0
	if state == State.ATTACK:
		_next_attack_usec = Time.get_ticks_usec() + int(_cfg_float(&"attack_windup_seconds", 0.3) * 1_000_000.0)
	elif state == State.DEAD:
		_disable_after_death()
	_update_debug_label()
	if debug_state_logs and OS.is_debug_build():
		print("DEADFALL_ZOMBIE_STATE entity=%d %s -> %s reason=%s" % [entity_id, State.keys()[previous], State.keys()[state], reason])
	state_changed.emit(previous, state, reason)

func _on_health_changed(_current: float, _maximum: float, event) -> void:
	if event == null or state == State.DEAD:
		return
	if health.has_method("is_dead") and bool(health.call("is_dead")):
		return
	_transition_to(State.STAGGER, "damage_received")

func _on_died(event) -> void:
	if event != null:
		_death_hit_direction = Vector3(event.hit_direction)
	_transition_to(State.DEAD, "health_depleted")

func _disable_after_death() -> void:
	velocity = Vector3.ZERO
	navigation_agent.avoidance_enabled = false
	navigation_agent.target_position = global_position
	collision_layer = 0
	collision_mask = 0
	for child in hitboxes.get_children():
		var area := child as Area3D
		if area != null:
			area.collision_layer = 0
			area.collision_mask = 0
			area.set_deferred("monitoring", false)
			area.set_deferred("monitorable", false)
	visual_root.rotation_degrees.z = 82.0
	state_label.visible = false
	if DisplayServer.get_name() != "headless":
		call_deferred("_spawn_death_proxy")

func _spawn_death_proxy() -> void:
	if not is_inside_tree() or get_parent() == null:
		return
	var proxy := RigidBody3D.new()
	proxy.name = "ZombieCorpse_%d" % entity_id
	proxy.mass = 35.0
	proxy.collision_layer = 16
	proxy.collision_mask = 1
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.72, 1.70, 0.46)
	shape_node.shape = shape
	proxy.add_child(shape_node)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.72, 1.70, 0.46)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.28, 0.34, 0.27)
	material.roughness = 0.9
	mesh.material = material
	mesh_node.mesh = mesh
	proxy.add_child(mesh_node)
	get_parent().add_child(proxy)
	proxy.global_position = global_position + Vector3.UP * 0.85
	proxy.global_rotation = global_rotation
	visual_root.visible = false
	var impulse := _death_hit_direction.normalized() * 2.5 if _death_hit_direction.length_squared() > 0.0 else -global_basis.z * 1.5
	proxy.apply_central_impulse(impulse + Vector3.UP * 0.6)

func _stop_horizontal() -> void:
	velocity.x = move_toward(velocity.x, 0.0, 0.8)
	velocity.z = move_toward(velocity.z, 0.0, 0.8)

func _face_position(position_value: Vector3) -> void:
	var direction := position_value - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		_face_direction(direction.normalized())

func _face_direction(direction: Vector3) -> void:
	look_at(global_position + direction, Vector3.UP, true)

func _get_active_authority():
	if authority_override != null:
		return authority_override
	if get_tree() == null:
		return null
	var game := get_tree().root.get_node_or_null("Game")
	return game.get("authority") if game != null else null

func _cfg_float(property_name: StringName, fallback: float) -> float:
	if zombie_data == null:
		return fallback
	var value = zombie_data.get(property_name)
	return fallback if value == null else float(value)

func _update_debug_label() -> void:
	if state_label != null:
		state_label.text = "%s\nHP %.0f" % [get_state_name(), float(health.get("current_health")) if health != null else 0.0]
