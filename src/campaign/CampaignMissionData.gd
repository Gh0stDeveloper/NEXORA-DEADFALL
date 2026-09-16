class_name DeadfallCampaignMissionData
extends Resource

@export var mission_id: StringName = &"mission"
@export var campaign_id: StringName = &"deadfall_campaign"
@export var title := "Mission"
@export_multiline var description := ""
@export var objectives: Array[Resource] = []
@export var next_mission_id: StringName = &""

func is_valid_definition() -> bool:
	if mission_id == &"" or objectives.is_empty():
		return false
	for objective in objectives:
		if objective == null or not objective.has_method("required_value"):
			return false
	return true

func objective_count() -> int:
	return objectives.size()

func objective_at(index: int) -> Resource:
	if index < 0 or index >= objectives.size():
		return null
	return objectives[index]
