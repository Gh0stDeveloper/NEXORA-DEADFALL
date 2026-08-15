extends Node

const LocalAuthorityScript = preload("res://src/core/authority/LocalAuthority.gd")

enum SessionMode {
	NONE,
	LOCAL,
	DEDICATED_SERVER,
	NETWORK_CLIENT,
}

var session_mode: SessionMode = SessionMode.NONE
var authority: RefCounted

func start_local_session() -> void:
	session_mode = SessionMode.LOCAL
	authority = LocalAuthorityScript.new()
	authority.start()

func stop_session() -> void:
	if authority != null:
		authority.stop()
	authority = null
	session_mode = SessionMode.NONE
