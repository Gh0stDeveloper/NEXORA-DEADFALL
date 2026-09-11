class_name DeadfallZombieModelPresenter
extends Node3D

const ExternalModels = preload("res://src/assets/ExternalModelCatalog.gd")
const ModelNormalizer = preload("res://src/assets/ModelNormalizer.gd")
const AnimationDriver = preload("res://src/assets/ImportedAnimationDriver.gd")
const ProceduralCharacters = preload("res://src/assets/ProceduralCharacterModel.gd")
const TARGET_VISUAL_HEIGHT := 1.64
const USE_EXTERNAL_MODELS := false
const VISIBILITY_RANGE_BY_TIER := {
	0: 52.0,
	1: 72.0,
	2: 96.0,
	3: 128.0,
}

@export var prepared_rig_path := NodePath("../PreparedRig")
@export var variant: StringName = &"animated"
@export_range(0.05, 0.50, 0.01) var animation_update_interval := 0.10

var _prepared_rig: Node3D
var _loaded_model: Node3D
var _animation_status: Dictionary = {}
var _semantic_state := StringName()
var _animation_elapsed := 0.0
var _procedural_elapsed := 0.0
var _model_is_procedural := false
var _visuals_enabled := true
var _quality_tier := 1
var _animation_overrides: Dictionary = {}
var _gore_destroyed_parts: Dictionary = {}

func _ready() -> void:
	_prepared_rig = get_node_or_null(prepared_rig_path) as Node3D
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		_visuals_enabled = false
		visible = false
		set_process(false)
		return
	_bind_quality_profile()
	set_process(true)
	call_deferred("load_external_model")

func _process(delta: float) -> void:
	if not _visuals_enabled or not has_external_model():
		return
	if _model_is_procedural:
		_update_procedural_presentation(delta)
		return
	_animation_elapsed += delta
	if _animation_elapsed < animation_update_interval:
		return
	_animation_elapsed = 0.0
	_update_semantic_animation()

func load_external_model() -> bool:
	if not _visuals_enabled:
		return false
	_clear_loaded_model()
	if not USE_EXTERNAL_MODELS:
		return _load_procedural_model()
	var config := ExternalModels.zombie(variant)
	if not ExternalModels.model_exists(config):
		_set_prepared_rig_visible(true)
		return false
	var resource := load(String(config.get("path", "")))
	var scene := resource as PackedScene
	if scene == null:
		_set_prepared_rig_visible(true)
		return false
	_loaded_model = scene.instantiate() as Node3D
	if _loaded_model == null:
		_set_prepared_rig_visible(true)
		return false
	_model_is_procedural = false
	var configured_scale: Vector3 = config.get("scale", Vector3.ONE)
	var configured_rotation: Vector3 = config.get("rotation_degrees", Vector3.ZERO)
	var configured_offset: Vector3 = config.get("offset", Vector3.ZERO)
	_animation_overrides = Dictionary(config.get("animation_semantics", {})).duplicate(true)
	_loaded_model.name = "ExternalZombieModel"
	_loaded_model.scale = configured_scale
	_loaded_model.rotation_degrees = configured_rotation
	_loaded_model.position = configured_offset
	add_child(_loaded_model)
	var normalization := ModelNormalizer.normalize_visual(_loaded_model, self, TARGET_VISUAL_HEIGHT)
	if not bool(normalization.get("ok", false)):
		push_warning("DEADFALL zombie model normalization failed: %s" % String(normalization.get("reason", "unknown")))
	_set_prepared_rig_visible(false)
	_apply_quality_visibility()
	_semantic_state = &"idle"
	_animation_status = _play_semantic(_semantic_state, 0.0, 1.0)
	if not bool(_animation_status.get("ok", false)):
		_animation_status = AnimationDriver.play_best_pose(_loaded_model, ["idle", "stand", "walk", "run", "locomotion", "attack"])
	if bool(config.get("expects_animation", false)) and not bool(_animation_status.get("ok", false)):
		push_warning("DEADFALL expected animated zombie model has no usable runtime clip: %s" % String(config.get("source_name", variant)))
	return true

func _load_procedural_model() -> bool:
	_loaded_model = ProceduralCharacters.create_zombie(variant)
	if _loaded_model == null:
		_set_prepared_rig_visible(true)
		return false
	_loaded_model.name = "ProceduralZombieModel"
	add_child(_loaded_model)
	_model_is_procedural = true
	_set_prepared_rig_visible(false)
	_apply_procedural_gore_state()
	_semantic_state = &"idle"
	_animation_status = {
		"ok": true,
		"source": "procedural",
		"semantic": "idle",
		"clip": "static_pose",
	}
	return true

func _update_procedural_presentation(delta: float) -> void:
	_procedural_elapsed += delta
	if _loaded_model == null or not is_instance_valid(_loaded_model):
		return
	var zombie := get_parent() as CharacterBody3D
	var moving := zombie != null and Vector2(zombie.velocity.x, zombie.velocity.z).length() > 0.18
	var frequency := 8.0 if moving else 2.6
	var amplitude := 0.008 if moving else 0.002
	_loaded_model.position.y = sin(_procedural_elapsed * frequency) * amplitude
	_loaded_model.rotation.z = sin(_procedural_elapsed * frequency * 0.38) * 0.012

