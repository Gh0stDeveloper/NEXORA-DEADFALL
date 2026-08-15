class_name LocalAuthority
extends GameAuthority

var active := false

func start() -> void:
	active = true

func stop() -> void:
	active = false

func resolve_damage(event: DamageEvent) -> bool:
	if not active or not event.is_valid():
		return false
	damage_resolved.emit(event)
	return true
