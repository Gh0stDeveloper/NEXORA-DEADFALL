class_name DeadfallHordeHUD
extends CanvasLayer

const HordeDirectorScript = preload("res://src/horde/HordeDirector.gd")
@export var director_path := NodePath("../HordeDirector")
@export var restart_handler_path := NodePath("")

@onready var wave_label: Label = $SafeArea/StatsPanel/VBox/WaveLabel
@onready var score_label: Label = $SafeArea/StatsPanel/VBox/ScoreLabel
@onready var kills_label: Label = $SafeArea/StatsPanel/VBox/KillsLabel
@onready var enemies_label: Label = $SafeArea/StatsPanel/VBox/EnemiesLabel
@onready var budget_label: Label = $SafeArea/StatsPanel/VBox/BudgetLabel
@onready var countdown_label: Label = $SafeArea/CountdownLabel
@onready var game_over_panel: PanelContainer = $SafeArea/GameOverCenter/GameOverPanel
@onready var game_over_summary: Label = $SafeArea/GameOverCenter/GameOverPanel/VBox/Summary
@onready var restart_button: Button = $SafeArea/GameOverCenter/GameOverPanel/VBox/RestartButton
var _director: Node
var _restart_handler: Node

func _ready() -> void:
	_director = get_node_or_null(director_path)
	_restart_handler = get_node_or_null(restart_handler_path) if not restart_handler_path.is_empty() else null
	if _director == null:
		visible = false
		return
	for signal_name in ["state_changed", "wave_started", "wave_completed", "countdown_changed", "score_changed", "population_changed", "game_over", "run_restarted"]:
		if _director.has_signal(signal_name): _director.connect(signal_name, Callable(self, "_on_horde_updated"))
	restart_button.pressed.connect(_on_restart_pressed)
	_refresh()

func _on_horde_updated(_a = null, _b = null, _c = null, _d = null) -> void: _refresh()
func _on_restart_pressed() -> void:
	if _restart_handler != null and _restart_handler.has_method("request_restart"):
		_restart_handler.call("request_restart")
	elif _director != null and _director.has_method("restart_run"):
		_director.call("restart_run")

func _refresh() -> void:
	if _director == null: return
	var snapshot: Dictionary = _director.call("get_status_snapshot")
	var wave := int(snapshot.get("wave", 0))
	var state := int(snapshot.get("state", HordeDirectorScript.State.DISABLED))
	wave_label.text = "WAVE %d" % maxi(1, wave)
	score_label.text = "SCORE %d" % int(snapshot.get("score", 0))
	kills_label.text = "KILLS %d" % int(snapshot.get("kills", 0))
	enemies_label.text = "ENEMIES %d" % int(snapshot.get("enemies_remaining", 0))
	budget_label.text = "POP %d/%d" % [int(snapshot.get("active_population_cost", 0)), int(snapshot.get("population_budget", 0))]
	var show_countdown := state == HordeDirectorScript.State.COUNTDOWN or state == HordeDirectorScript.State.INTERMISSION
	countdown_label.visible = show_countdown
	if show_countdown:
		countdown_label.text = "WAVE %d IN %d" % [1 if state == HordeDirectorScript.State.COUNTDOWN else wave + 1, int(snapshot.get("countdown", 0))]
	game_over_panel.visible = state == HordeDirectorScript.State.GAME_OVER
	if game_over_panel.visible:
		game_over_summary.text = "WAVE %d\nSCORE %d\nKILLS %d" % [wave, int(snapshot.get("score", 0)), int(snapshot.get("kills", 0))]
