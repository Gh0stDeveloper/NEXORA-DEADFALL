extends Node3D

func rebuild(kind: String, amount: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if kind == "health":
		_box(Vector3(0.46, 0.24, 0.31), Vector3.ZERO, Color("e4dfcb"))
		_box(Vector3(0.15, 0.045, 0.035), Vector3(0, 0.15, 0), Color("495e59"))
		_box(Vector3(0.19, 0.055, 0.015), Vector3(0, 0.025, 0.162), Color("29a88d"))
		_box(Vector3(0.055, 0.17, 0.015), Vector3(0, 0.025, 0.163), Color("29a88d"))
	else:
		_box(Vector3(0.43, 0.055, 0.20), Vector3(0, -0.12, 0), Color("303d48"))
		for i in range(5):
			var cartridge := CylinderMesh.new()
			cartridge.top_radius = 0.031
			cartridge.bottom_radius = 0.031
			cartridge.height = 0.23
			_mesh(cartridge, Vector3((i - 2) * 0.074, 0, 0), Color("d7ad56"))
			var tip := CylinderMesh.new()
			tip.top_radius = 0.0
			tip.bottom_radius = 0.031
			tip.height = 0.085
			_mesh(tip, Vector3((i - 2) * 0.074, 0.157, 0), Color("b1744e"))
	var label := Label3D.new()
	label.text = "%s +%d" % ["SALUD" if kind == "health" else "MUNICIÓN", amount]
	label.position.y = 0.48
	label.font_size = 34
	label.pixel_size = 0.0035
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("88e4c8") if kind == "health" else Color("f2cb7b")
	label.no_depth_test = false
	add_child(label)

func _box(size_value: Vector3, location: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size_value
	_mesh(mesh, location, color)

func _mesh(mesh: Mesh, location: Vector3, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.65
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = location
	add_child(instance)
