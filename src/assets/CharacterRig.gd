class_name DeadfallCharacterRig
extends Node3D

var infected := false
var archetype: StringName = &"walker"
var _weapon_slot := -1
var _weapon: Node3D

func animate_pose(time: float, speed: float, action: StringName = &"idle") -> void:
	var stride := clampf(speed / 4.0, 0.0, 1.0)
	var cycle := time * (6.0 + stride * 4.0)
	var death := action == &"death"
	var crawl := action == &"crawl"
	var body := get_node_or_null("Torso") as Node3D
	if body != null:
		body.rotation.z = sin(time * 1.5) * 0.012
		body.rotation.x = -0.10 if infected else 0.0
		if action == &"hurt":
			body.rotation.z += sin(time * 22.0) * 0.1
	for side in [-1, 1]:
		var prefix := "Left" if side < 0 else "Right"
		var leg := get_node_or_null(prefix + "Leg") as Node3D
		if leg != null:
			leg.rotation.x = sin(cycle + (PI if side < 0 else 0.0)) * stride * 0.48
			var knee := leg.get_node_or_null("Knee") as Node3D
			if knee != null:
				knee.rotation.x = maxf(0.0, -sin(cycle + (PI if side < 0 else 0.0))) * stride * 0.75
		var arm := get_node_or_null(prefix + "Arm") as Node3D
		if arm != null:
			arm.rotation.x = -0.28 if infected else -0.50
			arm.rotation.z = side * (-0.14 if infected else 0.14)
			if infected:
				arm.rotation.x += sin(cycle + side) * stride * 0.22
				if action == &"attack":
					arm.rotation.x = -1.3 + sin(time * 14.0) * 0.4
			elif action == &"attack":
				arm.rotation.x += sin(time * 35.0) * 0.06
	if not infected and is_instance_valid(_weapon):
		_pose_weapon_arms(time, action)
	if crawl:
		rotation.x = -1.43
		position.y = 0.24
	elif death:
		rotation.x = 1.48
		position.y = 0.16
	else:
		rotation.x = 0
		position.y = sin(time * 2.1) * 0.004 + absf(sin(cycle)) * stride * 0.012

func equip_visual(slot: int) -> void:
	if infected or _weapon_slot == slot:
		return
	_weapon_slot = slot
	if is_instance_valid(_weapon):
		_weapon.free()
	var factory = load("res://src/assets/ProceduralWeaponModels.gd")
	_weapon = factory.create_view_model(&"nxr_rifle_01" if slot == 0 else (&"nxr_pistol_01" if slot == 1 else &"machete"))
	_weapon.name = "HeldWeapon"
	_weapon.scale = Vector3.ONE * 0.78
	_weapon.position = Vector3(0.08, 1.13, -0.28)
	_weapon.rotation = Vector3(-0.13, 1.05, 0.03)
	if slot == 1:
		_weapon.position = Vector3(0.10, 1.09, -0.35)
		_weapon.rotation = Vector3(-0.12, 0.32, 0)
	if slot == 2:
		_weapon.rotation = Vector3(-0.20, 0.25, -0.45)
		_weapon.position = Vector3(0.31, 1.02, -0.23)
	add_child(_weapon)

func _pose_weapon_arms(time: float, action: StringName) -> void:
	for side in [-1, 1]:
		if _weapon_slot == 2 and side == -1:
			continue
		var prefix := "Left" if side < 0 else "Right"
		var arm := get_node_or_null(prefix + "Arm") as Node3D
		var grip := _weapon.get_node_or_null("GripLeft" if side < 0 else "GripRight") as Node3D
		if arm == null or grip == null:
			continue
		var elbow := arm.get_node_or_null("Elbow") as Node3D
		if elbow == null:
			continue
		var target: Vector3 = _weapon.transform * grip.position
		if action == &"attack":
			target.z += sin(time * 35.0) * 0.008
		var upper_length := 0.24
		var lower_length := 0.255
		var reach := target - arm.position
		var distance := clampf(reach.length(), 0.06, upper_length + lower_length - 0.002)
		var direction := reach.normalized()
		var pole := Vector3(float(side) * 0.7, -0.6, 0.15)
		pole = (pole - direction * pole.dot(direction)).normalized()
		var along := (upper_length * upper_length + distance * distance - lower_length * lower_length) / (2.0 * distance)
		var bend := sqrt(maxf(0.0, upper_length * upper_length - along * along))
		var elbow_at := arm.position + direction * along + pole * bend
		arm.quaternion = Quaternion(Vector3.DOWN, (elbow_at - arm.position).normalized())
		var lower_direction := arm.basis.inverse() * (target - elbow_at).normalized()
		elbow.quaternion = Quaternion(Vector3.DOWN, lower_direction.normalized())
		var hand := elbow.get_node_or_null("Hand") as Node3D
		if hand != null:
			hand.basis = (arm.basis * elbow.basis).inverse() * _weapon.basis.orthonormalized()
