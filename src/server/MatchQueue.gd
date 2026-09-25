class_name DeadfallMatchQueue
extends RefCounted

const FILL_WAIT_USEC := 8_000_000
const RIVAL_WAIT_USEC := 30_000_000
const Catalog = preload("res://src/modes/ModeCatalog.gd")
var social: Node
var launcher: Callable
var entries: Dictionary = {}

func enqueue(party: Dictionary, mode: String, mission: String) -> Dictionary:
	var code := String(party.get("code", ""))
	if entries.has(code): return {"ok": true, "queued": true}
	var definition := Catalog.find(mode)
	if definition.is_empty(): return {"ok": false, "reason": "invalid_game_mode"}
	var capacity := int(party.get("capacity", 1))
	if capacity not in definition.formations: return {"ok": false, "reason": "mode_capacity_invalid"}
	if mode == "pvp_squad" and Array(party.get("members", [])).size() < 2:
		return {"ok": false, "reason": "party_needs_opponent"}
	if entries.size() >= 128: return {"ok": false, "reason": "match_capacity_reached"}
	entries[code] = {"code": code, "mode": mode, "mission": mission, "capacity": capacity,
		"members": Array(party.get("members", [])).duplicate(), "created_usec": Time.get_ticks_usec()}
	social.call("set_party_queue", code, {"mode": mode, "status": "SEARCHING", "started_unix": int(Time.get_unix_time_from_system()), "wait_seconds": 30 if Catalog.is_pvp(mode) else 8})
	return {"ok": true, "queued": true}

func cancel(code: String, reason: String = "") -> void:
	entries.erase(code)
	social.call("set_party_queue", code, {}, reason)

func tick(now_usec: int = -1) -> void:
	var now := Time.get_ticks_usec() if now_usec < 0 else now_usec
	for code in entries.keys().duplicate():
		if not entries.has(code): continue
		var entry: Dictionary = entries[code]
		var party: Dictionary = social.call("server_party_record", String(code))
		if party.is_empty() or Array(party.get("members", [])) != Array(entry.members) or not bool(social.call("party_members_online", String(code))):
			cancel(String(code), "queue_member_offline")
	for code in entries.keys().duplicate():
		if not entries.has(code): continue
		var plan := plan_for(String(code), now)
		if plan.is_empty(): continue
		if plan.has("reason"):
			cancel(String(code), String(plan.reason))
			continue
		var parties: Array = []
		for selected in plan.codes:
			parties.append(social.call("server_party_record", String(selected)))
		var entry: Dictionary = entries[code]
		var result: Dictionary = launcher.call(parties, String(entry.mission), String(entry.mode), Dictionary(plan.teams))
		for selected in plan.codes:
			# Clear only the queue; never overwrite an assignment already created.
			cancel(String(selected), "" if result.get("ok", false) else String(result.get("reason", "match_start_failed")))

func plan_for(code: String, now: int) -> Dictionary:
	if not entries.has(code): return {}
	var first: Dictionary = entries[code]
	var mode := String(first.mode)
	var capacity := int(first.capacity)
	var is_pvp := Catalog.is_pvp(mode)
	var maximum := 4 if is_pvp else capacity
	var codes: Array = [code]
	var members: Array = Array(first.members).duplicate()
	var teams := {}
	var team_counts := [0, 0]
	for guest in members:
		teams[guest] = members.find(guest) if is_pvp and mode != "pvp_duo" else 0
	team_counts[0] = members.size()
	if mode != "pvp_squad":
		for candidate_code in entries:
			if candidate_code == code: continue
			var candidate: Dictionary = entries[candidate_code]
			if candidate.mode != mode or candidate.mission != first.mission: continue
			if not is_pvp and int(candidate.capacity) != capacity: continue
			var incoming: Array = candidate.members
			if incoming.size() + members.size() > maximum: continue
			var team := 0
			if mode == "pvp_duo":
				team = 0 if int(team_counts[0]) < int(team_counts[1]) else 1
				if int(team_counts[team]) + incoming.size() > 2:
					team = 1 - team
				if int(team_counts[team]) + incoming.size() > 2: continue
			for guest in incoming:
				teams[guest] = members.size() if is_pvp and mode != "pvp_duo" else team
				members.append(guest)
			team_counts[team] += incoming.size()
			codes.append(candidate_code)
	var elapsed := now - int(first.created_usec)
	var has_opponent: bool = members.size() >= 2 and (mode != "pvp_duo" or int(team_counts[1]) > 0)
	if is_pvp and not has_opponent:
		return {"reason": "no_opponents"} if elapsed >= RIVAL_WAIT_USEC else {}
	if mode == "pvp_squad" or members.size() == maximum or elapsed >= FILL_WAIT_USEC:
		return {"codes": codes, "teams": teams}
	return {}
