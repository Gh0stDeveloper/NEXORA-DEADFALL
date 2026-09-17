class_name DeadfallFemaleOperatorDesign
extends RefCounted

const M = preload("res://src/assets/PresentationMesh.gd")

# Original VALERIA silhouette, face and equipment presentation. The supplied
# J-Toastie base supplies the weighted body/skeleton; DANTE remains unmodified.
static func reshape_body(instance: MeshInstance3D, reference: Node3D) -> void:
	var skin := instance.skin
	var skeleton := instance.get_node_or_null(instance.skeleton) as Skeleton3D
	if skin == null or skeleton == null:
		return
	var poses: Array[Transform3D] = []
	for bind in range(skin.get_bind_count()):
		var bone := skin.get_bind_bone(bind)
		if bone < 0: bone = skeleton.find_bone(skin.get_bind_name(bind))
		if bone < 0: return
		poses.append(skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(bind))
	var to_reference := reference.global_transform.affine_inverse() * skeleton.global_transform
	var mesh := ArrayMesh.new()
	for surface in range(instance.mesh.get_surface_count()):
		var arrays := instance.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var above_neck: Array[bool] = []
		var influences := int(bones.size() / vertices.size())
		for i in range(vertices.size()):
			var x := Vector3.ZERO
			var y := Vector3.ZERO
			var z := Vector3.ZERO
			var origin := Vector3.ZERO
			for influence in range(influences):
				var index := i * influences + influence
				var pose: Transform3D = poses[bones[index]]
				var weight := weights[index]
				x += pose.basis.x * weight
				y += pose.basis.y * weight
				z += pose.basis.z * weight
				origin += pose.origin * weight
			var deformation := to_reference * Transform3D(Basis(x, y, z), origin)
			var point := deformation * vertices[i]
			above_neck.append(point.y > 1.475)
			if absf(deformation.basis.determinant()) < 0.00000001:
				continue
			var waist := exp(-pow((point.y - 1.02) / 0.12, 2.0))
			var shoulders := exp(-pow((point.y - 1.36) / 0.14, 2.0))
			var hips := exp(-pow((point.y - 0.83) / 0.12, 2.0))
			point.x *= 1.0 - waist * 0.13 - shoulders * 0.09 + hips * 0.07
			point.z *= 1.0 - waist * 0.07
			vertices[i] = deformation.affine_inverse() * point
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var old_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var indices := PackedInt32Array()
		for triangle in range(0, old_indices.size(), 3):
			var a := old_indices[triangle]
			var b := old_indices[triangle + 1]
			var c := old_indices[triangle + 2]
			if above_neck[a] and above_neck[b] and above_neck[c]: continue
			indices.append_array(PackedInt32Array([a, b, c]))
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	instance.mesh = mesh

static func add_head(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var skin := M.material(Color("b98970"), 0.0, 0.78)
	var hair := M.material(Color("30241f"), 0.0, 0.91)
	var dark := M.material(Color("272b2d"), 0.1, 0.8)
	var iris := M.material(Color("31443c"), 0.0, 0.58)
	var lips := M.material(Color("8d594f"), 0.0, 0.8)
	var radius := clampf(size.x * 0.46, 0.084, 0.105)
	var face := M.capsule(parent, "ValeriaFace", radius, 0.235, at, skin)
	face.scale = Vector3(1, 1, 0.86)
	var cap := M.capsule(parent, "SweptHair", radius * 1.05, 0.24, at + Vector3(0, 0.05, 0.038), hair)
	cap.scale = Vector3(1.06, 0.63, 0.95)
	for side in [-1.0, 1.0]:
		var fringe := M.capsule(parent, "SideHair", 0.025, 0.14, at + Vector3(side * radius * 0.86, 0.026, 0.018), hair)
		fringe.rotation.z = side * 0.16
		M.capsule(parent, "Ear", 0.014, 0.042, at + Vector3(side * radius * 0.94, -0.012, 0), skin)
		var eye := M.capsule(parent, "Eye", 0.008, 0.026, at + Vector3(side * 0.034, 0.020, -radius * 0.81), iris)
		eye.rotation.z = PI * 0.5
		eye.scale.z = 0.4
		var brow := M.box(parent, "Brow", Vector3(0.034, 0.005, 0.005), at + Vector3(side * 0.035, 0.040, -radius * 0.77), hair)
		brow.rotation.z = side * 0.13
	var nose := M.capsule(parent, "Nose", 0.009, 0.033, at + Vector3(0, -0.005, -radius * 0.88), skin)
	nose.rotation.x = 0.13
	var mouth := M.capsule(parent, "Mouth", 0.006, 0.031, at + Vector3(0, -0.040, -radius * 0.80), lips)
	mouth.rotation.z = PI * 0.5
	mouth.scale.z = 0.4
	M.capsule(parent, "HairTie", 0.027, 0.050, at + Vector3(0, 0.046, 0.115), dark)
	var ponytail := M.capsule(parent, "Ponytail", 0.041, 0.21, at + Vector3(0, -0.04, 0.14), hair)
	ponytail.rotation.x = -0.3
	var tail := M.capsule(parent, "PonytailTip", 0.025, 0.13, at + Vector3(0, -0.18, 0.17), hair)
	tail.rotation.x = 0.12
	M.capsule(parent, "CommsEarpiece", 0.027, 0.053, at + Vector3(-radius - 0.012, 0.0, 0.01), dark)
	M.cylinder(parent, "CommsMicrophone", 0.004, 0.09, at + Vector3(-0.068, -0.046, -0.063), dark, true)
