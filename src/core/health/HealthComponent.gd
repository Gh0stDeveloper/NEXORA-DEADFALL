class_name DeadfallHealthComponent
extends Node

signal health_changed(current: float, maximum: float, event)
signal died(event)

@export var entity_id: int = 0
@export var max_health: float = 100.0

var current_health: float = 0.0
var _registered_authority: RefCounted
var _dead := false

func _ready() -> void:
	reset_health()
	_register_with_active_authority()

func _exit_tree() -> void:
	_unregister_from_authority()

func reset_health() -> void:
	current_health = maxf(1.0, max_health)
	_dead = false
	health_changed.emit(current_health, max_health, null)

func is_dead() -> bool:
	return _dead

func apply_authoritative_damage(event) -> bool:
	if event == null or _dead:
		return false
	if int(event.victim_id) != entity_id or float(event.resolved_amount) <= 0.0:
		return false

	current_health = maxf(0.0, current_health - float(event.resolved_amount))
	health_changed.emit(current_health, max_health, event)
	if current_health <= 0.0 and not _dead:
		_dead = true
		died.emit(event)
	return true

func _register_with_active_authority() -> void:
	if entity_id == 0 or get_tree() == null:
		return
	var game := get_tree().root.get_node_or_null("Game")
	if game == null:
		return
	var active_authority = game.get("authority")
	if active_authority == null:
		return
	if active_authority.has_method("register_damageable") and active_authority.register_damageable(entity_id, self):
		_registered_authority = active_authority

func _unregister_from_authority() -> void:
	if _registered_authority != null and _registered_authority.has_method("unregister_damageable"):
		_registered_authority.unregister_damageable(entity_id, self)
	_registered_authority = null
