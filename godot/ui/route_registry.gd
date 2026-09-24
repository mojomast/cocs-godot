extends RefCounted
## Loader and validator for res://ui/routes.json (schema version 1). The menu
## renders exactly what the registry declares; START runs every selection
## through validate_route() before assemble_args() emits it. Flags are copied
## verbatim from the JSON; optional toggle flags are allowlisted for reviewed
## local routes only, and the lobby cannot acquire --debug-panel.

const ROUTES_PATH := "res://ui/routes.json"

var version := 0
var error := ""
var categories: Array = []
var routes: Array = []
var maps: Dictionary = {}
var _categories: Dictionary = {}
var _routes: Dictionary = {}

func open() -> bool:
	error = ""
	version = 0
	categories = []
	routes = []
	maps = {}
	_categories = {}
	_routes = {}
	# Same read pattern as world/catalog.gd:12.
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROUTES_PATH))
	if not data is Dictionary:
		error = "Missing or invalid routes.json"
		return false
	var parsed_version := int(data.get("version", 0))
	if parsed_version != 1:
		error = "Unsupported routes.json schema version: %d" % parsed_version
		return false
	var category_list: Variant = data.get("categories")
	var route_list: Variant = data.get("routes")
	if not category_list is Array or category_list.is_empty():
		error = "routes.json declares no categories"
		return false
	if not route_list is Array or route_list.is_empty():
		error = "routes.json declares no routes"
		return false
	var map_table: Variant = data.get("maps", {})
	if not map_table is Dictionary:
		error = "routes.json maps table is not an object"
		return false
	maps = map_table
	categories = category_list
	routes = route_list
	var seen := {}
	for category: Variant in categories:
		if not category is Dictionary:
			error = "Category entry is not an object"
			return false
		var id := str(category.get("id", ""))
		if id.is_empty() or str(category.get("label", "")).is_empty() or seen.has(id):
			error = "Invalid or duplicate category identity: " + id
			return false
		seen[id] = true
		_categories[id] = category
	for route: Variant in routes:
		if not route is Dictionary:
			error = "Route entry is not an object"
			return false
		var problem := validate_shape(route, seen)
		if not problem.is_empty():
			error = problem
			return false
		_routes[str(route.get("id", ""))] = route
	version = parsed_version
	return true

func validate_shape(route: Dictionary, seen_categories: Dictionary) -> String:
	var id := str(route.get("id", ""))
	if id.is_empty(): return "Route with an empty id"
	if str(route.get("label", "")).is_empty(): return "Route %s has no label" % id
	if str(route.get("description", "")).is_empty(): return "Route %s has no description" % id
	var category := str(route.get("category", ""))
	if not seen_categories.has(category):
		return "Route %s references unknown category %s" % [id, category]
	var flags: Variant = route.get("flags")
	if not flags is Array or flags.is_empty(): return "Route %s declares no flags" % id
	for flag: Variant in flags:
		if not flag is String or not str(flag).begins_with("--"):
			return "Route %s has a malformed flag" % id
	if not str(flags[0]).begins_with("--experience="):
		return "Route %s flags[0] is not an --experience flag" % id
	var debug_flagged: bool = "--debug-panel" in flags
	if debug_flagged and category != "cheats":
		return "--debug-panel may only appear on cheats routes: " + id
	if not debug_flagged and category == "cheats":
		return "Cheats route is missing --debug-panel: " + id
	var params: Variant = route.get("params", [])
	if not params is Array:
		return "Route %s params is not an array" % id
	for param: Variant in params:
		var problem := validate_param_shape(id, param)
		if not problem.is_empty(): return problem
	var toggles: Variant = route.get("toggles", [])
	if not toggles is Array: return "Route %s toggles is not an array" % id
	for toggle: Variant in toggles:
		if not toggle is Dictionary: return "Route %s has a malformed toggle" % id
		var flag := str(toggle.get("flag", ""))
		if flag != "--diagnostics" and not (flag == "--debug-panel" and id in ["combat", "horde", "native-dm", "identity-zones"]):
			return "Route %s has an unsupported toggle" % id
	return ""

func validate_param_shape(route_id: String, param: Variant) -> String:
	if not param is Dictionary:
		return "Route %s has a param that is not an object" % route_id
	var key := str(param.get("key", ""))
	if key.is_empty():
		return "Route %s has a param without a key" % route_id
	var kind := str(param.get("kind", ""))
	if kind == "choice":
		var values: Variant = param.get("values")
		var by_map: Variant = param.get("values_by_map")
		if not (values is Array and not values.is_empty()) and not (by_map is Dictionary and not by_map.is_empty()):
			return "Choice param %s.%s declares no values" % [route_id, key]
	elif kind == "range":
		if int(param.get("min", 0)) >= int(param.get("max", 0)):
			return "Range param %s.%s has min >= max" % [route_id, key]
		if int(param.get("step", 1)) < 1:
			return "Range param %s.%s has step < 1" % [route_id, key]
	else:
		return "Route %s param %s has unknown kind '%s'" % [route_id, key, kind]
	return ""

