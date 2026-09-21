class_name DeadfallAmmoDropDirector
extends Node

const AmmoPickupScene = preload("res://src/horde/AmmoPickup.tscn")

@export var zombies_root_path := NodePath("../HordeZombies")
@export var pickups_root_path := NodePath("../WorldPickups")
@export_range(0.0, 1.0, 0.01) var drop_chance := 0.72
@export_range(1, 240, 1) var min_ammo := 24
@export_range(1, 240, 1) var max_ammo := 48

var _zombies_root: Node3D
var _pickups_root: Node3D
var _rng := RandomNumberGenerator.new()
var _next_pickup_id := 700001
var _tracked: Dictionary = {}
var _drop_count := 0

func _ready() -> void:
	_rng.randomize()
	call_deferred("_initialize")

func _initialize() -> void:
	_zombies_root = get_node_or_null(zombies_root_path) as Node3D
	_pickups_root = get_node_or_null(pickups_root_path) as Node3D
	if _zombies_root == null or _pickups_root == null:
		call_deferred("_initialize")
		return
	if not _zombies_root.child_entered_tree.is_connected(_on_zombie_entered):
		_zombies_root.child_entered_tree.connect(_on_zombie_entered)
	for child in _zombies_root.get_children():
		_on_zombie_entered(child)
	var horde := get_node_or_null("../HordeDirector")
	if horde != null and horde.has_signal("run_restarted") and not horde.is_connected("run_restarted", _on_run_restarted):
		horde.connect("run_restarted", _on_run_restarted)

func _on_zombie_entered(node: Node) -> void:
	if node == null or not node.is_in_group("deadfall_zombie"):
		return
	var key := node.get_instance_id()
	if _tracked.has(key):
		return
	_tracked[key] = true
	node.tree_exiting.connect(_on_zombie_exiting.bind(node, key), CONNECT_ONE_SHOT)

func _on_zombie_exiting(zombie: Node, key: int) -> void:
	_tracked.erase(key)
	if not _has_simulation_authority() or zombie == null or not is_instance_valid(zombie):
		return
	var health := zombie.get_node_or_null("Health")
	if health == null or not health.has_method("is_dead") or not bool(health.call("is_dead")):
		return
	if _rng.randf() > drop_chance:
		return
	var amount := _rng.randi_range(mini(min_ammo, max_ammo), maxi(min_ammo, max_ammo))
	_drop_count += 1
	_spawn_ammo(zombie.global_position, 25 if _drop_count % 4 == 0 else amount, "health" if _drop_count % 4 == 0 else "ammo")

func _spawn_ammo(position: Vector3, amount: int, kind: String = "ammo") -> void:
	if _pickups_root == null or not is_instance_valid(_pickups_root):
		return
	var pickup := AmmoPickupScene.instantiate() as Area3D
	if pickup == null:
		return
	var id := _next_pickup_id
	_next_pickup_id += 1
	pickup.name = "AmmoPickup_%d" % id
	if pickup.has_method("configure"):
		pickup.call("configure", id, amount, false, kind)
	_pickups_root.add_child(pickup)
	pickup.global_position = position + Vector3(0.0, 0.08, 0.0)
	print("DEADFALL_AMMO_DROP id=%d amount=%d" % [id, amount])

func _on_run_restarted() -> void:
	_drop_count = 0
	if not _has_simulation_authority() or _pickups_root == null:
		return
	for child in _pickups_root.get_children():
		child.queue_free()

func _has_simulation_authority() -> bool:
	return Game != null and Game.is_simulation_authority()
