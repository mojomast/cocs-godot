extends "res://world/catalog.gd"
## Native DM assets have their own identity; the nine-map source catalog is untouched.
## Two reviewed families share the source-Match factory:
##   native   — Prism Foundry / Aurora Basin / Cinder Array (builder-owned atmosphere)
##   identity — Lacuna Court / Vermilion Fold / Nacre Engine (identity_maps/map.gd)
## `open()` keeps the historical native-only allowlist that isolated fixtures
## depend on; `open_dm()` validates the full playable Deathmatch roster.
const NATIVE_ROOT := "res://native_arenas/generated/"
const IDENTITY_ROOT := "res://identity_maps/generated/"
const MAP_IDS := ["prism-foundry", "aurora-basin", "cinder-array"]
const IDENTITY_MAP_IDS := ["lacuna-court", "vermilion-fold", "nacre-engine"]
const DM_MAP_IDS := ["prism-foundry", "aurora-basin", "cinder-array",
	"lacuna-court", "vermilion-fold", "nacre-engine"]
const FAMILY := {
	"prism-foundry":"native", "aurora-basin":"native", "cinder-array":"native",
	"lacuna-court":"identity", "vermilion-fold":"identity", "nacre-engine":"identity",
}
const RENDERERS := {
	"prism-foundry":"res://native_arenas/maps/prism-foundry.gd",
	"aurora-basin":"res://native_arenas/maps/aurora-basin.gd",
	"cinder-array":"res://native_arenas/maps/cinder-array.gd",
	"lacuna-court":"res://identity_maps/map.gd",
	"vermilion-fold":"res://identity_maps/map.gd",
	"nacre-engine":"res://identity_maps/map.gd",
}
const TITLES := {
	"prism-foundry":"Prism Foundry",
	"aurora-basin":"Aurora Basin",
	"cinder-array":"Cinder Array",
	"lacuna-court":"Lacuna Court",
	"vermilion-fold":"Vermilion Fold",
	"nacre-engine":"Nacre Engine",
}
const ORIENTATION := {
	"prism-foundry":"Read the foundry's colored lanes. Use elevated routes to change your angle, and cover to break pursuit.",
	"aurora-basin":"Track the basin's height changes. Cross open ground with purpose and contest the upper approaches.",
	"cinder-array":"Work the array's platforms and sightlines. Reposition between bursts and watch the routes above you.",
	"lacuna-court":"Hold the court's open centre and carved terraces. Rotate through the outer loop before the lanes converge.",
	"vermilion-fold":"Read the fold's west and east rotations. Contest the authored objective axis and use the raised cover between folds.",
	"nacre-engine":"Fight around the layered engine drum. Keep to the inner retreat when the outer ring is covered.",
}
const IDENTITY_MODES := ["deathmatch", "domination", "horde"]
# Injectable only by code for isolated fixture tests; no CLI filesystem override.
var asset_root := NATIVE_ROOT
var identity_root := IDENTITY_ROOT

func open() -> bool:
	return _open(MAP_IDS)

func open_dm() -> bool:
	return _open(DM_MAP_IDS)

