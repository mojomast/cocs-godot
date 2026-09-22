extends RefCounted
## Shared bounded texture registry. Resources are immutable; returned containers are caller-owned.
const MANIFEST_PATH := "res://moth/generated/manifest.json"
const MAX_TEXTURES := 128
static var _manifest: Dictionary = {}
static var _loaded := false
static var _textures: Dictionary = {}
static var _lru: Array[String] = []

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
