class_name DeadfallModeCatalog
extends RefCounted

const MODES := [
	{"id": "campaign", "title": "ZOMBIS · CAMPAÑA", "tag": "COOPERATIVO", "description": "Avanza por la ciudad, cumple los objetivos y alcanza la evacuación.", "formations": [1, 2, 4], "pvp": false},
	{"id": "waves", "title": "ASALTO · 10 OLEADAS", "tag": "COOPERATIVO", "description": "Sobrevive diez rondas de enemigos. Completa la última para ganar.", "formations": [1, 2, 4], "pvp": false},
	{"id": "endless", "title": "RESISTENCIA INFINITA", "tag": "COOPERATIVO", "description": "Oleadas sin límite. Supera tu puntuación hasta caer o abandonar.", "formations": [1, 2, 4], "pvp": false},
	{"id": "pvp_ffa", "title": "TODOS CONTRA TODOS", "tag": "ENFRENTAMIENTO", "description": "De 2 a 4 rivales. Reaparece y consigue 10 bajas antes de 5 minutos.", "formations": [1, 2, 4], "pvp": true},
	{"id": "pvp_duo", "title": "DUELO DE DÚOS", "tag": "ENFRENTAMIENTO", "description": "Dos equipos de hasta 2. Se permite 1 contra 1. Primera pareja en 10 bajas.", "formations": [1, 2], "pvp": true},
	{"id": "pvp_squad", "title": "DUELO INTERNO", "tag": "PARTIDA PRIVADA", "description": "Enfréntate a tus propios compañeros. De 2 a 4, cada uno por su cuenta.", "formations": [2, 4], "pvp": true},
]

static func find(id: String) -> Dictionary:
	for mode in MODES:
		if mode.id == id: return mode.duplicate(true)
	return {}

static func is_pvp(id: String) -> bool:
	return bool(find(id).get("pvp", false))
