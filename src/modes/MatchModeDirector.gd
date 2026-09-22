class_name DeadfallMatchModeDirector
extends Node

signal finished(outcome: String, reason: String)
const Catalog = preload("res://src/modes/ModeCatalog.gd")
const Hitbox = preload("res://src/core/hitbox/Hitbox3D.gd")
const KILL_TARGET := 10
const TIME_LIMIT := 300.0
const JOIN_WAIT := 25.0
const RESPAWN_SECONDS := 3.0
var game_mode := "campaign"
var phase := "WAITING"
var winner_team := -1
var expected_members := 1
var remaining := TIME_LIMIT
var player_stats: Dictionary = {}
var _entities: Dictionary = {}
var _team_scores: Dictionary = {}
var _respawns: Dictionary = {}
var _first_join_usec := 0
var _all_ready_usec := 0
var _horde: Node
var _replica_snapshot: Dictionary = {}

func _ready() -> void:
	_horde = get_parent().get_node_or_null("HordeDirector")
	if Game.is_simulation_authority() and Game.authority != null:
		Game.authority.damage_filter = allow_damage
		Game.authority.damage_resolved.connect(_on_damage)
	if _horde != null and game_mode == "waves":
		_horde.connect("wave_completed", _on_wave_completed)

func register_member(player: Node3D, member: Dictionary, reconnecting: bool = false) -> void:
	if player == null or not Game.is_simulation_authority(): return
	var entity := int(player.get("player_entity_id"))
	var guest := String(member.get("guest_id", ""))
	var team := int(member.get("team_id", 0))
	_entities[entity] = {"guest_id": guest, "team": team, "player": player}
	if not player_stats.has(guest): player_stats[guest] = {"kills": 0, "damage": 0}
	if not _team_scores.has(team): _team_scores[team] = 0
	if _first_join_usec == 0: _first_join_usec = Time.get_ticks_usec()
	if not Catalog.is_pvp(game_mode): return
	configure_pvp_player(player, team)
	var died := Callable(self, "_on_player_died").bind(entity)
	if not player.get_node("Health").is_connected("died", died):
		player.get_node("Health").connect("died", died)
	if not reconnecting:
		_place_player(player, team)
	elif bool(player.get_node("Health").call("is_dead")) and not _respawns.has(entity):
		_respawns[entity] = Time.get_ticks_usec() + int(RESPAWN_SECONDS * 1_000_000)

func configure_pvp_player(player: Node3D, team: int) -> void:
	player.set_meta("team_id", team)
	player.get_node("LifeState").call("configure_squad_mode", false)
	player.get_node("PrimaryWeapon").set("hitscan_mask", 21)
	player.get_node("SecondaryWeapon").set("hitscan_mask", 21)
	player.get_node("MacheteWeapon").set("melee_mask", 21)
	if player.has_node("PvPHitboxes"): return
	var root := Node3D.new()
	root.name = "PvPHitboxes"
	player.add_child(root)
	for data in [["Torso", Vector3(0, 0.95, 0), Vector3(0.72, 1.05, 0.48), 1], ["Head", Vector3(0, 1.64, 0), Vector3(0.39, 0.38, 0.39), 0]]:
		var area := Hitbox.new()
		area.name = data[0]
		area.victim_id = int(player.get("player_entity_id"))
		area.body_part = int(data[3])
		area.collision_layer = 16
		area.collision_mask = 0
		area.monitoring = false
		area.position = data[1]
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = data[2]
		collision.shape = shape
		area.add_child(collision)
		root.add_child(area)

func _process(delta: float) -> void:
	if not Game.is_simulation_authority() or not Catalog.is_pvp(game_mode) or phase == "FINISHED": return
	var active := _active_players()
	var now := Time.get_ticks_usec()
	var teams: Array = []
	for record in active:
		if not teams.has(record.team): teams.append(record.team)
	if phase == "WAITING":
		if active.size() >= expected_members and teams.size() >= 2:
			if _all_ready_usec == 0: _all_ready_usec = now
			if now - _all_ready_usec >= 3_000_000: phase = "RUNNING"
		else:
			_all_ready_usec = 0
		if _first_join_usec > 0 and now - _first_join_usec >= int(JOIN_WAIT * 1_000_000):
			if teams.size() >= 2: phase = "RUNNING"
			else: _finish("ABORTED", "opponent_did_not_connect")
		return
	remaining = maxf(0, remaining - delta)
	for entity in _respawns.keys():
		if now >= int(_respawns[entity]):
			var record: Dictionary = _entities.get(entity, {})
			var player := record.get("player") as Node3D
			if is_instance_valid(player):
				player.get_node("Health").call("reset_health")
				player.get_node("LifeState").call("reset_authoritative_life")
				for path in ["PrimaryWeapon", "SecondaryWeapon"]:
					var weapon := player.get_node(path)
					var data: Resource = weapon.get("weapon_data")
					weapon.call("restore_authoritative_state", {"ammo": int(data.get("magazine_size")), "reserve": int(data.get("starting_reserve_ammo")), "reloading": false})
				player.get_node("WeaponLoadout").call("force_active_slot", 0)
				_place_player(player, int(record.team))
			_respawns.erase(entity)
	if remaining <= 0:
		var best := -1
		var tied := false
		for team in _team_scores:
			var score := int(_team_scores[team])
			if score > best:
				best = score
				winner_team = int(team)
				tied = false
			elif score == best: tied = true
		if tied: winner_team = -1
		_finish("DRAW" if tied else "VICTORY", "time_limit")

