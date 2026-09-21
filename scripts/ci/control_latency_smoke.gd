extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.max_fps = 120
	var port := 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--control-test-port="): port = int(argument.get_slice("=", 1))
	if port <= 0:
		quit(1)
		return
	var probe := preload("res://src/network/ControlLatencyProbe.gd").new()
	root.add_child(probe)
	for index in range(3):
		probe.measure("http://127.0.0.1:%d" % port)
		var result: Array = await probe.completed
		if int(result[0]) >= 999:
			push_error("Persistent control RTT probe failed: %s" % [result])
			quit(1)
			return
		print("DEADFALL_CONTROL_RTT ", JSON.stringify(result))
		await create_timer(0.1).timeout
	probe.measure("http://127.0.0.1:%d/bad" % port)
	var invalid: Array = await probe.completed
	if int(invalid[0]) != 999:
		push_error("Invalid health body must not produce a healthy ping")
		quit(1)
		return
	var telemetry := root.get_node("NetworkTelemetry")
	telemetry.call("_set_control_ping", 25)
	if int(telemetry.call("get_display_ping_ms")) != 25:
		push_error("RTT must not be rounded down to zero")
		quit(1)
		return
	probe.queue_free()
	await process_frame
	print("NEXORA: DEADFALL control RTT smoke passed")
	quit(0)
