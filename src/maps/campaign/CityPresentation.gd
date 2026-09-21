class_name DeadfallCityPresentation
extends Node3D

const Layout = preload("res://src/maps/campaign/CityLayout.gd")
const PALETTE := {
	"ground": Color(0.3, 0.35, 0.2), "asphalt": Color(0.16, 0.17, 0.17),
	"concrete": Color(0.58, 0.57, 0.52), "plaster": Color(0.71, 0.69, 0.60),
	"brick": Color(0.43, 0.22, 0.14), "sage": Color(0.40, 0.49, 0.42),
	"sand": Color(0.64, 0.48, 0.32), "interior": Color(0.58, 0.55, 0.47),
	"roof": Color(0.22, 0.23, 0.23), "wood": Color(0.28, 0.18, 0.10),
	"fabric": Color(0.27, 0.31, 0.26), "metal": Color(0.18, 0.20, 0.20),
	"rust": Color(0.33, 0.16, 0.085), "tire": Color(0.055, 0.055, 0.049),
	"glass": Color(0.10, 0.18, 0.20), "paint": Color(0.86, 0.80, 0.61),
	"barrier": Color(0.58, 0.53, 0.39), "boundary": Color(0.42, 0.43, 0.40),
	"leaf": Color(0.21, 0.32, 0.12), "grass": Color(0.31, 0.40, 0.17),
}
var _groups: Dictionary = {}
var _materials: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func build(city: Dictionary) -> void:
	_rng.seed = 764209
	for box: Dictionary in city.boxes:
		if box.surface not in ["wreck_collision", "trunk_collision"]:
			_box(box.at, box.size, String(box.surface), Vector3(0, float(box.yaw), 0))
	_streets()
	for house: Dictionary in city.houses:
		_house_details(house)
	for car: Dictionary in city.cars:
		_wreck(car)
	_vegetation()
	_street_furniture()
	_skyline()
	_flush()
	_sign("HOSPITAL CENTRAL", Vector3(-28, 3.1, -17.7), Color(0.14, 0.37, 0.39), 0.0)
	_sign("RADIO  /  104.8 FM", Vector3(28, 3.1, 38.3), Color(0.43, 0.22, 0.11), 0.0)
	_sign("DEADFALL  /  SECTOR 07", Vector3(0, 4.7, 89), Color(0.20, 0.25, 0.24), 0.0)
	_sign("EVACUACIÓN", Vector3(-80, 3.1, -69.7), Color(0.16, 0.34, 0.23), 0.0)

func _streets() -> void:
	for road in Layout.ROAD_CENTERS:
		_box(Vector3(road, 0.012, 0), Vector3(14, 0.02, 192), "asphalt")
		_box(Vector3(0, 0.015, road), Vector3(192, 0.02, 14), "asphalt")
		for step in range(-90, 96, 8):
			var along := float(step)
			if _near_intersection(along):
				continue
			for side in [-0.13, 0.13]:
				_box(Vector3(road + side, 0.032, along), Vector3(0.10, 0.014, 3.5), "paint")
				_box(Vector3(along, 0.034, road + side), Vector3(3.5, 0.014, 0.10), "paint")
		for cross in Layout.ROAD_CENTERS:
			for stripe in range(-5, 6, 2):
				for side in [-1.0, 1.0]:
					_box(Vector3(road + float(stripe), 0.04, cross + side * 10), Vector3(0.8, 0.014, 2.7), "concrete")
					_box(Vector3(road + side * 10, 0.04, cross + float(stripe)), Vector3(2.7, 0.014, 0.8), "concrete")

func _near_intersection(value: float) -> bool:
	for center in Layout.ROAD_CENTERS:
		if absf(value - center) < 13.0:
			return true
	return false

