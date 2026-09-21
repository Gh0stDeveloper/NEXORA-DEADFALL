class_name DeadfallSkinnedOperatorRig
extends Node3D

const Catalog = preload("res://src/assets/ExternalModelCatalog.gd")
const Normalizer = preload("res://src/assets/ModelNormalizer.gd")
const Animator = preload("res://src/assets/ImportedAnimationDriver.gd")
const Weapons = preload("res://src/assets/ProceduralWeaponModels.gd")
const M = preload("res://src/assets/PresentationMesh.gd")
static var _uniform_meshes: Dictionary = {}
static var _normalized_transforms: Dictionary = {}

var character_id: StringName = &"operator_01"
var _skeleton: Skeleton3D
var _rest: Array[Transform3D] = []
var _bones: Dictionary = {}
var _attachments: Array[Dictionary] = []
var _weapon: Node3D
var _slot := -1
var _fallback: Node3D
var _head_bounds := AABB(Vector3(-0.11, 1.47, -0.1), Vector3(0.22, 0.22, 0.22))

func _ready() -> void:
	var config := Catalog.character(&"operator_02" if character_id == &"operator_01" else character_id)
	if not Catalog.model_exists(config):
		_use_fallback()
		return
	var model := (load(config.path) as PackedScene).instantiate() as Node3D
	model.name = "SkinnedBody"
	# The supplied models face +Z; every runtime visual uses forward -Z.
	model.rotation.y = PI
	add_child(model)
	Animator.play_best_pose(model)
	for player in model.find_children("*", "AnimationPlayer", true, false):
		(player as AnimationPlayer).pause()
	_skeleton = model.find_child("*Skeleton*", true, false) as Skeleton3D
	var normalized := _skeleton != null
	if normalized and _normalized_transforms.has(character_id):
		model.transform = _normalized_transforms[character_id]
	elif normalized:
		normalized = bool(Normalizer.normalize_visual(model, self, 1.69).get("ok", false))
		if normalized:
			_normalized_transforms[character_id] = model.transform
	if not normalized:
		model.free()
		_skeleton = null
		_use_fallback()
		return
	for index in range(_skeleton.get_bone_count()):
		_rest.append(_skeleton.get_bone_pose(index))
		var bone_name := String(_skeleton.get_bone_name(index)).trim_prefix("mixamorig_").trim_prefix("mixamorig:")
		_bones[bone_name] = index
	for required in ["Hips", "Spine2", "Head", "LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand", "LeftUpLeg", "RightUpLeg"]:
		if not _bones.has(required):
			model.free()
			_skeleton = null
			_use_fallback()
			return
	_color_uniform(model)
	_add_equipment()
	equip_visual(0)
	animate_pose(0, 0)
	set_meta("source", "skinned_with_procedural_pose")

func _use_fallback() -> void:
	_fallback = load("res://src/assets/ProceduralCharacterModel.gd").create_fallback_operator(character_id)
	add_child(_fallback)
	set_meta("source", "procedural_fallback")

func _color_uniform(model: Node3D) -> void:
	# Vertex colors are baked once. No texture downloads or per-frame skinning
	# on the CPU: Godot continues to deform the original mesh on the GPU.
	var female := character_id == &"operator_01"
	var fabric := Color("64746a") if female else Color("596c7b")
	var trousers := Color("46504a") if female else Color("394754")
	var boots := Color("293235")
	var skin := Color("a9785b") if female else Color("856049")
	for value in model.find_children("*", "MeshInstance3D", true, false):
		var instance := value as MeshInstance3D
		var cache_key := "%s:%s" % [character_id, instance.name]
		if _uniform_meshes.has(cache_key):
			instance.mesh = _uniform_meshes[cache_key][0]
			instance.material_override = _uniform_meshes[cache_key][1]
			_head_bounds = _uniform_meshes[cache_key][2]
			continue
		if female:
			preload("res://src/assets/FemaleOperatorDesign.gd").reshape_body(instance, self)
		var points := Normalizer._skinned_points(instance, self)
		if points.is_empty():
			continue
		var head_min := Vector3(INF, INF, INF)
		var head_max := -head_min
		for point in points:
			if point.y > 1.47:
				head_min = head_min.min(point)
				head_max = head_max.max(point)
		if head_min.is_finite():
			_head_bounds = AABB(head_min, head_max - head_min)
		var painted := ArrayMesh.new()
		var offset := 0
		for surface in range(instance.mesh.get_surface_count()):
			var arrays := instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors := PackedColorArray()
			colors.resize(vertices.size())
			for i in range(vertices.size()):
				var p := points[offset + i]
				var color := fabric
				if p.y < 0.18:
					color = boots
				elif p.y < 0.86:
					color = trousers
				elif p.y > 1.48:
					color = skin
				elif absf(p.x) > 0.24 and p.y < 1.09:
					color = boots
				if p.y > 0.2 and p.y < 1.46:
					var pattern := sin(p.x * 49 + sin(p.y * 31)) * cos(p.z * 53 + p.y * 39)
					color = color.darkened(0.22) if pattern > 0.12 else color.lightened(0.025)
				colors[i] = color
			arrays[Mesh.ARRAY_COLOR] = colors
			painted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			offset += vertices.size()
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.92
		instance.mesh = painted
		instance.material_override = material
		_uniform_meshes[cache_key] = [painted, material, _head_bounds]

