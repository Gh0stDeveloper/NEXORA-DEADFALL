class_name DeadfallImportedAnimationDriver
extends RefCounted

const DEFAULT_KEYWORDS := ["idle", "stand", "breath", "walk", "run", "locomotion", "move", "attack"]
const SEMANTIC_KEYWORDS := {
	&"idle": ["idle", "stand", "breath", "rest", "default"],
	&"walk": ["walk", "walking", "locomotion", "move"],
	&"run": ["run", "running", "sprint", "jog"],
	&"crawl": ["crawl", "crawling", "prone", "downed"],
	&"attack": ["attack", "attacking", "melee", "slash", "swing", "bite", "punch"],
	&"hurt": ["hurt", "hit", "damage", "stagger", "react", "impact"],
	&"death": ["death", "die", "dying", "dead", "fall"],
	&"reload": ["reload", "reloading"],
}
const FALLBACK_SEMANTICS := {
	&"walk": [&"idle"],
	&"run": [&"walk", &"idle"],
	&"crawl": [&"walk", &"idle"],
	&"attack": [],
	&"hurt": [],
	&"death": [],
	&"reload": [&"idle"],
}
const UNSAFE_GENERIC_KEYWORDS := ["death", "die", "dead", "ragdoll", "hurt", "damage", "fall", "attack", "melee", "slash", "bite", "punch"]

static func play_best_pose(root: Node, preferred_keywords: Array = DEFAULT_KEYWORDS) -> Dictionary:
	return _play_scored(root, preferred_keywords, &"idle", true, 0.0, 1.0)

static func play_named(root: Node, animation_name: StringName, semantic: StringName = &"", blend_seconds: float = 0.12, speed: float = 1.0) -> Dictionary:
	if root == null:
		return {"ok": false, "reason": "missing_root", "semantic": String(semantic)}
	if animation_name.is_empty():
		return {"ok": false, "reason": "missing_animation_name", "semantic": String(semantic)}
	var players: Array[AnimationPlayer] = []
	_collect_animation_players(root, players)
	for player in players:
		if not player.has_animation(animation_name):
			continue
		player.play(animation_name, maxf(0.0, blend_seconds), maxf(0.05, speed))
		player.advance(0.0)
		return {
			"ok": true,
			"animation": String(animation_name),
			"semantic": String(semantic),
			"matched": true,
			"explicit_mapping": true,
			"player_path": String(player.get_path()),
		}
	return {
		"ok": false,
		"reason": "named_animation_missing",
		"animation": String(animation_name),
		"semantic": String(semantic),
	}

static func play_semantic(root: Node, semantic: StringName, blend_seconds: float = 0.12, speed: float = 1.0) -> Dictionary:
	if root == null:
		return {"ok": false, "reason": "missing_root", "semantic": String(semantic)}
	var requested := semantic if SEMANTIC_KEYWORDS.has(semantic) else &"idle"
	var keywords: Array = Array(SEMANTIC_KEYWORDS.get(requested, SEMANTIC_KEYWORDS[&"idle"]))
	var result := _play_scored(root, keywords, requested, false, blend_seconds, speed)
	if bool(result.get("ok", false)):
		return result
	for fallback_value in Array(FALLBACK_SEMANTICS.get(requested, [])):
		var fallback := StringName(fallback_value)
		var fallback_result := _play_scored(
			root,
			Array(SEMANTIC_KEYWORDS.get(fallback, SEMANTIC_KEYWORDS[&"idle"])),
			fallback,
			false,
			blend_seconds,
			speed
		)
		if bool(fallback_result.get("ok", false)):
			fallback_result["requested_semantic"] = String(requested)
			fallback_result["fallback"] = true
			return fallback_result

	# Some imported Mixamo/Sketchfab GLBs expose one valid clip under a generic
	# library name (for example "mixamo_com"). A single neutral-looking generic
	# clip is safe as a degraded presentation fallback and prevents bind/T-pose.
	# Multiple unlabeled clips stay ambiguous and are not guessed.
	var generic_result := _find_safe_generic_candidate(root, requested)
	if bool(generic_result.get("ok", false)):
		var player := generic_result.get("player") as AnimationPlayer
		var animation_name := StringName(generic_result.get("animation", ""))
		if player != null and not animation_name.is_empty():
			player.play(animation_name, maxf(0.0, blend_seconds), maxf(0.05, speed))
			player.advance(0.0)
			generic_result.erase("player")
			generic_result["semantic"] = String(requested)
			generic_result["requested_semantic"] = String(requested)
			generic_result["fallback"] = true
			generic_result["generic_fallback"] = true
			generic_result["matched"] = false
			generic_result["player_path"] = String(player.get_path())
			return generic_result
	return result

static func has_named_animation(root: Node, animation_name: StringName) -> bool:
	if root == null or animation_name.is_empty():
		return false
	var players: Array[AnimationPlayer] = []
	_collect_animation_players(root, players)
	for player in players:
		if player.has_animation(animation_name):
			return true
	return false

static func has_semantic_animation(root: Node, semantic: StringName) -> bool:
	if root == null:
		return false
	var keywords: Array = Array(SEMANTIC_KEYWORDS.get(semantic, [String(semantic)]))
	var candidate := _find_best_candidate(root, keywords, semantic, false)
	return bool(candidate.get("ok", false))

static func has_usable_animation(root: Node) -> bool:
	return not _usable_clips(root).is_empty()

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

static func semantic_inventory(root: Node) -> Dictionary:
	var result := {}
	for semantic in SEMANTIC_KEYWORDS.keys():
		var candidate := _find_best_candidate(root, Array(SEMANTIC_KEYWORDS[semantic]), StringName(semantic), false)
		if bool(candidate.get("ok", false)):
			result[String(semantic)] = String(candidate.get("animation", ""))
	return result

