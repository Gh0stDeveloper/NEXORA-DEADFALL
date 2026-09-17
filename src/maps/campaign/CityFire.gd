extends Node3D

var _light: OmniLight3D
var _smoke: CPUParticles3D
var _elapsed := 0.0

func _ready() -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/maps/campaign/CityFire.gdshader")
	for angle in [0.0, PI * 0.5]:
		var plane := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(1.4, 2.6)
		plane.mesh = mesh
		plane.position.y = 1.4
		plane.rotation.y = angle
		plane.material_override = material
		plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(plane)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.35, 0.06)
	_light.light_energy = 1.4
	_light.omni_range = 6.0
	_light.position.y = 1.8
	_light.shadow_enabled = false
	add_child(_light)
	_smoke = CPUParticles3D.new()
	_smoke.amount = 10
	_smoke.lifetime = 4.5
	_smoke.preprocess = 3.0
	_smoke.position.y = 1.4
	_smoke.direction = Vector3(0.3, 1, 0.1)
	_smoke.spread = 18.0
	_smoke.gravity = Vector3(0.15, 0.1, 0.0)
	_smoke.initial_velocity_min = 0.9
	_smoke.initial_velocity_max = 1.5
	_smoke.scale_amount_min = 0.7
	_smoke.scale_amount_max = 1.8
	var sphere := SphereMesh.new()
	sphere.height = 0.7
	sphere.radius = 0.35
	sphere.radial_segments = 8
	sphere.rings = 4
	_smoke.mesh = sphere
	var smoke_material := StandardMaterial3D.new()
	smoke_material.albedo_color = Color(0.12, 0.11, 0.10, 0.38)
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.vertex_color_use_as_albedo = true
	smoke_material.roughness = 1.0
	_smoke.material_override = smoke_material
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.55))
	gradient.set_color(1, Color(1, 1, 1, 0))
	_smoke.color_ramp = gradient
	_smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_smoke)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.2:
		return
	_elapsed = 0.0
	var camera := get_viewport().get_camera_3d()
	var near := camera != null and camera.global_position.distance_squared_to(global_position) < 3600.0
	_light.visible = near and int(Settings.quality_tier) > 0
	_light.light_energy = 1.2 + sin(float(Time.get_ticks_msec()) * 0.021 + position.x) * 0.25
	_smoke.emitting = near
	visible = camera != null and camera.global_position.distance_squared_to(global_position) < 14400.0
