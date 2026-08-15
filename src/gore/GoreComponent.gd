class_name DeadfallGoreComponent
extends Node

signal body_part_damage_changed(body_part: int, accumulated_damage: float, threshold: float)
signal limb_destroyed(body_part: int, event)
signal crawler_required(event)
signal attack_capability_changed(damage_multiplier: float, cooldown_multiplier: float)
signal head_destroyed(event)

const DamageEventScript = preload("res://src/core/damage/DamageEvent.gd")

@export var zombie_data: Resource
@export var health_path := NodePath("../Health")
@export var hitboxes_path := NodePath("../Hitboxes")
@export var rig_path := NodePath("../VisualRoot/PreparedRig")
@export var wounds_path := NodePath("../VisualRoot/Wounds")

var _health: Node
var _hitboxes: Node3D
var _rig: Node3D
var _wounds: Node3D
var _damage_by_part: Dictionary = {}
var _destroyed: Dictionary = {}

func _ready() -> void:
	_health = get_node_or_null(health_path)
	_hitboxes = get_node_or_null(hitboxes_path) as Node3D
	_rig = get_node_or_null(rig_path) as Node3D
	_wounds = get_node_or_null(wounds_path) as Node3D
	if _health != null and _health.has_signal("health_changed"):
		_health.connect("health_changed", Callable(self, "_on_health_changed"))

func process_damage_event(event) -> void:
	if event == null or float(event.resolved_amount) <= 0.0:
		return
	if _health != null and int(event.victim_id) != int(_health.get("entity_id")):
		return
	_spawn_impact_effects(event, 1.0)
	var body_part := int(event.body_part)
	if not _is_dismemberable(body_part):
		return
	var accumulated := float(_damage_by_part.get(body_part, 0.0)) + float(event.resolved_amount)
	_damage_by_part[body_part] = accumulated
	var threshold := _threshold_for(body_part)
	body_part_damage_changed.emit(body_part, accumulated, threshold)
	if not is_limb_destroyed(body_part) and accumulated >= threshold:
		_destroy_limb(body_part, event)

func is_limb_destroyed(body_part: int) -> bool:
	return bool(_destroyed.get(body_part, false))

func get_body_part_damage(body_part: int) -> float:
	return float(_damage_by_part.get(body_part, 0.0))

func get_destroyed_count() -> int:
	var count := 0
	for value in _destroyed.values():
		if bool(value):
			count += 1
	return count

func requires_crawler() -> bool:
	return is_limb_destroyed(DamageEventScript.BodyPart.LEFT_LEG) or is_limb_destroyed(DamageEventScript.BodyPart.RIGHT_LEG)

func get_attack_damage_multiplier() -> float:
	var arms_lost := 0
	if is_limb_destroyed(DamageEventScript.BodyPart.LEFT_ARM):
		arms_lost += 1
	if is_limb_destroyed(DamageEventScript.BodyPart.RIGHT_ARM):
		arms_lost += 1
	match arms_lost:
		1:
			return _cfg_float(&"one_arm_damage_multiplier", 0.72)
		2:
			return _cfg_float(&"two_arm_damage_multiplier", 0.45)
		_:
			return 1.0

func get_attack_cooldown_multiplier() -> float:
	var arms_lost := 0
	if is_limb_destroyed(DamageEventScript.BodyPart.LEFT_ARM):
		arms_lost += 1
	if is_limb_destroyed(DamageEventScript.BodyPart.RIGHT_ARM):
		arms_lost += 1
	match arms_lost:
		1:
			return _cfg_float(&"one_arm_cooldown_multiplier", 1.25)
		2:
			return _cfg_float(&"two_arm_cooldown_multiplier", 1.65)
		_:
			return 1.0

func _on_health_changed(_current: float, _maximum: float, event) -> void:
	if event != null:
		process_damage_event(event)

