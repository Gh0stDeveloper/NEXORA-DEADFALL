extends Node

const DedicatedServerScript = preload("res://src/server/DedicatedServer.gd")

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--server" in args:
		_boot_dedicated_server(args)
		return

	Game.start_local_session()
	print("NEXORA: DEADFALL client bootstrap ready")

func _boot_dedicated_server(args: PackedStringArray) -> void:
	var port := 24560
	for arg in args:
		if arg.begins_with("--port="):
			port = int(arg.trim_prefix("--port="))

	var server := DedicatedServerScript.new()
	server.name = "DedicatedServer"
	add_child(server)
	server.start(port)
