class_name GameAuthority
extends RefCounted

signal damage_resolved(event: DamageEvent)

func start() -> void:
	pass

func stop() -> void:
	pass

func resolve_damage(_event: DamageEvent) -> bool:
	push_error("GameAuthority.resolve_damage must be implemented by the active authority")
	return false