func _destroy_limb(body_part: int, event) -> void:
	_destroyed[body_part] = true
	var part_name := _node_name_for_part(body_part)
	var mesh: MeshInstance3D = null
	var wound: MeshInstance3D = null
	if _rig != null:
		mesh = _rig.get_node_or_null(part_name) as MeshInstance3D
	if _wounds != null:
		wound = _wounds.get_node_or_null(part_name) as MeshInstance3D
	var parent_3d := get_parent() as Node3D
	var spawn_transform := Transform3D.IDENTITY
	if parent_3d != null:
		spawn_transform = parent_3d.global_transform
	if mesh != null:
		spawn_transform = mesh.global_transform
		mesh.visible = false
	if wound != null:
		wound.visible = true
	_disable_hitbox(part_name)

	var manager: Node = null
	if get_tree() != null:
		manager = get_tree().root.get_node_or_null("Gore")
	if manager != null:
		manager.call("spawn_detached_limb", body_part, spawn_transform, Vector3(event.hit_direction))
		manager.call("spawn_blood", Vector3(event.hit_position), Vector3(event.hit_direction), 2.2)
		if parent_3d != null:
			var ground_position := parent_3d.global_position
			ground_position.y = 0.03
			manager.call("spawn_blood_decal", ground_position, 1.15)

	limb_destroyed.emit(body_part, event)
	match body_part:
		DamageEventScript.BodyPart.HEAD:
			head_destroyed.emit(event)
		DamageEventScript.BodyPart.LEFT_LEG, DamageEventScript.BodyPart.RIGHT_LEG:
			crawler_required.emit(event)
		DamageEventScript.BodyPart.LEFT_ARM, DamageEventScript.BodyPart.RIGHT_ARM:
			attack_capability_changed.emit(get_attack_damage_multiplier(), get_attack_cooldown_multiplier())

func _spawn_impact_effects(event, intensity: float) -> void:
	if get_tree() == null:
		return
	var manager := get_tree().root.get_node_or_null("Gore")
	if manager == null:
		return
	manager.call("spawn_blood", Vector3(event.hit_position), Vector3(event.hit_direction), intensity)

func _disable_hitbox(part_name: StringName) -> void:
	if _hitboxes == null:
		return
	var hitbox := _hitboxes.get_node_or_null(part_name) as Area3D
	if hitbox == null:
		return
	hitbox.collision_layer = 0
	hitbox.collision_mask = 0
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	var shape := hitbox.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape != null:
		shape.set_deferred("disabled", true)

func _threshold_for(body_part: int) -> float:
	match body_part:
		DamageEventScript.BodyPart.HEAD:
			return _cfg_float(&"head_dismember_damage", 42.0)
		DamageEventScript.BodyPart.LEFT_ARM, DamageEventScript.BodyPart.RIGHT_ARM:
			return _cfg_float(&"arm_dismember_damage", 36.0)
		DamageEventScript.BodyPart.LEFT_LEG, DamageEventScript.BodyPart.RIGHT_LEG:
			return _cfg_float(&"leg_dismember_damage", 38.0)
		_:
			return INF

func _is_dismemberable(body_part: int) -> bool:
	return body_part in [
		DamageEventScript.BodyPart.HEAD,
		DamageEventScript.BodyPart.LEFT_ARM,
		DamageEventScript.BodyPart.RIGHT_ARM,
		DamageEventScript.BodyPart.LEFT_LEG,
		DamageEventScript.BodyPart.RIGHT_LEG,
	]

func _node_name_for_part(body_part: int) -> StringName:
	match body_part:
		DamageEventScript.BodyPart.HEAD:
			return &"Head"
		DamageEventScript.BodyPart.LEFT_ARM:
			return &"LeftArm"
		DamageEventScript.BodyPart.RIGHT_ARM:
			return &"RightArm"
		DamageEventScript.BodyPart.LEFT_LEG:
			return &"LeftLeg"
		DamageEventScript.BodyPart.RIGHT_LEG:
			return &"RightLeg"
		_:
			return &""

func _cfg_float(property_name: StringName, fallback: float) -> float:
	if zombie_data == null:
		return fallback
	var value = zombie_data.get(property_name)
	return fallback if value == null else float(value)
