class_name DeadfallImportedAnimationDriver
extends RefCounted

const DEFAULT_KEYWORDS := ["idle", "stand", "breath", "walk", "run", "locomotion", "move", "attack"]
const REJECTED_KEYWORDS := ["death", "die", "dead", "ragdoll", "hit", "hurt", "damage", "fall"]

static func play_best_pose(root: Node, preferred_keywords: Array = DEFAULT_KEYWORDS) -> Dictionary:
	if root == null:
		return {"ok": false, "reason": "missing_root"}
	var players: Array[AnimationPlayer] = []
	_collect_animation_players(root, players)
	if players.is_empty():
		return {"ok": false, "reason": "no_animation_player"}

	var best_player: AnimationPlayer
	var best_name := StringName()
	var best_score := -100000
	var clip_count := 0
	for player in players:
		for animation_name in player.get_animation_list():
			var normalized := String(animation_name).strip_edges().to_lower()
			if normalized.is_empty() or normalized == "reset" or normalized.ends_with("/reset"):
				continue
			clip_count += 1
			var score := _score_animation_name(normalized, preferred_keywords)
			if score > best_score:
				best_score = score
				best_player = player
				best_name = animation_name

	if best_player == null or best_name.is_empty():
		return {"ok": false, "reason": "no_usable_animation", "clip_count": clip_count}

	best_player.play(best_name)
	# AnimationPlayer.play() applies the new animation on its next processing
	# tick. Imported GLBs can otherwise be visible for one frame in bind/T-pose.
	# advance(0) evaluates the selected clip immediately without advancing time.
	best_player.advance(0.0)
	return {
		"ok": true,
		"animation": String(best_name),
		"score": best_score,
		"clip_count": clip_count,
		"player_path": String(best_player.get_path()),
	}

static func has_usable_animation(root: Node) -> bool:
	if root == null:
		return false
	var players: Array[AnimationPlayer] = []
	_collect_animation_players(root, players)
	for player in players:
		for animation_name in player.get_animation_list():
			var normalized := String(animation_name).strip_edges().to_lower()
			if not normalized.is_empty() and normalized != "reset" and not normalized.ends_with("/reset"):
				return true
	return false

static func animation_inventory(root: Node) -> Array[String]:
	var result: Array[String] = []
	if root == null:
		return result
	var players: Array[AnimationPlayer] = []
	_collect_animation_players(root, players)
	for player in players:
		for animation_name in player.get_animation_list():
			result.append("%s:%s" % [String(player.get_path()), String(animation_name)])
	return result

static func _score_animation_name(normalized: String, preferred_keywords: Array) -> int:
	var score := 1
	for rejected in REJECTED_KEYWORDS:
		if normalized.contains(String(rejected)):
			score -= 80
	for index in range(preferred_keywords.size()):
		var keyword := String(preferred_keywords[index]).to_lower()
		if not keyword.is_empty() and normalized.contains(keyword):
			score += 200 - index * 12
	return score

static func _collect_animation_players(node: Node, output: Array[AnimationPlayer]) -> void:
	if node is AnimationPlayer:
		output.append(node as AnimationPlayer)
	for child in node.get_children():
		_collect_animation_players(child, output)
