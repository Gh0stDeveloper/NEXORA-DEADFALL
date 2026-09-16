class_name DeadfallProceduralWeaponModels
extends RefCounted
const M = preload("res://src/assets/PresentationMesh.gd")

static func create_view_model(weapon_id: StringName) -> Node3D:
	var id := String(weapon_id).to_lower()
	var root: Node3D
	if id == "machete" or id.contains("melee"):
		root = _create_machete()
	elif id.contains("pistol") or id.contains("sidearm"):
		root = _create_pistol()
	else:
		root = _create_rifle()
	root.set_meta("source", "procedural")
	root.set_meta("weapon_id", weapon_id)
	var right := M.joint(root, "GripRight", Vector3(0,-0.11,0.12))
	var left := M.joint(root, "GripLeft", Vector3(0,-0.075,-0.35))
	if id.contains("pistol") or id.contains("sidearm"):
		right.position = Vector3(0,-0.11,0.005)
		left.position = Vector3(-0.055,-0.10,-0.025)
	elif id == "machete" or id.contains("melee"):
		right.position = Vector3(0,-0.10,0)
		left.position = right.position
	M.combine_static(root, ["MuzzleFlash"])
	return root

static func _create_rifle() -> Node3D:
	var root := Node3D.new()
	root.name = "ProceduralRifle"
	var steel := M.material(Color("65787c"),0.8,0.3)
	var body := M.material(Color("424f50"),0.65,0.4)
	var dark := M.material(Color("35464d"),0.2,0.68)
	var accent := M.material(Color("bf8b49"),0.5,0.4)
	M.box(root,"Receiver",Vector3(0.12,0.14,0.37),Vector3.ZERO,body)
	M.box(root,"Stock",Vector3(0.09,0.13,0.24),Vector3(0,-0.025,0.29),dark)
	M.box(root,"StockPad",Vector3(0.10,0.16,0.035),Vector3(0,-0.025,0.42),dark)
	M.box(root,"CheekRest",Vector3(0.10,0.055,0.16),Vector3(0,0.06,0.29),body)
	M.box(root,"Handguard",Vector3(0.115,0.12,0.30),Vector3(0,0.015,-0.32),body)
	M.cylinder(root,"Barrel",0.014,0.30,Vector3(0,0.025,-0.57),steel,true)
	M.cylinder(root,"MuzzleBrake",0.024,0.067,Vector3(0,0.025,-0.73),dark,true)
	M.cylinder(root,"Bore",0.013,0.007,Vector3(0,0.025,-0.767),M.material(Color.BLACK),true)
	var mag := M.box(root,"Magazine",Vector3(0.068,0.20,0.13),Vector3(0,-0.155,-0.075),dark)
	mag.rotation.x = -0.13
	var grip := M.box(root,"PistolGrip",Vector3(0.065,0.17,0.08),Vector3(0,-0.145,0.12),dark)
	grip.rotation.x = -0.25
	M.box(root,"TriggerGuard",Vector3(0.07,0.022,0.14),Vector3(0,-0.12,0.05),steel)
	M.box(root,"Trigger",Vector3(0.018,0.062,0.018),Vector3(0,-0.085,0.06),steel)
	for i in range(7):
		M.box(root,"Rail%d"%i,Vector3(0.08,0.018,0.024),Vector3(0,0.09,-0.39+i*0.057),dark)
		for side in [-1,1]:
			M.box(root,"Vent%d_%d"%[side,i],Vector3(0.006,0.035,0.024),Vector3(side*0.059,0.02,-0.44+i*0.045),dark)
	M.box(root,"EjectionPort",Vector3(0.007,0.04,0.12),Vector3(0.061,0.02,0.01),dark)
	M.box(root,"Bolt",Vector3(0.026,0.017,0.07),Vector3(0.074,0.02,0.02),steel)
	M.box(root,"SightBase",Vector3(0.08,0.04,0.12),Vector3(0,0.12,0.035),steel)
	for side in [-1,1]:
		M.box(root,"OpticFrame%d"%side,Vector3(0.015,0.073,0.05),Vector3(side*0.036,0.165,0.035),dark)
	M.box(root,"OpticTop",Vector3(0.085,0.015,0.05),Vector3(0,0.207,0.035),dark)
	M.box(root,"OpticLens",Vector3(0.060,0.053,0.005),Vector3(0,0.168,0.048),M.material(Color("31707b"),0.65,0.2))
	M.box(root,"Reticle",Vector3(0.005,0.005,0.007),Vector3(0,0.17,0.052),M.material(Color("f3ac62"),0,0.4,1.0))
	M.box(root,"SerialPlate",Vector3(0.004,0.025,0.072),Vector3(0.065,-0.031,-0.045),accent)
	M.box(root,"ForeGrip",Vector3(0.055,0.12,0.065),Vector3(0,-0.095,-0.35),dark)
	for i in range(3):
		M.box(root,"MagazineRib%d"%i,Vector3(0.072,0.012,0.115),Vector3(0,-0.12-i*0.047,-0.07),body)
	_muzzle(root,Vector3(0,0.025,-0.79))
	return root

