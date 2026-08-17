class_name DeadfallModelNormalizer
extends RefCounted

const MIN_VALID_HEIGHT := 0.01
const MAX_SCALE_FACTOR := 100.0

static func normalize_visual(model: Node3D, reference_root: Node3D, target_height: float) -> Dictionary:
	if model == null or reference_root == null or target_height <= 0.0 or not model.is_inside_tree():
		return {"ok": false, "reason": "invalid_model_context"}
	var initial := _visual_bounds(reference_root, model)
	if initial.is_empty():
		return {"ok": false, "reason": "no_mesh_bounds"}
	var initial_min: Vector3 = initial["min"]
	var initial_max: Vector3 = initial["max"]
	var source_height := initial_max.y - initial_min.y
	if source_height < MIN_VALID_HEIGHT:
		return {"ok": false, "reason": "invalid_height", "height": source_height}
	var factor := clampf(target_height / source_height, 1.0 / MAX_SCALE_FACTOR, MAX_SCALE_FACTOR)
	model.scale = model.scale * factor

	var adjusted := _visual_bounds(reference_root, model)
	if adjusted.is_empty():
		return {"ok": false, "reason": "bounds_after_scale_failed"}
	var adjusted_min: Vector3 = adjusted["min"]
	var adjusted_max: Vector3 = adjusted["max"]
	var center_x := (adjusted_min.x + adjusted_max.x) * 0.5
	var center_z := (adjusted_min.z + adjusted_max.z) * 0.5
	# Keep the gameplay collider authoritative and move only the imported visual.
	model.position += Vector3(-center_x, -adjusted_min.y, -center_z)
	var final_bounds := _visual_bounds(reference_root, model)
	return {
		"ok": true,
		"source_height": source_height,
		"target_height": target_height,
		"scale_factor": factor,
		"final_height": float(final_bounds["max"].y - final_bounds["min"].y) if not final_bounds.is_empty() else target_height,
	}

static func _visual_bounds(reference_root: Node3D, model: Node3D) -> Dictionary:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(model, meshes)
	if meshes.is_empty():
		return {}
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var has_point := false
	for mesh_instance in meshes:
		if mesh_instance.mesh == null:
			continue
		var local_bounds := mesh_instance.mesh.get_aabb()
		for endpoint_index in range(8):
			var world_point := mesh_instance.to_global(local_bounds.get_endpoint(endpoint_index))
			var point := reference_root.to_local(world_point)
			minimum.x = minf(minimum.x, point.x)
			minimum.y = minf(minimum.y, point.y)
			minimum.z = minf(minimum.z, point.z)
			maximum.x = maxf(maximum.x, point.x)
			maximum.y = maxf(maximum.y, point.y)
			maximum.z = maxf(maximum.z, point.z)
			has_point = true
	return {"min": minimum, "max": maximum} if has_point else {}

static func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, output)
