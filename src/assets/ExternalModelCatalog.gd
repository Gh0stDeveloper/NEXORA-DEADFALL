class_name DeadfallExternalModelCatalog
extends RefCounted

const SOURCE_REPOSITORY := "Gh0stDeveloper/Objetos3D"
const BASE_PATH := "res://assets/external/objetos3d"

const CHARACTER_MODELS := {
	&"operator_01": {
		"path": BASE_PATH + "/operator_01.glb",
		"source_name": "low poly survival character by Daren - WJiiE1qmRU.glb",
		"creator": "Daren",
		"scale": Vector3.ONE,
		"rotation_degrees": Vector3.ZERO,
		"offset": Vector3.ZERO,
	},
	&"operator_02": {
		"path": BASE_PATH + "/operator_02.glb",
		"source_name": "Animated Character Base by J-Toastie - AZzoJo1FBm.glb",
		"creator": "J-Toastie",
		"scale": Vector3.ONE,
		"rotation_degrees": Vector3.ZERO,
		"offset": Vector3.ZERO,
	},
}

const ZOMBIE_MODELS := {
	&"animated": {
		"path": BASE_PATH + "/zombie_animated.glb",
		"source_name": "Animated Zombie by Quaternius - jkrEvQZb8J.glb",
		"creator": "Quaternius",
		"scale": Vector3.ONE,
		"rotation_degrees": Vector3.ZERO,
		"offset": Vector3.ZERO,
	},
	&"static": {
		"path": BASE_PATH + "/zombie_static.glb",
		"source_name": "Zombie by cs_aaron - ftpTNkeqGWc.glb",
		"creator": "cs_aaron",
		"scale": Vector3.ONE,
		"rotation_degrees": Vector3.ZERO,
		"offset": Vector3.ZERO,
	},
}

static func character(character_id: StringName) -> Dictionary:
	if CHARACTER_MODELS.has(character_id):
		return Dictionary(CHARACTER_MODELS[character_id]).duplicate(true)
	return Dictionary(CHARACTER_MODELS[&"operator_01"]).duplicate(true)

static func zombie(variant: StringName = &"animated") -> Dictionary:
	if ZOMBIE_MODELS.has(variant):
		return Dictionary(ZOMBIE_MODELS[variant]).duplicate(true)
	return Dictionary(ZOMBIE_MODELS[&"animated"]).duplicate(true)

static func model_exists(config: Dictionary) -> bool:
	var path := String(config.get("path", ""))
	return not path.is_empty() and ResourceLoader.exists(path)
