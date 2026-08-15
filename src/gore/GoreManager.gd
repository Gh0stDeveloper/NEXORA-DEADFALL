class_name DeadfallGoreManager
extends Node

const BudgetScript = preload("res://src/gore/GorePoolBudget.gd")
const DamageEventScript = preload("res://src/core/damage/DamageEvent.gd")

var _budget = BudgetScript.new()
var _profile: Dictionary = {}
var _limb_pool: Array = []
var _blood_pool: Array = []
var _decal_pool: Array = []
var _limb_expiry: Array = []
var _decal_expiry: Array = []
var _blood_texture: Texture2D
var _visuals_available := false
var _stats := {
	"limb_requests": 0,
	"blood_requests": 0,
	"decal_requests": 0,
	"limb_peak_active": 0,
	"decal_peak_active": 0,
}

func _ready() -> void:
	_visuals_available = DisplayServer.get_name() != "headless"
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		if settings.has_signal("quality_profile_changed"):
			settings.connect("quality_profile_changed", Callable(self, "_on_quality_profile_changed"))
		_profile = settings.call("current_profile")
	else:
		_profile = _fallback_profile()
	_apply_profile(_profile)

func _process(_delta: float) -> void:
	if not _visuals_available:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for index in range(_limb_pool.size()):
		if index >= _limb_expiry.size():
			continue
		var expiry := float(_limb_expiry[index] if _limb_expiry[index] != null else 0.0)
		if expiry > 0.0 and now >= expiry:
			_deactivate_limb(index)
	for index in range(_decal_pool.size()):
		if index >= _decal_expiry.size():
			continue
		var expiry := float(_decal_expiry[index] if _decal_expiry[index] != null else 0.0)
		if expiry > 0.0 and now >= expiry:
			_deactivate_decal(index)

func spawn_detached_limb(body_part: int, spawn_transform: Transform3D, impulse_direction: Vector3) -> int:
	if not _gore_visuals_enabled():
		return -1
	var slot := _budget.acquire(BudgetScript.LIMBS)
	if slot < 0:
		return -1
	_ensure_limb_pool(_budget.get_limit(BudgetScript.LIMBS))
	var body := _limb_pool[slot] as RigidBody3D
	if body == null:
		return -1
	_configure_limb_body(body, body_part)
	body.freeze = true
	body.global_transform = spawn_transform
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	var shape_node := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var mesh_node := body.get_node_or_null("Mesh") as MeshInstance3D
	if shape_node != null:
		shape_node.set_deferred("disabled", false)
	if mesh_node != null:
		mesh_node.visible = true
	body.freeze = false
	body.sleeping = false
	var direction := impulse_direction.normalized() if impulse_direction.length_squared() > 0.0001 else Vector3.UP
	body.apply_central_impulse(direction * 3.2 + Vector3.UP * 1.4)
	body.angular_velocity = Vector3(randf_range(-4.0, 4.0), randf_range(-5.0, 5.0), randf_range(-4.0, 4.0))
	_limb_expiry[slot] = Time.get_ticks_msec() / 1000.0 + float(_profile.get("limb_lifetime", 8.0))
	_stats["limb_requests"] = int(_stats["limb_requests"]) + 1
	_stats["limb_peak_active"] = maxi(int(_stats["limb_peak_active"]), _active_limb_count())
	return slot

func spawn_corpse(spawn_transform: Transform3D, impulse_direction: Vector3) -> int:
	var corpse_transform := spawn_transform
	corpse_transform.origin += Vector3.UP * 0.72
	return spawn_detached_limb(DamageEventScript.BodyPart.CHEST, corpse_transform, impulse_direction * 0.75)

func spawn_blood(position: Vector3, direction: Vector3, intensity: float = 1.0) -> int:
	if not _gore_visuals_enabled():
		return -1
	var slot := _budget.acquire(BudgetScript.BLOOD)
	if slot < 0:
		return -1
	_ensure_blood_pool(_budget.get_limit(BudgetScript.BLOOD))
	var particles := _blood_pool[slot] as GPUParticles3D
	if particles == null:
		return -1
	particles.global_position = position
	particles.amount = maxi(1, int(round(float(_profile.get("blood_particles", 18)) * clampf(intensity, 0.25, 3.0))))
	var material := particles.process_material as ParticleProcessMaterial
	if material != null:
		material.direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.UP
	particles.restart()
	particles.emitting = true
	_stats["blood_requests"] = int(_stats["blood_requests"]) + 1
	return slot

