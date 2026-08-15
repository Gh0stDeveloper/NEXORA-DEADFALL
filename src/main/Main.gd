extends Node

const DedicatedServerScript = preload("res://src/server/DedicatedServer.gd")
const TestRangeScene = preload("res://src/maps/test_range/TestRange.tscn")
const AndroidDiagnosticsScript = preload("res://src/mobile/AndroidDiagnostics.gd")

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--server" in args:
		_boot_dedicated_server(args)
		return

	Game.start_local_session()
	_boot_local_vertical_slice()
	_boot_android_diagnostics()
	print("NEXORA: DEADFALL client bootstrap ready")

func _boot_local_vertical_slice() -> void:
	var test_range := TestRangeScene.instantiate()
	test_range.name = "TestRange"
	add_child(test_range)

func _boot_android_diagnostics() -> void:
	if not OS.has_feature("android") or not OS.is_debug_build():
		return
	var diagnostics := AndroidDiagnosticsScript.new()
	diagnostics.name = "AndroidDiagnostics"
	add_child(diagnostics)

func _boot_dedicated_server(args: PackedStringArray) -> void:
	var port := 24560
	for arg in args:
		if arg.begins_with("--port="):
			port = int(arg.trim_prefix("--port="))

	var server := DedicatedServerScript.new()
	server.name = "DedicatedServer"
	add_child(server)
	server.start(port)
