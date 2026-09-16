extends Control

const MAIN_PATH := "res://src/main/Main.tscn"
const UI = preload("res://src/ui/TacticalTheme.gd")
const Backdrop = preload("res://src/ui/TacticalBackdrop.gd")
var _bar: ProgressBar
var _status: Label
var _started := false
var _retry: Button

func _ready() -> void:
	# Headless automation keeps its established synchronous server/test bootstrap.
	if DisplayServer.get_name() == "headless" or "--server" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred(MAIN_PATH)
		return
	UI.apply(self)
	NetworkTelemetry.set_frontend_mode(true)
	add_child(Backdrop.new())
	UI.place(UI.label("N E X O R A", 32, UI.AMBER), self, Rect2(0.06, 0.45, 0.8, 0.06))
	UI.place(UI.label("DEADFALL", 110), self, Rect2(0.055, 0.50, 0.8, 0.17))
	_status = UI.label("PREPARANDO RECURSOS", 26, UI.MUTED)
	UI.place(_status, self, Rect2(0.06, 0.82, 0.8, 0.05))
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	UI.place(_bar, self, Rect2(0.06, 0.89, 0.88, 0.009))
	# Let the splash reach the screen before loading the gameplay dependency graph.
	await RenderingServer.frame_post_draw
	_start_load()

func _start_load() -> void:
	if _started:
		return
	if is_instance_valid(_retry):
		_retry.hide()
	_status.text = "PREPARANDO RECURSOS"
	var error := ResourceLoader.load_threaded_request(MAIN_PATH, "PackedScene", true)
	if error != OK:
		_show_error()
		return
	_started = true

func _process(_delta: float) -> void:
	if not _started:
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(MAIN_PATH, progress)
	if not progress.is_empty():
		_bar.value = float(progress[0]) * 100.0
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_started = false
		var scene := ResourceLoader.load_threaded_get(MAIN_PATH) as PackedScene
		if scene == null or get_tree().change_scene_to_packed(scene) != OK:
			_show_error()
	elif status in [ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
		_started = false
		_show_error()

func _show_error() -> void:
	_status.text = "No se pudieron cargar los recursos del juego."
	if not is_instance_valid(_retry):
		_retry = UI.button("REINTENTAR", _start_load, true)
		UI.place(_retry, self, Rect2(0.70, 0.78, 0.24, 0.075))
	_retry.show()
