class_name DeadfallHealthComponent
extends Node

signal health_changed(current: float, maximum: float, event)
signal died(event)

@export var entity_id: int = 0
@export var max_health: float = 100.0

var current_health: float = 0.0
var _registered_authority: RefCounted
var _dead := false
var _lethal_handler: Node

func _ready() -> void:
	reset_health()
	_register_with_active_authority()

func _exit_tree() -> void:
	_unregister_from_authority()

func configure_entity(new_entity_id: int, new_max_health: float = -1.0) -> void:
	_unregister_from_authority()
	entity_id = new_entity_id
	if new_max_health > 0.0:
		max_health = new_max_health
	reset_health()
	if is_inside_tree():
		_register_with_active_authority()

func set_lethal_handler(handler: Node) -> void:
	_lethal_handler = handler

func get_entity_id() -> int:
	return entity_id

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
	if current_health <= 0.0 and _lethal_handler != null and is_instance_valid(_lethal_handler) and _lethal_handler.has_method("intercept_lethal_damage"):
		var replacement_health := float(_lethal_handler.call("intercept_lethal_damage", event))
		if replacement_health > 0.0:
			current_health = clampf(replacement_health, 1.0, max_health)
			_dead = false
			health_changed.emit(current_health, max_health, event)
			return true

	health_changed.emit(current_health, max_health, event)
	if current_health <= 0.0 and not _dead:
		_dead = true
		died.emit(event)
	return true

func force_authoritative_death(event = null) -> bool:
	if _dead or not _can_mutate_authoritative_state():
		return false
	current_health = 0.0
	_dead = true
	health_changed.emit(current_health, max_health, event)
	died.emit(event)
	return true

func apply_network_snapshot(current: float, maximum: float, dead: bool) -> bool:
	max_health = maxf(1.0, maximum)
	current_health = clampf(current, 0.0, max_health)
	_dead = dead or current_health <= 0.0
	health_changed.emit(current_health, max_health, null)
	return true

func restore_authoritative_state(current: float, maximum: float, dead: bool) -> bool:
	if not _can_mutate_authoritative_state():
		return false
	max_health = maxf(1.0, maximum)
	current_health = clampf(current, 0.0, max_health)
	_dead = dead or current_health <= 0.0
	health_changed.emit(current_health, max_health, null)
	return true

func _can_mutate_authoritative_state() -> bool:
	var game := get_tree().root.get_node_or_null("Game") if get_tree() != null else null
	if game != null and game.has_method("is_network_client") and bool(game.call("is_network_client")):
		return false
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

func heal_authoritative(amount: float) -> float:
	if amount <= 0.0 or _dead or not _can_mutate_authoritative_state():
		return 0.0
	var restored := minf(amount, maxf(0.0, max_health - current_health))
	if restored > 0.0:
		current_health += restored
		health_changed.emit(current_health, max_health, null)
	return restored
