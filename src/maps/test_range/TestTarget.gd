class_name DeadfallTestTarget
extends Node3D

@onready var health = $Health
@onready var hitboxes = $Hitboxes

var _status_label: Label3D

func _ready() -> void:
	health.connect(&"health_changed", _on_health_changed)
	health.connect(&"died", _on_died)
	if DisplayServer.get_name() != "headless":
		_build_debug_visuals()
		_update_label(float(health.get("current_health")))

func _build_debug_visuals() -> void:
	for child in hitboxes.get_children():
		if not child is Area3D:
			continue
		var shape_node := child.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape_node == null or not shape_node.shape is BoxShape3D:
			continue
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "%sVisual" % child.name
		mesh_instance.position = child.position
		var mesh := BoxMesh.new()
		mesh.size = (shape_node.shape as BoxShape3D).size
		var material := StandardMaterial3D.new()
		material.albedo_color = _color_for_body_part(int(child.get("body_part")))
		material.roughness = 0.78
		mesh.material = material
		mesh_instance.mesh = mesh
		add_child(mesh_instance)

	_status_label = Label3D.new()
	_status_label.name = "StatusLabel"
	_status_label.position = Vector3(0.0, 2.55, 0.0)
	_status_label.font_size = 28
	add_child(_status_label)

func _color_for_body_part(body_part: int) -> Color:
	match body_part:
		0:
			return Color(0.72, 0.18, 0.18)
		1, 2:
			return Color(0.34, 0.38, 0.43)
		_:
			return Color(0.23, 0.30, 0.36)

func _on_health_changed(current: float, _maximum: float, _event) -> void:
	_update_label(current)

func _on_died(_event) -> void:
	if _status_label != null:
		_status_label.text = "TEST TARGET\nDESTROYED"

func _update_label(current: float) -> void:
	if _status_label != null:
		_status_label.text = "TEST TARGET\nHP %d" % int(round(current))
