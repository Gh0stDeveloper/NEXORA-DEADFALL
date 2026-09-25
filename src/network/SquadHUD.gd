class_name DeadfallSquadHUD
extends CanvasLayer

const SafeAreaScript = preload("res://src/mobile/SafeArea.gd")

var _session: Node
var _safe_root: Control
var _title: Label
var _labels: Array[Label] = []

func bind_session(session: Node) -> void:
	_session = session
	if _session != null and _session.has_signal("snapshot_received"):
		var callable := Callable(self, "_on_snapshot_received")
		if not _session.is_connected("snapshot_received", callable):
			_session.connect("snapshot_received", callable)

func _ready() -> void:
	_build_hud()

func _build_hud() -> void:
	_safe_root = SafeAreaScript.new()
	_safe_root.name = "SafeArea"
	add_child(_safe_root)
	_safe_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.name = "SquadPanel"
	panel.position = Vector2(24, 128)
	panel.size = Vector2(330, 214)
	panel.modulate = Color(1, 1, 1, 0.86)
	_safe_root.add_child(panel)

	var box := VBoxContainer.new()
	box.name = "VBox"
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)

	_title = Label.new()
	_title.text = "SQUAD 0/4"
	_title.add_theme_font_size_override("font_size", 18)
	box.add_child(_title)

	for index in range(4):
		var label := Label.new()
		label.name = "Player%d" % (index + 1)
		label.text = "--"
		label.add_theme_font_size_override("font_size", 16)
		box.add_child(label)
		_labels.append(label)

func _on_snapshot_received(snapshot: Dictionary) -> void:
	var players: Array = Array(snapshot.get("players", [])).duplicate(true)
	var mode := Dictionary(snapshot.get("match_mode", {}))
	if String(mode.get("game_mode", "")).begins_with("pvp_"):
		var local_team := -1
		for player in players:
			if _session != null and int(player.get("entity_id", 0)) == int(_session.get("local_entity_id")):
				local_team = int(player.get("team_id", -1))
		players = players.filter(func(player: Dictionary) -> bool: return int(player.get("team_id", -2)) == local_team)

	_title.text = "SQUAD %d/4" % mini(4, players.size())
	for index in range(_labels.size()):
		_labels[index].text = "--"
	for index in range(mini(players.size(), _labels.size())):
		var player: Dictionary = players[index]
		_labels[index].text = _format_player(player)

func _format_player(player: Dictionary) -> String:
	var entity_id := int(player.get("entity_id", 0))
	var name := String(player.get("name", "Player"))
	if _session != null and int(_session.get("local_entity_id")) == entity_id:
		name += " [YOU]"
	var life: Dictionary = player.get("life", {})
	var state := int(life.get("state", 0))
	if state == 1:
		var bleedout := int(ceil(float(life.get("bleedout", 0.0))))
		var progress := int(round(float(life.get("revive_progress", 0.0)) * 100.0))
		return "%s  DOWN %ds  REV %d%%" % [name, bleedout, progress]
	if state == 2 or bool(player.get("dead", false)):
		return "%s  DEAD" % name
	return "%s  HP %d/%d" % [name, int(round(float(player.get("health", 0.0)))), int(round(float(player.get("max_health", 100.0))))]
