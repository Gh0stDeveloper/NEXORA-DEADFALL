class_name GameAuthority
extends RefCounted

signal damage_resolved(event)
signal damage_rejected(event, reason: String)

func start() -> void:
	pass

func stop() -> void:
	pass

func register_damageable(_entity_id: int, _health_component: Node) -> bool:
	push_error("GameAuthority.register_damageable must be implemented by the active authority")
	return false

func unregister_damageable(_entity_id: int, _health_component: Node = null) -> void:
	pass

func resolve_damage(_event) -> bool:
	push_error("GameAuthority.resolve_damage must be implemented by the active authority")
	return false
