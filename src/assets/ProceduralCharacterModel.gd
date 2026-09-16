class_name DeadfallProceduralCharacterModel
extends RefCounted
const M = preload("res://src/assets/PresentationMesh.gd")
const Rig = preload("res://src/assets/CharacterRig.gd")

static func create_operator(character_id: StringName = &"operator_01", slot_index: int = 0) -> Node3D:
	var root := preload("res://src/assets/SkinnedOperatorRig.gd").new()
	root.character_id = character_id
	root.name = "TacticalOperator"
	root.set_meta("character_id", character_id)
	root.set_meta("slot", slot_index)
	root.set_meta("visual_height", 1.69)
	return root

static func create_fallback_operator(character_id: StringName = &"operator_01", slot_index: int = 0) -> Node3D:
	var root := Rig.new()
	root.name = "ProceduralOperator"
	var mara := character_id == &"operator_01"
	var cloth := M.material(Color("405052") if mara else Color("354651"))
	var armor := M.material(Color("26363b") if mara else Color("354046"), 0.12, 0.78)
	var dark := M.material(Color("172329"), 0.1, 0.65)
	var accent := M.material(Color("c78d55") if mara else Color("53b3ce"), 0.05, 0.82)
	var skin := M.material(Color("aa7860") if mara else Color("77533f"))
	var steel := M.material(Color("8c9b9b"), 0.7, 0.34)
	_build_limbs(root, cloth, dark, skin, false)
	M.box(root, "Pelvis", Vector3(0.34,0.19,0.25), Vector3(0,0.87,0), cloth)
	var torso := M.joint(root, "Torso", Vector3(0,1.17,0))
	var jacket := M.capsule(torso,"Jacket",0.22,0.48,Vector3.ZERO,cloth)
	jacket.scale.z = 0.62
	M.box(torso,"PlateCarrier",Vector3(0.40,0.38,0.11),Vector3(0,0.02,-0.16),armor)
	M.box(torso,"ChestInsert",Vector3(0.29,0.16,0.045),Vector3(0,0.10,-0.235),dark)
	M.box(torso,"Callsign",Vector3(0.12,0.038,0.02),Vector3(-0.07,0.12,-0.26),accent)
	for i in range(3):
		M.box(torso,"MagazinePouch%d"%i,Vector3(0.09,0.14,0.055),Vector3(-0.105+i*0.105,-0.09,-0.245),cloth)
		M.box(torso,"PouchFlap%d"%i,Vector3(0.095,0.033,0.065),Vector3(-0.105+i*0.105,-0.035,-0.25),dark)
	for side in [-1,1]:
		M.box(torso,"Strap%d"%side,Vector3(0.053,0.37,0.043),Vector3(side*0.155,0.10,-0.15),dark)
		M.box(torso,"Buckle%d"%side,Vector3(0.062,0.04,0.052),Vector3(side*0.155,0.12,-0.17),steel)
	M.box(root,"Belt",Vector3(0.38,0.055,0.29),Vector3(0,0.94,0),dark)
	M.box(root,"BeltBuckle",Vector3(0.055,0.045,0.03),Vector3(0,0.94,-0.16),steel)
	M.box(root,"UtilityPouch",Vector3(0.10,0.16,0.11),Vector3(-0.23,0.89,0.02),armor)
	M.box(root,"Holster",Vector3(0.09,0.24,0.10),Vector3(0.23,0.77,0.02),dark)
	M.capsule(root,"Neck",0.062,0.14,Vector3(0,1.43,0),skin)
	var head := M.joint(root,"Head",Vector3(0,1.56,0))
	var skull := M.capsule(head,"Face",0.102,0.23,Vector3.ZERO,skin)
	skull.scale.z = 0.88
	M.box(head,"Mask",Vector3(0.17,0.08,0.06),Vector3(0,-0.047,-0.075),dark)
	if mara:
		var hood := M.capsule(head,"Hood",0.116,0.23,Vector3(0,0.013,0.035),cloth)
		hood.scale.z = 0.8
		M.box(head,"GoggleFrame",Vector3(0.19,0.059,0.045),Vector3(0,0.028,-0.084),dark)
		for side in [-1,1]:
			M.box(head,"Lens%d"%side,Vector3(0.063,0.029,0.012),Vector3(side*0.049,0.03,-0.113),M.material(Color("9bdaed"),0.5,0.2,0.22))
		M.box(root,"ScarfCollar",Vector3(0.23,0.065,0.20),Vector3(0,1.415,-0.005),accent)
		var scarf := M.box(torso,"ScarfTail",Vector3(0.08,0.14,0.025),Vector3(-0.07,0.18,-0.185),accent)
		scarf.rotation.z = -0.20
	else:
		var helmet := M.capsule(head,"Helmet",0.119,0.24,Vector3(0,0.045,0.02),armor)
		helmet.scale.y = 0.68
		M.box(head,"Visor",Vector3(0.19,0.06,0.045),Vector3(0,0.02,-0.1),M.material(Color("377e8f"),0.65,0.17))
		M.box(head,"HelmetMount",Vector3(0.05,0.06,0.04),Vector3(0,0.12,-0.06),steel)
		M.capsule(head,"LeftHeadset",0.052,0.10,Vector3(-0.12,-0.01,0.015),dark)
	M.box(torso,"Backpack",Vector3(0.29,0.36,0.15),Vector3(0,0.0,0.18),cloth)
	M.box(torso,"Radio",Vector3(0.055,0.13,0.055),Vector3(0.19,0.16,0.10),dark)
	M.cylinder(torso,"Antenna",0.006,0.19,Vector3(0.19,0.29,0.10),steel)
	M.box(root,"SquadStripe",Vector3(0.12,0.04,0.022),Vector3(-0.27,1.30,0),accent)
	root.set_meta("source","procedural")
	root.set_meta("visual_height",1.69)
	root.set_meta("character_id",character_id)
	root.set_meta("slot",slot_index)
	root.equip_visual(0)
	root.animate_pose(0,0)
	return root