static func _create_pistol() -> Node3D:
	var root := Node3D.new()
	root.name = "ProceduralPistol"
	var steel := M.material(Color("76878a"),0.75,0.32)
	var dark := M.material(Color("35454d"),0.20,0.60)
	M.box(root,"Slide",Vector3(0.075,0.074,0.27),Vector3(0,0.03,-0.08),steel)
	M.box(root,"Frame",Vector3(0.065,0.056,0.22),Vector3(0,-0.03,-0.07),dark)
	var grip := M.box(root,"Grip",Vector3(0.07,0.16,0.10),Vector3(0,-0.11,0.005),dark)
	grip.rotation.x=-0.25
	M.box(root,"TriggerGuard",Vector3(0.057,0.016,0.095),Vector3(0,-0.095,-0.082),steel)
	M.box(root,"Trigger",Vector3(0.012,0.04,0.015),Vector3(0,-0.065,-0.073),dark)
	M.cylinder(root,"Barrel",0.018,0.028,Vector3(0,0.025,-0.227),dark,true)
	M.cylinder(root,"Bore",0.009,0.005,Vector3(0,0.025,-0.244),M.material(Color.BLACK),true)
	for i in range(5):
		for side in [-1,1]:
			M.box(root,"Serration%d_%d"%[side,i],Vector3(0.003,0.043,0.008),Vector3(side*0.038,0.035,0.025-i*0.014),dark)
	M.box(root,"FrontSight",Vector3(0.012,0.022,0.018),Vector3(0,0.078,-0.19),dark)
	for side in [-1,1]:
		M.box(root,"RearSight%d"%side,Vector3(0.014,0.022,0.018),Vector3(side*0.024,0.078,0.035),dark)
	_muzzle(root,Vector3(0,0.025,-0.26))
	return root

static func _create_machete() -> Node3D:
	var root := Node3D.new()
	root.name = "ProceduralMachete"
	var steel := M.material(Color("9aabb0"),0.86,0.28)
	var edge := M.material(Color("e4eced"),0.88,0.2)
	var dark := M.material(Color("28363d"),0.05,0.85)
	# Tapered blade silhouette with an angled, widened cutting tip.
	var blade := M.box(root,"BladeCore",Vector3(0.067,0.43,0.012),Vector3(0,0.24,0),steel)
	blade.rotation.z = -0.025
	var tip := M.box(root,"BladeTip",Vector3(0.065,0.11,0.012),Vector3(-0.006,0.48,0),steel)
	tip.rotation.z = -0.27
	M.box(root,"BladeEdge",Vector3(0.010,0.43,0.010),Vector3(-0.034,0.25,-0.002),edge)
	M.box(root,"Guard",Vector3(0.13,0.024,0.052),Vector3.ZERO,dark)
	M.box(root,"Handle",Vector3(0.054,0.17,0.042),Vector3(0,-0.10,0),dark)
	for i in range(6):
		M.box(root,"GripWrap%d"%i,Vector3(0.058,0.009,0.048),Vector3(0,-0.045-i*0.024,0),M.material(Color("7e6249")))
	M.box(root,"Pommel",Vector3(0.064,0.024,0.052),Vector3(0,-0.19,0),steel)
	return root

static func _muzzle(root: Node3D, at: Vector3) -> void:
	var flash := M.box(root,"MuzzleFlash",Vector3(0.075,0.06,0.14),at,M.material(Color("ffd078"),0,0.4,3.0))
	flash.visible = false
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func add_first_person_hands(model: Node3D, weapon_id: StringName) -> void:
	var glove := M.material(Color("39484c"),0.05,0.8)
	var sleeve := M.material(Color("536366"),0,0.94)
	var right_at := (model.get_node("GripRight") as Node3D).position
	var hands := Node3D.new()
	hands.name = "FirstPersonHands"
	model.add_child(hands)
	var wrist := M.capsule(hands,"RightSleeve",0.052,0.22,right_at + Vector3(0.025,-0.10,0.07),sleeve)
	wrist.rotation.x = -0.65
	M.box(hands,"RightGlove",Vector3(0.079,0.08,0.078),right_at + Vector3(0.015,0,0),glove)
	if weapon_id != &"machete":
		var left_at := (model.get_node("GripLeft") as Node3D).position
		var left := M.capsule(hands,"LeftSleeve",0.05,0.30,left_at + Vector3(-0.08,-0.1,0.12),sleeve)
		left.rotation.z = -0.72
		M.box(hands,"LeftGlove",Vector3(0.082,0.08,0.10),left_at + Vector3(-0.028,0,0),glove)
	M.combine_static(hands)
