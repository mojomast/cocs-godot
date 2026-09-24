extends SceneTree
## Route-registry and menu-tree contracts for res://ui/routes.json and
## res://ui/main_menu.tscn. Headless, no rendering. Must run WITHOUT --smoke
## in the user args: the menu self-quits one frame after MENU_READY on that
## marker (a distinct --contracts arg is accepted and ignored if a marker arg
## is wanted on the command line).

const MENU_SCENE_PATH := "res://ui/main_menu.tscn"
const ROUTES_PATH := "res://ui/routes.json"
const MIN_ROUTES := 22

var failed := false
var checks := 0
var lines: Array[String] = []

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error(message)
	lines.append(("PASS " if value else "FAIL ") + message)

func _initialize() -> void:
	if "--smoke" in OS.get_cmdline_user_args():
		# The menu's smoke self-quit would race this run's own quit codes.
		print("MENU_CONTRACTS checks=1 failures=1")
		print("  FAIL contracts must run without --smoke (the menu would self-quit)")
		quit(1)
		return
	call_deferred("run")

func run() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROUTES_PATH))
	check(raw is Dictionary, "routes.json parses as a JSON object")
	if not raw is Dictionary:
		finish()
		return
	check(int(raw.get("version", 0)) == 1, "schema version is 1")
	var category_list: Variant = raw.get("categories")
	var route_list: Variant = raw.get("routes")
	var map_table: Variant = raw.get("maps")
	check(category_list is Array and not category_list.is_empty(), "categories is a non-empty array")
	check(route_list is Array, "routes is an array")
	check(route_list is Array and route_list.size() >= MIN_ROUTES, "at least %d routes are declared (got %s)" % [MIN_ROUTES, str(route_list.size() if route_list is Array else -1)])
	check(map_table is Dictionary, "maps table is an object")
	if not (category_list is Array) or not (route_list is Array) or not (map_table is Dictionary):
		finish()
		return
	var categories: Array = category_list
	var routes: Array = route_list
	var maps: Dictionary = map_table

	var category_ids := {}
	for category: Variant in categories:
		check(category is Dictionary, "category entry is an object")
		if not category is Dictionary: continue
		var id := str(category.get("id", ""))
		check(not id.is_empty(), "category id '%s' is non-empty" % id)
		check(not category_ids.has(id), "category id '%s' is unique" % id)
		category_ids[id] = true
		check(not str(category.get("label", "")).is_empty(), "category %s has a label" % id)
		check(not str(category.get("description", "")).is_empty(), "category %s has a description" % id)

	for map_id: Variant in maps:
		var entry: Variant = maps[map_id]
		check(entry is Dictionary and not str(entry.get("name", "")).is_empty(),
			"map '%s' resolves to a display name" % str(map_id))

	var route_ids := {}
	for route: Variant in routes:
		check(route is Dictionary, "route entry is an object")
		if not route is Dictionary: continue
		var id := str(route.get("id", ""))
		check(not id.is_empty(), "route id is non-empty")
		check(not route_ids.has(id), "route id '%s' is unique" % id)
		route_ids[id] = true
		check(not str(route.get("label", "")).is_empty(), "route %s has a non-empty label" % id)
		check(not str(route.get("description", "")).is_empty(), "route %s has a non-empty description" % id)
		check(category_ids.has(str(route.get("category", ""))),
			"route %s references a declared category ('%s')" % [id, str(route.get("category", ""))])
		var flags: Variant = route.get("flags")
		check(flags is Array and not flags.is_empty(), "route %s declares flags" % id)
		var has_debug: bool = flags is Array and "--debug-panel" in flags
		if flags is Array and not flags.is_empty():
			check(str(flags[0]).begins_with("--experience="),
				"route %s flags[0] starts with --experience=" % id)
		if id.begins_with("cheats-"):
			check(has_debug, "cheats route %s carries --debug-panel" % id)
		else:
			check(not has_debug, "route %s carries no --debug-panel" % id)
		if id == "lobby":
			check(not has_debug, "lobby route never carries --debug-panel")
		var toggles: Variant = route.get("toggles", [])
		check(toggles is Array and toggles.any(func(toggle: Variant) -> bool:
			return toggle is Dictionary and toggle.get("key") == "diagnostics" and toggle.get("flag") == "--diagnostics"),
			"route %s offers read-only diagnostics" % id)
		if toggles is Array:
			var cheats: bool = toggles.any(func(toggle: Variant) -> bool:
				return toggle is Dictionary and toggle.get("flag") == "--debug-panel")
			check(cheats == (id in ["combat", "horde", "native-dm", "identity-zones"]),
				"route %s only exposes cheats where local authority supports them" % id)
		var params: Variant = route.get("params", [])
		check(params is Array, "route %s params is an array" % id)
		if not params is Array: continue
		var param_keys := {}
		for param: Variant in params:
			check(param is Dictionary, "route %s param entry is an object" % id)
			if not param is Dictionary: continue
			var param_dict: Dictionary = param
			var key := str(param_dict.get("key", ""))
			var kind := str(param_dict.get("kind", ""))
			check(not key.is_empty(), "route %s param has a non-empty key" % id)
			check(not param_keys.has(key), "route %s param '%s' is unique" % [id, key])
			param_keys[key] = true
			if kind == "choice":
				check_choice(id, key, param_dict, maps)
			elif kind == "range":
				check_range(id, key, param_dict)
			else:
				check(false, "route %s param '%s' has a known kind ('%s')" % [id, key, kind])
			check_map_refs(id, param_dict, maps)

	check_tree(routes, categories)
	finish()