static func _build_limbs(root: Node3D, cloth: Material, armor: Material, skin: Material, infected: bool) -> void:
	for side in [-1,1]:
		var prefix := "Left" if side<0 else "Right"
		var leg := M.joint(root,prefix+"Leg",Vector3(side*0.115,0.87,0))
		M.capsule(leg,"Thigh",0.091,0.39,Vector3(0,-0.18,0),cloth)
		var knee := M.joint(leg,"Knee",Vector3(0,-0.37,0))
		M.capsule(knee,"Shin",0.071,0.35,Vector3(0,-0.17,0),cloth)
		M.box(knee,"Kneepad",Vector3(0.13,0.12,0.06),Vector3(0,-0.03,-0.072),armor)
		M.box(knee,"Boot",Vector3(0.15,0.12,0.25),Vector3(0,-0.43,-0.045),armor)
		var arm := M.joint(root,prefix+"Arm",Vector3(side*0.265,1.34,0))
		M.capsule(arm,"UpperArm",0.067,0.27,Vector3(0,-0.11,0),cloth)
		if not infected:
			M.box(arm,"ShoulderPlate",Vector3(0.13,0.13,0.18),Vector3(side*0.016,-0.025,0),armor)
		var elbow := M.joint(arm,"Elbow",Vector3(0,-0.24,0))
		elbow.rotation.x = -0.82 if not infected else -0.20
		M.capsule(elbow,"Forearm",0.052,0.25,Vector3(0,-0.115,0),skin if infected else cloth)
		M.box(elbow,"Hand",Vector3(0.085,0.10,0.10),Vector3(0,-0.255,0),skin if infected else armor)

static func create_zombie(variant: StringName = &"walker") -> Node3D:
	var root := preload("res://src/assets/SkinnedZombieRig.gd").new()
	root.archetype = variant
	root.name = "TacticalInfected"
	root.set_meta("visual_height", 1.64)
	return root

static func create_fallback_zombie(variant: StringName = &"walker") -> Node3D:
	var root := Rig.new()
	root.name = "ProceduralZombie"
	root.infected = true
	root.archetype = variant
	var kind := String(variant).to_lower()
	var skin_color := Color("818b65")
	if kind.contains("runner"):
		skin_color = Color("9a8a72")
	elif kind.contains("screamer"):
		skin_color = Color("a89995")
	var skin := M.material(skin_color,0,0.96)
	var cloth := M.material(Color("43564e"),0,0.94)
	var dark := M.material(Color("29312a"),0,0.9)
	var wound := M.material(Color("692e28"),0,0.78)
	_build_limbs(root,cloth,dark,skin,true)
	M.box(root,"Pelvis",Vector3(0.32,0.18,0.26),Vector3(0,0.85,0),dark)
	var torso := M.joint(root,"Torso",Vector3(0,1.17,0))
	var chest := M.capsule(torso,"Chest",0.21,0.46,Vector3.ZERO,skin)
	chest.scale.z = 0.66
	M.box(torso,"TornShirt",Vector3(0.34,0.22,0.035),Vector3(-0.04,0.01,-0.14),cloth)
	for index in range(4):
		var rib := M.box(torso,"ExposedRib%d"%index,Vector3(0.15,0.022,0.03),Vector3(0.08,0.06-index*0.042,-0.18),wound)
		rib.rotation.z = -0.20
	M.capsule(root,"Neck",0.055,0.10,Vector3(0,1.42,-0.025),skin)
	var head := M.joint(root,"Head",Vector3(0.015,1.53,-0.06))
	var skull := M.capsule(head,"Skull",0.108,0.22,Vector3.ZERO,skin)
	skull.scale.z=0.88
	M.box(head,"Jaw",Vector3(0.12,0.08,0.10),Vector3(0,-0.09,-0.04),wound)
	for side in [-1,1]:
		M.box(head,"EyeSocket%d"%side,Vector3(0.065,0.055,0.02),Vector3(side*0.049,0.021,-0.092),dark)
		M.box(head,"Eye%d"%side,Vector3(0.024,0.018,0.014),Vector3(side*0.049,0.023,-0.105),M.material(Color("f6b267"),0,0.4,0.6))
	for i in range(4):
		M.box(head,"Tooth%d"%i,Vector3(0.016,0.022,0.01),Vector3(-0.033+i*0.022,-0.06,-0.10),M.material(Color("bfb38f")))
	if kind.contains("tank"):
		M.box(torso,"InfectedArmor",Vector3(0.44,0.29,0.12),Vector3(0,0.0,-0.16),dark)
		root.scale = Vector3(1.2,1.0,1.15)
	elif kind.contains("screamer"):
		M.capsule(root,"ThroatSac",0.084,0.22,Vector3(0,1.36,-0.11),wound)
	elif kind.contains("runner"):
		root.scale = Vector3(0.9,1.0,0.94)
	root.set_meta("source","procedural")
	root.set_meta("visual_height",1.64)
	root.animate_pose(0,0)
	return root