func _house_details(house: Dictionary) -> void:
	var at: Vector3 = house.at
	var w: float = house.width
	var d: float = house.depth
	var ruined: bool = house.ruined
	# Different upper silhouettes: standing facades, exposed rafters and torn roofs.
	for z in [-d * 0.35, 0.0, d * 0.35]:
		_box(at + Vector3(0, 3.9, z), Vector3(w + 0.3, 0.20, 0.19), "wood", Vector3(0, 0, 0.025 if ruined else 0))
	for front in [-1.0, 1.0]:
		for x in [-w * 0.30, w * 0.30]:
			var window := at + Vector3(x, 2.15, front * (d * 0.5 + 0.24))
			_box(window, Vector3(2.3, 1.7, 0.06), "metal")
			_box(window + Vector3(0, 0, front * 0.05), Vector3(1.98, 1.42, 0.04), "glass")
			_box(window + Vector3(0, 0, front * 0.1), Vector3(0.11, 1.55, 0.10), "wood")
			_box(window + Vector3(0, -0.84, 0), Vector3(2.6, 0.14, 0.25), "concrete")
			if ruined:
				_box(window + Vector3(0, 0.12, front * 0.13), Vector3(2.5, 0.15, 0.07), "wood", Vector3(0, 0, 0.4))
		# Door posts emphasize that the dark central opening is an actual passage.
		for x in [-1.56, 1.56]:
			_box(at + Vector3(x, 1.42, front * (d * 0.5 + 0.25)), Vector3(0.16, 2.84, 0.22), "wood")
		_box(at + Vector3(0, 2.84, front * (d * 0.5 + 0.25)), Vector3(3.3, 0.18, 0.22), "wood")
	# Interior details stay away from both doorways and their connecting route.
	_box(at + Vector3(w * 0.30, 1.08, -d * 0.30), Vector3(3.8, 0.10, 0.95), "metal")
	_box(at + Vector3(-w * 0.28, 0.91, d * 0.30 + 0.4), Vector3(2.8, 0.4, 0.25), "fabric")
	for i in range(9 if ruined else 3):
		var side := -1.0 if i % 2 == 0 else 1.0
		var pos := at + Vector3(side * _rng.randf_range(w * 0.30, w * 0.60), 0.10, _rng.randf_range(-d * 0.48, d * 0.48))
		_box(pos, Vector3(_rng.randf_range(0.2, 0.8), 0.18, _rng.randf_range(0.25, 0.65)), "brick", Vector3(0, _rng.randf() * TAU, 0.12))

func _wreck(car: Dictionary) -> void:
	var origin := Transform3D(Basis(Vector3.UP, float(car.yaw)), car.at)
	var burnt: bool = car.burning
	var paint: Color = [Color(0.39, 0.47, 0.48), Color(0.54, 0.36, 0.20), Color(0.47, 0.22, 0.16), Color(0.70, 0.68, 0.60)][int(car.id) % 4]
	if burnt: paint = Color(0.20, 0.18, 0.15)
	_car_box(origin, Vector3(0, 0.65, 0), Vector3(1.92, 0.65, 4.2), "metal", paint)
	_car_box(origin, Vector3(0, 0.90, -1.50), Vector3(1.86, 0.18, 1.25), "metal", paint, Vector3(-0.17, 0, 0.06))
	_car_box(origin, Vector3(0, 0.95, 1.67), Vector3(1.86, 0.2, 0.78), "metal", paint)
	_car_box(origin, Vector3(0, 1.48, 0.25), Vector3(1.70, 0.13, 1.85), "metal", paint, Vector3(0.05, 0, -0.055))
	for side in [-1.0, 1.0]:
		for z in [-1.3, 1.35]:
			_add("cylinder", origin * Vector3(side * 0.98, 0.38, z), Vector3(0.70, 0.23, 0.70), "tire", origin.basis * Basis(Vector3.FORWARD, PI * 0.5))
			_add("cylinder", origin * Vector3(side * 1.11, 0.38, z), Vector3(0.34, 0.04, 0.34), "rust", origin.basis * Basis(Vector3.FORWARD, PI * 0.5))
		_car_box(origin, Vector3(side * 0.79, 1.22, -0.72), Vector3(0.08, 0.64, 0.10), "rust", Color.WHITE, Vector3(-0.35, 0, 0))
		_car_box(origin, Vector3(side * 0.79, 1.22, 1.08), Vector3(0.09, 0.57, 0.12), "rust", Color.WHITE, Vector3(0.3, 0, 0))
		_car_box(origin, Vector3(side * 0.94, 0.94, 0.22), Vector3(0.08, 0.18, 1.9), "rust")
		_car_box(origin, Vector3(side * 0.68, 0.65, -2.14), Vector3(0.38, 0.16, 0.05), "paint")
		_car_box(origin, Vector3(side * 0.43, 0.95, 0.26), Vector3(0.55, 0.56, 0.34), "tire")
	_car_box(origin, Vector3(0, 0.54, -2.18), Vector3(1.80, 0.17, 0.13), "rust")
	_car_box(origin, Vector3(0, 0.78, -2.13), Vector3(0.64, 0.21, 0.08), "tire")
	if burnt:
		var fire := preload("res://src/maps/campaign/CityFire.gd").new()
		fire.name = "WreckFire_%d" % int(car.id)
		fire.position = origin * Vector3(0, 0.85, -1.1)
		add_child(fire)

