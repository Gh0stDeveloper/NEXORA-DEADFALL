class_name DeadfallZombieModelPresenter
extends Node3D

const ExternalModels = preload("res://src/assets/ExternalModelCatalog.gd")
const ModelNormalizer = preload("res://src/assets/ModelNormalizer.gd")
const AnimationDriver = preload("res://src/assets/ImportedAnimationDriver.gd")
const TARGET_VISUAL_HEIGHT := 1.95

@export var prepared_rig_path := NodePath("../PreparedRig")
@export var variant: StringName = &"animated"

var _prepared_rig: Node3D
var _loaded_model: Node3D
var _animation_status: Dictionary = {}

func _ready() -> void:
	_prepared_rig = get_node_or_null(prepared_rig_path) as Node3D
	call_deferred("load_external_model")

func load_external_model() -> bool:
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

func _clear_loaded_model() -> void:
	if _loaded_model != null and is_instance_valid(_loaded_model):
		_loaded_model.queue_free()
	_loaded_model = null
	_animation_status = {}

func _set_prepared_rig_visible(visible: bool) -> void:
	if _prepared_rig != null:
		_prepared_rig.visible = visible
