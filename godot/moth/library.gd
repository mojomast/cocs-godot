extends RefCounted
## Shared bounded texture registry. Resources are immutable; returned containers are caller-owned.
##
## Two buckets, two caches: the 101-plane baked registry under
## res://moth/generated (asserted by the package probes) and the derived bucket
## under res://moth/derived (tools/godot-moth/derive.mjs, own manifest). The
## baked cache accounting is unchanged so existing counts keep meaning.
const MANIFEST_PATH := "res://moth/generated/manifest.json"
const DERIVED_MANIFEST_PATH := "res://moth/derived/manifest.json"
const MAX_TEXTURES := 128
const MAX_DERIVED_TEXTURES := 64
static var _manifest: Dictionary = {}
static var _loaded := false
static var _textures: Dictionary = {}
static var _lru: Array[String] = []
static var _derived_manifest: Dictionary = {}
static var _derived_loaded := false
static var _derived_textures: Dictionary = {}
static var _derived_lru: Array[String] = []

static func manifest() -> Dictionary:
	if not _loaded:
		_loaded = true
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if parsed is Dictionary and parsed.get("version") == 1:
			_manifest = parsed
		else:
			push_error("Moth manifest missing or invalid: " + MANIFEST_PATH)
	return _manifest.duplicate(true)

static func _record(bucket: String, key: String) -> Dictionary:
	if not _loaded: manifest()
	return _manifest.get(bucket, {}).get(key, {})

static func _load_plane(record: Dictionary) -> Texture2D:
	var path: String = record.get("path", "")
	if not path.begins_with("res://moth/generated/") or ".." in path or not path.ends_with(".png"):
		return null
	if _textures.has(path):
		_lru.erase(path)
		_lru.append(path)
		return _textures[path]
	var result := load(path) as Texture2D
	if result == null: return null
	if result.get_width() != int(record.get("width", 0)) or result.get_height() != int(record.get("height", 0)):
		push_error("Moth image dimensions disagree with manifest: " + path)
		return null
	if _lru.size() >= MAX_TEXTURES:
		_textures.erase(_lru.pop_front())
	_textures[path] = result
	_lru.append(path)
	return result

static func texture(name: String) -> Texture2D:
	return _load_plane(_record("textures", name))

static func normal(name: String) -> Texture2D:
	return _load_plane(_record("normals", name))

static func sky(name: String) -> Texture2D:
	return _load_plane(_record("sky", name))

static func effect(name: String) -> Dictionary:
	var record := _record("effects", name)
	if record.is_empty(): return {}
	var frames: Array[Texture2D] = []
	for frame in record.frames:
		var image := _load_plane(frame)
		if image == null: return {}
		frames.append(image)
	return {"frames": frames, "fps": float(record.fps)}

static func material_lut(name: String) -> Dictionary:
	var record := _record("materials", name)
	if record.is_empty(): return {}
	var r := _load_plane(record.r)
	var t := _load_plane(record.t)
	if r == null or t == null: return {}
	return {"r": r, "t": t, "width": int(record.width), "height": int(record.height)}

static func cache_stats() -> Dictionary:
	return {"textures": _textures.size(), "limit": MAX_TEXTURES}

static func clear_cache() -> void:
	_textures.clear()
	_lru.clear()

# ---------------------------------------------------------------- derived ---

static func derived_manifest() -> Dictionary:
	if not _derived_loaded:
		_derived_loaded = true
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DERIVED_MANIFEST_PATH))
		if parsed is Dictionary and parsed.get("version") == 1:
			_derived_manifest = parsed
		else:
			push_warning("Moth derived manifest missing or invalid (optional bucket): " + DERIVED_MANIFEST_PATH)
	return _derived_manifest.duplicate(true)

static func derived_record(key: String) -> Dictionary:
	if not _derived_loaded: derived_manifest()
	return _derived_manifest.get("derived", {}).get(key, {})

static func derived_keys() -> PackedStringArray:
	if not _derived_loaded: derived_manifest()
	var result := PackedStringArray()
	var keys: Array = _derived_manifest.get("derived", {}).keys()
	keys.sort()
	for key: String in keys: result.append(key)
	return result

static func derived_texture(key: String) -> Texture2D:
	var record := derived_record(key)
	if record.is_empty(): return null
	var path: String = record.get("path", "")
	if not path.begins_with("res://moth/derived/") or ".." in path or not path.ends_with(".png"):
		return null
	if _derived_textures.has(path):
		_derived_lru.erase(path)
		_derived_lru.append(path)
		return _derived_textures[path]
	var result := load(path) as Texture2D
	if result == null: return null
	if result.get_width() != int(record.get("width", 0)) or result.get_height() != int(record.get("height", 0)):
		push_error("Derived Moth image dimensions disagree with manifest: " + path)
		return null
	if _derived_lru.size() >= MAX_DERIVED_TEXTURES:
		_derived_textures.erase(_derived_lru.pop_front())
	_derived_textures[path] = result
	_derived_lru.append(path)
	return result

static func derived_cache_stats() -> Dictionary:
	return {"textures": _derived_textures.size(), "limit": MAX_DERIVED_TEXTURES, "keys": _derived_manifest.get("derived", {}).size()}

static func clear_derived_cache() -> void:
	_derived_textures.clear()
	_derived_lru.clear()
