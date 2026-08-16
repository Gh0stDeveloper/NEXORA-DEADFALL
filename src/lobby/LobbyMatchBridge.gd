class_name DeadfallLobbyMatchBridge
extends Node

func _ready() -> void:
	var lobby := get_parent()
	if lobby == null:
		return
	var overlay := lobby.get_node_or_null("SocialOverlay")
	if overlay != null and overlay.has_signal("online_match_ready"):
		overlay.connect("online_match_ready", Callable(self, "_on_online_match_ready"))

func _on_online_match_ready(match: Dictionary) -> void:
	var lobby := get_parent()
	var main := lobby.get_parent() if lobby != null else null
	if main != null and main.has_method("_on_lobby_online_match_ready"):
		main.call("_on_lobby_online_match_ready", match, lobby)
