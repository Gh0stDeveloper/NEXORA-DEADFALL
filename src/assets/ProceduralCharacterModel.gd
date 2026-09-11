class_name DeadfallProceduralCharacterModel
extends RefCounted

static func create_operator(character_id: StringName = &"operator_01", slot_index: int = 0) -> Node3D:
	var root := Node3D.new()
	root.name = "ProceduralOperator"
	var palette := _operator_palette(character_id)
	var dark: Color = palette.get("dark", Color(0.045, 0.055, 0.07))
	var cloth: Color = palette.get("cloth", Color(0.18, 0.20, 0.23))
	var accent: Color = _slot_accent(palette.get("accent", Color(0.72, 0.08, 0.10)), slot_index)
	var metal: Color = palette.get("metal", Color(0.24, 0.28, 0.31))
	var skin: Color = palette.get("skin", Color(0.48, 0.34, 0.26))
	var visor: Color = palette.get("visor", Color(0.05, 0.15, 0.18))

	_box(root, "LeftBoot", Vector3(0.24, 0.10, 0.38), Vector3(-0.16, 0.05, -0.035), dark, 0.08, 0.82)
	_box(root, "RightBoot", Vector3(0.24, 0.10, 0.38), Vector3(0.16, 0.05, -0.035), dark, 0.08, 0.82)
	_box(root, "LeftShin", Vector3(0.25, 0.40, 0.30), Vector3(-0.16, 0.29, 0.0), cloth, 0.02, 0.76)
	_box(root, "RightShin", Vector3(0.25, 0.40, 0.30), Vector3(0.16, 0.29, 0.0), cloth, 0.02, 0.76)
	_box(root, "HipArmor", Vector3(0.58, 0.27, 0.34), Vector3(0.0, 0.56, 0.0), dark, 0.10, 0.64)
	_box(root, "Torso", Vector3(0.66, 0.58, 0.38), Vector3(0.0, 0.94, 0.0), cloth, 0.04, 0.72)
	_box(root, "ChestPlate", Vector3(0.54, 0.40, 0.08), Vector3(0.0, 1.01, -0.205), accent, 0.12, 0.42)
	_box(root, "ChestPanel", Vector3(0.24, 0.18, 0.025), Vector3(0.0, 1.02, -0.252), metal, 0.55, 0.30)
	_box(root, "LeftShoulder", Vector3(0.20, 0.18, 0.40), Vector3(-0.41, 1.20, 0.0), dark, 0.12, 0.55)
	_box(root, "RightShoulder", Vector3(0.20, 0.18, 0.40), Vector3(0.41, 1.20, 0.0), dark, 0.12, 0.55)
	_box(root, "LeftArm", Vector3(0.20, 0.55, 0.24), Vector3(-0.43, 0.92, 0.0), cloth, 0.02, 0.78)
	_box(root, "RightArm", Vector3(0.20, 0.55, 0.24), Vector3(0.43, 0.92, 0.0), cloth, 0.02, 0.78)
	_box(root, "LeftGlove", Vector3(0.22, 0.14, 0.27), Vector3(-0.43, 0.64, -0.015), dark, 0.10, 0.64)
	_box(root, "RightGlove", Vector3(0.22, 0.14, 0.27), Vector3(0.43, 0.64, -0.015), dark, 0.10, 0.64)
	_cylinder(root, "Neck", 0.13, 0.12, Vector3(0.0, 1.34, 0.0), dark)
	_capsule(root, "Head", 0.205, 0.34, Vector3(0.0, 1.49, 0.0), skin)
	_cylinder(root, "Helmet", 0.235, 0.11, Vector3(0.0, 1.69, 0.0), dark)
	_box(root, "HelmetBand", Vector3(0.42, 0.06, 0.39), Vector3(0.0, 1.66, -0.005), accent, 0.18, 0.48)
	_box(root, "Visor", Vector3(0.34, 0.09, 0.045), Vector3(0.0, 1.51, -0.19), visor, 0.42, 0.24)
	_box(root, "Backpack", Vector3(0.42, 0.52, 0.18), Vector3(0.0, 0.98, 0.23), dark, 0.12, 0.76)
	_box(root, "Radio", Vector3(0.11, 0.22, 0.08), Vector3(0.25, 1.18, 0.20), metal, 0.60, 0.26)
	_cylinder(root, "RadioAntenna", 0.012, 0.24, Vector3(0.25, 1.40, 0.20), metal, 8)
	_box(root, "LeftKneePad", Vector3(0.20, 0.10, 0.055), Vector3(-0.16, 0.40, -0.16), accent, 0.10, 0.55)
	_box(root, "RightKneePad", Vector3(0.20, 0.10, 0.055), Vector3(0.16, 0.40, -0.16), accent, 0.10, 0.55)
	_box(root, "UtilityBelt", Vector3(0.61, 0.08, 0.40), Vector3(0.0, 0.70, -0.015), dark, 0.12, 0.74)
	root.set_meta("source", "procedural")
	root.set_meta("visual_height", 1.72)
	return root

