class_name DeadfallLobbyPartyAvatar
extends Control

const ProceduralCharacters = preload("res://src/assets/ProceduralCharacterModel.gd")
const AVATAR_VIEWPORT_SIZE := Vector2i(128, 128)

var _viewport: SubViewport
var _turntable: Node3D
var _model: Node3D
var _empty_badge: Label
var _active := false
var _slot_index := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(76.0, 76.0)
	_build_viewport()

func set_member(member: Dictionary, slot_index: int) -> void:
	_slot_index = slot_index
	_active = true
	_clear_model()
	var character_id := StringName(String(member.get("selected_character", member.get("character_id", "operator_01"))))
	_model = ProceduralCharacters.create_operator(character_id, slot_index)
	_model.name = "MemberOperator%d" % (slot_index + 1)
	_model.scale = Vector3.ONE * 0.91
	_turntable.add_child(_model)
	_empty_badge.visible = false

func set_empty(slot_index: int) -> void:
	_slot_index = slot_index
	_active = false
	_clear_model()
	_empty_badge.text = "+" if slot_index < 4 else "—"
	_empty_badge.visible = true

func _build_viewport() -> void:
	var container := SubViewportContainer.new()
	container.name = "AvatarViewportContainer"
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	_viewport = SubViewport.new()
	_viewport.name = "AvatarViewport"
	_viewport.size = AVATAR_VIEWPORT_SIZE
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_viewport)

	var world := Node3D.new()
	world.name = "AvatarWorld"
	_viewport.add_child(world)
	var camera := Camera3D.new()
	camera.name = "AvatarCamera"
	camera.position = Vector3(0.0, 0.86, 3.05)
	camera.fov = 31.0
	camera.current = true
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 0.82, 0.0))
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, -25.0, 0.0)
	key.light_energy = 1.25
	key.light_color = Color(0.88, 0.92, 1.0)
	key.shadow_enabled = true
	world.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-0.9, 1.3, -0.8)
	rim.light_color = Color(0.80, 0.06, 0.08)
	rim.light_energy = 2.2
	rim.omni_range = 4.0
	world.add_child(rim)
	_turntable = Node3D.new()
	_turntable.name = "AvatarTurntable"
	world.add_child(_turntable)
	var floor := MeshInstance3D.new()
	floor.name = "AvatarFloor"
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 0.72
	floor_mesh.bottom_radius = 0.78
	floor_mesh.height = 0.035
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.025, 0.032, 0.040)
	floor_material.metallic = 0.35
	floor_material.roughness = 0.56
	floor_mesh.material = floor_material
	floor.mesh = floor_mesh
	floor.position = Vector3(0.0, 0.015, 0.0)
	world.add_child(floor)

	_empty_badge = Label.new()
	_empty_badge.name = "EmptyBadge"
	_empty_badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empty_badge.text = "+"
	_empty_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_badge.add_theme_font_size_override("font_size", 30)
	_empty_badge.add_theme_color_override("font_color", Color(0.50, 0.56, 0.64))
	_empty_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_empty_badge)
	_empty_badge.visible = true

func _process(delta: float) -> void:
	if _active and _turntable != null and is_instance_valid(_turntable) and _model != null and is_instance_valid(_model):
		_turntable.rotation.y = fposmod(_turntable.rotation.y + delta * 0.16, TAU)

func _clear_model() -> void:
	if _model != null and is_instance_valid(_model):
		_model.queue_free()
	_model = null
