class_name DeadfallCampaignHUD
extends CanvasLayer

@export var director_path := NodePath("../CampaignDirector")

var _director: Node
var _label: Label
var _last_text := ""

func _ready() -> void:
	_director = get_node_or_null(director_path)
	if DisplayServer.get_name() == "headless":
		return
	var panel := PanelContainer.new()
	panel.name = "CampaignPanel"
	panel.position = Vector2(24, 24)
	panel.custom_minimum_size = Vector2(520, 118)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	_label = Label.new()
	_label.name = "CampaignStatus"
	_label.add_theme_font_size_override("font_size", 22)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(_label)

func _process(_delta: float) -> void:
	if _label == null or _director == null or not _director.has_method("get_status_snapshot"):
		return
	var status: Dictionary = _director.call("get_status_snapshot")
	var mission_title := String(status.get("mission_title", "Campaign"))
	var state_name := String(status.get("state_name", "DISABLED"))
	var objective_title := String(status.get("objective_title", ""))
	var current := float(status.get("progress", 0.0))
	var required := maxf(0.001, float(status.get("required", 1.0)))
	var objective_index := int(status.get("objective_index", 0)) + 1
	var objective_count := int(status.get("objective_count", 0))
	var progress_text := "%d%%" % int(round(clampf(current / required, 0.0, 1.0) * 100.0))
	var text := "%s  |  %s\nObjective %d/%d: %s\nProgress: %s" % [mission_title, state_name, objective_index, objective_count, objective_title, progress_text]
	if state_name == "COMPLETED":
		text = "%s  |  MISSION COMPLETE" % mission_title
	if text != _last_text:
		_last_text = text
		_label.text = text