func check_choice(route_id: String, key: String, param: Dictionary, maps: Dictionary) -> void:
	var values: Variant = param.get("values")
	var by_map: Variant = param.get("values_by_map")
	check((values is Array and not values.is_empty()) or (by_map is Dictionary and not by_map.is_empty()),
		"choice %s.%s declares values or values_by_map" % [route_id, key])
	if by_map is Dictionary and not by_map.is_empty():
		var table: Dictionary = by_map
		for map_id: Variant in table:
			var listed: Variant = table[map_id]
			check(listed is Array and not listed.is_empty(),
				"values_by_map['%s'] list of %s.%s is non-empty" % [str(map_id), route_id, key])
		var map_keys: Array = table.keys()
		var first_list: Variant = table[map_keys[0]] if not map_keys.is_empty() else null
		check(first_list is Array and not first_list.is_empty(),
			"first values_by_map list of %s.%s is non-empty" % [route_id, key])
		if first_list is Array and not first_list.is_empty():
			# SPEC §3: the values_by_map default is the first list's first entry.
			var derived := str(first_list[0])
			var first_default := str(param.get("default", ""))
			check(first_default.is_empty() or first_default == derived,
				"default of %s.%s equals the first list's first entry '%s' (got '%s')" % [route_id, key, derived, first_default])
		if values is Array and not values.is_empty():
			var declared_value := str(param.get("default", ""))
			check(declared_value.is_empty() or declared_value in values,
				"default of %s.%s is among its declared values" % [route_id, key])
		return
	if values is Array and not values.is_empty():
		var declared := str(param.get("default", ""))
		check(not declared.is_empty(), "choice %s.%s declares a default" % [route_id, key])
		check(declared in values, "default of %s.%s is among its choices" % [route_id, key])

func check_range(route_id: String, key: String, param: Dictionary) -> void:
	check(param.has("min") and param.has("max"), "range %s.%s declares min and max" % [route_id, key])
	check(param.has("default"), "range %s.%s declares a default" % [route_id, key])
	check(param.has("step"), "range %s.%s declares a step" % [route_id, key])
	var low := int(param.get("min", 0))
	var high := int(param.get("max", 0))
	var fallback := int(param.get("default", 0))
	var step := int(param.get("step", 0))
	check(low < high, "range %s.%s has min < max" % [route_id, key])
	check(low <= fallback and fallback <= high, "range %s.%s default is within [min,max]" % [route_id, key])
	check(step >= 1, "range %s.%s step >= 1" % [route_id, key])
	if param.get("max_by_map") is Dictionary:
		var table: Dictionary = param.get("max_by_map")
		for map_id: Variant in table:
			var cap := int(table[map_id])
			check(low <= cap and cap <= high,
				"max_by_map['%s'] of %s.%s stays within [min,max] (got %d)" % [str(map_id), route_id, key, cap])

