extends SceneTree

const ExternalModels = preload("res://src/assets/ExternalModelCatalog.gd")
const REQUIRED_MODELS := {
	"operator_01": {
		"canonical": "res://assets/external/objetos3d/operator_01.glb",
		"vendor": "res://vendor/Objetos3D/low poly survival character by Daren - WJiiE1qmRU.glb",
	},
	"operator_02": {
		"canonical": "res://assets/external/objetos3d/operator_02.glb",
		"vendor": "res://vendor/Objetos3D/Animated Character Base by J-Toastie - AZzoJo1FBm.glb",
	},
	"zombie_animated": {
		"canonical": "res://assets/external/objetos3d/zombie_animated.glb",
		"vendor": "res://vendor/Objetos3D/Animated Zombie by Quaternius - jkrEvQZb8J.glb",
	},
	"zombie_static": {
		"canonical": "res://assets/external/objetos3d/zombie_static.glb",
		"vendor": "res://vendor/Objetos3D/Zombie by cs_aaron - ftpTNkeqGWc.glb",
	},
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var configs := {
		"operator_01": ExternalModels.character(&"operator_01"),
		"operator_02": ExternalModels.character(&"operator_02"),
		"zombie_animated": ExternalModels.zombie(&"animated"),
		"zombie_static": ExternalModels.zombie(&"static"),
	}

	for model_name in REQUIRED_MODELS.keys():
		var expected: Dictionary = REQUIRED_MODELS[model_name]
		var config: Dictionary = configs[model_name]
		var canonical_path := String(expected.get("canonical", ""))
		var vendor_path := String(expected.get("vendor", ""))
		if String(config.get("canonical_path", "")) != canonical_path:
			_fail("%s canonical model mapping changed" % model_name)
			return
		if String(config.get("vendor_path", "")) != vendor_path:
			_fail("%s vendored runtime model mapping changed" % model_name)
			return
		if not FileAccess.file_exists(canonical_path):
			_fail("Required Phase 11.3 canonical GLB is missing after sync: %s" % canonical_path)
			return

		var runtime_path := String(config.get("path", ""))
		if runtime_path not in [vendor_path, canonical_path]:
			_fail("Unexpected Phase 11.3 runtime GLB path for %s: %s" % [model_name, runtime_path])
			return
		if not FileAccess.file_exists(runtime_path):
			_fail("Required Phase 11.3 runtime GLB is missing: %s" % runtime_path)
			return
		if not ResourceLoader.exists(runtime_path):
			_fail("Godot did not import required Phase 11.3 runtime GLB: %s" % runtime_path)
			return
		var resource := load(runtime_path)
		var scene := resource as PackedScene
		if scene == null:
			_fail("Imported GLB is not a PackedScene: %s" % runtime_path)
			return
		var instance := scene.instantiate() as Node3D
		if instance == null:
			_fail("Imported GLB could not instantiate as Node3D: %s" % runtime_path)
			return
		if String(model_name) == "zombie_animated" and not _has_runtime_animation(instance):
			instance.free()
			_fail("Animated zombie imported without a runtime animation")
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
