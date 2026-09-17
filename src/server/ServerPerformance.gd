class_name DeadfallServerPerformance
extends Node

# This is simulation scheduling time, not Internet latency. Logs are usable on
# the VPS without installing a renderer or exposing a public diagnostics API.
var _previous_tick_usec := 0
var _window_started_usec := 0
var _tick_intervals: Array[float] = []
var _snapshot_usec := 0
var _snapshot_count := 0
var _snapshot_bytes := 0
var _snapshot_max_usec := 0

func _ready() -> void:
	add_to_group("deadfall_server_performance")
	_window_started_usec = Time.get_ticks_usec()

func _physics_process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _previous_tick_usec > 0:
		_tick_intervals.append(float(now - _previous_tick_usec) / 1000.0)
	_previous_tick_usec = now
	if now - _window_started_usec >= 10_000_000:
		print("DEADFALL_SERVER_PERF ", JSON.stringify(snapshot()))
		_window_started_usec = now
		_tick_intervals.clear()
		_snapshot_usec = 0
		_snapshot_count = 0
		_snapshot_bytes = 0
		_snapshot_max_usec = 0

func record_snapshot(elapsed_usec: int, wire_bytes: int) -> void:
	_snapshot_usec += elapsed_usec
	_snapshot_max_usec = maxi(_snapshot_max_usec, elapsed_usec)
	_snapshot_count += 1
	_snapshot_bytes += wire_bytes

func snapshot() -> Dictionary:
	var ordered := _tick_intervals.duplicate()
	ordered.sort()
	var duration := maxf(0.001, float(Time.get_ticks_usec() - _window_started_usec) / 1_000_000.0)
	return {
		"pid": OS.get_process_id(),
		"physics_hz": Engine.physics_ticks_per_second,
		"frame_cap": Engine.max_fps,
		"ticks_per_second": snappedf(float(ordered.size()) / duration, 0.1),
		"tick_interval_p95_ms": ordered[int(floor(float(ordered.size() - 1) * 0.95))] if not ordered.is_empty() else 0.0,
		"tick_interval_max_ms": ordered.back() if not ordered.is_empty() else 0.0,
		"physics_cpu_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"process_cpu_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"snapshot_avg_ms": float(_snapshot_usec) / float(maxi(1, _snapshot_count)) / 1000.0,
		"snapshot_max_ms": float(_snapshot_max_usec) / 1000.0,
		"snapshot_payload_bytes_per_second": int(float(_snapshot_bytes) / duration),
		"players": get_tree().get_nodes_in_group("deadfall_player").size(),
		"zombies": get_tree().get_nodes_in_group("deadfall_zombie").size(),
	}
