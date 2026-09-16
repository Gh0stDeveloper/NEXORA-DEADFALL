class_name DeadfallExternalModelCatalog
extends RefCounted

const SOURCE_REPOSITORY := "Gh0stDeveloper/Objetos3D"
const CANONICAL_BASE_PATH := "res://assets/external/objetos3d"
const VENDOR_BASE_PATH := "res://vendor/Objetos3D"

const CHARACTER_MODELS := {
	&"operator_01": {
		"vendor_path": VENDOR_BASE_PATH + "/low poly survival character by Daren - WJiiE1qmRU.glb",
		"canonical_path": CANONICAL_BASE_PATH + "/operator_01.glb",
		"source_name": "low poly survival character by Daren - WJiiE1qmRU.glb",
		"creator": "Daren",
		"expects_animation": false,
		"scale": Vector3.ONE,
		"rotation_degrees": Vector3.ZERO,
		"offset": Vector3.ZERO,
	},
	&"operator_02": {
		"vendor_path": VENDOR_BASE_PATH + "/Animated Character Base by J-Toastie - AZzoJo1FBm.glb",
		"canonical_path": CANONICAL_BASE_PATH + "/operator_02.glb",
		"source_name": "Animated Character Base by J-Toastie - AZzoJo1FBm.glb",
		"creator": "J-Toastie",
		"expects_animation": true,
		# The current GLB exposes a single generic Mixamo clip named
		# `mixamo_com`. Keep it as an explicit neutral fallback so the runtime
		# can leave bind/T-pose without pretending that one clip represents
		# Idle/Walk/Run/Attack/Death independently.
		"generic_animation_fallback": "mixamo_com",
		"scale": Vector3.ONE,
		"rotation_degrees": Vector3.ZERO,
		"offset": Vector3.ZERO,
	},
}

const ZOMBIE_MODELS := {
	&"animated": {
		"vendor_path": VENDOR_BASE_PATH + "/Animated Zombie by Quaternius - jkrEvQZb8J.glb",
		"canonical_path": CANONICAL_BASE_PATH + "/zombie_animated.glb",
		"source_name": "Animated Zombie by Quaternius - jkrEvQZb8J.glb",
		"creator": "Quaternius",
		"expects_animation": true,
		# Verified on Godot 4.6.3 headless import in production VPS.
		"animation_semantics": {
			"idle": "Zombie|ZombieIdle",
			"walk": "Zombie|ZombieWalk",
			"run": "Zombie|ZombieRun",
			"crawl": "Zombie|ZombieCrawl",
			"attack": "Zombie|ZombieBite",
		},
		"scale": Vector3.ONE,
		"rotation_degrees": Vector3.ZERO,
		"offset": Vector3.ZERO,
	},
	&"static": {
		"vendor_path": VENDOR_BASE_PATH + "/Zombie by cs_aaron - ftpTNkeqGWc.glb",
		"canonical_path": CANONICAL_BASE_PATH + "/zombie_static.glb",
		"source_name": "Zombie by cs_aaron - ftpTNkeqGWc.glb",
		"creator": "cs_aaron",
		"expects_animation": false,
		"scale": Vector3.ONE,
		"rotation_degrees": Vector3.ZERO,
		"offset": Vector3.ZERO,
	},
}

static func character(character_id: StringName) -> Dictionary:
	var config: Dictionary
	if CHARACTER_MODELS.has(character_id):
		config = Dictionary(CHARACTER_MODELS[character_id]).duplicate(true)
	else:
		config = Dictionary(CHARACTER_MODELS[&"operator_01"]).duplicate(true)
	return _with_runtime_path(config)

static func zombie(variant: StringName = &"animated") -> Dictionary:
	var config: Dictionary
	if ZOMBIE_MODELS.has(variant):
		config = Dictionary(ZOMBIE_MODELS[variant]).duplicate(true)
	else:
		config = Dictionary(ZOMBIE_MODELS[&"animated"]).duplicate(true)
	return _with_runtime_path(config)

static func model_exists(config: Dictionary) -> bool:
	var path := String(config.get("path", ""))
	return not path.is_empty() and ResourceLoader.exists(path)

static func _with_runtime_path(config: Dictionary) -> Dictionary:
	var vendor_path := String(config.get("vendor_path", ""))
	var canonical_path := String(config.get("canonical_path", ""))
	# Godot imports the physical GLB in the pinned submodule. The canonical
	# assets/external paths are tracked symlinks and are intentionally retained
	# for repository/deployment contracts, but ResourceLoader cannot reliably
	# resolve an imported scene through that symlink on Linux headless builds.
	if not vendor_path.is_empty() and ResourceLoader.exists(vendor_path):
		config["path"] = vendor_path
	elif not canonical_path.is_empty() and ResourceLoader.exists(canonical_path):
		# Compatibility fallback for CI/older checkouts where sync_objetos3d.sh
		# materializes a real file at the canonical path instead of a symlink.
		config["path"] = canonical_path
	else:
		# Keep the preferred physical path for deterministic diagnostics.
		config["path"] = vendor_path if not vendor_path.is_empty() else canonical_path
	return config
