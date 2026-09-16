class_name DeadfallPresentationMesh
extends RefCounted

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}

static func material(color: Color, metal: float = 0.0, rough: float = 0.75, glow: float = 0.0) -> StandardMaterial3D:
	var key := str([color, metal, rough, glow])
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	_materials[key] = m
	return m

static func part(parent: Node3D, name_value: String, mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_value
	node.mesh = mesh
	node.position = at
	node.material_override = mat
	parent.add_child(node)
	return node

static func box(parent: Node3D, name_value: String, dimensions: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var key := "box:%s" % dimensions
	if _meshes.has(key):
		return part(parent, name_value, _meshes[key], at, mat)
	# Flat normals and clockwise front faces keep plates solid and bevels crisp.
	var x := dimensions.x * 0.5
	var y := dimensions.y * 0.5
	var z := dimensions.z * 0.5
	var b := minf(x, y) * 0.28
	var outline := [Vector2(-x+b,-y), Vector2(x-b,-y), Vector2(x,-y+b), Vector2(x,y-b), Vector2(x-b,y), Vector2(-x+b,y), Vector2(-x,y-b), Vector2(-x,-y+b)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in range(8):
		var a: Vector2 = outline[i]
		var c: Vector2 = outline[(i+1)%8]
		for vertex in [Vector3(a.x,a.y,-z), Vector3(c.x,c.y,z), Vector3(c.x,c.y,-z), Vector3(a.x,a.y,-z), Vector3(a.x,a.y,z), Vector3(c.x,c.y,z), Vector3(0,0,-z), Vector3(a.x,a.y,-z), Vector3(c.x,c.y,-z), Vector3(0,0,z), Vector3(c.x,c.y,z), Vector3(a.x,a.y,z)]:
			st.add_vertex(vertex)
	st.generate_normals()
	var mesh := st.commit()
	_meshes[key] = mesh
	return part(parent, name_value, mesh, at, mat)

static func capsule(parent: Node3D, name_value: String, radius: float, height: float, at: Vector3, mat: Material) -> MeshInstance3D:
	var key := "capsule:%s:%s" % [radius, height]
	if _meshes.has(key):
		return part(parent, name_value, _meshes[key], at, mat)
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(radius * 2, height)
	mesh.radial_segments = 12
	mesh.rings = 4
	_meshes[key] = mesh
	return part(parent, name_value, mesh, at, mat)

static func cylinder(parent: Node3D, name_value: String, radius: float, length: float, at: Vector3, mat: Material, barrel: bool = false) -> MeshInstance3D:
	var key := "cylinder:%s:%s" % [radius, length]
	var mesh: CylinderMesh = _meshes.get(key)
	if mesh == null:
		mesh = CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = length
		mesh.radial_segments = 12
		_meshes[key] = mesh
	var node := part(parent, name_value, mesh, at, mat)
	if barrel:
		node.rotation.x = PI * 0.5
	return node

static func combine_static(parent: Node3D, excluded: Array[String] = []) -> void:
	# One surface per material instead of a draw call for every rail/vent/pouch.
	# Joints, grip markers and explicitly dynamic meshes remain addressable.
	var groups: Dictionary = {}
	for child in parent.get_children():
		if not child is MeshInstance3D or String(child.name) in excluded:
			continue
		var instance := child as MeshInstance3D
		if instance.mesh == null or not instance.visible:
			continue
		for surface in range(instance.mesh.get_surface_count()):
			var mat := instance.get_active_material(surface)
			if not groups.has(mat):
				var builder := SurfaceTool.new()
				builder.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[mat] = builder
			var builder: SurfaceTool = groups[mat]
			# Primitive meshes have different array formats (UV/tangents). Append
			# a common position/normal format so mixed cylinders and plates survive.
			var arrays := instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var normal_basis := instance.basis.inverse().transposed()
			for index in range(indices.size() if not indices.is_empty() else vertices.size()):
				var vertex_index := indices[index] if not indices.is_empty() else index
				builder.set_normal((normal_basis * normals[vertex_index]).normalized())
				builder.add_vertex(instance.transform * vertices[vertex_index])
		instance.free()
	if groups.is_empty():
		return
	var combined := ArrayMesh.new()
	for mat in groups:
		var builder: SurfaceTool = groups[mat]
		builder.set_material(mat)
		builder.commit(combined)
	part(parent, "BatchedGeometry", combined, Vector3.ZERO, null)

static func joint(parent: Node3D, name_value: String, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = name_value
	node.position = at
	parent.add_child(node)
	return node