func apply_gore_visual(body_part: int) -> void:
	_gore_destroyed_parts[body_part] = true
	_apply_procedural_gore_state()

func _apply_procedural_gore_state() -> void:
	if not _model_is_procedural or _loaded_model == null or not is_instance_valid(_loaded_model):
		return
	var part_names := {
		0: ["Head", "Jaw", "LeftEye", "RightEye"],
		3: ["LeftArm"],
		4: ["RightArm"],
		5: ["LeftLeg"],
		6: ["RightLeg"],
	}
	for body_part in _gore_destroyed_parts:
		var names: Array = part_names.get(int(body_part), [])
		for part_name in names:
			var part := _loaded_model.get_node_or_null(String(part_name)) as MeshInstance3D
			if part != null:
				part.visible = false

func fallback_to_prepared_rig() -> void:
	_clear_loaded_model()
	if _visuals_enabled and not USE_EXTERNAL_MODELS:
		_load_procedural_model()
	else:
		_set_prepared_rig_visible(true)

func has_external_model() -> bool:
	return _loaded_model != null and is_instance_valid(_loaded_model)

func get_animation_status() -> Dictionary:
	return _animation_status.duplicate(true)

func get_semantic_state() -> StringName:
	return _semantic_state

func get_semantic_inventory() -> Dictionary:
	return AnimationDriver.semantic_inventory(_loaded_model) if has_external_model() else {}

func get_animation_overrides() -> Dictionary:
	return _animation_overrides.duplicate(true)

func _bind_quality_profile() -> void:
	var settings := get_tree().root.get_node_or_null("Settings") if get_tree() != null else null
	if settings == null:
		return
	var tier_value = settings.get("quality_tier")
	_quality_tier = clampi(int(tier_value) if tier_value != null else 1, 0, 3)
	if settings.has_signal("quality_profile_changed"):
		var callback := Callable(self, "_on_quality_profile_changed")
		if not settings.is_connected("quality_profile_changed", callback):
			settings.connect("quality_profile_changed", callback)

func _on_quality_profile_changed(tier: int, _profile: Dictionary) -> void:
	_quality_tier = clampi(tier, 0, 3)
	_apply_quality_visibility()

func _apply_quality_visibility() -> void:
	if not has_external_model():
		return
	var end_distance := float(VISIBILITY_RANGE_BY_TIER.get(_quality_tier, 72.0))
	_apply_visibility_range_recursive(_loaded_model, end_distance)

func _apply_visibility_range_recursive(node: Node, end_distance: float) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.visibility_range_end = end_distance
		geometry.visibility_range_end_margin = 6.0
		geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	for child in node.get_children():
		_apply_visibility_range_recursive(child, end_distance)

func _update_semantic_animation() -> void:
	var desired := _desired_semantic_state()
	if desired == _semantic_state:
		return
	_semantic_state = desired
	var speed := 1.0
	if desired == &"run":
		speed = 1.08
	elif desired == &"walk" or desired == &"crawl":
		speed = 0.92
	var result := _play_semantic(desired, 0.10, speed)
	if bool(result.get("ok", false)):
		_animation_status = result

func _play_semantic(semantic: StringName, blend_seconds: float, speed: float) -> Dictionary:
	var mapped_name := StringName(String(_animation_overrides.get(String(semantic), "")))
	if not mapped_name.is_empty():
		var exact := AnimationDriver.play_named(_loaded_model, mapped_name, semantic, blend_seconds, speed)
		if bool(exact.get("ok", false)):
			return exact
		push_warning("DEADFALL zombie exact animation mapping missing at runtime: %s -> %s" % [String(semantic), String(mapped_name)])
	return AnimationDriver.play_semantic(_loaded_model, semantic, blend_seconds, speed)

func _desired_semantic_state() -> StringName:
	var zombie := get_parent() as CharacterBody3D
	if zombie == null:
		return &"idle"
	var state_value = zombie.get("state")
	var state := int(state_value) if state_value != null else 0
	match state:
		5:
			return &"death"
		4:
			return &"hurt"
		3:
			return &"attack"
	var crawler_value = zombie.get("_crawler_mode")
	var crawler := bool(crawler_value) if crawler_value != null else false
	var planar_speed := Vector2(zombie.velocity.x, zombie.velocity.z).length()
	if crawler and planar_speed > 0.12:
		return &"crawl"
	if state == 2 and planar_speed > 2.5:
		return &"run"
	if planar_speed > 0.18:
		return &"walk"
	return &"idle"

func _clear_loaded_model() -> void:
	if _loaded_model != null and is_instance_valid(_loaded_model):
		_loaded_model.queue_free()
	_loaded_model = null
	_animation_status = {}
	_semantic_state = StringName()
	_animation_overrides = {}
	_procedural_elapsed = 0.0
	_model_is_procedural = false

func _set_prepared_rig_visible(visible: bool) -> void:
	if _prepared_rig != null:
		_prepared_rig.visible = visible
