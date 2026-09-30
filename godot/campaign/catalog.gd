extends "res://world/catalog.gd"
const MAP_IDS := ["rootfall-verge", "siltwake-crossing", "emberline-ascent", "crown-array"]
const TITLES := ["Rootfall Verge", "Siltwake Crossing", "Emberline Ascent", "Crown Array"]
var envelopes: Dictionary = {}

func open() -> bool:
	entries.clear()
	envelopes.clear()
	for id: String in MAP_IDS:
		var path := "res://campaign/generated/" + id + ".json"
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not value is Dictionary or value.get("id") != id or value.get("schemaVersion") != 1 or not value.get("arena") is Dictionary or not value.get("geometryHash") is String:
			error = "Campaign recipe missing or invalid: " + id
			return false
		envelopes[id] = value
		entries[id] = {"id":id, "name":value.name, "modes":["campaign"], "geometryHash":value.geometryHash}
	return true

func resolve_envelope(id: String) -> Dictionary:
	return envelopes.get(id, {})

func resolve_map(id: String) -> Dictionary:
	return resolve_envelope(id).get("arena", {})
