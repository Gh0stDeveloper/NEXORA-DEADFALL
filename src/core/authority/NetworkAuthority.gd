class_name DeadfallNetworkAuthority
extends "res://src/core/authority/GameAuthority.gd"

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
	# A network client is presentation/prediction only. It can never resolve
	# authoritative health mutations locally.
	damage_rejected.emit(event, "network_client_not_authoritative")
	return false

func apply_health_snapshot(entity_id: int, current: float, maximum: float, dead: bool) -> bool:
	if not active or not _damageables.has(entity_id):
		return false
	var health = instance_from_id(int(_damageables[entity_id]))
	if health == null or not is_instance_valid(health):
		_damageables.erase(entity_id)
		return false
	if not health.has_method("apply_network_snapshot"):
		return false
	return bool(health.call("apply_network_snapshot", current, maximum, dead))
