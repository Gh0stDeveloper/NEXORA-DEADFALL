extends Node

enum SessionMode {
	NONE,
	LOCAL,
	DEDICATED_SERVER,
	NETWORK_CLIENT,
}

var session_mode: SessionMode = SessionMode.NONE
var authority: GameAuthority

func start_local_session() -> void:
	session_mode = SessionMode.LOCAL
	authority = LocalAuthority.new()
	authority.start()

func stop_session() -> void:
	if authority != null:
		authority.stop()
	authority = null
	session_mode = SessionMode.NONE