## Every map id the schema references must resolve in the maps table: plain
## map-param values plus values_by_map / max_by_map keys.
func check_map_refs(route_id: String, param: Dictionary, maps: Dictionary) -> void:
	var key := str(param.get("key", ""))
	if key == "map" and param.get("values") is Array:
		for value: Variant in param.get("values"):
			check(maps.has(str(value)),
				"route %s map value '%s' resolves in the maps table" % [route_id, str(value)])
	if param.get("values_by_map") is Dictionary:
		var by_map: Dictionary = param.get("values_by_map")
		for map_id: Variant in by_map:
			check(maps.has(str(map_id)),
				"route %s values_by_map key '%s' resolves in the maps table" % [route_id, str(map_id)])
	if param.get("max_by_map") is Dictionary:
		var max_table: Dictionary = param.get("max_by_map")
		for max_map_id: Variant in max_table:
			check(maps.has(str(max_map_id)),
				"route %s max_by_map key '%s' resolves in the maps table" % [route_id, str(max_map_id)])

## Instantiate the menu and assert its node-name conventions: one Route_<id>
## button per route, one Category_<id> button per category, exactly one
## Start and one Quit button (see ui/main_menu.gd).
func check_tree(routes: Array, categories: Array) -> void:
	var packed: Variant = load(MENU_SCENE_PATH)
	check(packed is PackedScene, "main_menu.tscn loads as a scene")
	if not packed is PackedScene: return
	var scene: PackedScene = packed
	var menu: Control = scene.instantiate()
	root.add_child(menu)
	check(menu.get_script() != null, "menu scene attaches its script")
	var route_nodes := {}
	collect_prefixed(menu, "Route_", route_nodes)
	check(route_nodes.size() == routes.size(),
		"menu declares one route button per route (%d buttons for %d routes)" % [route_nodes.size(), routes.size()])
	for route: Variant in routes:
		if not route is Dictionary: continue
		var id := str(route.get("id", ""))
		var node_name := "Route_" + id
		check(route_nodes.has(node_name), "route button %s exists" % node_name)
		if route_nodes.has(node_name):
			check(route_nodes[node_name] is Button, "%s is a Button" % node_name)
	var category_nodes := {}
	collect_prefixed(menu, "Category_", category_nodes)
	check(category_nodes.size() == categories.size(),
		"menu declares one button per category (%d buttons for %d categories)" % [category_nodes.size(), categories.size()])
	check(count_named(menu, "Start") == 1, "menu declares exactly one START button")
	var start_node := find_named(menu, "Start")
	check(start_node != null and start_node is Button, "START control is a Button")
	check(count_named(menu, "Quit") == 1, "menu declares exactly one QUIT button")
	var quit_node := find_named(menu, "Quit")
	check(quit_node != null and quit_node is Button, "QUIT control is a Button")
	menu.select_route("combat")
	var local_toggles: Array = menu.params_box.get_children().filter(func(child: Node) -> bool:
		return child is CheckButton and not child.is_queued_for_deletion())
	check(local_toggles.size() == 2, "Combat displays diagnostics and local cheats as menu switches")
	menu.selections.diagnostics = true
	check("--diagnostics" in menu.registry.assemble_args(menu.current_route, menu.selections),
		"enabled menu diagnostics reach the launched scene")
	menu.select_route("lobby")
	var lobby_toggles: Array = menu.params_box.get_children().filter(func(child: Node) -> bool:
		return child is CheckButton and not child.is_queued_for_deletion())
	check(lobby_toggles.size() == 1, "multiplayer lobby displays read-only diagnostics without a cheat switch")

func collect_prefixed(node: Node, prefix: String, found: Dictionary) -> void:
	for child: Node in node.get_children():
		if str(child.name).begins_with(prefix): found[str(child.name)] = child
		collect_prefixed(child, prefix, found)

func count_named(node: Node, wanted: String) -> int:
	var total := 0
	for child: Node in node.get_children():
		if str(child.name) == wanted: total += 1
		total += count_named(child, wanted)
	return total

func find_named(node: Node, wanted: String) -> Node:
	for child: Node in node.get_children():
		if str(child.name) == wanted: return child
		var deeper := find_named(child, wanted)
		if deeper != null: return deeper
	return null

func finish() -> void:
	var failure_count: int = lines.filter(func(line: String) -> bool: return line.begins_with("FAIL")).size()
	print("MENU_CONTRACTS checks=", checks, " failures=", failure_count)
	for line: String in lines:
		if line.begins_with("FAIL"): print("  ", line)
	quit(0 if failure_count == 0 else 1)
