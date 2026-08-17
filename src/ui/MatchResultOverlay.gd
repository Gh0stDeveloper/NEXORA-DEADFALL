class_name DeadfallMatchResultOverlay
extends CanvasLayer

signal return_requested()

const AUTO_RETURN_SECONDS := 8.0

var _title: Label
var _summary: Label
var _countdown: Label
var _return_button: Button
var _timer: Timer
var _remaining := AUTO_RETURN_SECONDS
var _result: Dictionary = {}

func _ready() -> void:
	layer = 95
	_build_ui()
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.autostart = false
	_timer.timeout.connect(_on_tick)
	add_child(_timer)

func present(result: Dictionary) -> void:
	_result = result.duplicate(true)
	_remaining = AUTO_RETURN_SECONDS
	var outcome := String(result.get("outcome", "ABORTED")).to_upper()
	_title.text = "MISIÓN COMPLETADA" if outcome == "VICTORY" else "ESCUADRÓN ELIMINADO" if outcome == "DEFEAT" else "PARTIDA FINALIZADA"
	var wave := int(result.get("wave", 0))
	var score := int(result.get("score", 0))
	var kills := int(result.get("kills", 0))
	var reason := String(result.get("reason", "match_finished")).replace("_", " ").to_upper()
	_summary.text = "RESULTADO AUTORITATIVO DEL SERVIDOR\nPUNTOS  %d    BAJAS  %d    OLEADA  %d\n%s" % [score, kills, wave, reason]
	_update_countdown()
	visible = true
	_timer.start()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.045, 0.92)
	root.add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-310, -150)
	panel.size = Vector2(620, 300)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.065, 0.09, 0.98)
	style.border_color = Color(0.12, 0.68, 0.68, 0.75)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 26
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	column.add_child(_title)

	_summary = Label.new()
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.add_theme_font_size_override("font_size", 18)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_summary)

	_countdown = Label.new()
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown.add_theme_font_size_override("font_size", 15)
	column.add_child(_countdown)

	_return_button = Button.new()
	_return_button.text = "VOLVER AL LOBBY"
	_return_button.custom_minimum_size = Vector2(0, 52)
	_return_button.pressed.connect(_request_return)
	column.add_child(_return_button)

func _on_tick() -> void:
	_remaining = maxf(0.0, _remaining - 1.0)
	_update_countdown()
	if _remaining <= 0.0:
		_request_return()

func _update_countdown() -> void:
	if _countdown != null:
		_countdown.text = "Regreso automático al lobby en %d s" % int(ceil(_remaining))

func _request_return() -> void:
	if _timer != null:
		_timer.stop()
	return_requested.emit()
