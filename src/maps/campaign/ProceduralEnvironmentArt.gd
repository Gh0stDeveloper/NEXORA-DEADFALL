class_name DeadfallProceduralEnvironmentArt
extends RefCounted

static func create_structure(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	base_color: Color,
	detail: StringName = &"building"
) -> StaticBody3D:
	if parent == null or size_value.x <= 0.0 or size_value.y <= 0.0 or size_value.z <= 0.0:
		return null
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		return body
	var visual_root := Node3D.new()
	visual_root.name = "ProceduralModel"
	body.add_child(visual_root)
	_add_box(visual_root, "MainMass", Vector3.ZERO, size_value, base_color, 0.88)
	_add_structure_details(visual_root, size_value, base_color, detail)
	return body

static func _add_structure_details(root: Node3D, size_value: Vector3, base_color: Color, detail: StringName) -> void:
	var width := size_value.x
	var height := size_value.y
	var depth := size_value.z
	var top_y := height * 0.5
	var cap_color := base_color.lightened(0.10)
	var edge_color := base_color.darkened(0.22)
	_add_box(root, "TopCap", Vector3(0.0, top_y + 0.045, 0.0), Vector3(width + 0.14, 0.09, depth + 0.14), cap_color, 0.82)
	if detail == &"ground":
		_add_box(root, "GroundSurface", Vector3(0.0, size_value.y * 0.5 + 0.028, 0.0), Vector3(width - 0.20, 0.04, depth - 0.20), base_color.lightened(0.035), 0.98)
		_add_box(root, "RoadWear", Vector3(0.0, size_value.y * 0.5 + 0.052, 0.0), Vector3(width * 0.32, 0.012, depth - 0.40), edge_color, 1.0)
		_add_box(root, "RoadWearCross", Vector3(0.0, size_value.y * 0.5 + 0.055, 0.0), Vector3(width - 0.40, 0.012, depth * 0.12), edge_color, 1.0)
		return
	if detail == &"barrier":
		_add_box(root, "BarrierTop", Vector3(0.0, top_y + 0.09, 0.0), Vector3(width + 0.18, 0.16, depth + 0.12), cap_color, 0.74)
		for side in [-1.0, 1.0]:
			_add_box(root, "BarrierStripe_%s" % String(side), Vector3(side * width * 0.28, 0.02, -depth * 0.5 - 0.025), Vector3(width * 0.12, height * 0.72, 0.045), Color(0.66, 0.37, 0.08), 0.70)
		return
	if detail == &"cover":
		_add_box(root, "CoverLip", Vector3(0.0, top_y + 0.06, 0.0), Vector3(width + 0.10, 0.12, depth + 0.10), cap_color, 0.78)
		_add_box(root, "CoverFace", Vector3(0.0, height * 0.22, -depth * 0.5 - 0.018), Vector3(width * 0.78, height * 0.28, 0.05), edge_color, 0.94)
		_add_rubble(root, Vector3(-width * 0.65, 0.04, depth * 0.65), 0.18, edge_color)
		_add_rubble(root, Vector3(width * 0.62, 0.03, -depth * 0.58), 0.13, cap_color)
		return
	if detail == &"perimeter":
		_add_perimeter_piers(root, size_value, cap_color)
		_add_box(root, "WeatherBand", Vector3(0.0, height * 0.26, -depth * 0.5 - 0.018), Vector3(maxf(0.5, width - 0.5), 0.11, 0.05), edge_color, 0.96)
		_add_box(root, "WeatherBandUpper", Vector3(0.0, height * 0.72, depth * 0.5 + 0.018), Vector3(maxf(0.5, width - 0.5), 0.08, 0.05), edge_color, 0.96)
		return
	_add_perimeter_piers(root, size_value, cap_color)
	_add_facade_windows(root, size_value)
	_add_box(root, "LowerGrimeBand", Vector3(0.0, height * 0.12, -depth * 0.5 - 0.020), Vector3(maxf(0.5, width - 0.7), height * 0.12, 0.045), edge_color, 0.98)
	_add_box(root, "UpperTrim", Vector3(0.0, height * 0.78, -depth * 0.5 - 0.024), Vector3(maxf(0.5, width - 0.7), 0.10, 0.05), cap_color, 0.78)
	_add_rubble(root, Vector3(-width * 0.34, 0.06, depth * 0.56), 0.16, edge_color)
	_add_rubble(root, Vector3(width * 0.41, 0.04, -depth * 0.58), 0.12, cap_color)

static func _add_perimeter_piers(root: Node3D, size_value: Vector3, color: Color) -> void:
	var x_offset := maxf(0.08, size_value.x * 0.5 - 0.09)
	var z_offset := maxf(0.08, size_value.z * 0.5 - 0.09)
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			_add_box(
				root,
				"CornerPier_%s_%s" % [String(x_sign), String(z_sign)],
				Vector3(x_sign * x_offset, size_value.y * 0.5, z_sign * z_offset),
				Vector3(0.18, size_value.y + 0.04, 0.18),
				color,
				0.80
			)

static func _add_facade_windows(root: Node3D, size_value: Vector3) -> void:
	if size_value.x < 4.0 or size_value.y < 2.0 or size_value.z < 1.0:
		return
	var count := clampi(int(floor(size_value.x / 3.6)), 2, 5)
	var window_width := maxf(0.65, (size_value.x - 1.8 - float(count - 1) * 0.55) / float(count))
	var window_height := maxf(0.65, size_value.y * 0.22)
	var glass := Color(0.055, 0.11, 0.13)
	var frame := Color(0.24, 0.26, 0.25)
	for face in [-1.0, 1.0]:
		var face_value: float = float(face)
		var z: float = face_value * (size_value.z * 0.5 + 0.026)
		for index in range(count):
			var x := -size_value.x * 0.5 + 0.9 + window_width * 0.5 + float(index) * (window_width + 0.55)
			_add_box(root, "WindowGlass_%s_%d" % [String(face_value), index], Vector3(x, size_value.y * 0.47, z), Vector3(window_width, window_height, 0.045), glass, 0.32)
			_add_box(root, "WindowFrame_%s_%d" % [String(face_value), index], Vector3(x, size_value.y * 0.47, z + face_value * 0.026), Vector3(window_width + 0.08, 0.07, 0.025), frame, 0.72)

static func _add_rubble(root: Node3D, local_position: Vector3, radius: float, color: Color) -> void:
	var rubble := MeshInstance3D.new()
	rubble.name = "Rubble"
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.62
	mesh.bottom_radius = radius
	mesh.height = radius * 0.75
	mesh.radial_segments = 6
	mesh.material = _material(color, 0.94)
	rubble.mesh = mesh
	rubble.position = local_position
	rubble.rotation_degrees = Vector3(0.0, 27.0, -8.0)
	rubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(rubble)

static func _add_box(root: Node3D, node_name: String, local_position: Vector3, box_size: Vector3, color: Color, roughness: float) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = _material(color, roughness)
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(mesh_instance)

static func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = clampf(roughness, 0.0, 1.0)
	material.metallic = 0.02
	return material
