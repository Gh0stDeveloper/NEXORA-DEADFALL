extends SceneTree

const REQUIRED_FILES := [
	"res://project.godot",
	"res://src/main/Main.tscn",
	"res://src/main/Main.gd",
	"res://src/core/authority/GameAuthority.gd",
	"res://src/core/authority/LocalAuthority.gd",
	"res://src/core/damage/DamageEvent.gd",
	"res://src/server/DedicatedServer.gd",
]

func _initialize() -> void:
	for path in REQUIRED_FILES:
		if not FileAccess.file_exists(path):
			push_error("Missing required project file: %s" % path)
			quit(1)
			return

	var main_scene := load("res://src/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Main scene could not be loaded")
		quit(1)
		return

	var instance := main_scene.instantiate()
	if instance == null:
		push_error("Main scene could not be instantiated")
		quit(1)
		return
	instance.free()

	print("NEXORA: DEADFALL smoke test passed")
	quit(0)
