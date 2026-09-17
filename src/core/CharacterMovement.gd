class_name DeadfallCharacterMovement
extends RefCounted

const STEP_HEIGHT := 0.25

static func move(body: CharacterBody3D, delta: float) -> void:
	var stepped := _try_step(body, delta)
	body.move_and_slide()
	if stepped:
		body.apply_floor_snap()

static func _try_step(body: CharacterBody3D, delta: float) -> bool:
	if not body.is_on_floor() or body.velocity.y > 0.1:
		return false
	var motion := Vector3(body.velocity.x, 0, body.velocity.z) * delta
	if motion.length_squared() < 0.000001:
		return false
	var hit := KinematicCollision3D.new()
	if not body.test_move(body.global_transform, motion, hit) or hit.get_normal().y >= cos(body.floor_max_angle):
		return false
	if body.test_move(body.global_transform, Vector3.UP * STEP_HEIGHT):
		return false # Preserve low-ceiling and stance clearance.
	var raised := body.global_transform
	raised.origin.y += STEP_HEIGHT
	if body.test_move(raised, motion):
		return false # A wall/vehicle is taller than a curb.
	var landing := raised
	landing.origin += motion
	if not body.test_move(landing, Vector3.DOWN * (STEP_HEIGHT + 0.03), hit) or hit.get_normal().y < 0.7:
		return false
	body.global_position.y += STEP_HEIGHT
	return true
