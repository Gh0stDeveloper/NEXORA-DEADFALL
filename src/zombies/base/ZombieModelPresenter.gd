class_name DeadfallZombieModelPresenter
extends Node3D

const ExternalModels = preload("res://src/assets/ExternalModelCatalog.gd")

@export var prepared_rig_path := NodePath("../PreparedRig")
@export var variant: StringName = &"animated"

var _prepared_rig: Node3D
var _loaded_model: Node3D

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
	_loaded_model.name = "ExternalZombieModel"
	_loaded_model.scale = Vector3(config.get("scale", Vector3.ONE))
	_loaded_model.rotation_degrees = Vector3(config.get("rotation_degrees", Vector3.ZERO))
	_loaded_model.position = Vector3(config.get("offset", Vector3.ZERO))
	add_child(_loaded_model)
	_set_prepared_rig_visible(false)
	_play_idle_if_available(_loaded_model)
	return true

func fallback_to_prepared_rig() -> void:
	_clear_loaded_model()
	_set_prepared_rig_visible(true)

func has_external_model() -> bool:
	return _loaded_model != null and is_instance_valid(_loaded_model)

func _clear_loaded_model() -> void:
	if _loaded_model != null and is_instance_valid(_loaded_model):
		_loaded_model.queue_free()
	_loaded_model = null

func _set_prepared_rig_visible(visible: bool) -> void:
	if _prepared_rig != null:
		_prepared_rig.visible = visible

func _play_idle_if_available(root: Node) -> void:
	var animation_player := _find_animation_player(root)
	if animation_player == null:
		return
	var animations := animation_player.get_animation_list()
	for candidate in ["Idle", "idle", "IDLE"]:
		if candidate in animations:
			animation_player.play(candidate)
			return

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
