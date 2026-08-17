class_name DeadfallWeaponLoadout
extends Node

signal active_weapon_changed(slot: int, weapon_id: StringName, display_name: String, weapon: Node)
signal network_fire_intent(slot: int, intent)
signal network_reload_started(slot: int)
signal network_melee_intent(slot: int, sequence: int, simulation_tick: int)
signal network_switch_requested(slot: int, sequence: int)

enum Slot {
	PRIMARY,
	SECONDARY,
	MELEE,
}

@export var primary_path := NodePath("../PrimaryWeapon")
@export var secondary_path := NodePath("../SecondaryWeapon")
@export var melee_path := NodePath("../MacheteWeapon")
@export var input_path := NodePath("../PlayerInput")
@export var active_slot: int = Slot.PRIMARY

var _primary: Node
var _secondary: Node
var _melee: Node
var _input: Node
var _local_input_enabled := false
var _switch_sequence := 0
var _last_server_switch_sequence := 0

func _ready() -> void:
	_primary = get_node_or_null(primary_path)
	_secondary = get_node_or_null(secondary_path)
	_melee = get_node_or_null(melee_path)
	_input = get_node_or_null(input_path)
	_ensure_input_actions()
	_connect_weapon_signals()
	_sync_local_control_mode(true)
	_apply_slot(active_slot, false)

func _process(_delta: float) -> void:
	_sync_local_control_mode(false)
	if not _local_input_enabled or _input == null:
		return
	if bool(_input.call("consume_action_just_pressed", &"weapon_primary")):
		request_slot(Slot.PRIMARY)
	elif bool(_input.call("consume_action_just_pressed", &"weapon_secondary")):
		request_slot(Slot.SECONDARY)
	elif bool(_input.call("consume_action_just_pressed", &"weapon_melee")):
		request_slot(Slot.MELEE)
	elif bool(_input.call("consume_action_just_pressed", &"weapon_next")):
		request_slot((active_slot + 1) % Slot.size())

func request_slot(slot: int) -> bool:
	var requested := clampi(slot, Slot.PRIMARY, Slot.MELEE)
	if requested == active_slot:
		return true
	if not _slot_available(requested):
		return false
	_apply_slot(requested, true)
	return true

func server_set_active_slot(slot: int, request_sequence: int) -> bool:
	if not Game.is_simulation_authority() or request_sequence <= _last_server_switch_sequence:
		return false
	var requested := clampi(slot, Slot.PRIMARY, Slot.MELEE)
	if not _slot_available(requested):
		return false
	_last_server_switch_sequence = request_sequence
	_apply_slot(requested, false)
	return true

func force_active_slot(slot: int) -> void:
	_apply_slot(clampi(slot, Slot.PRIMARY, Slot.MELEE), false)

func get_active_weapon() -> Node:
	match active_slot:
		Slot.SECONDARY:
			return _secondary
		Slot.MELEE:
			return _melee
		_:
			return _primary

func get_weapon_for_slot(slot: int) -> Node:
	match slot:
		Slot.SECONDARY:
			return _secondary
		Slot.MELEE:
			return _melee
		_:
			return _primary

func get_active_weapon_id() -> StringName:
	return _weapon_id(get_active_weapon(), active_slot)

func get_active_display_name() -> String:
	return _weapon_display_name(get_active_weapon(), active_slot)

func add_ammo(amount: int) -> int:
	if amount <= 0 or not Game.is_simulation_authority():
		return 0
	var target := get_active_weapon()
	if target == _melee or target == null or not target.has_method("add_reserve_ammo"):
		target = _primary
	var added := int(target.call("add_reserve_ammo", amount)) if target != null and target.has_method("add_reserve_ammo") else 0
	if added <= 0 and _secondary != null and _secondary.has_method("add_reserve_ammo"):
		added = int(_secondary.call("add_reserve_ammo", amount))
	return added

func get_authoritative_state() -> Dictionary:
	return {
		"active_slot": active_slot,
		"primary": _primary.call("get_authoritative_state") if _primary != null and _primary.has_method("get_authoritative_state") else {},
		"secondary": _secondary.call("get_authoritative_state") if _secondary != null and _secondary.has_method("get_authoritative_state") else {},
		"melee": _melee.call("get_authoritative_state") if _melee != null and _melee.has_method("get_authoritative_state") else {},
	}