func spawn_blood_decal(position: Vector3, scale_factor: float = 1.0) -> int:
	if not _gore_visuals_enabled():
		return -1
	var slot := _budget.acquire(BudgetScript.DECALS)
	if slot < 0:
		return -1
	_ensure_decal_pool(_budget.get_limit(BudgetScript.DECALS))
	var decal := _decal_pool[slot] as Decal
	if decal == null:
		return -1
	decal.global_position = position + Vector3.UP * 0.025
	decal.rotation.y = randf_range(-PI, PI)
	var footprint := clampf(0.65 * scale_factor, 0.35, 1.25)
	decal.size = Vector3(footprint, 0.12, footprint)
	decal.visible = true
	_decal_expiry[slot] = Time.get_ticks_msec() / 1000.0 + float(_profile.get("decal_lifetime", 20.0))
	_stats["decal_requests"] = int(_stats["decal_requests"]) + 1
	_stats["decal_peak_active"] = maxi(int(_stats["decal_peak_active"]), _active_decal_count())
	return slot

func get_budget_limits() -> Dictionary:
	return _budget.snapshot()

func get_runtime_stats() -> Dictionary:
	var result := _stats.duplicate(true)
	result["pool_limbs"] = _limb_pool.size()
	result["pool_blood"] = _blood_pool.size()
	result["pool_decals"] = _decal_pool.size()
	result["active_limbs"] = _active_limb_count()
	result["active_decals"] = _active_decal_count()
	return result

func debug_acquire_slot(kind: StringName) -> int:
	return _budget.acquire(kind)

func reset_runtime_stats() -> void:
	_stats = {
		"limb_requests": 0,
		"blood_requests": 0,
		"decal_requests": 0,
		"limb_peak_active": 0,
		"decal_peak_active": 0,
	}

func _on_quality_profile_changed(_tier: int, profile: Dictionary) -> void:
	_apply_profile(profile)

func _apply_profile(profile: Dictionary) -> void:
	_profile = profile.duplicate(true)
	_budget.configure(_profile)
	if not _visuals_available:
		return
	_ensure_limb_pool(_budget.get_limit(BudgetScript.LIMBS))
	_ensure_blood_pool(_budget.get_limit(BudgetScript.BLOOD))
	_ensure_decal_pool(_budget.get_limit(BudgetScript.DECALS))
	_disable_slots_above_budget()

func _gore_visuals_enabled() -> bool:
	if not _visuals_available:
		return false
	var settings := get_node_or_null("/root/Settings")
	return settings == null or bool(settings.get("gore_enabled"))

func _ensure_limb_pool(count: int) -> void:
	while _limb_pool.size() < count:
		var body := RigidBody3D.new()
		body.name = "PooledLimb_%02d" % _limb_pool.size()
		body.mass = 6.0
		body.collision_layer = 16
		body.collision_mask = 1
		body.freeze = true
		var shape_node := CollisionShape3D.new()
		shape_node.name = "CollisionShape3D"
		shape_node.shape = BoxShape3D.new()
		shape_node.disabled = true
		body.add_child(shape_node)
		var mesh_node := MeshInstance3D.new()
		mesh_node.name = "Mesh"
		var mesh := BoxMesh.new()
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.30, 0.33, 0.25)
		material.roughness = 0.92
		mesh.material = material
		mesh_node.mesh = mesh
		mesh_node.visible = false
		body.add_child(mesh_node)
		add_child(body)
		_limb_pool.append(body)
		_limb_expiry.append(0.0)

func _ensure_blood_pool(count: int) -> void:
	while _blood_pool.size() < count:
		var particles := GPUParticles3D.new()
		particles.name = "PooledBlood_%02d" % _blood_pool.size()
		particles.emitting = false
		particles.one_shot = true
		particles.explosiveness = 0.92
		particles.lifetime = 0.72
		particles.local_coords = false
		particles.visibility_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3.UP
		process.spread = 55.0
		process.initial_velocity_min = 2.0
		process.initial_velocity_max = 5.5
		process.gravity = Vector3(0, -9.8, 0)
		process.scale_min = 0.7
		process.scale_max = 1.35
		process.color = Color(0.35, 0.015, 0.02, 1.0)
		particles.process_material = process
		var droplet := BoxMesh.new()
		droplet.size = Vector3(0.035, 0.035, 0.035)
		var droplet_material := StandardMaterial3D.new()
		droplet_material.albedo_color = Color(0.28, 0.008, 0.015)
		droplet_material.roughness = 0.55
		droplet.material = droplet_material
		particles.draw_pass_1 = droplet
		add_child(particles)
		_blood_pool.append(particles)

