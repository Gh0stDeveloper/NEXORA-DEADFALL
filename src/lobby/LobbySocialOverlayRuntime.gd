extends "res://src/lobby/LobbySocialOverlay.gd"

func allow_match_reentry(match_id: String = "") -> void:
	if match_id.is_empty() or _last_match_emitted == match_id:
		_last_match_emitted = ""
