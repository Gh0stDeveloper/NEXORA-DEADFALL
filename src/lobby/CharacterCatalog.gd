class_name DeadfallCharacterCatalog
extends RefCounted

const CHARACTERS := [
	{
		"id": &"operator_01",
		"name": "MARA",
		"role": "SUPERVIVIENTE",
		"description": "Operadora equilibrada para reconocimiento y combate urbano.",
		"accent": Color(0.74, 0.08, 0.10, 1.0),
		"model_scene": "res://assets/external/objetos3d/operator_01.glb",
	},
	{
		"id": &"operator_02",
		"name": "DANTE",
		"role": "VANGUARDIA",
		"description": "Operador de primera línea preparado para presión y rescate.",
		"accent": Color(0.15, 0.34, 0.48, 1.0),
		"model_scene": "res://assets/external/objetos3d/operator_02.glb",
	},
]

static func all() -> Array:
	return CHARACTERS.duplicate(true)

static func get_character(character_id: StringName) -> Dictionary:
	for character in CHARACTERS:
		if StringName(character.get("id", &"")) == character_id:
			return Dictionary(character).duplicate(true)
	return Dictionary(CHARACTERS[0]).duplicate(true)
