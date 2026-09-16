class_name DeadfallSkinnedZombieRig
extends Node3D

const Catalog = preload("res://src/assets/ExternalModelCatalog.gd")
const Normalizer = preload("res://src/assets/ModelNormalizer.gd")
const Animator = preload("res://src/assets/ImportedAnimationDriver.gd")
const PART_BONES := {0: "Head", 3: "LeftArm", 4: "RightArm", 5: "LeftUpLeg", 6: "RightUpLeg"}
static var _normalized_transform := Transform3D.IDENTITY
static var _normalization_cached := false
var archetype: StringName = &"walker"
var _skeleton: Skeleton3D
var _player: AnimationPlayer
var _fallback: Node3D
var _semantic: StringName = &""
var _destroyed: Array = []
var _last_time := -1.0
var _elapsed := 0.0
var _base_scales: Dictionary = {}

func _ready() -> void:
	var config := Catalog.zombie(&"animated")
	if not Catalog.model_exists(config):
		_use_fallback()
		return
	var model := (load(config.path) as PackedScene).instantiate() as Node3D
	model.name = "SkinnedInfected"
	model.rotation.y = PI
	add_child(model)
	Animator.play_named(model, &"Zombie|ZombieIdle", &"idle", 0.0)
	_skeleton = model.find_child("*Skeleton*", true, false) as Skeleton3D
	_player = model.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
	var normalized := _skeleton != null and _player != null
	if normalized and _normalization_cached:
		model.transform = _normalized_transform
	elif normalized:
		normalized = bool(Normalizer.normalize_visual(model, self, 1.64).get("ok", false))
		if normalized:
			_normalized_transform = model.transform
			_normalization_cached = true
	if not normalized:
		model.free()
		_skeleton = null
		_player = null
		_use_fallback()
		return
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for part in PART_BONES:
		var index := _skeleton.find_bone(PART_BONES[part])
		if index >= 0:
			_base_scales[index] = _skeleton.get_bone_pose_scale(index)
	var tint := Color("94a490")
	if String(archetype).contains("runner"):
		tint = Color("b5a297")
		model.scale *= Vector3(0.91, 1, 0.93)
	elif String(archetype).contains("tank"):
		tint = Color("7f8996")
		model.scale *= Vector3(1.30, 1.08, 1.2)
	elif String(archetype).contains("screamer"):
		tint = Color("bdb1ad")
	for value in model.find_children("*", "MeshInstance3D", true, false):
		var instance := value as MeshInstance3D
		var original := instance.get_active_material(0) as StandardMaterial3D
		if original != null:
			var material := original.duplicate() as StandardMaterial3D
			material.albedo_color *= tint
			material.roughness = 0.94
			instance.material_override = material
	set_meta("source", "skinned_semantic_animation")
	animate_pose(0, 0)

func _use_fallback() -> void:
	_fallback = load("res://src/assets/ProceduralCharacterModel.gd").create_fallback_zombie(archetype)
	add_child(_fallback)
	set_meta("source", "procedural_fallback")

func animate_pose(time: float, speed: float, action: StringName = &"idle") -> void:
	if _fallback != null:
		_fallback.call("animate_pose", time, speed, &"idle" if action in [&"crawl", &"death"] else action)
		return
	if _player == null:
		return
	var desired := action
	# VisualRoot supplies the corpse/crawler transform and authoritative wounds.
	# Freeze a neutral upper body for crawling; never substitute a walk for death.
	if action in [&"crawl", &"death", &"hurt"]:
		desired = &"idle"
	elif action == &"idle" and speed > 0.18:
		desired = &"run" if speed > 2.5 else &"walk"
	if desired != _semantic:
		var clips := {&"idle": &"Zombie|ZombieIdle", &"walk": &"Zombie|ZombieWalk", &"run": &"Zombie|ZombieRun", &"attack": &"Zombie|ZombieBite"}
		var clip: StringName = clips.get(desired, &"Zombie|ZombieIdle")
		_player.play(clip, 0.10)
		_semantic = desired
	_elapsed += maxf(0, time - _last_time) if _last_time >= 0 else 0
	_last_time = time
	if _elapsed < 0.05 and time > 0:
		return
	for index in _base_scales:
		_skeleton.set_bone_pose_scale(index, _base_scales[index])
	_player.advance(minf(_elapsed, 0.15) if action != &"death" else 0.0)
	_elapsed = 0
	_apply_destroyed()

func set_destroyed_parts(parts: Array) -> void:
	_destroyed = parts.duplicate()
	_apply_destroyed()

func _apply_destroyed() -> void:
	for part in _destroyed:
		if not PART_BONES.has(int(part)):
			continue
		if _fallback != null:
			var names := {0: "Head", 3: "LeftArm", 4: "RightArm", 5: "LeftLeg", 6: "RightLeg"}
			var node := _fallback.get_node_or_null(names[int(part)]) as Node3D
			if node != null:
				node.hide()
		elif _skeleton != null:
			var index := _skeleton.find_bone(PART_BONES[int(part)])
			if index >= 0:
				_skeleton.set_bone_pose_scale(index, Vector3.ONE * 0.001)
