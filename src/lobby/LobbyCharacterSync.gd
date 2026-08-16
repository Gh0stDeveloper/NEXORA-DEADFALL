class_name DeadfallLobbyCharacterSync
extends Node

func _ready() -> void:
	if GuestIdentity.has_signal("selected_character_changed"):
		GuestIdentity.selected_character_changed.connect(_on_selected_character_changed)

func _on_selected_character_changed(character_id: StringName) -> void:
	if SocialClient.has_session():
		SocialClient.update_selected_character(character_id)
