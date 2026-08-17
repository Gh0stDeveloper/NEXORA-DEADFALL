class_name DeadfallPlayerModelPresenter
extends Node3D

const ExternalModels = preload("res://src/assets/ExternalModelCatalog.gd")
const ModelNormalizer = preload("res://src/assets/ModelNormalizer.gd")
const AnimationDriver = preload("res://src/assets/ImportedAnimationDriver.gd")
const TARGET_VISUAL_HEIGHT := 1.76
const ATTACK_PRESENTATION_USEC := 360_000

@export var fallback_body_path := NodePath("../Body")
@export_range(0.05, 0.50, 0.01) var animation_update_interval := 0.10

var _fallback_body: GeometryInstance3D
var _loaded_model: Node3D
var _character_id: StringName = &"operator_01"
var _configured_once := false
var _animation_status: Dictionary = {}
var _animation_elapsed := 0.0
var _semantic_state := StringName()
var _last_action_sequences := {0: 0, 1: 0, 2: 0}
var _attack_until_usec := 0
var _visuals_enabled := true

func _ready() -> void:
	_fallback_body = get_node_or_null(fallback_body_path) as GeometryInstance3D
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		_visuals_enabled = false
		visible = false
		set_process(false)
		return
	set_process(true)
	call_deferred("configure_character", _character_id)

func _process(delta: float) -> void:
	if not _visuals_enabled or not has_external_model():
		return
	_animation_elapsed += delta
	if _animation_elapsed < animation_update_interval:
		return
	_animation_elapsed = 0.0
	_detect_weapon_action()
	_update_semantic_animation()

func configure_character(character_id: StringName) -> bool:
	var requested := character_id if not character_id.is_empty() else &"operator_01"
	var unchanged := _configured_once and requested == _character_id and has_external_model()
	_character_id = requested
	if not _visuals_enabled:
		return false
	if unchanged:
		return true
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
	_semantic_state = &"idle"
	_animation_status = AnimationDriver.play_semantic(_loaded_model, _semantic_state, 0.0)
	if not bool(_animation_status.get("ok", false)):
		_animation_status = AnimationDriver.play_best_pose(_loaded_model, ["idle", "stand", "breath", "walk", "run", "locomotion"])
	if bool(config.get("expects_animation", false)) and not bool(_animation_status.get("ok", false)):
		push_warning("DEADFALL expected animated player model has no usable runtime clip: %s" % String(config.get("source_name", _character_id)))
	return true

func current_character_id() -> StringName:
	return _character_id

func has_external_model() -> bool:
	return _loaded_model != null and is_instance_valid(_loaded_model)

func get_animation_status() -> Dictionary:
	return _animation_status.duplicate(true)

func get_semantic_state() -> StringName:
	return _semantic_state

func get_semantic_inventory() -> Dictionary:
	return AnimationDriver.semantic_inventory(_loaded_model) if has_external_model() else {}

func _detect_weapon_action() -> void:
	var owner := get_parent()
	if owner == null:
		return
	var loadout := owner.get_node_or_null("WeaponLoadout")
	if loadout == null or not loadout.has_method("get_authoritative_state"):
		return
	var state: Dictionary = loadout.call("get_authoritative_state")
	var slot := clampi(int(state.get("active_slot", 0)), 0, 2)
	var weapon_state: Dictionary
	match slot:
		1:
			weapon_state = Dictionary(state.get("secondary", {}))
		2:
			weapon_state = Dictionary(state.get("melee", {}))
		_:
			weapon_state = Dictionary(state.get("primary", {}))
	var sequence := int(weapon_state.get("last_sequence", 0))
	var previous := int(_last_action_sequences.get(slot, 0))
	if sequence > previous:
		_last_action_sequences[slot] = sequence
		_attack_until_usec = Time.get_ticks_usec() + ATTACK_PRESENTATION_USEC

func _update_semantic_animation() -> void:
	var desired := _desired_semantic_state()
	if desired == _semantic_state:
		return
	_semantic_state = desired
	var speed := 1.0
	if desired == &"run":
		speed = 1.10
	elif desired == &"walk" or desired == &"crawl":
		speed = 0.95
	var result := AnimationDriver.play_semantic(_loaded_model, desired, 0.12, speed)
	if bool(result.get("ok", false)):
		_animation_status = result

func _desired_semantic_state() -> StringName:
	var owner := get_parent() as CharacterBody3D
	if owner == null:
		return &"idle"
	var life_state := owner.get_node_or_null("LifeState")
	if life_state != null:
		var state_value = life_state.get("state")
		var state := int(state_value) if state_value != null else 0
		if state == 2:
			return &"death"
		if state == 1:
			return &"crawl"
	if Time.get_ticks_usec() < _attack_until_usec:
		return &"attack"
	var planar_speed := Vector2(owner.velocity.x, owner.velocity.z).length()
	var stance_value = owner.get("stance")
	var stance := int(stance_value) if stance_value != null else 0
	if stance == 2 and planar_speed > 0.18:
		return &"crawl"
	if planar_speed > 5.8:
		return &"run"
	if planar_speed > 0.22:
		return &"walk"
	return &"idle"

func _clear_loaded_model() -> void:
	if _loaded_model != null and is_instance_valid(_loaded_model):
		_loaded_model.queue_free()
	_loaded_model = null
	_animation_status = {}
	_semantic_state = StringName()
	_last_action_sequences = {0: 0, 1: 0, 2: 0}
	_attack_until_usec = 0

func _set_fallback_visible(visible: bool) -> void:
	if _fallback_body != null:
		_fallback_body.visible = visible
