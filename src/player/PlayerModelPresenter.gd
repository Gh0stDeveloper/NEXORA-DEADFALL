class_name DeadfallPlayerModelPresenter
extends Node3D

const ExternalModels = preload("res://src/assets/ExternalModelCatalog.gd")
const ModelNormalizer = preload("res://src/assets/ModelNormalizer.gd")
const TARGET_VISUAL_HEIGHT := 1.76

@export var fallback_body_path := NodePath("../Body")

var _fallback_body: GeometryInstance3D
var _loaded_model: Node3D
var _character_id: StringName = &"operator_01"
var _configured_once := false

func _ready() -> void:
	_fallback_body = get_node_or_null(fallback_body_path) as GeometryInstance3D
	call_deferred("configure_character", _character_id)

func configure_character(character_id: StringName) -> bool:
	var requested := character_id if not character_id.is_empty() else &"operator_01"
	if _configured_once and requested == _character_id:
		return has_external_model()
	_character_id = requested
	_configured_once = true
	_clear_loaded_model()
	var config := ExternalModels.character(_character_id)
	if not ExternalModels.model_exists(config):
		_set_fallback_visible(true)
		return false
	var resource := load(String(config.get("path", "")))
	var scene := resource as PackedScene
	if scene == null:
		_set_fallback_visible(true)
		return false
	_loaded_model = scene.instantiate() as Node3D
	if _loaded_model == null:
		_set_fallback_visible(true)
		return false
	var configured_scale: Vector3 = config.get("scale", Vector3.ONE)
	var configured_rotation: Vector3 = config.get("rotation_degrees", Vector3.ZERO)
	var configured_offset: Vector3 = config.get("offset", Vector3.ZERO)
	_loaded_model.name = "ExternalCharacterModel"
	_loaded_model.scale = configured_scale
	_loaded_model.rotation_degrees = configured_rotation
	_loaded_model.position = configured_offset
	add_child(_loaded_model)
	var normalization := ModelNormalizer.normalize_visual(_loaded_model, self, TARGET_VISUAL_HEIGHT)
	if not bool(normalization.get("ok", false)):
		push_warning("DEADFALL player model normalization failed: %s" % String(normalization.get("reason", "unknown")))
	_set_fallback_visible(false)
	_play_idle_if_available(_loaded_model)
	return true

func current_character_id() -> StringName:
	return _character_id

func has_external_model() -> bool:
	return _loaded_model != null and is_instance_valid(_loaded_model)

func _clear_loaded_model() -> void:
	if _loaded_model != null and is_instance_valid(_loaded_model):
		_loaded_model.queue_free()
	_loaded_model = null

func _set_fallback_visible(visible: bool) -> void:
	if _fallback_body != null:
		_fallback_body.visible = visible

func _play_idle_if_available(root: Node) -> void:
	var player := _find_animation_player(root)
	if player == null:
		return
	var names := player.get_animation_list()
	for name in names:
		var lowered := String(name).to_lower()
		if lowered.contains("idle") or lowered.contains("stand") or lowered.contains("breath"):
			player.play(StringName(name))
			return
	# Avoid leaving imported animated characters in T-pose when the source uses
	# generic animation names. RESET is never selected as a presentation clip.
	for name in names:
		if String(name).to_lower() != "reset":
			player.play(StringName(name))
			return

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
