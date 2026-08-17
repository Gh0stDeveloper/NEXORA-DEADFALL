class_name DeadfallLobbyCharacterPreviewBridge
extends Node

const ExternalModels = preload("res://src/assets/ExternalModelCatalog.gd")
const ModelNormalizer = preload("res://src/assets/ModelNormalizer.gd")
const AnimationDriver = preload("res://src/assets/ImportedAnimationDriver.gd")
const PREVIEW_HEIGHT := 1.76

@export_range(0.0, 1.0, 0.01) var turntable_radians_per_second := 0.10

var _viewport: SubViewport
var _preview_root: Node3D
var _turntable: Node3D
var _placeholder: MeshInstance3D
var _model: Node3D
var _current_character: StringName = &""
var _animation_status: Dictionary = {}

func _ready() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		set_process(false)
		return
	GuestIdentity.selected_character_changed.connect(_on_character_changed)
	set_process(true)
	call_deferred("_initialize_preview")

func _process(delta: float) -> void:
	if _turntable != null and is_instance_valid(_turntable) and _model != null and is_instance_valid(_model):
		_turntable.rotation.y = fposmod(_turntable.rotation.y + turntable_radians_per_second * delta, TAU)

func _initialize_preview() -> void:
	var lobby := get_parent()
	if lobby == null:
		return
	_viewport = lobby.get_node_or_null("SafeArea/OperatorStage/CharacterViewportContainer/CharacterViewport") as SubViewport
	if _viewport == null or _viewport.get_child_count() == 0:
		return
	_preview_root = _viewport.get_child(0) as Node3D
	if _preview_root == null:
		return
	_placeholder = _preview_root.get_node_or_null("OperatorPlaceholder") as MeshInstance3D
	_turntable = _preview_root.get_node_or_null("LobbyCharacterTurntable") as Node3D
	if _turntable == null:
		_turntable = Node3D.new()
		_turntable.name = "LobbyCharacterTurntable"
		_preview_root.add_child(_turntable)
	_show_character(GuestIdentity.selected_character)

func _on_character_changed(character_id: StringName) -> void:
	_show_character(character_id)

func _show_character(character_id: StringName) -> void:
	if _preview_root == null or _turntable == null:
		return
	var requested := character_id if not character_id.is_empty() else &"operator_01"
	if requested == _current_character and _model != null and is_instance_valid(_model):
		return
	_current_character = requested
	_clear_model()
	var config := ExternalModels.character(requested)
	if not ExternalModels.model_exists(config):
		_set_placeholder_visible(true)
		return
	var resource := load(String(config.get("path", "")))
	var scene := resource as PackedScene
	if scene == null:
		_set_placeholder_visible(true)
		return
	_model = scene.instantiate() as Node3D
	if _model == null:
		_set_placeholder_visible(true)
		return
	var configured_scale: Vector3 = config.get("scale", Vector3.ONE)
	var configured_rotation: Vector3 = config.get("rotation_degrees", Vector3.ZERO)
	var configured_offset: Vector3 = config.get("offset", Vector3.ZERO)
	_model.name = "LobbyCharacterModel"
	_model.scale = configured_scale
	_model.rotation_degrees = configured_rotation
	_model.position = configured_offset
	_turntable.rotation = Vector3.ZERO
	_turntable.add_child(_model)
	var normalization := ModelNormalizer.normalize_visual(_model, _preview_root, PREVIEW_HEIGHT)
	if not bool(normalization.get("ok", false)):
		push_warning("DEADFALL lobby preview normalization failed: %s" % String(normalization.get("reason", "unknown")))
	_set_placeholder_visible(false)
	_animation_status = AnimationDriver.play_semantic(_model, &"idle", 0.0)
	if not bool(_animation_status.get("ok", false)):
		_animation_status = AnimationDriver.play_best_pose(_model, ["idle", "stand", "breath", "walk", "run"])
	if bool(config.get("expects_animation", false)) and not bool(_animation_status.get("ok", false)):
		push_warning("DEADFALL lobby animated character has no usable runtime pose: %s" % String(config.get("source_name", requested)))

func get_animation_status() -> Dictionary:
	return _animation_status.duplicate(true)

func _clear_model() -> void:
	if _model != null and is_instance_valid(_model):
		_model.queue_free()
	_model = null
	_animation_status = {}

func _set_placeholder_visible(visible: bool) -> void:
	if _placeholder != null:
		_placeholder.visible = visible
