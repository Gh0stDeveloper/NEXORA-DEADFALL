class_name DeadfallNetworkTelemetry
extends Node

signal ping_changed(display_ping_ms: int, raw_ping_ms: int, quality: String, source: String)

const CONTROL_PING_INTERVAL_SECONDS := 3.0
const PRESENCE_INTERVAL_SECONDS := 5.0
const MATCH_PING_STALE_SECONDS := 5.0
const REQUEST_TIMEOUT_SECONDS := 5.0
const EXCELLENT_PING_THRESHOLD_MS := 25

var _display_ping_ms := 999
var _raw_ping_ms := 999
var _quality := "SIN CONEXIÓN"
var _source := "control"
var _control_display_ping := 999
var _control_raw_ping := 999
var _control_quality := "SIN CONEXIÓN"
var _match_display_ping := 999
var _match_raw_ping := 999
var _match_quality := "SIN CONEXIÓN"
var _last_match_ping_usec := 0
var _control_elapsed := 0.0
var _presence_elapsed := 0.0
var _control_probe: Node
var _control_connection_ms := 0
var _control_total_ms := 0
var _overlay_label: Label
var _ping_panel: PanelContainer

func _ready() -> void:
	if DisplayServer.get_name() == "headless" or "--server" in OS.get_cmdline_user_args():
		set_process(false)
		return
	_build_overlay()
	set_process(true)
	call_deferred("_start_control_ping")

func _process(delta: float) -> void:
	_control_elapsed += delta
	_presence_elapsed += delta
	if _control_elapsed >= CONTROL_PING_INTERVAL_SECONDS:
		_control_elapsed = 0.0
		_start_control_ping()
	if _presence_elapsed >= PRESENCE_INTERVAL_SECONDS:
		_presence_elapsed = 0.0
		_report_presence()
	if _last_match_ping_usec > 0 and float(Time.get_ticks_usec() - _last_match_ping_usec) / 1_000_000.0 > MATCH_PING_STALE_SECONDS:
		_last_match_ping_usec = 0
		_apply_effective_ping()

func set_match_ping(display_ping_ms: int, raw_ping_ms: int, quality: String) -> void:
	_match_display_ping = clampi(display_ping_ms, 0, 999)
	_match_raw_ping = clampi(raw_ping_ms, 0, 999)
	_match_quality = quality
	_last_match_ping_usec = Time.get_ticks_usec()
	_apply_effective_ping()

func clear_match_ping() -> void:
	_last_match_ping_usec = 0
	_match_display_ping = 999
	_match_raw_ping = 999
	_match_quality = "SIN CONEXIÓN"
	_apply_effective_ping()

func get_display_ping_ms() -> int:
	return _display_ping_ms

func get_raw_ping_ms() -> int:
	return _raw_ping_ms

func get_quality() -> String:
	return _quality

func get_source() -> String:
	return _source

func is_online() -> bool:
	return _display_ping_ms < 999

func snapshot() -> Dictionary:
	return {
		"display_ping_ms": _display_ping_ms,
		"raw_ping_ms": _raw_ping_ms,
		"quality": _quality,
		"source": _source,
		"online": is_online(),
		"control_connection_ms": _control_connection_ms,
		"control_total_ms": _control_total_ms,
	}

func _start_control_ping() -> void:
	# Gameplay has its own ENet ping. Do not add HTTPS traffic during a match.
	if Game.is_network_client():
		return
	var social := get_node_or_null("/root/SocialClient")
	if social == null:
		_set_control_ping(999)
		return
	var base := String(social.get("api_base")).trim_suffix("/").trim_suffix("/v1")
	if base.is_empty():
		_set_control_ping(999)
		return
	if _control_probe == null:
		_control_probe = preload("res://src/network/ControlLatencyProbe.gd").new()
		_control_probe.name = "ControlLatencyProbe"
		add_child(_control_probe)
		_control_probe.connect("completed", _on_control_ping_completed)
	_control_probe.call("measure", base)

func _on_control_ping_completed(request_ms: int, connection_ms: int, total_ms: int) -> void:
	_control_connection_ms = connection_ms
	_control_total_ms = total_ms
	_set_control_ping(request_ms)

