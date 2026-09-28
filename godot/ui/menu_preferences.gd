extends RefCounted
## Local menu convenience only. Every value is rebuilt against the current
## route registry; this file is never an authority for launch arguments.

const VERSION := 1
const MAX_BYTES := 65536

var path: String
var routes: Dictionary = {}
var last_route := ""

func _init(file_path: String = "user://menu_preferences.json") -> void:
	path = file_path

func load_from_disk(registry: Variant) -> void:
	routes = {}
	last_route = ""
	if not FileAccess.file_exists(path): return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return
	if file.get_length() > MAX_BYTES:
		file.close()
		return
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK: return
	var data: Variant = parser.data
	if not data is Dictionary or typeof(data.get("version")) != TYPE_FLOAT or data.get("version") != VERSION:
		return
	var saved: Variant = data.get("routes")
	if saved is Dictionary:
		for route: Dictionary in registry.routes:
			var id := str(route.get("id", ""))
			if not _storable(route) or not saved.get(id) is Dictionary: continue
			routes[id] = normalize(registry, route, saved[id])
	var candidate: Variant = data.get("last_route")
	if candidate is String:
		var route: Dictionary = registry.route_by_id(candidate)
		if _storable(route): last_route = candidate

func _storable(route: Dictionary) -> bool:
	return not route.is_empty() and str(route.get("category", "")) != "cheats" and not "--debug-panel" in route.get("flags", [])

func normalize(registry: Variant, route: Dictionary, raw: Dictionary) -> Dictionary:
	var clean := {}
	var params: Array = registry.params_of(route)
	var map_key: String = registry.map_param_key(route)
	# Resolve the map before choices and ranges that depend on it.
	if not map_key.is_empty():
		for param: Dictionary in params:
			if str(param.get("key", "")) == map_key:
				clean[map_key] = _choice(registry, param, raw.get(map_key), "")
				break
	var map_id := str(clean.get(map_key, ""))
	for param: Dictionary in params:
		var key := str(param.get("key", ""))
		if key == map_key: continue
		if str(param.get("kind", "")) == "choice":
			clean[key] = _choice(registry, param, raw.get(key), map_id)
		else:
			var low := int(param.get("min", 0))
			var high: int = registry.range_max(param, map_id)
			var value: Variant = raw.get(key)
			if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
				value = param.get("default", low)
			if value is float and (is_nan(value) or is_inf(value)):
				value = param.get("default", low)
			var step := maxi(1, int(param.get("step", 1)))
			clean[key] = clampi(low + roundi((clampf(float(value), low, high) - low) / step) * step, low, high)
	for toggle: Dictionary in registry.toggles_of(route):
		if str(toggle.get("flag", "")) == "--debug-panel": continue
		var key := str(toggle.get("key", ""))
		var value: Variant = raw.get(key)
		clean[key] = value if value is bool else bool(toggle.get("default", false))
	# Cross-field constraints, e.g. Claude requires the Claude Code harness.
	if not registry.validate_route(route, clean).is_empty():
		if clean.get("operator") == "claude" and clean.has("harness"):
			clean["harness"] = "claudecode"
	return clean

func _choice(registry: Variant, param: Dictionary, value: Variant, map_id: String) -> String:
	var allowed: Array = registry.choice_values(param, map_id)
	return value if value is String and value in allowed else registry.choice_default(param, map_id)

func remember(registry: Variant, route: Dictionary, selections: Dictionary) -> void:
	if not _storable(route): return
	var id := str(route.get("id", ""))
	routes[id] = normalize(registry, route, selections)
	last_route = id

func save_to_disk() -> bool:
	var text := JSON.stringify({"version": VERSION, "last_route": last_route, "routes": routes})
	if text.to_utf8_buffer().size() > MAX_BYTES: return false
	var temp := path + ".%d.tmp" % OS.get_process_id()
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return false
	file.store_string(text)
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	if ok:
		ok = DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(path)) == OK
	if not ok: DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
	return ok
