extends SceneTree
var _store: Node
var _social: Node
var _tokens: Array[String] = []
var _guests: Array[String] = []
var _launched: Array = []

class IsolatedAccountStore:
	extends "res://src/server/GuestAccountStore.gd"
	func _load() -> void: pass
	func _save() -> void: pass

class IsolatedSocialStore:
	extends "res://src/server/SocialService.gd"
	var stored: Dictionary = {}
	func _save() -> void:
		stored = {"friends": _friends.duplicate(true), "history": _match_history.duplicate(true)}
	func _load() -> void:
		_friends = stored.get("friends", {}).duplicate(true)
		_match_history = stored.get("history", {}).duplicate(true)

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	create_timer(35).timeout.connect(func() -> void: quit(1))
	_store = IsolatedAccountStore.new()
	root.add_child(_store)
	_social = IsolatedSocialStore.new()
	root.add_child(_social)
	_social.configure(_store)
	for index in range(4):
		var guest := "gst_beta8_test_%s" % str(index).repeat(20)
		_guests.append(guest)
		var registration: Dictionary = _store.register_claim({"guest_id": guest, "username": "B8Tester%d" % index, "secret_verifier": "a".repeat(64)})
		assert(registration.get("ok", false))
		_tokens.append(String(_social.issue_session(guest).session_token))
	var search: Dictionary = _social.search_players(_tokens[0], "b8tester1")
	assert(search.ok and search.players.size() == 1 and not search.players[0].has("secret_verifier"))
	assert(_store.resolve_guest_id("B8Tester1") == _guests[1])
	assert(_social.request_friend(_tokens[0], _guests[1]).ok)
	assert(_social.friends_snapshot(_tokens[1]).friends.incoming.size() == 1)
	assert(_social.accept_friend(_tokens[1], _guests[0]).ok)
	assert(_social.friends_snapshot(_tokens[0]).friends.accepted.size() == 1)
	assert(_social.request_friend(_tokens[2], _guests[1]).ok)
	assert(_social.reject_friend(_tokens[1], _guests[2]).ok)
	assert(_social.friends_snapshot(_tokens[2]).friends.outgoing_ids.is_empty())
	assert(not _social.match_history("").ok)
	var result := {"match_id": "beta8-real-result-test", "server_authoritative": true, "outcome": "VICTORY", "winner_team": 0, "player_stats": {_guests[0]: {"kills": 10, "damage": 980}}, "completed_unix": int(Time.get_unix_time_from_system()), "uptime_seconds": 120}
	var teams := {_guests[0]: 0, _guests[1]: 1}
	_social.record_match_result([_guests[0], _guests[1]], result, "pvp_ffa", teams)
	_social.record_match_result([_guests[0], _guests[1]], result, "pvp_ffa", teams)
	assert(_social.match_history(_tokens[0]).matches.size() == 1)
	assert(_social.match_history(_tokens[0]).matches[0].kills == 10)
	assert(_social.match_history(_tokens[1]).matches[0].outcome == "DEFEAT")
	_social._load()
	assert(_social.match_history(_tokens[0]).stats.wins == 1, "History did not survive reload")
	assert(_social.friends_snapshot(_tokens[0]).friends.accepted.size() == 1, "Friends did not survive reload")
	assert(_test_queue())
	assert(await _test_pvp())
	_social.free()
	_store.free()
	await process_frame
	print("NEXORA: DEADFALL social history, flexible queue and PvP authority smoke passed")
	quit(0)

