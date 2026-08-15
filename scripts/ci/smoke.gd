extends SceneTree

const REQUIRED_FILES := [
	"res://project.godot",
	"res://src/main/Main.tscn",
	"res://src/main/Main.gd",
	"res://src/core/authority/GameAuthority.gd",
	"res://src/core/authority/LocalAuthority.gd",
	"res://src/core/damage/DamageEvent.gd",
	"res://src/server/DedicatedServer.gd",
	"res://src/player/Player.tscn",
	"res://src/player/PlayerController.gd",
	"res://src/player/PlayerInput.gd",
	"res://src/player/CameraRig.gd",
	"res://src/mobile/MobileHUD.tscn",
	"res://src/maps/test_range/TestRange.tscn",
]

func _initialize() -> void:
	for path in REQUIRED_FILES:
		if not FileAccess.file_exists(path):
			_fail("Missing required project file: %s" % path)
			return

	var main_scene := load("res://src/main/Main.tscn") as PackedScene
	if main_scene == null or main_scene.instantiate() == null:
		_fail("Main scene could not be instantiated")
		return

	var range_scene := load("res://src/maps/test_range/TestRange.tscn") as PackedScene
	if range_scene == null:
		_fail("Test range scene could not be loaded")
		return
	var range_instance := range_scene.instantiate()
	root.add_child(range_instance)

	var player := range_instance.get_node_or_null("Player")
	if player == null or not player is CharacterBody3D:
		_fail("Test range Player must be a CharacterBody3D")
		return
	if player.get_node_or_null("PlayerInput") == null:
		_fail("PlayerInput node missing")
		return
	if player.get_node_or_null("CameraRig/Pitch/FirstPerson") == null:
		_fail("First-person camera missing")
		return
	if player.get_node_or_null("CameraRig/Pitch/ThirdPersonRear") == null:
		_fail("Rear third-person camera missing")
		return
	if player.get_node_or_null("CameraRig/Pitch/ThirdPersonFront") == null:
		_fail("Front third-person camera missing")
		return
	if range_instance.get_node_or_null("MobileHUD") == null:
		_fail("Mobile HUD missing")
		return

	for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "prone", "camera_cycle"]:
		if not InputMap.has_action(action):
			_fail("Input action was not registered: %s" % action)
			return

	range_instance.free()
	print("NEXORA: DEADFALL smoke test passed")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
