class_name DeadfallTouchActionButton
extends Button

var input_target: Node
var action_name: StringName

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

func _exit_tree() -> void:
	if input_target != null and input_target.has_method("set_mobile_action"):
		input_target.set_mobile_action(action_name, false)

func _on_button_down() -> void:
	if input_target != null and input_target.has_method("set_mobile_action"):
		input_target.set_mobile_action(action_name, true)

func _on_button_up() -> void:
	if input_target != null and input_target.has_method("set_mobile_action"):
		input_target.set_mobile_action(action_name, false)