static func create_zombie(variant: StringName = &"walker") -> Node3D:
	var root := Node3D.new()
	root.name = "ProceduralZombie"
	var variant_text := String(variant).to_lower()
	var body_color := Color(0.24, 0.30, 0.23)
	var shadow_color := Color(0.12, 0.15, 0.12)
	var wound_color := Color(0.34, 0.035, 0.025)
	var eye_color := Color(0.86, 0.12, 0.04)
	var size_factor := 1.0
	if variant_text.contains("crawler"):
		size_factor = 0.80
		body_color = Color(0.28, 0.24, 0.16)
	elif variant_text.contains("runner"):
		size_factor = 0.94
		body_color = Color(0.30, 0.34, 0.22)
	elif variant_text.contains("screamer"):
		size_factor = 1.0
		body_color = Color(0.34, 0.22, 0.28)
	elif variant_text.contains("tank"):
		size_factor = 1.08
		body_color = Color(0.20, 0.27, 0.19)
	root.scale = Vector3.ONE * size_factor

	_box(root, "LeftFoot", Vector3(0.24, 0.08, 0.34), Vector3(-0.15, 0.04, -0.025), shadow_color, 0.02, 0.90)
	_box(root, "RightFoot", Vector3(0.24, 0.08, 0.34), Vector3(0.15, 0.04, -0.025), shadow_color, 0.02, 0.90)
	_box(root, "LeftLeg", Vector3(0.25, 0.46, 0.27), Vector3(-0.15, 0.28, 0.0), body_color, 0.0, 0.92)
	_box(root, "RightLeg", Vector3(0.25, 0.46, 0.27), Vector3(0.15, 0.28, 0.0), body_color, 0.0, 0.92)
	_box(root, "Pelvis", Vector3(0.54, 0.25, 0.32), Vector3(0.0, 0.55, 0.0), shadow_color, 0.0, 0.90)
	_box(root, "Torso", Vector3(0.62, 0.56, 0.38), Vector3(0.0, 0.91, 0.0), body_color, 0.0, 0.94)
	_box(root, "RibStripe", Vector3(0.48, 0.07, 0.035), Vector3(0.0, 1.02, -0.205), wound_color, 0.0, 0.76)
	_box(root, "LeftShoulder", Vector3(0.18, 0.15, 0.34), Vector3(-0.37, 1.13, 0.0), shadow_color, 0.0, 0.90)
	_box(root, "RightShoulder", Vector3(0.18, 0.15, 0.34), Vector3(0.37, 1.13, 0.0), shadow_color, 0.0, 0.90)
	_box(root, "LeftArm", Vector3(0.20, 0.52, 0.22), Vector3(-0.40, 0.88, 0.0), body_color, 0.0, 0.94)
	_box(root, "RightArm", Vector3(0.20, 0.52, 0.22), Vector3(0.40, 0.88, 0.0), body_color, 0.0, 0.94)
	_box(root, "Jaw", Vector3(0.30, 0.15, 0.25), Vector3(0.0, 1.31, -0.08), shadow_color, 0.0, 0.92)
	_capsule(root, "Head", 0.20, 0.34, Vector3(0.0, 1.43, 0.0), body_color)
	_box(root, "LeftEye", Vector3(0.055, 0.045, 0.025), Vector3(-0.085, 1.47, -0.19), eye_color, 0.0, 0.25)
	_box(root, "RightEye", Vector3(0.055, 0.045, 0.025), Vector3(0.085, 1.47, -0.19), eye_color, 0.0, 0.25)
	_box(root, "LeftWound", Vector3(0.11, 0.10, 0.025), Vector3(-0.25, 0.98, -0.21), wound_color, 0.0, 0.78)
	_box(root, "RightWound", Vector3(0.10, 0.16, 0.025), Vector3(0.24, 0.76, -0.21), wound_color, 0.0, 0.78)
	root.set_meta("source", "procedural")
	root.set_meta("visual_height", 1.60 * size_factor)
	return root

static func _operator_palette(character_id: StringName) -> Dictionary:
	if String(character_id).to_lower().contains("02"):
		return {
			"dark": Color(0.035, 0.065, 0.090),
			"cloth": Color(0.12, 0.22, 0.28),
			"accent": Color(0.08, 0.45, 0.68),
			"metal": Color(0.28, 0.34, 0.38),
			"skin": Color(0.42, 0.30, 0.24),
			"visor": Color(0.04, 0.22, 0.30),
		}
	return {
		"dark": Color(0.075, 0.040, 0.045),
		"cloth": Color(0.22, 0.15, 0.17),
		"accent": Color(0.78, 0.07, 0.09),
		"metal": Color(0.30, 0.28, 0.29),
		"skin": Color(0.48, 0.34, 0.26),
		"visor": Color(0.19, 0.055, 0.06),
	}

static func _slot_accent(color: Color, slot_index: int) -> Color:
	if slot_index % 2 == 0:
		return color
	return Color(clampf(color.r + 0.10, 0.0, 1.0), clampf(color.g + 0.10, 0.0, 1.0), clampf(color.b + 0.10, 0.0, 1.0), color.a)

static func _box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, color: Color, metallic: float, roughness: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color, metallic, roughness)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.mesh = mesh
	instance.cast_shadow = 1
	parent.add_child(instance)
	return instance

static func _capsule(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.material = _material(color, 0.0, 0.86)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.mesh = mesh
	instance.cast_shadow = 1
	parent.add_child(instance)
	return instance

static func _cylinder(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, color: Color, radial_segments: int = 12) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	mesh.material = _material(color, 0.18, 0.66)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
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