func _test_queue() -> bool:
	var queue: RefCounted = load("res://src/server/MatchQueue.gd").new()
	queue.social = _social
	queue.launcher = func(parties: Array, mission: String, mode: String, teams: Dictionary) -> Dictionary:
		_launched.append({"parties": parties, "mission": mission, "mode": mode, "teams": teams})
		return {"ok": true}
	var first: Dictionary = _social.create_party(_tokens[0], 4).party
	assert(_social.join_party(_tokens[1], first.code).ok)
	# Resizing formation must preserve the existing teammate.
	assert(_social.create_party(_tokens[0], 2).party.members.size() == 2)
	assert(_social.create_party(_tokens[0], 4).party.members.size() == 2)
	var second: Dictionary = _social.create_party(_tokens[2], 4).party
	var third: Dictionary = _social.create_party(_tokens[3], 2).party
	queue.enqueue(_social.server_party_record(first.code), "waves", "mission_01_first_signal")
	queue.enqueue(_social.server_party_record(second.code), "waves", "mission_01_first_signal")
	queue.enqueue(_social.server_party_record(third.code), "endless", "mission_01_first_signal")
	assert(not _social.leave_party(_tokens[0]).ok, "Queued party was mutable")
	assert(queue.plan_for(first.code, Time.get_ticks_usec()).is_empty(), "Incomplete squad skipped fill window")
	queue.tick(Time.get_ticks_usec() + 9_000_000)
	assert(_launched.size() == 2)
	assert(_launched[0].teams.size() == 3 and _launched[0].mode == "waves", "Compatible incomplete squad was not filled")
	assert(_launched[1].teams.size() == 1 and _launched[1].mode == "endless", "Single duo could not start alone")
	assert(queue.entries.is_empty())
	_launched.clear()
	_social.create_party(_tokens[0], 2)
	_social.create_party(_tokens[3], 2)
	queue.enqueue(_social.server_party_record(first.code), "pvp_duo", "mission_01_first_signal")
	queue.enqueue(_social.server_party_record(third.code), "pvp_duo", "mission_01_first_signal")
	queue.tick(Time.get_ticks_usec() + 9_000_000)
	assert(_launched.size() == 1 and _launched[0].teams[_guests[0]] == _launched[0].teams[_guests[1]])
	assert(_launched[0].teams[_guests[0]] != _launched[0].teams[_guests[3]], "Duo had no opposing team")
	_launched.clear()
	queue.enqueue(_social.server_party_record(third.code), "pvp_ffa", "mission_01_first_signal")
	queue.tick(Time.get_ticks_usec() + 31_000_000)
	assert(_launched.is_empty() and queue.entries.is_empty(), "PvP launched without rival")
	assert(_social.current_party(_tokens[3]).party.queue_error == "no_opponents")
	queue.enqueue(_social.server_party_record(third.code), "campaign", "mission_01_first_signal")
	queue.cancel(third.code)
	assert(queue.entries.is_empty() and _social.current_party(_tokens[3]).party.state == "OPEN")

	return true

func _test_pvp() -> bool:
	var game := root.get_node("Game")
	game.start_dedicated_server_session()
	var arena := load("res://src/maps/campaign/OutbreakDistrict.tscn").instantiate() as Node3D
	arena.game_mode = "pvp_duo"
	root.add_child(arena)
	var session := arena.get_node("NetworkSession")
	var mode := arena.get_node("MatchModeDirector")
	var horde := arena.get_node("HordeDirector")
	assert(not horde.start_run(), "PvP spawned zombies")
	var players: Array[Node3D] = []
	for index in range(3):
		var player: Node3D = session._spawn_player(101 + index, 2, index)
		player.set_physics_process(false)
		mode.register_member(player, {"guest_id": _guests[index], "team_id": 1 if index == 1 else 0})
		player.set_meta("spawn_shield_until", 0)
		players.append(player)
	mode.phase = "RUNNING"
	players[0].position = Vector3(0, 0.2, 0)
	players[0].rotation = Vector3.ZERO
	players[1].position = Vector3(0, 0.2, -5)
	players[2].position = Vector3(5, 0.2, 0)
	var event: RefCounted = load("res://src/core/damage/DamageEvent.gd").new()
	event.attacker_id = 101
	event.victim_id = 103
	event.amount = 500
	assert(not game.authority.resolve_damage(event), "Friendly damage was allowed")
	event.victim_id = 102
	mode.phase = "WAITING"
	assert(not game.authority.resolve_damage(event), "Warmup damage was allowed")
	mode.phase = "RUNNING"
	for frame in range(4): await physics_frame
	var rifle := players[0].get_node("PrimaryWeapon")
	assert(rifle.server_try_fire(1))
	assert(players[1].get_node("Health").current_health < 100, "PvP ray did not hit player hitboxes")
	while Time.get_ticks_usec() - int(rifle._state.last_shot_usec) < 150000:
		await process_frame
	assert(rifle.server_try_fire(2))
	assert(players[1].get_node("Health").is_dead(), "PvP should kill instead of down")
	assert(mode.player_stats[_guests[0]].kills == 1)
	mode._respawns[102] = Time.get_ticks_usec() - 1
	mode._process(0)
	assert(not players[1].get_node("Health").is_dead() and players[1].get_node("LifeState").is_alive(), "Respawn failed")
	assert(not game.authority.resolve_damage(event), "Spawn shield did not protect respawn")
	players[1].set_meta("spawn_shield_until", 0)
	mode._team_scores[0] = 9
	var ended: Array = []
	mode.finished.connect(func(outcome: String, reason: String) -> void: ended.append([outcome, reason]))
	assert(game.authority.resolve_damage(event))
	assert(ended.size() == 1 and mode.phase == "FINISHED" and mode.winner_team == 0)
	assert(not game.authority.resolve_damage(event), "Finished match still accepted damage")
	# Departed players remain in the identity/statistics registry. Never cast
	# their freed scene nodes while ticking or during a pending respawn.
	players[1].free()
	mode.phase = "RUNNING"
	mode._respawns[102] = Time.get_ticks_usec() - 1
	mode._process(0)
	mode._physics_process(0)
	assert(mode._active_players().size() == 2)
	assert(not game.authority.resolve_damage(event), "Damage targeted a departed player")
	while not arena.navigation_is_ready: await process_frame
	arena.free()
	game.stop_session()

	return true