func _open(ids: Array) -> bool:
	entries.clear()
	error = ""
	source_commit = "" # Native geometry is not presented as a locked source-map export.
	var next := {}
	for id: String in ids:
		var family: String = FAMILY[id]
		var root: String = identity_root if family == "identity" else asset_root
		var path := root + id + ".json"
		var data := read_identity_envelope(path, id) if family == "identity" else read_envelope(path, id)
		if data.is_empty(): return false
		next[id] = {"id":id, "name":data.name, "modes":["deathmatch"],
			"path":id + ".json", "sha256":FileAccess.get_sha256(path),
			"nativeGeometry":family == "native", "identityGeometry":family == "identity",
			"family":family, "geometryHash":data.geometryHash,
			"renderer":RENDERERS[id],
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

func _hex_hash(value: Variant) -> bool:
	return value is String and RegEx.create_from_string("^[a-f0-9]{64}$").search(value) != null

func _hex_color(value: Variant) -> bool:
	return value is String and RegEx.create_from_string("^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$").search(value) != null

func _finite(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func _point3(value: Variant) -> bool:
	if not value is Array or value.size() != 3: return false
	for axis: Variant in value:
		if not _finite(axis): return false
	return true

func _mesh_shaped(value: Variant) -> bool:
	if not value is Dictionary: return false
	if not value.get("id") is String or value.id.is_empty(): return false
	if not value.get("material") is String or value.material.is_empty(): return false
	if not value.get("vertices") is Array or value.vertices.size() < 3: return false
	if not value.get("triangles") is Array or value.triangles.is_empty(): return false
	return true

## Strict identity-map envelope validation: the fields map.gd actually consumes
## (palette/art/arena/terrain) plus the optional contract fields. The canonical
## arena geometryHash itself is computed and enforced by the Node authority.
func read_identity_envelope(path: String, id: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		error = "Identity Deathmatch geometry is missing: " + id
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("schemaVersion") != 1 or data.get("id") != id:
		error = "Identity geometry identity/schema mismatch: " + id
		return {}
	if not data.get("name") is String or data.name.is_empty():
		error = "Identity geometry name is incomplete: " + id
		return {}
	if not _hex_hash(data.get("geometryHash")):
		error = "Identity geometry hash is invalid: " + id
		return {}
	if data.has("mode") and str(data.mode) not in IDENTITY_MODES:
		error = "Identity geometry mode is unsupported: " + id
		return {}
	if data.has("grayboxHash") and not _hex_hash(data.grayboxHash):
		error = "Identity graybox hash is invalid: " + id
		return {}
	if not data.get("palette") is Array or data.palette.size() != 4:
		error = "Identity palette must have four colors: " + id
		return {}
	for color: Variant in data.palette:
		if not _hex_color(color):
			error = "Identity palette color is invalid: " + id
			return {}
	if not data.get("art") is Array or data.art.is_empty():
		error = "Identity art geometry is missing: " + id
		return {}
	for surface: Variant in data.art:
		if not _mesh_shaped(surface) or surface.get("walkable") != false:
			error = "Identity art mesh is incomplete: " + id
			return {}
	if not data.get("arena") is Dictionary or data.arena.get("id") != id or data.arena.get("name") != data.name:
		error = "Identity arena identity is incomplete: " + id
		return {}
	var bounds: Variant = data.arena.get("bounds")
	if not bounds is Dictionary:
		error = "Identity arena has no bounds: " + id
		return {}
	for axis: String in ["minX", "maxX", "minZ", "maxZ"]:
		if not _finite(bounds.get(axis)):
			error = "Identity arena bounds are invalid: " + id
			return {}
	if float(bounds.get("minX")) >= float(bounds.get("maxX")) or float(bounds.get("minZ")) >= float(bounds.get("maxZ")):
		error = "Identity arena bounds are degenerate: " + id
		return {}
	for field: String in ["spawns", "pickups", "navNodes", "blocks"]:
		if not data.arena.get(field) is Array:
			error = "Identity arena has no " + field + ": " + id
			return {}
	if data.arena.spawns.size() < 2:
		error = "Identity arena needs at least two spawns: " + id
		return {}
	var terrain: Variant = data.arena.get("terrain")
	if not terrain is Dictionary or not terrain.get("surfaces") is Array or terrain.surfaces.is_empty() or not terrain.get("walls") is Array:
		error = "Identity arena terrain is incomplete: " + id
		return {}
	for surface: Variant in terrain.surfaces:
		if not _mesh_shaped(surface):
			error = "Identity terrain surface is incomplete: " + id
			return {}
	if not data.get("routes") is Array:
		error = "Identity arena routes are missing: " + id
		return {}
	if data.has("spawnPoints"):
		if not data.spawnPoints is Array or data.spawnPoints.size() != data.arena.spawns.size():
			error = "Identity spawn points disagree with arena spawns: " + id
			return {}
		for point: Variant in data.spawnPoints:
			if not point is Dictionary or not _finite(point.get("x")) or not _finite(point.get("y")) or not _finite(point.get("z")):
				error = "Identity spawn point is invalid: " + id
				return {}
	if data.arena.has("teamSpawns"):
		var teams: Variant = data.arena.teamSpawns
		if not teams is Dictionary or teams.size() != 2:
			error = "Identity team spawns must name two teams: " + id
			return {}
		for key: Variant in teams:
			if not teams[key] is Array or teams[key].size() < 2:
				error = "Identity team spawn pool is incomplete: " + id
				return {}
			for spawn: Variant in teams[key]:
				if not spawn is Array or spawn.size() != 2 or not _finite(spawn[0]) or not _finite(spawn[1]):
					error = "Identity team spawn point is invalid: " + id
					return {}
	if data.arena.has("objectiveZones"):
		var zones: Variant = data.arena.objectiveZones
		if not zones is Array or zones.is_empty() or (id == "vermilion-fold" and zones.size() != 3):
			error = "Identity objective zones are incomplete: " + id
			return {}
		for zone: Variant in zones:
			if not zone is Dictionary or not _finite(zone.get("x")) or not _finite(zone.get("z")):
				error = "Identity objective zone is invalid: " + id
				return {}
	return data

func resolve_envelope(id: String) -> Dictionary:
	error = ""
	if id not in DM_MAP_IDS or not entries.has(id):
		error = "Native Deathmatch map is not allowlisted: " + id
		return {}
	var family: String = entries[id].family
	var root: String = identity_root if family == "identity" else asset_root
	var path := root + id + ".json"
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != entries[id].sha256:
		error = "Native geometry changed or is missing; relaunch: " + id
		return {}
	var data := read_identity_envelope(path, id) if family == "identity" else read_envelope(path, id)
	return data

func resolve_map(id: String) -> Dictionary:
	var data := resolve_envelope(id)
	return data.arena if not data.is_empty() else {}
