class_name DeadfallModelNormalizer
extends RefCounted

const MIN_VALID_HEIGHT := 0.01
const MAX_SCALE_FACTOR := 1000.0

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
	var factor := target_height / source_height
	if not is_finite(factor) or factor < 1.0 / MAX_SCALE_FACTOR or factor > MAX_SCALE_FACTOR:
		return {"ok": false, "reason": "unsafe_scale", "height": source_height}
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
		# Imported skin vertices can be in centimeters or bind space. The mesh
		# AABB alone does not describe the visible, skeleton-deformed character.
		var points := _skinned_points(mesh_instance, reference_root)
		if not points.is_empty():
			for point in points:
				minimum = minimum.min(point)
				maximum = maximum.max(point)
				has_point = true
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

static func _skinned_points(instance: MeshInstance3D, reference_root: Node3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	var skin := instance.skin
	var skeleton := instance.get_node_or_null(instance.skeleton) as Skeleton3D
	if skin == null or skeleton == null or skin.get_bind_count() == 0:
		return points
	var transforms: Array[Transform3D] = []
	for bind in range(skin.get_bind_count()):
		var bone := skin.get_bind_bone(bind)
		if bone < 0:
			bone = skeleton.find_bone(skin.get_bind_name(bind))
		if bone < 0 or bone >= skeleton.get_bone_count():
			return PackedVector3Array()
		transforms.append(skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(bind))
	var to_reference := reference_root.global_transform.affine_inverse() * skeleton.global_transform
	for surface in range(instance.mesh.get_surface_count()):
		var arrays := instance.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if vertices.is_empty() or bones.is_empty() or bones.size() != weights.size():
			return PackedVector3Array()
		var influences := int(bones.size() / vertices.size())
		for vertex_index in range(vertices.size()):
			var deformed := Vector3.ZERO
			for influence in range(influences):
				var index := vertex_index * influences + influence
				if weights[index] <= 0.0:
					continue
				if bones[index] < 0 or bones[index] >= transforms.size():
					return PackedVector3Array()
				deformed += (transforms[bones[index]] * vertices[vertex_index]) * weights[index]
			points.append(to_reference * deformed)
	return points

static func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, output)
