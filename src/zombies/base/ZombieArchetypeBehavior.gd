class_name DeadfallZombieArchetypeBehavior
extends Node

signal scream_emitted(affected_count: int)
signal rage_changed(enabled: bool, speed_multiplier: float, damage_multiplier: float)

var _zombie: Node3D
var _data: Resource
var _scream_elapsed := 0.0
var _rage_remaining := 0.0
var _rage_speed_multiplier := 1.0
var _rage_damage_multiplier := 1.0
var _base_move_speed := 0.0
var _base_attack_damage := 0.0

func _ready() -> void:
	_zombie = get_parent() as Node3D
	if _zombie == null:
		set_physics_process(false)
		return
	var source_data := _zombie.get("zombie_data") as Resource
	if source_data == null:
		set_physics_process(false)
		return
	_data = source_data.duplicate(true) as Resource
	_zombie.set("zombie_data", _data)
	var gore := _zombie.get_node_or_null("Gore")
	if gore != null:
		gore.set("zombie_data", _data)
	_base_move_speed = float(_data.get("move_speed"))
	_base_attack_damage = float(_data.get("attack_damage"))
	_scream_elapsed = float(_data.get("scream_cooldown_seconds")) * 0.45
	_apply_prototype_color()
	if bool(_data.get("native_crawler")):
		call_deferred("_activate_native_crawler")

func _exit_tree() -> void:
	_restore_rage_base_values()

func _physics_process(delta: float) -> void:
	if _zombie == null or _data == null or not is_instance_valid(_zombie):
		return
	if _zombie.has_method("has_simulation_authority") and not bool(_zombie.call("has_simulation_authority")):
		return
	if _zombie.has_method("get_state_name") and String(_zombie.call("get_state_name")) == "DEAD":
		return
	_update_rage(delta)
	if not bool(_data.get("screamer_enabled")):
		return
	_scream_elapsed += delta
	var cooldown := maxf(1.0, float(_data.get("scream_cooldown_seconds")))
	if _scream_elapsed < cooldown:
		return
	var state_name := String(_zombie.call("get_state_name")) if _zombie.has_method("get_state_name") else ""
	if state_name != "CHASE" and state_name != "ATTACK":
		return
	_scream_elapsed = 0.0
	_emit_scream()

func get_archetype_id() -> StringName:
	return StringName(_data.get("archetype_id")) if _data != null else &"unknown"

func is_raged() -> bool:
	return _rage_remaining > 0.0

func get_rage_speed_multiplier() -> float:
	return _rage_speed_multiplier

func get_rage_damage_multiplier() -> float:
	return _rage_damage_multiplier

func apply_horde_rage(duration: float, speed_multiplier: float, damage_multiplier: float) -> void:
	if _data == null or duration <= 0.0:
		return
	var state_name := String(_zombie.call("get_state_name")) if _zombie != null and _zombie.has_method("get_state_name") else ""
	if state_name == "DEAD":
		return
	_rage_remaining = maxf(_rage_remaining, duration)
	_rage_speed_multiplier = maxf(_rage_speed_multiplier, maxf(1.0, speed_multiplier))
	_rage_damage_multiplier = maxf(_rage_damage_multiplier, maxf(1.0, damage_multiplier))
	_data.set("move_speed", _base_move_speed * _rage_speed_multiplier)
	_data.set("attack_damage", _base_attack_damage * _rage_damage_multiplier)
	rage_changed.emit(true, _rage_speed_multiplier, _rage_damage_multiplier)
	if OS.is_debug_build():
		print("DEADFALL_HORDE_RAGE entity=%d speed=%.2f damage=%.2f" % [int(_zombie.get("entity_id")), _rage_speed_multiplier, _rage_damage_multiplier])

func _update_rage(delta: float) -> void:
	if _rage_remaining <= 0.0:
		return
	_rage_remaining = maxf(0.0, _rage_remaining - delta)
	if _rage_remaining > 0.0:
		return
	_restore_rage_base_values()
	rage_changed.emit(false, 1.0, 1.0)

func _restore_rage_base_values() -> void:
	if _data != null:
		_data.set("move_speed", _base_move_speed)
		_data.set("attack_damage", _base_attack_damage)
	_rage_speed_multiplier = 1.0
	_rage_damage_multiplier = 1.0
	_rage_remaining = 0.0

func _emit_scream() -> void:
	if get_tree() == null or _zombie == null:
		return
	var radius := maxf(1.0, float(_data.get("scream_radius")))
	var duration := maxf(0.5, float(_data.get("scream_rage_seconds")))
	var speed_multiplier := maxf(1.0, float(_data.get("scream_speed_multiplier")))
	var damage_multiplier := maxf(1.0, float(_data.get("scream_damage_multiplier")))
	var affected := 0
	for node in get_tree().get_nodes_in_group(&"deadfall_zombie"):
		var other := node as Node3D
		if other == null or other == _zombie or not is_instance_valid(other):
			continue
		if other.global_position.distance_to(_zombie.global_position) > radius:
			continue
		var behavior := other.get_node_or_null("ArchetypeBehavior")
		if behavior == null or not behavior.has_method("apply_horde_rage"):
			continue
		behavior.call("apply_horde_rage", duration, speed_multiplier, damage_multiplier)
		affected += 1
	scream_emitted.emit(affected)
	if OS.is_debug_build():
		print("DEADFALL_HORDE_SCREAM entity=%d affected=%d" % [int(_zombie.get("entity_id")), affected])

func _activate_native_crawler() -> void:
	if _zombie != null and is_instance_valid(_zombie) and _zombie.has_method("_on_crawler_required"):
		_zombie.call("_on_crawler_required", null)

func _apply_prototype_color() -> void:
	if _zombie == null or _data == null or DisplayServer.get_name() == "headless":
		return
	var rig := _zombie.get_node_or_null("VisualRoot/PreparedRig")
	if rig == null:
		return
	var color: Color = _data.get("prototype_color")
	for child in rig.get_children():
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null:
			continue
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.90
		mesh_instance.material_override = material