func _equipment_group(bone: String) -> Node3D:
	var group := Node3D.new()
	group.name = bone + "Equipment"
	add_child(group)
	_attachments.append({"node": group, "bone": _bones[bone], "inverse": _bone_transform(_bones[bone]).affine_inverse()})
	return group

func _add_equipment() -> void:
	var female := character_id == &"operator_01"
	var armor := M.material(Color("33454a"), 0.1, 0.82)
	var dark := M.material(Color("263338"), 0.05, 0.85)
	var accent := M.material(Color("c89a5e") if female else Color("58a9b8"), 0.1, 0.65)
	var glass := M.material(Color("4b91a3"), 0.35, 0.24)
	var chest := _equipment_group("Spine2")
	var center := _bone_transform(_bones.Spine2).origin + Vector3(0, 0.045, -0.035)
	M.box(chest, "PlateCarrier", Vector3(0.34, 0.31, 0.12), center + Vector3(0, 0, -0.095), armor)
	M.box(chest, "NamePatch", Vector3(0.12, 0.036, 0.012), center + Vector3(-0.06, 0.09, -0.162), accent)
	for i in range(3):
		M.box(chest, "MagazinePouch%d" % i, Vector3(0.082, 0.12, 0.055), center + Vector3(-0.09 + i * 0.09, -0.065, -0.178), dark)
	for side in [-1, 1]:
		M.box(chest, "ShoulderStrap%d" % side, Vector3(0.047, 0.19, 0.08), center + Vector3(side * 0.132, 0.075, -0.075), dark)
	M.box(chest, "Radio", Vector3(0.048, 0.10, 0.045), center + Vector3(0.15, 0.13, -0.15), dark)
	M.cylinder(chest, "Antenna", 0.004, 0.14, center + Vector3(0.15, 0.24, -0.15), armor)
	M.box(chest, "Pack", Vector3(0.27, 0.32, 0.12), center + Vector3(0, -0.015, 0.18), armor)
	M.combine_static(chest)
	var head := _equipment_group("Head")
	# Fit to the deformed head surface: a neck bone alone does not locate the
	# face on the two supplied rigs (their bind poses have different offsets).
	var head_at := _head_bounds.get_center()
	var radius := maxf(0.105, _head_bounds.size.x * 0.52)
	if female:
		preload("res://src/assets/FemaleOperatorDesign.gd").add_head(head, head_at, _head_bounds.size)
	else:
		var helmet := M.capsule(head, "Helmet", radius, radius * 2, Vector3(head_at.x, _head_bounds.end.y - 0.055, head_at.z + 0.008), armor)
		helmet.scale = Vector3(1, 0.62, maxf(1.0, _head_bounds.size.z / (radius * 2)))
		var face := Vector3(head_at.x, head_at.y, _head_bounds.position.z - 0.015)
		M.box(head, "Respirator", Vector3(0.15, 0.09, 0.065), face + Vector3(0, -0.04, 0), dark)
		M.box(head, "GoggleFrame", Vector3(0.195, 0.062, 0.038), face + Vector3(0, 0.035, -0.005), dark)
		for side in [-1, 1]:
			M.box(head, "Lens%d" % side, Vector3(0.07, 0.036, 0.01), face + Vector3(side * 0.048, 0.036, -0.028), glass)
			M.capsule(head, "Headset%d" % side, 0.035, 0.07, head_at + Vector3(side * radius, 0, 0.008), dark)
	M.combine_static(head)
	var hips := _equipment_group("Hips")
	var hip_at := _bone_transform(_bones.Hips).origin
	M.box(hips, "Belt", Vector3(0.32, 0.055, 0.23), hip_at + Vector3(0, 0.035, 0), dark)
	M.box(hips, "Buckle", Vector3(0.046, 0.04, 0.014), hip_at + Vector3(0, 0.035, -0.124), accent)
	M.box(hips, "UtilityPouch", Vector3(0.085, 0.13, 0.085), hip_at + Vector3(-0.17, -0.065, 0.015), armor)
	M.combine_static(hips)

func _bone_transform(index: int) -> Transform3D:
	return global_transform.affine_inverse() * _skeleton.global_transform * _skeleton.get_bone_global_pose(index)

