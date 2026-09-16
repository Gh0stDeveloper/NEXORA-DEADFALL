class_name DeadfallTestRange
extends Node3D

const NAV_SOURCE_GROUP: StringName = &"deadfall_nav_source"
var _navigation_region: NavigationRegion3D

func _ready() -> void:
	_build_environment()
	_build_geometry()
	# The prototype range bakes a tiny runtime navmesh on visual clients. Server
	# production maps will ship prebaked navigation data rather than doing this.
	if DisplayServer.get_name() != "headless":
		call_deferred("_build_navigation")

func _build_environment() -> void:
	var environment_node := WorldEnvironment.new()
	environment_node.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055, 0.065, 0.08)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.60, 0.68)
	environment.ambient_light_energy = 0.7
	environment_node.environment = environment
	add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)

func _build_geometry() -> void:
	_create_box("Floor", Vector3(0, -0.25, 0), Vector3(42, 0.5, 42), Color(0.13, 0.15, 0.18))
	_create_box("CoverA", Vector3(-4.5, 1.0, -6.0), Vector3(2.0, 2.0, 0.8), Color(0.24, 0.27, 0.31))
	_create_box("CoverB", Vector3(4.5, 0.7, -3.0), Vector3(3.0, 1.4, 0.8), Color(0.24, 0.27, 0.31))

	# Clearance tunnel: 1.45 m from floor to ceiling. Standing (1.80 m)
	# must be rejected while crouch (1.25 m) and prone (0.80 m) can fit.
	_create_box("LowTunnelTop", Vector3(0.0, 1.625, 5.0), Vector3(5.0, 0.35, 4.0), Color(0.20, 0.22, 0.25))
	_create_box("LowTunnelLeft", Vector3(-2.35, 0.725, 5.0), Vector3(0.35, 1.45, 4.0), Color(0.20, 0.22, 0.25))
	_create_box("LowTunnelRight", Vector3(2.35, 0.725, 5.0), Vector3(0.35, 1.45, 4.0), Color(0.20, 0.22, 0.25))

func _build_navigation() -> void:
	if _navigation_region != null:
		return
	_navigation_region = NavigationRegion3D.new()
	_navigation_region.name = "NavigationRegion"
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	nav_mesh.geometry_source_group_name = NAV_SOURCE_GROUP
	nav_mesh.geometry_collision_mask = 1
	nav_mesh.agent_radius = 0.50
	nav_mesh.agent_height = 1.75
	nav_mesh.agent_max_climb = 0.25
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	nav_mesh.filter_walkable_low_height_spans = true
	_navigation_region.navigation_mesh = nav_mesh
	add_child(_navigation_region)
	_navigation_region.bake_navigation_mesh(true)

func _create_box(node_name: String, position_value: Vector3, size_value: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.collision_layer = 1
	body.collision_mask = 0

	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	shape_node.shape = shape
	body.add_child(shape_node)

	if DisplayServer.get_name() != "headless":
		var mesh_node := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size_value
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.86
		mesh.material = material
		mesh_node.mesh = mesh
		body.add_child(mesh_node)

	add_child(body)
	body.add_to_group(NAV_SOURCE_GROUP)
