class_name DeadfallPresentationRuntime
extends RefCounted

static func enabled() -> bool:
	return DisplayServer.get_name() != "headless" and not OS.has_feature("dedicated_server") and not "--server" in OS.get_cmdline_user_args()

static func attach_actor(actor: Node, scene_path: String, infected: bool) -> void:
	if actor.has_node("VisualRoot"):
		return
	if not enabled():
		# A transform placeholder is used by stance/gore state; no render resources.
		var transform_root := Node3D.new()
		transform_root.name = "VisualRoot"
		actor.add_child(transform_root)
		return
	var scene := load(scene_path) as PackedScene
	actor.add_child(scene.instantiate())
	var sound: Node = load("res://src/audio/ActorAudio.gd").new()
	sound.name = "ActorAudio"
	sound.set("infected", infected)
	actor.add_child(sound)
