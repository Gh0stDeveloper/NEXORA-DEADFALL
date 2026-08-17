class_name DeadfallMatchLoadingOverlay
extends CanvasLayer

signal return_requested()

const LOADING_ART: Texture2D = preload("res://assets/ui/loading_deadfall.svg")

var _status_label: Label
var _detail_label: Label
var _progress: ProgressBar
var _return_button: Button
var _progress_value := 0.0
var _target_progress := 0.0

func _ready() -> void:
	layer = 90
	_build_ui()
	set_process(true)

func _process(delta: float) -> void:
	_progress_value = move_toward(_progress_value, _target_progress, maxf(0.08, delta * 0.75))
	if _progress != null:
		_progress.value = _progress_value * 100.0

func begin(endpoint: String) -> void:
	_progress_value = 0.04
	_target_progress = 0.16
	if _status_label != null:
		_status_label.text = "CARGANDO…"
	if _detail_label != null:
		_detail_label.text = "Preparando partida dedicada · %s" % endpoint
	if _return_button != null:
		_return_button.visible = false

func set_stage(text: String, progress_ratio: float) -> void:
	_target_progress = clampf(progress_ratio, _target_progress, 0.98)
	if _status_label != null:
		_status_label.text = "CARGANDO…"
	if _detail_label != null:
		_detail_label.text = text

func complete() -> void:
	_target_progress = 1.0
	if _status_label != null:
		_status_label.text = "LISTO"
	if _detail_label != null:
		_detail_label.text = "Entrando a la zona de supervivencia…"

func show_error(message: String) -> void:
	_target_progress = maxf(_target_progress, 0.18)
	if _status_label != null:
		_status_label.text = "NO SE PUDO CONECTAR"
	if _detail_label != null:
		_detail_label.text = message
	if _return_button != null:
		_return_button.visible = true

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var background := TextureRect.new()
	background.texture = LOADING_ART
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)

	var darken := ColorRect.new()
	darken.color = Color(0.0, 0.0, 0.0, 0.16)
	darken.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	darken.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(darken)

	var top_fade := ColorRect.new()
	top_fade.color = Color(0.0, 0.0, 0.0, 0.20)
	top_fade.anchor_right = 1.0
	top_fade.anchor_bottom = 0.24
	top_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_fade)

	var bottom := PanelContainer.new()
	bottom.anchor_left = 0.055
	bottom.anchor_top = 0.78
	bottom.anchor_right = 0.945
	bottom.anchor_bottom = 0.95
	bottom.add_theme_stylebox_override("panel", _panel_style(Color(0.010, 0.017, 0.024, 0.92), Color(0.18, 0.62, 0.68, 0.56), 18))
	root.add_child(bottom)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	bottom.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	_status_label = Label.new()
	_status_label.text = "CARGANDO…"
	_status_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_status_label)
	_detail_label = Label.new()
	_detail_label.text = "Preparando servidor…"
	_detail_label.add_theme_color_override("font_color", Color(0.72, 0.80, 0.84))
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_detail_label)
	_progress = ProgressBar.new()
	_progress.min_value = 0.0
	_progress.max_value = 100.0
	_progress.value = 0.0
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0, 18)
	_progress.add_theme_stylebox_override("background", _panel_style(Color(0.02, 0.04, 0.05, 0.96), Color(0.16, 0.30, 0.32, 0.65), 9))
	_progress.add_theme_stylebox_override("fill", _panel_style(Color(0.84, 0.09, 0.08, 1.0), Color(1.0, 0.33, 0.18, 0.95), 9))
	vbox.add_child(_progress)

	_return_button = Button.new()
	_return_button.text = "VOLVER AL LOBBY"
	_return_button.visible = false
	_return_button.custom_minimum_size = Vector2(210, 48)
	_return_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_return_button.add_theme_stylebox_override("normal", _panel_style(Color(0.12, 0.035, 0.045, 0.98), Color(0.78, 0.10, 0.12, 0.86), 12))
	_return_button.add_theme_stylebox_override("hover", _panel_style(Color(0.22, 0.045, 0.055, 1.0), Color(1.0, 0.22, 0.18, 1.0), 12))
	_return_button.add_theme_stylebox_override("pressed", _panel_style(Color(0.07, 0.025, 0.032, 1.0), Color(1.0, 0.30, 0.22, 1.0), 12))
	_return_button.pressed.connect(func() -> void: return_requested.emit())
	vbox.add_child(_return_button)

func _panel_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style