func _set_control_ping(raw_ms: int) -> void:
	_control_raw_ping = clampi(raw_ms, 0, 999)
	if _control_raw_ping >= 999:
		_control_display_ping = 999
		_control_quality = "SIN CONEXIÓN"
	elif _control_raw_ping <= EXCELLENT_PING_THRESHOLD_MS:
		_control_display_ping = _control_raw_ping
		_control_quality = "EXCELENTE"
	elif _control_raw_ping <= 70:
		_control_display_ping = _control_raw_ping
		_control_quality = "BUENO"
	elif _control_raw_ping <= 140:
		_control_display_ping = _control_raw_ping
		_control_quality = "MEDIO"
	else:
		_control_display_ping = _control_raw_ping
		_control_quality = "ALTO"
	_apply_effective_ping()

func _apply_effective_ping() -> void:
	var match_fresh := _last_match_ping_usec > 0 and float(Time.get_ticks_usec() - _last_match_ping_usec) / 1_000_000.0 <= MATCH_PING_STALE_SECONDS
	if match_fresh:
		_display_ping_ms = _match_display_ping
		_raw_ping_ms = _match_raw_ping
		_quality = _match_quality
		_source = "match"
	elif Game.is_network_client():
		_display_ping_ms = 999
		_raw_ping_ms = 999
		_quality = "SIN CONEXIÓN"
		_source = "match"
	else:
		_display_ping_ms = _control_display_ping
		_raw_ping_ms = _control_raw_ping
		_quality = _control_quality
		_source = "control"
	_refresh_overlay()
	ping_changed.emit(_display_ping_ms, _raw_ping_ms, _quality, _source)

func _report_presence() -> void:
	var social := get_node_or_null("/root/SocialClient")
	if social != null and social.has_method("has_session") and bool(social.call("has_session")) and social.has_method("report_presence"):
		social.call("report_presence", _display_ping_ms)

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "NetworkPingOverlay"
	layer.layer = 190
	add_child(layer)
	var panel := PanelContainer.new()
	_ping_panel = panel
	panel.anchor_left = 1.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -190.0
	panel.offset_top = 18.0
	panel.offset_right = -18.0
	panel.offset_bottom = 62.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.020, 0.028, 0.84)
	style.border_color = Color(0.25, 0.28, 0.34, 0.65)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	_overlay_label = Label.new()
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay_label.add_theme_font_size_override("font_size", 14)
	_overlay_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_overlay_label)
	_refresh_overlay()

func set_frontend_mode(frontend: bool) -> void:
	if _ping_panel == null:
		return
	_ping_panel.anchor_left = 0.97 if frontend else 1.0
	_ping_panel.anchor_right = _ping_panel.anchor_left
	_ping_panel.anchor_top = 0.105 if frontend else 0.0
	_ping_panel.anchor_bottom = _ping_panel.anchor_top
	_ping_panel.offset_left = -220.0 if frontend else -190.0
	_ping_panel.offset_right = 0.0 if frontend else -18.0
	_ping_panel.offset_top = 0.0 if frontend else 18.0
	_ping_panel.offset_bottom = 42.0 if frontend else 62.0
	_overlay_label.add_theme_font_size_override("font_size", 18 if frontend else 14)

func _refresh_overlay() -> void:
	if _overlay_label == null:
		return
	var ping_text := "+999" if _display_ping_ms >= 999 else str(_display_ping_ms)
	_overlay_label.text = "%s %s ms" % ["PARTIDA" if _source == "match" else "API LOBBY", ping_text]
	if _display_ping_ms >= 999:
		_overlay_label.add_theme_color_override("font_color", Color(0.88, 0.20, 0.22))
	elif _display_ping_ms <= EXCELLENT_PING_THRESHOLD_MS:
		_overlay_label.add_theme_color_override("font_color", Color(0.35, 0.92, 0.58))
	elif _display_ping_ms <= 70:
		_overlay_label.add_theme_color_override("font_color", Color(0.60, 0.88, 0.58))
	elif _display_ping_ms <= 140:
		_overlay_label.add_theme_color_override("font_color", Color(0.95, 0.74, 0.30))
	else:
		_overlay_label.add_theme_color_override("font_color", Color(0.95, 0.38, 0.28))
