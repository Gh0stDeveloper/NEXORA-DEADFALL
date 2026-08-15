class_name DeadfallHitbox3D
extends Area3D

@export var victim_id: int = 0
@export var body_part: int = 1

func get_victim_id() -> int:
	return victim_id

func get_body_part() -> int:
	return body_part