func _car_box(origin: Transform3D, at: Vector3, size: Vector3, material: String, tint: Color = Color.WHITE, rotation_value: Vector3 = Vector3.ZERO) -> void:
	_add("box", origin * at, size, material, origin.basis * Basis.from_euler(rotation_value), tint)

func _vegetation() -> void:
	var count := 1200 if int(Settings.quality_tier) == 0 else 3200
	for i in range(count):
		var point := Vector3(_rng.randf_range(-94, 94), 0.002, _rng.randf_range(-94, 94))
		var grass_allowed := true
		for road in Layout.ROAD_CENTERS:
			if absf(point.x - road) < 11.5 or absf(point.z - road) < 11.5:
				grass_allowed = false
		for x in Layout.LOT_CENTERS:
			for z in Layout.LOT_CENTERS:
				if absf(point.x - x) < 11.5 and absf(point.z - z) < 12.0 and not (x == 28 and z == -28):
					grass_allowed = false
		if grass_allowed:
			_add("grass", point, Vector3.ONE * _rng.randf_range(0.6, 1.7), "grass", Basis(Vector3.UP, _rng.randf() * TAU), Color(_rng.randf_range(0.78, 1.0), 1.0, 0.85))
	for point in Layout.TREE_POSITIONS:
		_add("cylinder", point + Vector3(0, 2.1, 0), Vector3(0.5, 4.2, 0.5), "wood")
		for branch in range(4):
			var crown: Vector3 = point + Vector3(_rng.randf_range(-1.1, 1.1), 4.2 + _rng.randf_range(0, 1.2), _rng.randf_range(-1.1, 1.1))
			_add("sphere", crown, Vector3(3.3, 2.8, 3.2), "leaf", Basis.IDENTITY, Color(1.0, _rng.randf_range(0.75, 1.0), 0.8))

func _street_furniture() -> void:
	for x in [-10.5, 10.5, -66.5, 66.5]:
		for z in [-75.0, -28.0, 28.0, 75.0]:
			_add("cylinder", Vector3(x, 3.4, z), Vector3(0.14, 6.8, 0.14), "metal")
			_box(Vector3(x + (-0.7 if x > 0 else 0.7), 6.7, z), Vector3(1.6, 0.14, 0.15), "metal")
			_box(Vector3(x + (-1.3 if x > 0 else 1.3), 6.65, z), Vector3(0.62, 0.13, 0.40), "paint")
	for x in [-2.4, 2.4]:
		_box(Vector3(x, 2.5, 89), Vector3(0.13, 5, 0.13), "metal")
	for point in [Vector3(22,0,-21), Vector3(36,0,-34), Vector3(-42,0,-20)]:
		_box(point + Vector3(0, 0.52, 0), Vector3(2.2, 0.12, 0.55), "wood")
		_box(point + Vector3(0, 0.95, 0.25), Vector3(2.2, 0.68, 0.1), "wood")
		for side in [-0.85, 0.85]:
			_box(point + Vector3(side, 0.25, 0), Vector3(0.12, 0.5, 0.55), "metal")

func _skyline() -> void:
	for index in range(26):
		var angle := float(index) / 26.0 * TAU
		var at := Vector3(cos(angle) * 126, 0, sin(angle) * 126)
		var height := _rng.randf_range(10, 29)
		_box(at + Vector3(0, height * 0.5, 0), Vector3(_rng.randf_range(10,18), height, 12), "boundary")
		for floor in range(2, int(height), 3):
			_box(at + Vector3(0, floor, 6.02), Vector3(8, 0.7, 0.03), "glass")

