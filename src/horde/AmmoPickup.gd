class_name DeadfallAmmoPickup
extends Area3D

signal collected(pickup_id: int, ammo_added: int, collector_entity_id: int)

@export var pickup_id := 0
@export_range(1, 240, 1) var ammo_amount := 30
@export_range(5.0, 180.0, 1.0) var lifetime_seconds := 45.0
@export var replica_only := false

var _age := 0.0
var _collected := false
var _visual: Node3D

func _ready() -> void:
	_visual = get_node_or_null("Visual") as Node3D
	body_entered.connect(_on_body_entered)
	monitoring = not replica_only and _has_simulation_authority()
	monitorable = true
	set_process(true)

func _process(delta: float) -> void:
	if _visual != null:
		_visual.rotation.y += delta * 1.35
		_visual.position.y = 0.16 + sin(Time.get_ticks_msec() * 0.004 + float(pickup_id % 17)) * 0.07
	if replica_only or not _has_simulation_authority():
		return
	_age += delta
	if _age >= lifetime_seconds:
		queue_free()

func configure(id: int, amount: int, as_replica: bool = false) -> void:
	pickup_id = id
	ammo_amount = maxi(1, amount)
	replica_only = as_replica
	if is_inside_tree():
		monitoring = not replica_only and _has_simulation_authority()

func get_network_snapshot() -> Dictionary:
	return {
		"pickup_id": pickup_id,
		"kind": "ammo",
		"position": global_position,
		"amount": ammo_amount,
	}

func apply_network_snapshot(snapshot: Dictionary) -> void:
	pickup_id = int(snapshot.get("pickup_id", pickup_id))
	ammo_amount = maxi(1, int(snapshot.get("amount", ammo_amount)))
	global_position = Vector3(snapshot.get("position", global_position))
	replica_only = true
	monitoring = false

func _on_body_entered(body: Node3D) -> void:
	if _collected or replica_only or not _has_simulation_authority() or body == null or not body.is_in_group("deadfall_player"):
		return
	var added := 0
	var loadout := body.get_node_or_null("WeaponLoadout")
	if loadout != null and loadout.has_method("add_ammo"):
		added = int(loadout.call("add_ammo", ammo_amount))
	else:
		var weapon := body.get_node_or_null("PrimaryWeapon")
		if weapon != null and weapon.has_method("add_reserve_ammo"):
			added = int(weapon.call("add_reserve_ammo", ammo_amount))
	if added <= 0:
		return
	_collected = true
	monitoring = false
	var entity_value = body.get("player_entity_id")
	var entity_id := int(entity_value) if entity_value != null else 0
	collected.emit(pickup_id, added, entity_id)
	print("DEADFALL_AMMO_PICKUP id=%d entity=%d added=%d" % [pickup_id, entity_id, added])
	queue_free()

func _has_simulation_authority() -> bool:
	return Game != null and Game.is_simulation_authority()
