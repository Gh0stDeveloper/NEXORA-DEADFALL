extends SceneTree

const ExternalModels = preload("res://src/assets/ExternalModelCatalog.gd")
const AnimationDriver = preload("res://src/assets/ImportedAnimationDriver.gd")
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
		root.add_child(instance)
		await process_frame
		var expects_animation := bool(config.get("expects_animation", false))
		if expects_animation:
			var capability: Dictionary = AnimationDriver.capability_snapshot(instance)
			var inventory: Array = Array(capability.get("inventory", []))
			if not bool(capability.get("usable", false)):
				instance.free()
				_fail("Animated model imported without a usable runtime animation: %s inventory=%s" % [model_name, JSON.stringify(inventory)])
				return
			var pose_result := AnimationDriver.play_best_pose(instance)
			if not bool(pose_result.get("ok", false)):
				instance.free()
				_fail("Animated model could not apply an initial non-bind pose: %s result=%s" % [model_name, JSON.stringify(pose_result)])
				return
			var semantics: Dictionary = Dictionary(capability.get("semantic", {}))
			var generic_fallback := bool(capability.get("generic_fallback", false))
			var mode := "generic_fallback" if semantics.is_empty() and generic_fallback else "semantic"
			if semantics.is_empty() and not generic_fallback:
				instance.free()
				_fail("Animated model has neither semantic clips nor a usable generic fallback: %s inventory=%s" % [model_name, JSON.stringify(inventory)])
				return
			var idle_result := AnimationDriver.play_semantic(instance, &"idle", 0.0)
			if not bool(idle_result.get("ok", false)):
				instance.free()
				_fail("Animated model could not resolve idle presentation, including generic fallback: %s result=%s" % [model_name, JSON.stringify(idle_result)])
				return
			print("DEADFALL_MODEL_ANIMATION_READY model=%s clip=%s mode=%s" % [model_name, String(pose_result.get("animation", "")), mode])
			print("DEADFALL_MODEL_SEMANTICS model=%s mode=%s semantics=%s inventory=%s" % [model_name, mode, JSON.stringify(semantics), JSON.stringify(inventory)])
		instance.free()
		await process_frame

	print("NEXORA: DEADFALL Phase 11.3 external GLB import/runtime smoke passed")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
