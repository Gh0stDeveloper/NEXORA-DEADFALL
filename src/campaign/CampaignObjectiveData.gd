class_name DeadfallCampaignObjectiveData
extends Resource

enum ObjectiveType {
	REACH,
	KILL,
	SURVIVE,
	INTERACT,
	EXTRACT,
}

@export var objective_id: StringName = &"objective"
@export var objective_type: int = ObjectiveType.REACH
@export var title := "Objective"
@export_multiline var description := ""
@export var target_id: StringName = &""
@export var required_count := 1
@export var duration_seconds := 0.0
@export var radius := 3.0
@export var interact_hold_seconds := 1.5
@export var checkpoint_id: StringName = &""

func required_value() -> float:
	match objective_type:
		ObjectiveType.KILL:
			return float(maxi(1, required_count))
		ObjectiveType.SURVIVE:
			return maxf(0.1, duration_seconds)
		ObjectiveType.INTERACT:
			return maxf(0.25, interact_hold_seconds)
		_:
			return 1.0

func get_type_name() -> String:
	return ObjectiveType.keys()[clampi(objective_type, ObjectiveType.REACH, ObjectiveType.EXTRACT)]
