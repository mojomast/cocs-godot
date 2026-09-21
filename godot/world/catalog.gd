class_name PortCatalog
extends RefCounted

const ROOT := "res://content/generated/"
var entries: Dictionary = {}
var error: String = ""
var source_commit: String = ""

func open() -> bool:
	entries.clear()
	error = ""
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
	if not value is Dictionary or value.get("schema_version") != 1 or value.get("maps", []).is_empty():
		error = "Missing/empty or unsupported manifest. Run semantic exporter."
		return false
	source_commit = value.get("source_commit", "")
	if source_commit.length() != 40:
		error = "Manifest has no pinned source revision"
		return false
	for entry: Dictionary in value.maps:
		var id: String = entry.get("id", "")
		if id.is_empty() or entries.has(id) or entry.get("path") != "maps/" + id + "/map.json" or "/" in id or ".." in id:
			error = "Invalid or duplicate map identity"
			entries.clear()
			return false
		entries[id] = entry
	return true

func resolve_map(id: String) -> Dictionary:
	if not entries.has(id):
		error = "Map is not allowlisted: " + id
		return {}
	var entry: Dictionary = entries[id]
	var path: String = ROOT + entry.path
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != entry.sha256:
		error = "Missing/corrupt semantic asset: " + id
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("schema_version") != 1 or data.get("source_map", {}).get("id") != id:
		error = "Semantic map identity/schema mismatch: " + id
		return {}
	return data.source_map
