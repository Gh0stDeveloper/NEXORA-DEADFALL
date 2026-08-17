class_name DeadfallZombieModelPresenter
extends Node3D

const ExternalModels = preload("res://src/assets/ExternalModelCatalog.gd")
const ModelNormalizer = preload("res://src/assets/ModelNormalizer.gd")
const AnimationDriver = preload("res://src/assets/ImportedAnimationDriver.gd")
const TARGET_VISUAL_HEIGHT := 1.95

@export var prepared_rig_path := NodePath("../PreparedRig")
@export var variant: StringName = &"animated"
@export_range(0.05, 0.50, 0.01) var animation_update_interval := 0.10

var _prepared_rig: Node3D
var _loaded_model: Node3D
var _animation_status: Dictionary = {}
var _semantic_state := StringName()
var _animation_elapsed := 0.0
var _visuals_enabled := true

func _ready() -> void:
	_prepared_rig = get_node_or_null(prepared_rig_path) as Node3D
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		_visuals_enabled = false
		visible = false
		set_process(false)
		return
	set_process(true)
	call_deferred("load_external_model")

func _process(delta: float) -> void:
	if not _visuals_enabled or not has_external_model():
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
	var configured_scale: Vector3 = config.get("scale", Vector3.ONE)
	var configured_rotation: Vector3 = config.get("rotation_degrees", Vector3.ZERO)
	var configured_offset: Vector3 = config.get("offset", Vector3.ZERO)
	_loaded_model.name = "ExternalZombieModel"
	_loaded_model.scale = configured_scale
	_loaded_model.rotation_degrees = configured_rotation
	_loaded_model.position = configured_offset
	add_child(_loaded_model)
	var normalization := ModelNormalizer.normalize_visual(_loaded_model, self, TARGET_VISUAL_HEIGHT)
	if not bool(normalization.get("ok", false)):
		push_warning("DEADFALL zombie model normalization failed: %s" % String(normalization.get("reason", "unknown")))
	_set_prepared_rig_visible(false)
	_semantic_state = &"idle"
	_animation_status = AnimationDriver.play_semantic(_loaded_model, _semantic_state, 0.0)
	if not bool(_animation_status.get("ok", false)):
		_animation_status = AnimationDriver.play_best_pose(_loaded_model, ["idle", "stand", "walk", "run", "locomotion", "attack"])
	if bool(config.get("expects_animation", false)) and not bool(_animation_status.get("ok", false)):
		push_warning("DEADFALL expected animated zombie model has no usable runtime clip: %s" % String(config.get("source_name", variant)))
	return true

func fallback_to_prepared_rig() -> void:
	_clear_loaded_model()
	_set_prepared_rig_visible(true)

func has_external_model() -> bool:
	return _loaded_model != null and is_instance_valid(_loaded_model)

func get_animation_status() -> Dictionary:
	return _animation_status.duplicate(true)

func get_semantic_state() -> StringName:
	return _semantic_state

func get_semantic_inventory() -> Dictionary:
	return AnimationDriver.semantic_inventory(_loaded_model) if has_external_model() else {}

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
	var result := AnimationDriver.play_semantic(_loaded_model, desired, 0.10, speed)
	if bool(result.get("ok", false)):
		_animation_status = result

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

func _set_prepared_rig_visible(visible: bool) -> void:
	if _prepared_rig != null:
		_prepared_rig.visible = visible
