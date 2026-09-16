extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var characters := load("res://src/assets/ProceduralCharacterModel.gd")
	var weapons := load("res://src/assets/ProceduralWeaponModels.gd")
	var normalizer := load("res://src/assets/ModelNormalizer.gd")
	var catalog := load("res://src/assets/ExternalModelCatalog.gd")
	var animator := load("res://src/assets/ImportedAnimationDriver.gd")
	var holder := Node3D.new()
	root.add_child(holder)
	for config in [catalog.character(&"operator_01"), catalog.character(&"operator_02"), catalog.zombie(&"animated"), catalog.zombie(&"static")]:
		var model := (load(config.path) as PackedScene).instantiate() as Node3D
		holder.add_child(model)
		animator.play_best_pose(model)
		var result: Dictionary = normalizer.normalize_visual(model, holder, 1.69)
		if not _check(result.get("ok", false) and absf(float(result.get("final_height", 0)) - 1.69) < 0.01, "Skinned/static model normalization must match visible height"):
			return
		var bounds: Dictionary = normalizer._visual_bounds(holder, model)
		if not _check(absf(bounds.min.y) < 0.01, "Normalized model must stand on the floor"):
			return
		model.free()
	for id in [&"operator_01", &"operator_02"]:
		var model: Node3D = characters.create_operator(id)
		holder.add_child(model)
		if not _check(model.get_meta("source", "") == "skinned_with_procedural_pose", "Operator must use its supplied skeleton"):
			return
		var skeleton: Skeleton3D = model.get("_skeleton")
		for slot in range(3):
			model.call("equip_visual", slot)
			model.call("animate_pose", 1.0, 0.0, &"idle")
			var gun := model.get_node("HeldWeapon")
			for side in ["Left", "Right"]:
				if slot == 2 and side == "Left":
					continue
				var hand: int = model.get("_bones")[side + "Hand"]
				var wrist := skeleton.global_transform * skeleton.get_bone_global_pose(hand).origin
				if not _check(wrist.distance_to((gun.get_node("Grip" + side) as Node3D).global_position) < 0.035, "Hand must reach weapon grip: %s slot=%d side=%s error=%.3fm" % [id, slot, side, wrist.distance_to((gun.get_node("Grip" + side) as Node3D).global_position)]):
					return
		var leg: int = model.get("_bones")["LeftUpLeg"]
		var resting := skeleton.get_bone_global_pose(leg)
		model.call("animate_pose", 1.2, 4.0, &"run")
		if not _check(not resting.basis.is_equal_approx(skeleton.get_bone_global_pose(leg).basis), "Locomotion must articulate the legs"):
			return
		model.call("animate_pose", 2.0, 0.0, &"crawl")
		var bounds: Dictionary = normalizer._visual_bounds(holder, model.get_node("SkinnedBody"))
		if not _check(bounds.max.y < 0.8 and bounds.min.y > -0.1, "Prone operator must stay low and above the floor: %s %s" % [id, bounds]):
			return
		model.free()
	for id in [&"nxr_rifle_01", &"nxr_pistol_01", &"machete"]:
		var model: Node3D = weapons.create_view_model(id)
		holder.add_child(model)
		var geometry := model.get_node("BatchedGeometry") as MeshInstance3D
		if not _check(geometry.mesh.get_surface_count() >= 3 and geometry.mesh.get_surface_count() <= 12, "Weapon must retain material detail within the draw-call budget"):
			return
		if id == &"nxr_rifle_01":
			var bounds := geometry.mesh.get_aabb()
			if not _check(bounds.position.z < -0.75 and bounds.end.z > 0.43 and bounds.position.y < -0.23, "Batching must retain muzzle, stock and magazine geometry"):
				return
		weapons.add_first_person_hands(model, id)
		if not _check(model.has_node("FirstPersonHands/BatchedGeometry"), "Each first-person weapon must include hands"):
			return
		model.free()
	for kind in [&"walker", &"runner", &"tank", &"screamer", &"crawler"]:
		var model: Node3D = characters.create_zombie(kind)
		holder.add_child(model)
		if not _check(model.get_meta("source", "") == "skinned_semantic_animation", "Infected must use the verified animated rig"):
			return
		var skeleton: Skeleton3D = model.get("_skeleton")
		var left_arm := skeleton.find_bone("LeftArm")
		model.call("set_destroyed_parts", [3, 5])
		var time := 0.0
		for action in [&"walk", &"run", &"attack", &"hurt", &"crawl", &"death"]:
			time += 0.2
			model.call("animate_pose", time, 3.0, action)
			if not _check(skeleton.get_bone_pose_scale(left_arm).length() < 0.01, "Animation must not restore a destroyed limb"):
				return
		model.free()
	var audio := root.get_node("AudioDirector")
	for cue in audio.CUES:
		var stream := load("res://assets/audio/%s.wav" % cue) as AudioStreamWAV
		if not _check(stream != null and stream.get_length() > 0.05 and stream.get_length() < 2.0, "Audio cue is absent or invalid: %s" % cue):
			return
	for name_value in ["last_signal", "quarantine_wind"]:
		var stream := load("res://assets/audio/%s.ogg" % name_value) as AudioStreamOggVorbis
		if not _check(stream != null and stream.get_length() >= 10.0, "Music/ambience stream must decode"):
			return
	if DisplayServer.get_name() == "headless":
		if not _check(not audio.get("_enabled") and audio.get("_world_voices").is_empty(), "Dedicated servers must allocate no audio voices"):
			return
	holder.free()
	await process_frame
	print("NEXORA: DEADFALL presentation assets smoke passed")
	quit(0)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
