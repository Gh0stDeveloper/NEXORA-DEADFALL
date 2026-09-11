class_name DeadfallProceduralWeaponModels
extends RefCounted

static func create_view_model(weapon_id: StringName) -> Node3D:
	var id := String(weapon_id).to_lower()
	if id == "machete" or id.contains("melee"):
		return _create_machete()
	if id.contains("pistol") or id.contains("sidearm"):
		return _create_pistol()
	return _create_rifle()

static func _create_rifle() -> Node3D:
	var root := Node3D.new()
	root.name = "ProceduralRifle"
	var dark := _material(Color(0.035, 0.045, 0.052), 0.45, 0.42)
	var body := _material(Color(0.12, 0.14, 0.15), 0.55, 0.34)
	var accent := _material(Color(0.52, 0.045, 0.035), 0.20, 0.48)
	var grip := _material(Color(0.065, 0.048, 0.038), 0.05, 0.84)
	var steel := _material(Color(0.34, 0.39, 0.40), 0.78, 0.24)

	_box(root, "Receiver", Vector3(0.48, 0.18, 0.28), Vector3(0.0, 0.0, 0.0), body)
	_box(root, "UpperReceiver", Vector3(0.30, 0.11, 0.31), Vector3(0.0, 0.10, -0.08), dark)
	_box(root, "Handguard", Vector3(0.30, 0.17, 0.43), Vector3(0.0, 0.0, -0.34), body)
	_box(root, "Stock", Vector3(0.23, 0.18, 0.42), Vector3(0.0, 0.01, 0.33), dark)
	_box(root, "StockPad", Vector3(0.24, 0.22, 0.07), Vector3(0.0, 0.0, 0.55), grip)
	_box(root, "Magazine", Vector3(0.14, 0.30, 0.13), Vector3(0.0, -0.20, 0.06), dark)
	_box(root, "MagazineMark", Vector3(0.08, 0.08, 0.018), Vector3(0.0, -0.20, -0.072), accent)
	_box(root, "PistolGrip", Vector3(0.15, 0.32, 0.15), Vector3(0.0, -0.21, 0.22), grip)
	_box(root, "ForeGrip", Vector3(0.13, 0.26, 0.14), Vector3(0.0, -0.16, -0.31), grip)
	_cylinder(root, "Barrel", 0.035, 0.68, Vector3(0.0, 0.0, -0.74), steel, 10)
	_cylinder(root, "MuzzleBrake", 0.065, 0.12, Vector3(0.0, 0.0, -1.10), dark, 10)
	_box(root, "TopRail", Vector3(0.12, 0.035, 0.34), Vector3(0.0, 0.17, -0.13), dark)
	_box(root, "RearSight", Vector3(0.09, 0.10, 0.08), Vector3(0.0, 0.23, 0.03), steel)
	_box(root, "FrontSight", Vector3(0.045, 0.10, 0.045), Vector3(0.0, 0.22, -0.46), steel)
	root.set_meta("source", "procedural")
	root.set_meta("weapon_id", "nxr_rifle_01")
	return root

static func _create_pistol() -> Node3D:
	var root := Node3D.new()
	root.name = "ProceduralPistol"
	var dark := _material(Color(0.035, 0.042, 0.048), 0.48, 0.40)
	var slide := _material(Color(0.20, 0.23, 0.24), 0.72, 0.28)
	var accent := _material(Color(0.50, 0.04, 0.035), 0.18, 0.50)
	var grip := _material(Color(0.07, 0.05, 0.04), 0.04, 0.88)
	var steel := _material(Color(0.40, 0.45, 0.45), 0.84, 0.22)

	_box(root, "Slide", Vector3(0.30, 0.13, 0.48), Vector3(0.0, 0.10, -0.14), slide)
	_box(root, "SlideAccent", Vector3(0.22, 0.035, 0.025), Vector3(0.0, 0.17, -0.18), accent)
	_box(root, "Frame", Vector3(0.27, 0.15, 0.36), Vector3(0.0, -0.01, 0.10), dark)
	_box(root, "Grip", Vector3(0.16, 0.31, 0.19), Vector3(0.0, -0.22, 0.20), grip)
	_box(root, "GripBase", Vector3(0.19, 0.07, 0.21), Vector3(0.0, -0.37, 0.20), dark)
	_box(root, "Magazine", Vector3(0.12, 0.22, 0.11), Vector3(0.0, -0.14, 0.10), steel)
	_box(root, "TriggerGuard", Vector3(0.18, 0.06, 0.16), Vector3(0.0, -0.11, -0.03), steel)
	_cylinder(root, "Barrel", 0.026, 0.28, Vector3(0.0, 0.10, -0.52), steel, 10)
	_box(root, "FrontSight", Vector3(0.035, 0.08, 0.035), Vector3(0.0, 0.20, -0.38), steel)
	root.set_meta("source", "procedural")
	root.set_meta("weapon_id", "nxr_pistol_01")
	return root

static func _create_machete() -> Node3D:
	var root := Node3D.new()
	root.name = "ProceduralMachete"
	var blade := _material(Color(0.46, 0.52, 0.53), 0.82, 0.24)
	var edge := _material(Color(0.76, 0.83, 0.82), 0.90, 0.16)
	var dark := _material(Color(0.045, 0.030, 0.024), 0.05, 0.88)
	var guard := _material(Color(0.12, 0.14, 0.14), 0.65, 0.32)
	var accent := _material(Color(0.55, 0.045, 0.035), 0.15, 0.48)

	_box(root, "BladeCore", Vector3(0.085, 0.62, 0.038), Vector3(0.0, 0.34, 0.0), blade)
	_box(root, "BladeEdge", Vector3(0.026, 0.55, 0.018), Vector3(0.052, 0.35, -0.023), edge)
	_box(root, "BladeTip", Vector3(0.14, 0.12, 0.038), Vector3(0.015, 0.68, 0.0), blade)
	_box(root, "Guard", Vector3(0.25, 0.07, 0.065), Vector3(0.0, 0.0, 0.0), guard)
	_box(root, "GuardAccent", Vector3(0.08, 0.085, 0.075), Vector3(0.0, 0.0, -0.01), accent)
	_box(root, "Handle", Vector3(0.12, 0.28, 0.10), Vector3(0.0, -0.18, 0.0), dark)
	_box(root, "HandleWrapA", Vector3(0.135, 0.035, 0.115), Vector3(0.0, -0.10, -0.005), accent)
	_box(root, "HandleWrapB", Vector3(0.135, 0.035, 0.115), Vector3(0.0, -0.25, -0.005), accent)
	_box(root, "Pommel", Vector3(0.16, 0.08, 0.12), Vector3(0.0, -0.36, 0.0), guard)
	root.set_meta("source", "procedural")
	root.set_meta("weapon_id", "machete")
	return root

static func _box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.mesh = mesh
	instance.cast_shadow = 1
	parent.add_child(instance)
	return instance

static func _cylinder(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: StandardMaterial3D, radial_segments: int = 10) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	instance.mesh = mesh
	instance.cast_shadow = 1
	parent.add_child(instance)
	return instance

static func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
