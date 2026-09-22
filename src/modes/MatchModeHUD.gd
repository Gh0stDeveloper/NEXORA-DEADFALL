class_name DeadfallMatchModeHUD
extends CanvasLayer
const UI = preload("res://src/ui/TacticalTheme.gd")
var _label: Label
var _detail: Label
var _session: Node

func _ready() -> void:
	layer = 25
	var safe := preload("res://src/mobile/SafeArea.gd").new()
	add_child(safe)
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UI.style(Color(0.02, 0.04, 0.06, 0.80), UI.CYAN, 10))
	UI.place(panel, safe, Rect2(0.32, 0.07, 0.36, 0.11))
	var box := UI.column(panel, 0)
	_label = UI.label("ESPERANDO RIVALES", 26, UI.AMBER)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_label)
	_detail = UI.label("", 22)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_detail)
	_session = get_parent().get_node_or_null("NetworkSession")
	if _session != null: _session.connect("snapshot_received", _on_snapshot)

func _on_snapshot(snapshot: Dictionary) -> void:
	var mode := Dictionary(snapshot.get("match_mode", {}))
	var phase := String(mode.get("phase", "WAITING"))
	var seconds := int(mode.get("remaining", 300))
	_label.text = "PREPARANDO ENFRENTAMIENTO" if phase == "WAITING" else "FINALIZADO" if phase == "FINISHED" else "%02d:%02d  ·  PRIMERO EN %d" % [seconds / 60, seconds % 60, int(mode.get("kill_target", 10))]
	var scores := Dictionary(mode.get("scores", {}))
	var text: Array[String] = []
	var local_team := -1
	for value in Array(snapshot.get("players", [])):
		if int(value.get("entity_id", 0)) == int(_session.get("local_entity_id")): local_team = int(value.get("team_id", -1))
	for team in scores:
		text.append("%s %d" % ["TÚ" if int(team) == local_team else "RIVAL %d" % (int(team) + 1), int(scores[team])])
	_detail.text = "  /  ".join(text) if phase != "WAITING" else "La partida empieza cuando estén listos · Protección al reaparecer: 2 s"
