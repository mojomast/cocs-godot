extends "res://world/catalog.gd"
## Native DM assets have their own identity; the nine-map source catalog is untouched.
const NATIVE_ROOT := "res://native_arenas/generated/"
const MAP_IDS := ["prism-foundry", "aurora-basin", "cinder-array"]
const TITLES := {
	"prism-foundry":"Prism Foundry",
	"aurora-basin":"Aurora Basin",
	"cinder-array":"Cinder Array",
}
const ORIENTATION := {
	"prism-foundry":"Read the foundry's colored lanes. Use elevated routes to change your angle, and cover to break pursuit.",
	"aurora-basin":"Track the basin's height changes. Cross open ground with purpose and contest the upper approaches.",
	"cinder-array":"Work the array's platforms and sightlines. Reposition between bursts and watch the routes above you.",
}
# Injectable only by code for isolated fixture tests; no CLI filesystem override.
var asset_root := NATIVE_ROOT

func open() -> bool:
	entries.clear()
	error = ""
	source_commit = "" # Native geometry is not presented as a locked source-map export.
	var next := {}
	for id: String in MAP_IDS:
		var path := asset_root + id + ".json"
		var data := read_envelope(path, id)
		if data.is_empty(): return false
		next[id] = {"id":id, "name":data.name, "modes":["deathmatch"],
			"path":id + ".json", "sha256":FileAccess.get_sha256(path),
			"nativeGeometry":true, "geometryHash":data.geometryHash,
			"renderer":"res://native_arenas/maps/" + id + ".gd",
			"orientation":ORIENTATION[id]}
	entries = next
	return true

func read_envelope(path: String, id: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		error = "Native Deathmatch geometry is missing: " + id
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("schemaVersion") != 1 or data.get("id") != id:
		error = "Native geometry identity/schema mismatch: " + id
		return {}
	if not data.get("name") is String or data.name.is_empty() or not data.get("geometryHash") is String or data.geometryHash.is_empty():
		error = "Native geometry metadata is incomplete: " + id
		return {}
	if not data.get("arena") is Dictionary or data.arena.get("id") != id or not data.arena.get("bounds") is Dictionary:
		error = "Native arena metadata is incomplete: " + id
		return {}
	for field: String in ["spawns", "pickups", "navNodes", "blocks"]:
		if not data.arena.get(field) is Array:
			error = "Native arena has no " + field + ": " + id
			return {}
	if not data.get("spawnPoints") is Array or data.spawnPoints.is_empty() or not data.get("routes") is Array:
		error = "Native arena spawn/routes metadata is incomplete: " + id
		return {}
	for point: Variant in data.spawnPoints:
		if not point is Dictionary:
			error = "Invalid native spawn point: " + id
			return {}
		for axis: String in ["x", "y", "z"]:
			var value: Variant = point.get(axis)
			if not (value is float or value is int) or not is_finite(float(value)):
				error = "Invalid native spawn coordinate: " + id
				return {}
	return data

func resolve_map(id: String) -> Dictionary:
	error = ""
	if id not in MAP_IDS or not entries.has(id):
		error = "Native Deathmatch map is not allowlisted: " + id
		return {}
	var path := asset_root + id + ".json"
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != entries[id].sha256:
		error = "Native geometry changed or is missing; relaunch: " + id
		return {}
	var data := read_envelope(path, id)
	return data.arena if not data.is_empty() else {}