func has_category(id: String) -> bool:
	return _categories.has(id)

func category_by_id(id: String) -> Dictionary:
	return _categories.get(id, {})

func route_by_id(id: String) -> Dictionary:
	return _routes.get(id, {})

func routes_in_category(id: String) -> Array:
	var out := []
	for route: Dictionary in routes:
		if str(route.get("category", "")) == id: out.append(route)
	return out

func params_of(route: Dictionary) -> Array:
	var params: Variant = route.get("params", [])
	return params if params is Array else []

func toggles_of(route: Dictionary) -> Array:
	var toggles: Variant = route.get("toggles", [])
	return toggles if toggles is Array else []

## Key of the route param whose value selects a map ("" when the route has
## none). values_by_map / max_by_map tables are keyed by that selection.
func map_param_key(route: Dictionary) -> String:
	for param: Dictionary in params_of(route):
		if str(param.get("key", "")) == "map": return "map"
	return ""

func map_display_name(id: String) -> String:
	var entry: Variant = maps.get(id)
	if entry is Dictionary:
		var display := str(entry.get("name", ""))
		if not display.is_empty(): return display
	return id

## Display text for a choice value: map ids resolve through the maps table,
## anything else (modes and the like) is humanized from its id.
func display_value(id: String) -> String:
	if maps.has(id): return map_display_name(id)
	return id.replace("-", " ").capitalize()

## Ordered choices for a choice param under the current map selection.
## values_by_map wins whenever it is declared (strict: a missing per-map list
## yields no choices instead of a union the supervisor would reject).
func choice_values(param: Dictionary, map_id: String) -> Array:
	if param.get("values_by_map") is Dictionary:
		var by_map: Dictionary = param.get("values_by_map")
		if not by_map.is_empty():
			var listed: Variant = by_map.get(map_id)
			return listed if listed is Array else []
	var values: Variant = param.get("values")
	return values if values is Array else []

## Effective choice for the given map: the declared default when it is a
## member, otherwise the first entry (options() allowed[0], SPEC §3).
func choice_default(param: Dictionary, map_id: String) -> String:
	var choices := choice_values(param, map_id)
	if choices.is_empty(): return ""
	var declared := str(param.get("default", ""))
	if declared.is_empty(): return str(choices[0])
	return declared if declared in choices else str(choices[0])

## Effective upper bound for a range param under the current map selection
## (max_by_map mirrors options.mjs, else the base max).
func range_max(param: Dictionary, map_id: String) -> int:
	if param.get("max_by_map") is Dictionary:
		var by_map: Dictionary = param.get("max_by_map")
		if by_map.has(map_id): return int(by_map.get(map_id))
	return int(param.get("max", 0))

## Bounds check for a single param; "" means the value is acceptable.
func validate_param(param: Dictionary, value: Variant, map_id: String) -> String:
	var key := str(param.get("key", ""))
	var kind := str(param.get("kind", ""))
	if kind == "choice":
		var choices := choice_values(param, map_id)
		if choices.is_empty():
			return "--%s has no choices for this map" % key
		if not str(value) in choices:
			return "--%s must be one of the declared choices (got '%s')" % [key, str(value)]
	elif kind == "range":
		if not value is int and not value is float:
			return "--%s must be an integer" % key
		var low := int(param.get("min", 0))
		var high := range_max(param, map_id)
		if int(value) < low or int(value) > high:
			return "--%s must be between %d and %d" % [key, low, high]
	else:
		return "Unknown kind '%s' for --%s" % [kind, key]
	return ""

## Full selection check for a route; "" means START may emit.
func validate_route(route: Dictionary, selections: Dictionary) -> String:
	if route.is_empty(): return "No route selected"
	var map_id := str(selections.get(map_param_key(route), ""))
	for param: Dictionary in params_of(route):
		var key := str(param.get("key", ""))
		if not selections.has(key):
			return "Missing selection for --%s" % key
		var problem := validate_param(param, selections[key], map_id)
		if not problem.is_empty(): return problem
	for toggle: Dictionary in toggles_of(route):
		var key := str(toggle.get("key", ""))
		if not selections.get(key, false) is bool: return "Invalid toggle: " + key
	if str(route.get("id", "")) == "lobby" and selections.get("cheats", false):
		return "Cheats unavailable in multiplayer"
	return ""

## Flags verbatim first, then one --key=value per param in schema order,
## followed by enabled optional toggles. The supervisor revalidates all args.
func assemble_args(route: Dictionary, selections: Dictionary) -> Array:
	var args: Array = []
	for flag: Variant in route.get("flags", []):
		args.append(str(flag))
	for param: Dictionary in params_of(route):
		var key := str(param.get("key", ""))
		args.append("--%s=%s" % [key, str(selections.get(key, ""))])
	for toggle: Dictionary in toggles_of(route):
		if selections.get(str(toggle.get("key", "")), false):
			var flag := str(toggle.get("flag", ""))
			if not flag in args: args.append(flag)
	return args
