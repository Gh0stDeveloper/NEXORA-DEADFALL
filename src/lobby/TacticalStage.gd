class_name DeadfallTacticalStage
extends Control

const Characters = preload("res://src/assets/ProceduralCharacterModel.gd")
const Weapons = preload("res://src/assets/ProceduralWeaponModels.gd")
var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _models: Array[Node3D] = []
var _signature := ""
var _time := 0.0
var _weapon_mode := false
var _drag := false
var _yaw := 0.18

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	var container := SubViewportContainer.new()
	container.name = "CharacterViewportContainer"
	container.stretch = true
	container.stretch_shrink = 2 if Settings.quality_tier == 0 else 1
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport = SubViewport.new()
	_viewport.name = "CharacterViewport"
	_viewport.size = Vector2i(1100, 760)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_DISABLED if Settings.quality_tier == 0 else Viewport.MSAA_2X
	container.add_child(_viewport)
	_world = Node3D.new()
	_world.name = "StageWorld"
	_viewport.add_child(_world)
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 1.03, 3.6)
	_camera.fov = 31
	_camera.current = true
	_world.add_child(_camera)
	_camera.look_at(Vector3(0, 0.86, 0))
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b0c9d0")
	environment.environment.ambient_light_energy = 0.65
	_world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, -28, 0)
	key.light_color = Color("ffe1b4")
	key.light_energy = 1.8
	_world.add_child(key)
	var fill := OmniLight3D.new()
	fill.name = "TealFill"
	fill.position = Vector3(-1.7, 1.8, 2)
	fill.light_color = Color("70cad8")
	fill.light_energy = 2.2
	fill.omni_range = 7
	_world.add_child(fill)
	visibility_changed.connect(_update_visibility)
	Settings.quality_profile_changed.connect(_on_quality_profile_changed)
	_update_visibility()

func _on_quality_profile_changed(tier: int, _profile: Dictionary) -> void:
	var container := get_node("CharacterViewportContainer") as SubViewportContainer
	container.stretch_shrink = 2 if tier == 0 else 1
	_viewport.msaa_3d = Viewport.MSAA_DISABLED if tier == 0 else Viewport.MSAA_2X

func set_members(members: Array, capacity: int) -> void:
	var appearance: Array = []
	for member in members.slice(0, capacity):
		appearance.append([String(member.get("guest_id", "")), String(member.get("selected_character", "operator_01"))])
	var signature := JSON.stringify([appearance, capacity])
	if signature == _signature:
		return
	_signature = signature
	_clear_models()
	_weapon_mode = false
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.position = Vector3(0, 1.03, 3.6 if capacity <= 2 else 4.5)
	_camera.look_at(Vector3(0, 0.86, 0))
	for i in range(mini(capacity, 4)):
		var x := (float(i) - float(capacity - 1) * 0.5) * (0.77 if capacity > 2 else 0.82)
		if i < members.size():
			var model := Characters.create_operator(StringName(members[i].get("selected_character", "operator_01")), i)
			model.position = Vector3(x, 0, 0.08 if i % 2 else 0)
			model.rotation.y = PI + _yaw
			_world.add_child(model)
			_models.append(model)
		else:
			var vacant := Node3D.new()
			_world.add_child(vacant)
			vacant.position.x = x
			_models.append(vacant)
			var sign := Label3D.new()
			sign.text = "+"
			sign.font_size = 100
			sign.pixel_size = 0.004
			sign.position.y = 0.8
			sign.modulate = Color(0.45, 0.85, 0.9, 0.75)
			sign.no_depth_test = true
			vacant.add_child(sign)
		var disk := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.33
		mesh.bottom_radius = 0.33
		mesh.height = 0.008
		mesh.radial_segments = 32
		disk.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.05, 0.18, 0.22, 0.65)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		disk.material_override = mat
		_models.back().add_child(disk)

func show_weapon(weapon_id: StringName) -> void:
	_clear_models()
	_signature = ""
	_weapon_mode = true
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 0.9 if weapon_id == &"machete" else (0.40 if weapon_id == &"nxr_pistol_01" else 0.58)
	_camera.position = Vector3(0,0.86,3.6)
	_camera.look_at(Vector3(0,0.86,0))
	var model := Weapons.create_view_model(weapon_id)
	model.position.y = 0.86
	model.rotation = Vector3(0, 1.2, 0)
	_world.add_child(model)
	_models.append(model)

func _clear_models() -> void:
	for model in _models:
		model.queue_free()
	_models.clear()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	for model in _models:
		if _weapon_mode:
			model.rotation.y += delta * 0.24
		elif model.has_method("animate_pose"):
			model.call("animate_pose", _time, 0.0, &"idle")
			model.rotation.y = PI + _yaw + sin(_time * 0.35) * 0.035

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_drag = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenDrag:
		_yaw += event.relative.x * 0.008
	elif event is InputEventMouseMotion and _drag:
		_yaw += event.relative.x * 0.008

func _update_visibility() -> void:
	set_process(is_visible_in_tree())
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
