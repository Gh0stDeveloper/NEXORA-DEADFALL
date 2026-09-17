class_name DeadfallCityLayout
extends RefCounted

const SIZE := 192.0
const ROAD_CENTERS := [-56.0, 0.0, 56.0]
const LOT_CENTERS := [-80.0, -28.0, 28.0, 80.0]
const NAV_SOURCE_GROUP: StringName = &"deadfall_nav_source"

# The collision description is deterministic and shared by solo, clients and
# dedicated servers. It contains no Mesh, Material, Texture or audio resources.
static func describe() -> Dictionary:
	var city := {"boxes": [], "houses": [], "cars": [], "spawns": [], "size": SIZE}
	_box(city, "Ground", Vector3(0, -0.3, 0), Vector3(SIZE, 0.6, SIZE), "ground")
	for road in ROAD_CENTERS:
		for side in [-1.0, 1.0]:
			# Continuous low curbs leave every intersection and crossing traversable.
			for block in LOT_CENTERS:
				var length := 30.0 if absf(block) > 60.0 else 38.0
				_box(city, "SidewalkX", Vector3(road + side * 9.0, 0.06, block), Vector3(4, 0.12, length), "concrete")
				_box(city, "SidewalkZ", Vector3(block, 0.06, road + side * 9.0), Vector3(length, 0.12, 4), "concrete")
	var index := 0
	for x in LOT_CENTERS:
		for z in LOT_CENTERS:
			if x == 28.0 and z == -28.0:
				continue # A grassy civic park between the hospital and shopping street.
			var house := {"id": index, "at": Vector3(x, 0, z), "width": 16.0 + float(index % 3) * 2.0, "depth": 16.0 + float(index % 2) * 4.0, "ruined": index % 3 != 1, "surface": ["plaster", "brick", "sage", "sand"][index % 4]}
			city.houses.append(house)
			_house(city, house)
			index += 1
	var cars := [
		[Vector3(-3, 0, 72), 0.16], [Vector3(4, 0, 40), -0.3], [Vector3(-4, 0, -22), 0.12],
		[Vector3(3, 0, -77), 0.6], [Vector3(-59, 0, 25), -0.18], [Vector3(-53, 0, -38), 0.3],
		[Vector3(59, 0, 74), -0.35], [Vector3(52, 0, -21), 0.45], [Vector3(-24, 0, 3), 1.3],
		[Vector3(30, 0, -3), 1.7], [Vector3(-78, 0, -59), 1.42], [Vector3(76, 0, 53), 1.8],
		[Vector3(24, 0, 60), 1.4], [Vector3(-30, 0, -52), 1.9],
	]
	for car_index in range(cars.size()):
		var car := {"id": car_index, "at": cars[car_index][0], "yaw": cars[car_index][1], "burning": car_index in [2, 5, 9, 11]}
		city.cars.append(car)
		_box(city, "Wreck_%d" % car_index, car.at + Vector3(0, 0.72, 0), Vector3(1.95, 1.35, 4.3), "wreck_collision", float(car.yaw))
	for side in [-1.0, 1.0]:
		_box(city, "BoundaryX", Vector3(side * 97, 3, 0), Vector3(2, 6, 196), "boundary")
		_box(city, "BoundaryZ", Vector3(0, 3, side * 97), Vector3(192, 6, 2), "boundary")
		_box(city, "Quarantine", Vector3(side * 8, 0.7, 48), Vector3(4, 1.4, 0.7), "barrier")
	for road in ROAD_CENTERS:
		for along in [-86.0, -70.0, -42.0, -15.0, 15.0, 42.0, 70.0, 86.0]:
			city.spawns.append(Vector3(road, 0.05, along))
			city.spawns.append(Vector3(along, 0.05, road))
	return city

static func _house(city: Dictionary, house: Dictionary) -> void:
	var at: Vector3 = house.at
	var w: float = house.width
	var d: float = house.depth
	var prefix := "House_%02d_" % int(house.id)
	var surface := String(house.surface)
	_box(city, prefix + "Floor", at + Vector3(0, 0.04, 0), Vector3(w, 0.08, d), "interior")
	# Opposite 3 m doorways, 2.9 m clear headroom; AI can follow into and out of rooms.
	for front in [-1.0, 1.0]:
		for side in [-1.0, 1.0]:
			_box(city, prefix + "DoorWall", at + Vector3(side * (w + 3.0) * 0.25, 1.9, front * d * 0.5), Vector3((w - 3.0) * 0.5, 3.8, 0.42), surface)
		_box(city, prefix + "Lintel", at + Vector3(0, 3.38, front * d * 0.5), Vector3(3.0, 0.84, 0.42), surface)
	_box(city, prefix + "RightWall", at + Vector3(w * 0.5, 1.9, 0), Vector3(0.42, 3.8, d), surface)
	if bool(house.ruined):
		for side in [-1.0, 1.0]:
			_box(city, prefix + "BrokenWall", at + Vector3(-w * 0.5, 1.6, side * (d + 4.0) * 0.25), Vector3(0.42, 3.2, (d - 4.0) * 0.5), surface)
	else:
		_box(city, prefix + "LeftWall", at + Vector3(-w * 0.5, 1.9, 0), Vector3(0.42, 3.8, d), surface)
	# Partial ceilings and exposed beams keep the damaged interior readable.
	_box(city, prefix + "Roof", at + Vector3(w * 0.30, 3.95, 0), Vector3(w * 0.42, 0.26, d + 0.6), "roof")
	_box(city, prefix + "Partition", at + Vector3(-w * 0.25, 1.5, -d * 0.12), Vector3(w * 0.40, 3.0, 0.25), "interior")
	_box(city, prefix + "Counter", at + Vector3(w * 0.30, 0.50, -d * 0.30), Vector3(3.6, 1.0, 0.85), "wood")
	_box(city, prefix + "Sofa", at + Vector3(-w * 0.28, 0.42, d * 0.30), Vector3(2.8, 0.84, 1.0), "fabric")

static func _box(city: Dictionary, id: String, at: Vector3, dimensions: Vector3, surface: String, yaw: float = 0.0) -> void:
	city.boxes.append({"id": id, "at": at, "size": dimensions, "surface": surface, "yaw": yaw})

static func build_collision(parent: Node3D, city: Dictionary) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "CityCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	var shapes: Dictionary = {}
	for box: Dictionary in city.boxes:
		var dimensions: Vector3 = box.size
		if not shapes.has(dimensions):
			var shape := BoxShape3D.new()
			shape.size = dimensions
			shapes[dimensions] = shape
		var collider := CollisionShape3D.new()
		collider.name = String(box.id)
		collider.position = box.at
		collider.rotation.y = float(box.yaw)
		collider.shape = shapes[dimensions]
		body.add_child(collider)
	parent.add_child(body)
	body.add_to_group(NAV_SOURCE_GROUP)
	return body
