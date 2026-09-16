class_name DeadfallNetworkReplicaInterpolator
extends Node

@export var interpolation_rate := 14.0
@export var hard_snap_distance := 6.0

var _target: Node3D
var _snapshot: Dictionary = {}
var _has_snapshot := false

func bind_target(target: Node3D) -> void:
	_target = target

func push_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	_has_snapshot = true

func _process(delta: float) -> void:
	if not _has_snapshot or _target == null or not is_instance_valid(_target):
		return
	var target_position := Vector3(_snapshot.get("position", _target.global_position))
	var target_yaw := float(_snapshot.get("yaw", _target.rotation.y))
	var error := _target.global_position.distance_to(target_position)
	if error >= hard_snap_distance:
		_target.global_position = target_position
		_target.rotation.y = target_yaw
	else:
		var alpha := 1.0 - exp(-interpolation_rate * delta)
		_target.global_position = _target.global_position.lerp(target_position, alpha)
		_target.rotation.y = lerp_angle(_target.rotation.y, target_yaw, alpha)
	if _target is CharacterBody3D:
		(_target as CharacterBody3D).velocity = Vector3(_snapshot.get("velocity", Vector3.ZERO))
	if _target.has_method("apply_replica_presentation"):
		_target.call("apply_replica_presentation", _snapshot)
