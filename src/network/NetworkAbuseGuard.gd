class_name DeadfallNetworkAbuseGuard
extends RefCounted

const MAX_STRIKES := 10
const RULES := {
	&"hello": {"limit": 6, "window_usec": 30_000_000},
	&"join": {"limit": 6, "window_usec": 30_000_000},
	&"command": {"limit": 180, "window_usec": 1_000_000},
	&"fire": {"limit": 32, "window_usec": 1_000_000},
	&"reload": {"limit": 8, "window_usec": 3_000_000},
	&"restart": {"limit": 4, "window_usec": 10_000_000},
}

var _windows: Dictionary = {}
var _strikes: Dictionary = {}
var _last_reason: Dictionary = {}

func allow(peer_id: int, action: StringName, now_usec: int = 0) -> bool:
	if peer_id <= 0 or not RULES.has(action):
		return false
	var now := now_usec if now_usec > 0 else Time.get_ticks_usec()
	var rule: Dictionary = RULES[action]
	var cutoff := now - int(rule.get("window_usec", 1_000_000))
	var peer_windows: Dictionary = _windows.get(peer_id, {})
	var samples: Array = peer_windows.get(action, [])
	var retained: Array = []
	for sample in samples:
		if int(sample) > cutoff:
			retained.append(sample)
	if retained.size() >= int(rule.get("limit", 1)):
		peer_windows[action] = retained
		_windows[peer_id] = peer_windows
		record_strike(peer_id, "rate_limit:%s" % String(action), 2)
		return false
	retained.append(now)
	peer_windows[action] = retained
	_windows[peer_id] = peer_windows
	return true

func validate_payload(payload, max_bytes: int) -> bool:
	if max_bytes <= 0:
		return false
	return var_to_bytes(payload).size() <= max_bytes

func record_strike(peer_id: int, reason: String, weight: int = 1) -> int:
	if peer_id <= 0:
		return 0
	var strikes := clampi(int(_strikes.get(peer_id, 0)) + maxi(1, weight), 0, 100)
	_strikes[peer_id] = strikes
	_last_reason[peer_id] = reason.left(96)
	return strikes

func should_disconnect(peer_id: int) -> bool:
	return int(_strikes.get(peer_id, 0)) >= MAX_STRIKES

func forget_peer(peer_id: int) -> void:
	_windows.erase(peer_id)
	_strikes.erase(peer_id)
	_last_reason.erase(peer_id)

func get_peer_snapshot(peer_id: int) -> Dictionary:
	return {
		"strikes": int(_strikes.get(peer_id, 0)),
		"disconnect": should_disconnect(peer_id),
		"last_reason": String(_last_reason.get(peer_id, "")),
	}