func apply_authoritative_state(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	if _primary != null and _primary.has_method("apply_authoritative_state"):
		_primary.call("apply_authoritative_state", Dictionary(snapshot.get("primary", {})))
	if _secondary != null and _secondary.has_method("apply_authoritative_state"):
		_secondary.call("apply_authoritative_state", Dictionary(snapshot.get("secondary", {})))
	if _melee != null and _melee.has_method("apply_authoritative_state"):
		_melee.call("apply_authoritative_state", Dictionary(snapshot.get("melee", {})))
	_apply_slot(clampi(int(snapshot.get("active_slot", active_slot)), Slot.PRIMARY, Slot.MELEE), false)

func restore_authoritative_state(snapshot: Dictionary) -> void:
	apply_authoritative_state(snapshot)

func _connect_weapon_signals() -> void:
	if _primary != null:
		if _primary.has_signal("shot_intent_created"):
			_primary.connect("shot_intent_created", Callable(self, "_on_fire_intent").bind(Slot.PRIMARY))
		if _primary.has_signal("reload_started"):
			_primary.connect("reload_started", Callable(self, "_on_reload_started").bind(Slot.PRIMARY))
	if _secondary != null:
		if _secondary.has_signal("shot_intent_created"):
			_secondary.connect("shot_intent_created", Callable(self, "_on_fire_intent").bind(Slot.SECONDARY))
		if _secondary.has_signal("reload_started"):
			_secondary.connect("reload_started", Callable(self, "_on_reload_started").bind(Slot.SECONDARY))
	if _melee != null and _melee.has_signal("attack_intent_created"):
		_melee.connect("attack_intent_created", Callable(self, "_on_melee_intent").bind(Slot.MELEE))

func _on_fire_intent(intent, slot: int) -> void:
	if slot == active_slot:
		network_fire_intent.emit(slot, intent)

func _on_reload_started(slot: int) -> void:
	if slot == active_slot:
		network_reload_started.emit(slot)

func _on_melee_intent(sequence: int, simulation_tick: int, slot: int) -> void:
	if slot == active_slot:
		network_melee_intent.emit(slot, sequence, simulation_tick)

func _apply_slot(slot: int, emit_request: bool) -> void:
	if not _slot_available(slot):
		return
	active_slot = slot
	_apply_input_flags()
	var weapon := get_active_weapon()
	active_weapon_changed.emit(active_slot, _weapon_id(weapon, active_slot), _weapon_display_name(weapon, active_slot), weapon)
	if emit_request and _is_network_predicted_owner():
		_switch_sequence += 1
		network_switch_requested.emit(active_slot, _switch_sequence)

func _apply_input_flags() -> void:
	if _primary != null and _primary.has_method("set_input_enabled"):
		_primary.call("set_input_enabled", _local_input_enabled and active_slot == Slot.PRIMARY)
	if _secondary != null and _secondary.has_method("set_input_enabled"):
		_secondary.call("set_input_enabled", _local_input_enabled and active_slot == Slot.SECONDARY)
	if _melee != null and _melee.has_method("set_input_enabled"):
		_melee.call("set_input_enabled", _local_input_enabled and active_slot == Slot.MELEE)

func _sync_local_control_mode(force: bool) -> void:
	var owner := get_parent()
	var mode_value = owner.get("control_mode") if owner != null else null
	var local := mode_value != null and int(mode_value) in [0, 1]
	if force or local != _local_input_enabled:
		_local_input_enabled = local
		_apply_input_flags()

func _is_network_predicted_owner() -> bool:
	var owner := get_parent()
	var mode_value = owner.get("control_mode") if owner != null else null
	return mode_value != null and int(mode_value) == 1

func _slot_available(slot: int) -> bool:
	return get_weapon_for_slot(slot) != null

func _weapon_id(weapon: Node, slot: int) -> StringName:
	if slot == Slot.MELEE:
		return &"machete"
	if weapon != null:
		var data = weapon.get("weapon_data")
		if data != null:
			return StringName(data.get("weapon_id"))
	return &"weapon"

func _weapon_display_name(weapon: Node, slot: int) -> String:
	if slot == Slot.MELEE:
		return "Machete"
	if weapon != null:
		var data = weapon.get("weapon_data")
		if data != null:
			return String(data.get("display_name"))
	return "Weapon"

func _ensure_input_actions() -> void:
	var bindings := {
		&"weapon_primary": KEY_1,
		&"weapon_secondary": KEY_2,
		&"weapon_melee": KEY_3,
		&"weapon_next": KEY_Q,
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		if InputMap.action_get_events(action).is_empty():
			var key := InputEventKey.new()
			key.physical_keycode = int(bindings[action])
			InputMap.action_add_event(action, key)
