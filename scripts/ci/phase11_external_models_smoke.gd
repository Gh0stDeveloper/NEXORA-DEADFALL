extends SceneTree

const ExternalModels = preload("res://src/assets/ExternalModelCatalog.gd")
const REQUIRED_MODELS := {
	"operator_01": "res://assets/external/objetos3d/operator_01.glb",
	"operator_02": "res://assets/external/objetos3d/operator_02.glb",
	"zombie_animated": "res://assets/external/objetos3d/zombie_animated.glb",
	"zombie_static": "res://assets/external/objetos3d/zombie_static.glb",
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if String(ExternalModels.character(&"operator_01").get("path", "")) != REQUIRED_MODELS["operator_01"]:
		_fail("operator_01 canonical model mapping changed")
		return
	if String(ExternalModels.character(&"operator_02").get("path", "")) != REQUIRED_MODELS["operator_02"]:
		_fail("operator_02 canonical model mapping changed")
		return
	if String(ExternalModels.zombie(&"animated").get("path", "")) != REQUIRED_MODELS["zombie_animated"]:
		_fail("animated zombie canonical model mapping changed")
		return
	if String(ExternalModels.zombie(&"static").get("path", "")) != REQUIRED_MODELS["zombie_static"]:
		_fail("static zombie canonical model mapping changed")
		return

	for model_name in REQUIRED_MODELS.keys():
		var path := String(REQUIRED_MODELS[model_name])
		if not FileAccess.file_exists(path):
			_fail("Required Phase 11.3 GLB is missing after sync: %s" % path)
			return
		if not ResourceLoader.exists(path):
			_fail("Godot did not import required Phase 11.3 GLB: %s" % path)
			return
		var resource := load(path)
		var scene := resource as PackedScene
		if scene == null:
			_fail("Imported GLB is not a PackedScene: %s" % path)
			return
		var instance := scene.instantiate() as Node3D
		if instance == null:
			_fail("Imported GLB could not instantiate as Node3D: %s" % path)
			return
		if String(model_name) == "zombie_animated" and not _has_runtime_animation(instance):
			instance.free()
			_fail("zombie_animated.glb imported without a runtime animation")
			return
		instance.free()

	print("NEXORA: DEADFALL Phase 11.3 external GLB import/runtime smoke passed")
	quit(0)

func _has_runtime_animation(root_node: Node) -> bool:
	var player := _find_animation_player(root_node)
	if player == null:
		return false
	for animation_name in player.get_animation_list():
		if String(animation_name).to_lower() != "reset":
			return true
	return false

func _find_animation_player(root_node: Node) -> AnimationPlayer:
	if root_node is AnimationPlayer:
		return root_node as AnimationPlayer
	for child in root_node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
