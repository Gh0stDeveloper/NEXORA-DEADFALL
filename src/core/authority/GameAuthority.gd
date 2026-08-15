class_name GameAuthority
extends RefCounted

signal damage_resolved(event)

func start() -> void:
	pass

func stop() -> void:
	pass

func resolve_damage(_event) -> bool:
	push_error("GameAuthority.resolve_damage must be implemented by the active authority")
	return false
