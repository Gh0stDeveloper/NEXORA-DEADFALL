extends Node

const MAX_WORLD_VOICES := 12
const CUES := [&"rifle", &"pistol", &"reload", &"dry", &"melee", &"impact", &"footstep", &"zombie_growl", &"zombie_attack", &"zombie_death", &"ui_click", &"ui_confirm", &"ui_error"]
var _streams: Dictionary = {}
var _world_voices: Array[AudioStreamPlayer3D] = []
var _ui_voices: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _context: StringName = &""
var _enabled := false
var _fade: Tween
var _recent: Dictionary = {}

func _ready() -> void:
	for bus in ["Music", "SFX", "UI", "Ambience"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
	Settings.apply_audio_settings()
	_enabled = DisplayServer.get_name() != "headless" and not OS.has_feature("dedicated_server") and "--server" not in OS.get_cmdline_user_args()
	if not _enabled:
		return
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), limiter)
	for cue in CUES:
		_streams[cue] = load("res://assets/audio/%s.wav" % cue)
	for i in range(MAX_WORLD_VOICES):
		var voice := AudioStreamPlayer3D.new()
		voice.bus = "SFX"
		voice.max_distance = 38.0
		voice.unit_size = 5.0
		voice.max_db = -3.0
		add_child(voice)
		_world_voices.append(voice)
	for i in range(4):
		var voice := AudioStreamPlayer.new()
		voice.bus = "UI"
		add_child(voice)
		_ui_voices.append(voice)
	_music = _loop_player("last_signal", "Music")
	_ambience = _loop_player("quarantine_wind", "Ambience")
	process_mode = Node.PROCESS_MODE_ALWAYS

func _loop_player(file: String, bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream := load("res://assets/audio/%s.ogg" % file) as AudioStreamOggVorbis
	stream.loop = true
	player.stream = stream
	player.bus = bus
	player.volume_db = -40.0
	add_child(player)
	return player

func set_context(context: StringName) -> void:
	if not _enabled or _context == context:
		return
	_context = context
	for voice in _world_voices:
		voice.stop()
	_recent.clear()
	if not _music.playing:
		_music.play()
	if not _ambience.playing:
		_ambience.play()
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(_music, "volume_db", -6.0 if context == &"lobby" else -20.0, 0.6)
	_fade.tween_property(_ambience, "volume_db", -18.0 if context == &"lobby" else -5.0, 0.6)

func play_ui(cue: StringName = &"ui_click") -> void:
	if not _enabled or not _streams.has(cue):
		return
	for voice in _ui_voices:
		if not voice.playing:
			voice.stream = _streams[cue]
			voice.play()
			return

func play_at(cue: StringName, at: Vector3, gain: float = 0.0, pitch: float = 1.0, emitter: int = 0) -> void:
	if not _enabled or not _streams.has(cue):
		return
	var now := Time.get_ticks_msec()
	var key := "%s:%d" % [cue, emitter]
	var gap := 700 if cue == &"zombie_growl" else (120 if cue == &"dry" else 25)
	if now - int(_recent.get(key, -10000)) < gap:
		return
	_recent[key] = now
	if _recent.size() > 128:
		for old in _recent.keys():
			if now - int(_recent[old]) > 4000:
				_recent.erase(old)
	var listener := get_viewport().get_camera_3d()
	if listener != null and listener.global_position.distance_squared_to(at) > 1444:
		return
	for voice in _world_voices:
		if not voice.playing:
			voice.stream = _streams[cue]
			voice.global_position = at
			voice.volume_db = clampf(gain, -30, 0)
			voice.pitch_scale = clampf(pitch, 0.7, 1.3)
			voice.play()
			return

func _notification(what: int) -> void:
	if not _enabled:
		return
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_pause(true)
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		_pause(false)

func _pause(value: bool) -> void:
	for player in _world_voices + _ui_voices + [_music, _ambience]:
		# Unpausing an already stopped voice can revive its pending mixer state.
		# Touch only voices that are active or were actually paused.
		if is_instance_valid(player) and (player.playing or player.stream_paused):
			player.stream_paused = value

func stop_all() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	for player in _world_voices + _ui_voices + [_music, _ambience]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_streams.clear()
	_context = &""

func _exit_tree() -> void:
	stop_all()