func allow_damage(event) -> bool:
	if not Catalog.is_pvp(game_mode):
		return not (_entities.has(int(event.attacker_id)) and _entities.has(int(event.victim_id)))
	if phase != "RUNNING": return false
	var attacker: Dictionary = _entities.get(int(event.attacker_id), {})
	var victim: Dictionary = _entities.get(int(event.victim_id), {})
	if attacker.is_empty() or victim.is_empty(): return false
	if int(attacker.team) == int(victim.team): return false
	var target := victim.get("player") as Node3D
	var shooter := attacker.get("player") as Node3D
	if not is_instance_valid(target) or not is_instance_valid(shooter): return false
	if not shooter.call("can_use_weapon"): return false
	return Time.get_ticks_usec() >= int(target.get_meta("spawn_shield_until", 0))

func _on_damage(event) -> void:
	var attacker: Dictionary = _entities.get(int(event.attacker_id), {})
	if attacker.is_empty(): return
	var guest := String(attacker.guest_id)
	var stats: Dictionary = player_stats[guest]
	stats["damage"] += maxi(0, roundi(float(event.resolved_amount)))
	var health_id := int(Game.authority._damageables.get(int(event.victim_id), 0))
	var health := instance_from_id(health_id) as Node if health_id > 0 else null
	if is_instance_valid(health) and health.call("is_dead"):
		stats["kills"] += 1
		if Catalog.is_pvp(game_mode):
			var team := int(attacker.team)
			_team_scores[team] = int(_team_scores.get(team, 0)) + 1
			if int(_team_scores[team]) >= KILL_TARGET:
				winner_team = team
				_finish("VICTORY", "kill_target")
	player_stats[guest] = stats

func _on_player_died(_event, entity: int) -> void:
	_respawns[entity] = Time.get_ticks_usec() + int(RESPAWN_SECONDS * 1_000_000)

func _place_player(player: Node3D, team: int) -> void:
	# Street intersections: valid collision ground, away from interior walls.
	var spawns := [Vector3(0, 0.2, 28), Vector3(0, 0.2, -28), Vector3(28, 0.2, 0), Vector3(-28, 0.2, 0)]
	var index := team % spawns.size()
	player.global_position = spawns[index] + Vector3(float(int(player.get("player_entity_id")) % 2) * 2.0 - 1.0, 0, 0)
	player.rotation.y = 0.0 if index == 0 else PI if index == 1 else PI * 0.5 if index == 2 else -PI * 0.5
	if player is CharacterBody3D: player.velocity = Vector3.ZERO
	player.set_meta("spawn_shield_until", Time.get_ticks_usec() + 2_000_000)

func _active_players() -> Array:
	var active: Array = []
	for value in _entities.values():
		var player := value.get("player") as Node3D
		if is_instance_valid(player) and not player.is_queued_for_deletion(): active.append(value)
	return active

func _on_wave_completed(wave: int, _bonus: int) -> void:
	if wave >= 10 and phase != "FINISHED":
		# Deferred so the horde's intermission transition cannot overwrite stop_run.
		call_deferred("_finish", "VICTORY", "ten_waves_completed")

func _finish(outcome: String, reason: String) -> void:
	if phase == "FINISHED": return
	phase = "FINISHED"
	if _horde != null and not Catalog.is_pvp(game_mode): _horde.call("stop_run", reason)
	finished.emit(outcome, reason)

func get_status_snapshot() -> Dictionary:
	if Game.is_network_client(): return _replica_snapshot.duplicate(true)
	return {"game_mode": game_mode, "phase": phase, "remaining": ceili(remaining), "winner_team": winner_team,
		"kill_target": KILL_TARGET, "scores": _team_scores.duplicate(), "wave_target": 10 if game_mode == "waves" else 0}

func apply_replica_snapshot(snapshot: Dictionary) -> void:
	if not Game.is_network_client(): return
	_replica_snapshot = snapshot.duplicate(true)

func result_metadata() -> Dictionary:
	return {"game_mode": game_mode, "winner_team": winner_team, "player_stats": player_stats.duplicate(true)}

func _physics_process(_delta: float) -> void:
	if not Game.is_simulation_authority() or not Catalog.is_pvp(game_mode): return
	for record in _active_players():
		var player := record.player as Node3D
		var hitboxes := player.get_node_or_null("PvPHitboxes") as Node3D
		var collision := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if hitboxes != null and collision != null and collision.shape is CapsuleShape3D:
			hitboxes.scale.y = (collision.shape as CapsuleShape3D).height / 1.8