func _box(at: Vector3, dimensions: Vector3, surface: String, rotation_value: Vector3 = Vector3.ZERO) -> void:
	_add("box", at, dimensions, surface, Basis.from_euler(rotation_value))

func _add(shape: String, at: Vector3, dimensions: Vector3, surface: String, rotation_basis: Basis = Basis.IDENTITY, tint: Color = Color.WHITE) -> void:
	# Batches are spatially bounded so off-screen blocks can be culled on phones.
	var chunk := Vector2i(floori(at.x / 64.0), floori(at.z / 64.0))
	var shadow := not (shape == "grass" or surface in ["paint", "asphalt", "ground", "leaf"])
	var key := "%s:%s:%s" % [chunk, shape, shadow]
	if not _groups.has(key):
		_groups[key] = {"shape": shape, "shadow": shadow, "transforms": [], "colors": [], "types": []}
	_groups[key].transforms.append(Transform3D(Basis(rotation_basis.x * dimensions.x, rotation_basis.y * dimensions.y, rotation_basis.z * dimensions.z), at))
	_groups[key].colors.append((PALETTE.get(surface, Color.GRAY) as Color).srgb_to_linear() * tint)
	_groups[key].types.append(float({"ground": 1, "asphalt": 2, "brick": 3, "concrete": 4, "interior": 4}.get(surface, 0)))

func _flush() -> void:
	var shapes: Dictionary = {}
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	shapes.box = box
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.5
	cylinder.bottom_radius = 0.5
	cylinder.height = 1.0
	cylinder.radial_segments = 10
	shapes.cylinder = cylinder
	var sphere := SphereMesh.new()
	sphere.height = 1.0
	sphere.radius = 0.5
	sphere.radial_segments = 10
	sphere.rings = 5
	shapes.sphere = sphere
	shapes.grass = _grass_mesh()
	for key: String in _groups:
		var group: Dictionary = _groups[key]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.use_custom_data = true
		multi.mesh = shapes[group.shape]
		multi.instance_count = group.transforms.size()
		for index in range(multi.instance_count):
			multi.set_instance_transform(index, group.transforms[index])
			multi.set_instance_color(index, group.colors[index])
			multi.set_instance_custom_data(index, Color(group.types[index], 0, 0, 0))
		var instance := MultiMeshInstance3D.new()
		instance.name = "CityBatch_%d" % get_child_count()
		instance.multimesh = multi
		instance.material_override = _material("city")
		instance.visibility_range_end = 65.0 if group.shape == "grass" else 0.0
		if not bool(group.shadow):
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	_groups.clear()

func _material(surface: String) -> Material:
	if _materials.has(surface):
		return _materials[surface]
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/maps/campaign/CitySurface.gdshader")
	material.set_shader_parameter("base_color", Color.WHITE)
	_materials[surface] = material
	return material

func _grass_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(7):
		var basis_value := Basis(Vector3.UP, float(index) * 2.4)
		var points := [Vector3(-0.018, 0, 0), Vector3(0.018, 0, 0), Vector3(0.025, 0.18 + float(index % 3) * 0.04, 0)]
		for order in [[0, 2, 1], [0, 1, 2]]:
			for vertex: int in order:
				tool.set_color(Color.WHITE)
				tool.add_vertex(basis_value * points[vertex] + Vector3(sin(index * 2.4), 0, cos(index * 2.4)) * 0.09)
	tool.generate_normals()
	return tool.commit()

func _sign(value: String, at: Vector3, color: Color, yaw: float) -> void:
	var board := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(5.8, 0.82, 0.12)
	board.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	board.material_override = material
	board.position = at
	board.rotation.y = yaw
	add_child(board)
	var label := Label3D.new()
	label.text = value
	label.font_size = 48
	label.pixel_size = 0.0035
	label.modulate = Color(0.92, 0.90, 0.79)
	label.position = Vector3(0, 0, 0.075)
	label.outline_size = 0
	board.add_child(label)
