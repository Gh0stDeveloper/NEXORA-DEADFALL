class_name LocalAuthority
extends "res://src/core/authority/GameAuthority.gd"

const DamageRulesScript = preload("res://src/core/damage/DamageRules.gd")

var active := false
var _damageables: Dictionary = {}

func start() -> void:
	active = true

func stop() -> void:
	active = false
	_damageables.clear()

func register_damageable(entity_id: int, health_component: Node) -> bool:
	if entity_id == 0 or health_component == null or not is_instance_valid(health_component):
		return false
	_damageables[entity_id] = health_component.get_instance_id()
	return true

func unregister_damageable(entity_id: int, health_component: Node = null) -> void:
	if not _damageables.has(entity_id):
		return
	if health_component != null and is_instance_valid(health_component):
		if int(_damageables[entity_id]) != health_component.get_instance_id():
			return
	_damageables.erase(entity_id)

func resolve_damage(event) -> bool:
	if not active or event == null:
		return false
	if not event.has_method("is_valid") or not event.is_valid():
		damage_rejected.emit(event, "invalid_event")
		return false
	if not _damageables.has(int(event.victim_id)):
		damage_rejected.emit(event, "unknown_victim")
		return false

	var health_component = instance_from_id(int(_damageables[int(event.victim_id)]))
	if health_component == null or not is_instance_valid(health_component):
		_damageables.erase(int(event.victim_id))
		damage_rejected.emit(event, "stale_victim")
		return false
	if not health_component.has_method("apply_authoritative_damage"):
		damage_rejected.emit(event, "invalid_health_component")
		return false

	event.resolved_amount = DamageRulesScript.resolve_amount(event)
	event.critical = DamageRulesScript.is_critical(event)
	if event.resolved_amount <= 0.0:
		damage_rejected.emit(event, "zero_damage")
		return false
	if not health_component.apply_authoritative_damage(event):
		damage_rejected.emit(event, "health_rejected")
		return false

	damage_resolved.emit(event)
	return true
