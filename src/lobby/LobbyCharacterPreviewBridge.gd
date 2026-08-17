class_name DeadfallLobbyCharacterPreviewBridge
extends Node

const ExternalModels = preload("res://src/assets/ExternalModelCatalog.gd")
const ModelNormalizer = preload("res://src/assets/ModelNormalizer.gd")
const PREVIEW_HEIGHT := 1.76

var _viewport: SubViewport
var _preview_root: Node3D
var _placeholder: MeshInstance3D
var _model: Node3D
var _current_character: StringName = &""

func _ready() -> void:
	GuestIdentity.selected_character_changed.connect(_on_character_changed)
	call_deferred("_initialize_preview")

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
	_show_character(GuestIdentity.selected_character)

func _on_character_changed(character_id: StringName) -> void:
	_show_character(character_id)

func _show_character(character_id: StringName) -> void:
	if _preview_root == null:
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
	_preview_root.add_child(_model)
	var normalization := ModelNormalizer.normalize_visual(_model, _preview_root, PREVIEW_HEIGHT)
	if not bool(normalization.get("ok", false)):
		push_warning("DEADFALL lobby preview normalization failed: %s" % String(normalization.get("reason", "unknown")))
	_set_placeholder_visible(false)
	_play_idle_if_available(_model)

func _clear_model() -> void:
	if _model != null and is_instance_valid(_model):
		_model.queue_free()
	_model = null

func _set_placeholder_visible(visible: bool) -> void:
	if _placeholder != null:
		_placeholder.visible = visible

func _play_idle_if_available(root: Node) -> void:
	var player := _find_animation_player(root)
	if player == null:
		return
	var animations := player.get_animation_list()
	for name in animations:
		var lowered := String(name).to_lower()
		if lowered.contains("idle") or lowered.contains("stand") or lowered.contains("breath"):
			player.play(StringName(name))
			return
	for name in animations:
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