static func generic_animation(root: Node) -> Dictionary:
	var candidate := _find_safe_generic_candidate(root, &"idle")
	if not bool(candidate.get("ok", false)):
		return candidate
	candidate.erase("player")
	candidate["generic_fallback"] = true
	return candidate

static func capability_snapshot(root: Node) -> Dictionary:
	var semantic := semantic_inventory(root)
	var generic := generic_animation(root)
	return {
		"usable": has_usable_animation(root),
		"semantic": semantic,
		"semantic_count": semantic.size(),
		"generic": generic,
		"generic_fallback": bool(generic.get("ok", false)),
		"inventory": animation_inventory(root),
	}

static func _play_scored(root: Node, keywords: Array, semantic: StringName, allow_generic: bool, blend_seconds: float, speed: float) -> Dictionary:
	var candidate := _find_best_candidate(root, keywords, semantic, allow_generic)
	if not bool(candidate.get("ok", false)):
		return candidate
	var player := candidate.get("player") as AnimationPlayer
	var animation_name := StringName(candidate.get("animation", ""))
	if player == null or animation_name.is_empty():
		return {"ok": false, "reason": "invalid_candidate", "semantic": String(semantic)}
	player.play(animation_name, maxf(0.0, blend_seconds), maxf(0.05, speed))
	player.advance(0.0)
	candidate.erase("player")
	candidate["semantic"] = String(semantic)
	candidate["player_path"] = String(player.get_path())
	return candidate

static func _find_best_candidate(root: Node, preferred_keywords: Array, semantic: StringName, allow_generic: bool) -> Dictionary:
	if root == null:
		return {"ok": false, "reason": "missing_root", "semantic": String(semantic)}
	var players: Array[AnimationPlayer] = []
	_collect_animation_players(root, players)
	if players.is_empty():
		return {"ok": false, "reason": "no_animation_player", "semantic": String(semantic)}

	var best_player: AnimationPlayer
	var best_name := StringName()
	var best_score := -100000
	var clip_count := 0
	var semantic_match := false
	for player in players:
		for animation_name in player.get_animation_list():
			var normalized := String(animation_name).strip_edges().to_lower()
			if not _is_usable_clip_name(normalized):
				continue
			clip_count += 1
			var scored := _score_animation_name(normalized, preferred_keywords, semantic)
			var score := int(scored.get("score", -100000))
			var matched := bool(scored.get("matched", false))
			if score > best_score:
				best_score = score
				best_player = player
				best_name = animation_name
				semantic_match = matched

	if best_player == null or best_name.is_empty():
		return {"ok": false, "reason": "no_usable_animation", "clip_count": clip_count, "semantic": String(semantic)}
	if not semantic_match and not allow_generic:
		return {
			"ok": false,
			"reason": "semantic_clip_missing",
			"semantic": String(semantic),
			"clip_count": clip_count,
			"best_candidate": String(best_name),
		}
	return {
		"ok": true,
		"animation": String(best_name),
		"score": best_score,
		"clip_count": clip_count,
		"matched": semantic_match,
		"player": best_player,
	}

static func _find_safe_generic_candidate(root: Node, semantic: StringName) -> Dictionary:
	var clips := _usable_clips(root)
	if clips.size() != 1:
		return {"ok": false, "reason": "generic_clip_ambiguous", "clip_count": clips.size(), "semantic": String(semantic)}
	var entry: Dictionary = clips[0]
	var normalized := String(entry.get("normalized", ""))
	for unsafe_keyword in UNSAFE_GENERIC_KEYWORDS:
		if normalized.contains(unsafe_keyword):
			return {"ok": false, "reason": "generic_clip_not_neutral", "clip_count": 1, "semantic": String(semantic), "best_candidate": String(entry.get("animation", ""))}
	return {
		"ok": true,
		"animation": String(entry.get("animation", "")),
		"score": 1,
		"clip_count": 1,
		"matched": false,
		"player": entry.get("player"),
	}

static func _usable_clips(root: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if root == null:
		return result
	var players: Array[AnimationPlayer] = []
	_collect_animation_players(root, players)
	for player in players:
		for animation_name in player.get_animation_list():
			var normalized := String(animation_name).strip_edges().to_lower()
			if _is_usable_clip_name(normalized):
				result.append({"player": player, "animation": String(animation_name), "normalized": normalized})
	return result

static func _is_usable_clip_name(normalized: String) -> bool:
	return not normalized.is_empty() and normalized != "reset" and not normalized.ends_with("/reset")

static func _score_animation_name(normalized: String, preferred_keywords: Array, semantic: StringName) -> Dictionary:
	var score := 1
	var matched := false
	for index in range(preferred_keywords.size()):
		var keyword := String(preferred_keywords[index]).to_lower()
		if not keyword.is_empty() and normalized.contains(keyword):
			score += 320 - index * 18
			matched = true
	if semantic not in [&"death", &"hurt"]:
		for rejected in ["death", "die", "dead", "ragdoll", "hurt", "damage", "fall"]:
			if normalized.contains(rejected):
				score -= 120
	if semantic != &"attack":
		for attack_word in ["attack", "melee", "slash", "bite", "punch"]:
			if normalized.contains(attack_word):
				score -= 70
	return {"score": score, "matched": matched}

static func _collect_animation_players(node: Node, output: Array[AnimationPlayer]) -> void:
	if node is AnimationPlayer:
		output.append(node as AnimationPlayer)
	for child in node.get_children():
		_collect_animation_players(child, output)