func _ensure_decal_pool(count: int) -> void:
	if _blood_texture == null:
		_blood_texture = _create_blood_texture()
	while _decal_pool.size() < count:
		var decal := Decal.new()
		decal.name = "PooledBloodDecal_%02d" % _decal_pool.size()
		decal.texture_albedo = _blood_texture
		decal.modulate = Color(0.45, 0.02, 0.025, 0.92)
		decal.size = Vector3(0.65, 0.12, 0.65)
		decal.upper_fade = 0.0
		decal.lower_fade = 0.0
		decal.normal_fade = 0.25
		decal.distance_fade_enabled = true
		decal.distance_fade_begin = 20.0
		decal.distance_fade_length = 12.0
		decal.visible = false
		add_child(decal)
		_decal_pool.append(decal)
		_decal_expiry.append(0.0)

func _configure_limb_body(body: RigidBody3D, body_part: int) -> void:
	var size := Vector3(0.72, 1.45, 0.46)
	var mass := 20.0
	match body_part:
		DamageEventScript.BodyPart.HEAD:
			size = Vector3(0.46, 0.46, 0.42)
			mass = 4.5
		DamageEventScript.BodyPart.LEFT_ARM, DamageEventScript.BodyPart.RIGHT_ARM:
			size = Vector3(0.24, 0.78, 0.26)
			mass = 4.0
		DamageEventScript.BodyPart.LEFT_LEG, DamageEventScript.BodyPart.RIGHT_LEG:
			size = Vector3(0.28, 0.70, 0.30)
			mass = 7.0
		_:
			size = Vector3(0.72, 1.45, 0.46)
			mass = 24.0
	body.mass = mass
	var shape_node := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is BoxShape3D:
		(shape_node.shape as BoxShape3D).size = size
	var mesh_node := body.get_node_or_null("Mesh") as MeshInstance3D
	if mesh_node != null and mesh_node.mesh is BoxMesh:
		(mesh_node.mesh as BoxMesh).size = size

func _deactivate_limb(index: int) -> void:
	if index < 0 or index >= _limb_pool.size():
		return
	var body := _limb_pool[index] as RigidBody3D
	if body != null:
		body.freeze = true
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		var shape_node := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		var mesh_node := body.get_node_or_null("Mesh") as MeshInstance3D
		if shape_node != null:
			shape_node.set_deferred("disabled", true)
		if mesh_node != null:
			mesh_node.visible = false
	_limb_expiry[index] = 0.0

func _deactivate_decal(index: int) -> void:
	if index < 0 or index >= _decal_pool.size():
		return
	var decal := _decal_pool[index] as Decal
	if decal != null:
		decal.visible = false
	_decal_expiry[index] = 0.0

func _disable_slots_above_budget() -> void:
	var limb_limit := _budget.get_limit(BudgetScript.LIMBS)
	for index in range(limb_limit, _limb_pool.size()):
		_deactivate_limb(index)
	var decal_limit := _budget.get_limit(BudgetScript.DECALS)
	for index in range(decal_limit, _decal_pool.size()):
		_deactivate_decal(index)
	var blood_limit := _budget.get_limit(BudgetScript.BLOOD)
	for index in range(blood_limit, _blood_pool.size()):
		var particles := _blood_pool[index] as GPUParticles3D
		if particles != null:
			particles.emitting = false

func _active_limb_count() -> int:
	var now := Time.get_ticks_msec() / 1000.0
	var count := 0
	var limit := mini(_budget.get_limit(BudgetScript.LIMBS), _limb_expiry.size())
	for index in range(limit):
		var expiry := float(_limb_expiry[index] if _limb_expiry[index] != null else 0.0)
		if expiry > now:
			count += 1
	return count

func _active_decal_count() -> int:
	var now := Time.get_ticks_msec() / 1000.0
	var count := 0
	var limit := mini(_budget.get_limit(BudgetScript.DECALS), _decal_expiry.size())
	for index in range(limit):
		var expiry := float(_decal_expiry[index] if _decal_expiry[index] != null else 0.0)
		if expiry > now:
			count += 1
	return count

func _create_blood_texture() -> Texture2D:
	var size := 32
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var uv := Vector2((float(x) + 0.5) / size, (float(y) + 0.5) / size) * 2.0 - Vector2.ONE
			var radius := uv.length()
			var wobble := 0.08 * sin(float(x * 3 + y * 5))
			var alpha := clampf((1.0 + wobble - radius) * 3.2, 0.0, 1.0)
			image.set_pixel(x, y, Color(0.52, 0.015, 0.02, alpha))
	return ImageTexture.create_from_image(image)

func _fallback_profile() -> Dictionary:
	return {
		"gore_parts": 8,
		"blood_emitters": 4,
		"blood_particles": 18,
		"decals": 20,
		"limb_lifetime": 8.0,
		"decal_lifetime": 20.0,
	}