func equip_visual(slot: int) -> void:
	if _fallback != null:
		_fallback.call("equip_visual", slot)
		return
	if _skeleton == null or _slot == slot:
		return
	_slot = slot
	if is_instance_valid(_weapon):
		_weapon.free()
	_weapon = Weapons.create_view_model(&"nxr_rifle_01" if slot == 0 else (&"nxr_pistol_01" if slot == 1 else &"machete"))
	_weapon.name = "HeldWeapon"
	_weapon.scale = Vector3.ONE * 0.78
	_weapon.position = Vector3(0.08, 1.09, -0.25)
	_weapon.rotation = Vector3(-0.13, 1.05, 0.03)
	if slot == 1:
		_weapon.position = Vector3(0.09, 1.10, -0.32)
		_weapon.rotation = Vector3(-0.12, 0.32, 0)
	elif slot == 2:
		_weapon.position = Vector3(0.31, 1.02, -0.23)
		_weapon.rotation = Vector3(-0.20, 0.25, -0.45)
	add_child(_weapon)

func animate_pose(time: float, speed: float, action: StringName = &"idle") -> void:
	if _fallback != null:
		_fallback.call("animate_pose", time, speed, action)
		return
	if _skeleton == null:
		return
	for index in range(_rest.size()):
		_skeleton.set_bone_pose(index, _rest[index])
	var stride := clampf(speed / 4.0, 0, 1)
	var cycle := time * (6 + stride * 4)
	for side in ["Left", "Right"]:
		var phase: float = cycle + (PI if side == "Left" else 0)
		_rotate_bone(side + "UpLeg", Vector3.RIGHT, sin(phase) * stride * 0.43)
		_rotate_bone(side + "Leg", Vector3.RIGHT, maxf(0, -sin(phase)) * stride * 0.60)
	_rotate_bone("Spine2", Vector3.FORWARD, sin(time * 1.4) * 0.012)
	if _weapon != null:
		for side in ["Left", "Right"]:
			if _slot == 2 and side == "Left":
				continue
			var marker := _weapon.get_node("Grip" + side) as Node3D
			var target := marker.global_position
			if action == &"attack":
				target += global_basis * Vector3(0, 0, sin(time * 35) * 0.007)
			_solve_arm(side, target)
	for attachment in _attachments:
		(attachment.node as Node3D).transform = _bone_transform(attachment.bone) * (attachment.inverse as Transform3D)
	if action == &"crawl":
		rotation.x = -1.43
		position.y = 0.37
	elif action == &"death":
		rotation.x = 1.48
		position.y = 0.17
	else:
		rotation.x = 0
		position.y = sin(time * 2.1) * 0.003 + absf(sin(cycle)) * stride * 0.012

func _rotate_bone(bone_name: String, axis: Vector3, angle: float) -> void:
	if not _bones.has(bone_name):
		return
	var index: int = _bones[bone_name]
	var pose := _skeleton.get_bone_global_pose(index)
	var skeleton_axis := _skeleton.global_basis.orthonormalized().inverse() * global_basis.orthonormalized() * axis
	pose.basis = Basis(skeleton_axis.normalized(), angle) * pose.basis
	_skeleton.set_bone_global_pose(index, pose)

func _solve_arm(side: String, target_world: Vector3) -> void:
	var upper: int = _bones[side + "Arm"]
	var lower: int = _bones[side + "ForeArm"]
	var hand: int = _bones[side + "Hand"]
	var shoulder := _skeleton.get_bone_global_pose(upper).origin
	var elbow := _skeleton.get_bone_global_pose(lower).origin
	var wrist := _skeleton.get_bone_global_pose(hand).origin
	var target := _skeleton.to_local(target_world)
	var upper_length := shoulder.distance_to(elbow)
	var lower_length := elbow.distance_to(wrist)
	var reach := target - shoulder
	var distance := clampf(reach.length(), upper_length * 0.1, upper_length + lower_length - 0.001)
	var direction := reach.normalized()
	var pole := _skeleton.global_basis.orthonormalized().inverse() * global_basis.orthonormalized() * Vector3(-0.7 if side == "Left" else 0.7, -0.6, 0.15)
	pole = (pole - direction * pole.dot(direction)).normalized()
	var along := (upper_length * upper_length + distance * distance - lower_length * lower_length) / (2 * distance)
	var bend := sqrt(maxf(0, upper_length * upper_length - along * along))
	var elbow_at := shoulder + direction * along + pole * bend
	var upper_pose := _skeleton.get_bone_global_pose(upper)
	upper_pose.basis = Basis(Quaternion((elbow - shoulder).normalized(), (elbow_at - shoulder).normalized())) * upper_pose.basis
	_skeleton.set_bone_global_pose(upper, upper_pose)
	elbow = _skeleton.get_bone_global_pose(lower).origin
	wrist = _skeleton.get_bone_global_pose(hand).origin
	var lower_pose := _skeleton.get_bone_global_pose(lower)
	lower_pose.basis = Basis(Quaternion((wrist - elbow).normalized(), (target - elbow).normalized())) * lower_pose.basis
	_skeleton.set_bone_global_pose(lower, lower_pose)
