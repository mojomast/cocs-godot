extends "res://world/catalog.gd"
const ID := "cinderwake-drydock"
const PATH := "res://horde_maps/generated/cinderwake-drydock.json"
var envelope: Dictionary = {}

func open() -> bool:
	error = ""
	entries.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary or parsed.get("id") != ID or parsed.get("mode") != "horde" or not parsed.get("arena") is Dictionary:
		error = "Cinderwake recipe missing or invalid"
		return false
	if not parsed.arena.get("hordeStagePlan") is Dictionary or parsed.arena.hordeStagePlan.get("version") != 1:
		error = "Cinderwake source stage contract missing"
		return false
	envelope = parsed
	entries[ID] = {"id": ID, "name": parsed.name, "modes": ["horde"], "geometryHash": parsed.geometryHash,
		"orientation": "Leave the loading cradle after wave 2. Follow numbered bulkheads; E is always open."}
	return true

func resolve_envelope(id: String) -> Dictionary:
	return envelope if id == ID else {}
