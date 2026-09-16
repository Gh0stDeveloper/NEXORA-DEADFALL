extends Node

@export var infected := false
var _body: CharacterBody3D
var _elapsed := 0.0
var _vocal := 0.0
var _distance := 0.0
var _previous := Vector3.ZERO
var _state := -1
var _last_health := -1.0

func _ready() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		set_process(false)
		return
	_body = get_parent() as CharacterBody3D
	if _body == null:
		set_process(false)
		return
	_previous = _body.global_position
	if not infected:
		var health := _body.get_node_or_null("Health")
		if health != null:
			_last_health = float(health.get("current_health"))
			health.connect("health_changed", _on_health_changed)
	_vocal = 2.0 + float(_body.get_instance_id() % 13) * 0.21

func _on_health_changed(current: float, _maximum: float, _event) -> void:
	if _last_health >= 0 and current < _last_health:
		AudioDirector.play_at(&"impact", _body.global_position, -3, 0.85, _body.get_instance_id())
	_last_health = current

func _process(delta: float) -> void:
	_elapsed += delta
	_vocal -= delta
	if _elapsed < 0.1:
		return
	_elapsed = 0
	var at := _body.global_position
	var moved := at.distance_to(_previous)
	_previous = at
	if infected:
		var state := int(_body.get("state"))
		if state != _state:
			if state == 3:
				AudioDirector.play_at(&"zombie_attack", at, -3, 0.94, _body.get_instance_id())
			elif state == 5:
				AudioDirector.play_at(&"zombie_death", at, -2, 0.9, _body.get_instance_id())
			elif state == 4:
				AudioDirector.play_at(&"impact", at, -5, 1, _body.get_instance_id())
			_state = state
		if state == 5:
			return
		if _vocal <= 0:
			_vocal = 4.0 + float(_body.get_instance_id() % 7) * 0.45
			AudioDirector.play_at(&"zombie_growl", at, -6, 0.85 + float(_body.get_instance_id() % 6) * 0.045, _body.get_instance_id())
	if moved < 2.0 and absf(_body.velocity.y) < 1.0:
		_distance += moved
	if _distance > (1.1 if infected else 1.45):
		_distance = 0
		AudioDirector.play_at(&"footstep", at, -10 if infected else -5, 0.9 if infected else 1.0, _body.get_instance_id())
