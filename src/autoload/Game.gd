extends Node

const LocalAuthorityScript = preload("res://src/core/authority/LocalAuthority.gd")
const DedicatedAuthorityScript = preload("res://src/core/authority/DedicatedAuthority.gd")
const NetworkAuthorityScript = preload("res://src/core/authority/NetworkAuthority.gd")

enum SessionMode {
	NONE,
	LOCAL,
	DEDICATED_SERVER,
	NETWORK_CLIENT,
}

var session_mode: SessionMode = SessionMode.NONE
var authority: RefCounted

func start_local_session() -> void:
	_replace_authority(LocalAuthorityScript.new(), SessionMode.LOCAL)

func start_dedicated_server_session() -> void:
	_replace_authority(DedicatedAuthorityScript.new(), SessionMode.DEDICATED_SERVER)

func start_network_client_session() -> void:
	_replace_authority(NetworkAuthorityScript.new(), SessionMode.NETWORK_CLIENT)

func stop_session() -> void:
	if authority != null:
		authority.stop()
	authority = null
	session_mode = SessionMode.NONE

func is_local_session() -> bool:
	return session_mode == SessionMode.LOCAL and authority != null

func is_dedicated_server() -> bool:
	return session_mode == SessionMode.DEDICATED_SERVER and authority != null

func is_simulation_authority() -> bool:
	return authority != null and session_mode in [SessionMode.LOCAL, SessionMode.DEDICATED_SERVER]

func is_network_client() -> bool:
	return session_mode == SessionMode.NETWORK_CLIENT and authority != null

func get_active_authority():
	return authority

func _replace_authority(next_authority: RefCounted, next_mode: int) -> void:
	if authority != null:
		authority.stop()
	authority = next_authority
	session_mode = next_mode as SessionMode
	if authority != null:
		authority.start()
