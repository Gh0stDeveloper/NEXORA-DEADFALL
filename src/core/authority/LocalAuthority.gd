class_name LocalAuthority
extends "res://src/core/authority/GameAuthority.gd"

var active := false

func start() -> void:
	active = true

func stop() -> void:
	active = false

func resolve_damage(event) -> bool:
	if not active or event == null:
		return false
	if not event.has_method("is_valid") or not event.is_valid():
		return false
	damage_resolved.emit(event)
	return true
