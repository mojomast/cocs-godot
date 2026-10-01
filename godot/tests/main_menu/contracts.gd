extends SceneTree
## Route-registry and menu-tree contracts for res://ui/routes.json and
## res://ui/main_menu.tscn. Headless, no rendering. Must run WITHOUT --smoke
## in the user args: the menu self-quits one frame after MENU_READY on that
## marker (a distinct --contracts arg is accepted and ignored if a marker arg
## is wanted on the command line).

const MENU_SCENE_PATH := "res://ui/main_menu.tscn"
const ROUTES_PATH := "res://ui/routes.json"
const MIN_ROUTES := 22
const PREF_SCENE := preload("res://ui/main_menu.tscn")
const MENU_SCRIPT := preload("res://ui/main_menu.gd")
const ATTRACT_SCRIPT := preload("res://ui/attract/demo.gd")

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

	await check_tree(routes, categories)
	await check_attract(routes.size(), categories.size())
	check_preferences()
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
	menu.preferences_path = isolated_preferences_path()
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
	check(count_named(menu, "Settings") == 1, "Home has one keyboard-focusable Settings button")
	check(find_named(menu, "Settings") is Button, "Settings is a native Button")
	var capability_label := find_named(menu, "RouteCapability")
	check(capability_label is Label, "menu renders generated route authority summary")
	if capability_label is Label and not menu.current_route.is_empty():
		check(capability_label.text == menu.registry.capability_summary(menu.current_route),
			"visible authority text comes from registry capability facts")
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
	await check_responsive_layout(menu)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(menu.preferences_path))
	root.remove_child(menu)
	menu.free()

func check_responsive_layout(menu: Control) -> void:
	var old_mode := root.content_scale_mode
	var old_base := root.content_scale_size
	var old_factor := root.content_scale_factor
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var columns := find_named(menu, "Columns") as BoxContainer
	var scroll := find_named(menu, "ContentScroll") as ScrollContainer
	var footer := find_named(menu, "Footer") as Label
	var capability := find_named(menu, "RouteCapability") as Label
	check(columns != null and scroll != null and footer != null and capability != null,
		"Home exposes responsive columns, scroll, footer and authority summary")
	if columns == null or scroll == null or footer == null or capability == null: return
	check(scroll.follow_focus and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"Home scroll follows keyboard focus without horizontal scrolling")
	check(footer.autowrap_mode != TextServer.AUTOWRAP_OFF and capability.autowrap_mode != TextServer.AUTOWRAP_OFF,
		"Home footer and authority summary wrap at compact widths")
	for case: Array in [[Vector2i(760, 520), 1.5], [Vector2i(760, 520), 1.0], [Vector2i(1280, 800), 1.0]]:
		var base: Vector2i = case[0]
		var factor: float = case[1]
		root.content_scale_factor = factor
		root.content_scale_size = base
		for _wait: int in range(12):
			await process_frame
			if menu.size.is_equal_approx(Vector2(base) / factor): break
		await process_frame
		var label := "%dx%d@%.1fx" % [base.x, base.y, factor]
		check(menu.size.is_equal_approx(Vector2(base) / factor), "Home tracks logical viewport " + label)
		check(columns.is_vertical() == (menu.size.x < 800.0), "Home stacks columns at " + label)
		for route_id: String in ["combat", "horde", "lattice-world", "sports"]:
			var route: Dictionary = menu.registry.route_by_id(route_id)
			menu.select_category(str(route.category))
			menu.select_route(route_id)
			await process_frame
			check(columns.get_combined_minimum_size().x <= scroll.size.x + 1.0,
				"%s central content fits horizontal viewport at %s" % [route_id, label])
			check(menu.route_column.size.x <= scroll.size.x + 1.0,
				"%s options column stays within scroll width at %s" % [route_id, label])
		for action: Button in [menu.settings_button, menu.start, menu.quit_button]:
			action.grab_focus()
			await process_frame
			await process_frame
			var viewport_rect := Rect2(scroll.global_position, scroll.size)
			var action_rect := Rect2(action.global_position, action.size)
			check(viewport_rect.grow(1.0).encloses(action_rect),
				"%s reachable by keyboard scroll at %s" % [action.name, label])
	root.content_scale_factor = old_factor
	root.content_scale_size = old_base
	root.content_scale_mode = old_mode

func isolated_preferences_path() -> String:
	return "user://menu_contracts_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]

func fresh_menu(path: String) -> Control:
	var menu: Control = PREF_SCENE.instantiate()
	menu.preferences_path = path
	root.add_child(menu)
	return menu

func discard_menu(menu: Control) -> void:
	root.remove_child(menu)
	menu.free()

func write_preferences(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(value)
		file.close()

func check_preferences() -> void:
	var path := isolated_preferences_path()
	# Three separate scene lifetimes exercise the same stable user:// file.
	var first := fresh_menu(path)
	first.select_category("modes")
	first.select_route("sports")
	first.selections = {"map": "aurora-stadium", "mode": "puma-soccer", "time-limit": 120,
		"round-target": 14, "diagnostics": true, "authority": "forged"}
	first.select_route("objectives")
	first.selections = {"map": "sunscar-convoy", "mode": "payload", "diagnostics": false}
	first.select_route("sports")
	check(first.selections.get("round-target") == 14 and first.selections.get("mode") == "puma-soccer",
		"switching routes restores the saved in-memory choices")
	first.selections["cheats"] = true
	first.save_preferences()
	discard_menu(first)
	var second := fresh_menu(path)
	check(second.current_route.get("id") == "sports" and second.selections.get("round-target") == 14,
		"second menu lifetime restores route and options from disk")
	check(second.selections.get("diagnostics") == true and not second.selections.has("cheats"),
		"diagnostics is retained but cheat activation is discarded")
	second.select_route("objectives")
	check(second.selections.get("map") == "sunscar-convoy" and second.selections.get("mode") == "payload",
		"another route's dependent selections survive a process-style restart")
	second.save_preferences()
	discard_menu(second)
	var third := fresh_menu(path)
	check(third.current_route.get("id") == "objectives" and third.selections.get("mode") == "payload",
		"third menu lifetime restores the last route")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(saved is Dictionary and saved.get("version") == 1 and saved.get("routes") is Dictionary,
		"preference file carries the versioned bounded UI shape")
	if saved is Dictionary and saved.get("routes") is Dictionary:
		check(not saved["routes"].get("sports", {}).has("authority") and not saved["routes"].get("sports", {}).has("cheats"),
			"unknown and cheat keys are never written")
	var before_failed_registry := FileAccess.get_file_as_string(path)
	third.registry_error = "Fixture registry startup failure"
	third.preferences.routes = {}
	third.preferences.last_route = ""
	third.current_route = {}
	third.save_preferences()
	check(FileAccess.get_file_as_string(path) == before_failed_registry,
		"failed registry startup cannot overwrite valid stored preferences")
	discard_menu(third)

	# A valid map drives both the legal mode list and per-map slider ceiling.
	write_preferences(path, JSON.stringify({"version": 1, "last_route": "sports", "routes": {
		"sports": {"map": "ion-speedway", "mode": "puma-soccer", "round-target": 99,
			"time-limit": -2, "diagnostics": "yes", "cheats": true, "wallet": "secret"},
		"objectives": {"map": "unknown", "mode": "payload"},
		"ghost-route": {"map": "anything"}}}))
	var recovered := fresh_menu(path)
	check(recovered.selections.get("mode") == "puma-race" and recovered.selections.get("round-target") == 10
		and recovered.selections.get("time-limit") == 60,
		"dependent mode defaults and map-specific ranges clamp invalid saved values")
	check(recovered.selections.get("diagnostics") == false and not recovered.selections.has("wallet")
		and not recovered.selections.has("cheats") and not recovered.preferences.routes.has("ghost-route"),
		"invalid toggles, authority fields and unknown routes are filtered")
	recovered.select_route("objectives")
	check(recovered.selections.get("map") == "tidal-citadel" and recovered.selections.get("mode") == "ctf",
		"invalid map is defaulted before its dependent mode")
	discard_menu(recovered)

	for bad: String in ["{broken", JSON.stringify({"version": 999, "last_route": "sports"}), " ".repeat(65537),
		JSON.stringify({"version": 1, "last_route": "cheats-native-dm", "routes": {"cheats-native-dm": {"bots": 9},
			"combat": {"cheats": true}}})]:
		write_preferences(path, bad)
		var menu := fresh_menu(path)
		check(menu.current_route.get("id") == "combat" and not menu.selections.get("cheats", false),
			"corrupt, unsupported, oversized or debug-only preferences boot safely")
		discard_menu(menu)
	write_preferences(path, JSON.stringify({"version": 1, "last_route": "combat", "routes": {
		"combat": {"map": "verdant-reliquary", "cheats": true, "diagnostics": true}}}))
	var normal := fresh_menu(path)
	check(normal.selections.get("map") == "verdant-reliquary" and normal.selections.get("diagnostics") == true
		and normal.selections.get("cheats") == false and not normal.start.disabled,
		"normal route restores valid options without arming local cheats")
	discard_menu(normal)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func check_attract(route_count: int, category_count: int) -> void:
	var sample := {"id":"relay-test","map":"rootfall-verge","kind":"combat","camera":"orbit",
		"duration":1.0,"focus":{"x":0,"y":0,"z":0},"frames":[
			{"t":0.0,"state":{"time":0,"actors":[],"campaign":{"story":{}}},"events":[]},
			{"t":1.0,"state":{"time":1,"actors":[],"campaign":{"story":{}}},"events":[]}]}
	check(ATTRACT_SCRIPT._valid_clip(sample) and not ATTRACT_SCRIPT._valid_clip(sample.merged({"camera":"video"}, true))
		and not ATTRACT_SCRIPT._valid_clip(sample.merged({"focus":{"x":NAN,"y":0,"z":0}}, true)),
		"bounded version-1 replay clip accepts authoritative frames, rejects invalid camera and nonfinite focus")
	var settings := root.get_node_or_null("LocalSettings")
	var previous: Dictionary = settings.values.duplicate() if settings != null else {}
	if settings != null:
		settings.set_value("attract_demo_enabled", true, false)
		settings.set_value("reduced_motion", false, false)
	var menu: Control = PREF_SCENE.instantiate()
	menu.preferences_path = isolated_preferences_path()
	menu.attract_test_scene = true
	root.add_child(menu)
	menu.refresh_attract()
	check(not MENU_SCRIPT.attract_window_active(Window.MODE_MINIMIZED, true)
		and not MENU_SCRIPT.attract_window_active(Window.MODE_WINDOWED, false)
		and MENU_SCRIPT.attract_window_active(Window.MODE_WINDOWED, true)
		and MENU_SCRIPT.attract_window_active(Window.MODE_MINIMIZED, false, true),
		"real minimized and unfocused windows cannot animate; virtual headless test windows can")
	check(menu.attract_active and menu.attract_background.visible and menu.attract_stage.active
		and menu.attract_stage.viewport.own_world_3d and not menu.attract_stage.viewport.physics_object_picking,
		"isolated in-engine replay starts beneath the menu without physics input")
	check(menu.attract_stage is SubViewportContainer and find_named(menu, "AttractVideo") == null,
		"menu backdrop uses a private Godot 3D viewport rather than movie playback")
	check(menu.get_child(menu.attract_background.get_index() + 1).name == "Shell",
		"backdrop draws before all menu interface widgets")
	var backdrop_nodes := [menu.attract_background, menu.attract_stage,
		menu.attract_background.get_node("AttractFrame"), menu.attract_background.get_node("AttractVeil")]
	check(backdrop_nodes.all(func(node: Control) -> bool:
		return node.mouse_filter == Control.MOUSE_FILTER_IGNORE and node.focus_mode == Control.FOCUS_NONE),
		"3D stage and its overlays ignore pointer and keyboard focus")
	var category: String = menu.current_category
	menu.category_buttons["modes"].emit_signal("pressed")
	check(menu.current_category == "modes" and menu.start.visible and menu.settings_button.visible,
		"route navigation and action buttons remain available over the reel")
	menu.category_buttons[category].grab_focus()
	await process_frame
	check(menu.get_viewport().gui_get_focus_owner() == menu.category_buttons[category],
		"keyboard focus remains on foreground category controls")
	var frame := menu.attract_background.get_node("AttractFrame") as AspectRatioContainer
	var old_base := root.content_scale_size
	var old_factor := root.content_scale_factor
	var old_mode := root.content_scale_mode
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for logical: Vector2i in [Vector2i(1280, 800), Vector2i(760, 520)]:
		root.content_scale_size = logical
		root.content_scale_factor = 1.0
		for _wait: int in range(12):
			await process_frame
			if menu.size.is_equal_approx(Vector2(logical)): break
		await process_frame
		var stage_size: Vector2 = menu.attract_stage.size
		check(frame.size.is_equal_approx(menu.size) and stage_size.x <= frame.size.x + 1.0
			and stage_size.y <= frame.size.y + 1.0 and absf(stage_size.x / maxf(stage_size.y, 1.0) - 16.0 / 9.0) < 0.02,
			"3D viewport letterboxes without stretch at %dx%d" % [logical.x, logical.y])
		check(menu.attract_stage.viewport.size.x <= 960 and menu.attract_stage.viewport.size.y <= 540,
			"private 3D render resolution is capped at %dx%d" % [logical.x, logical.y])
	root.content_scale_size = old_base
	root.content_scale_factor = old_factor
	root.content_scale_mode = old_mode
	var route_nodes := {}
	var category_nodes := {}
	collect_prefixed(menu, "Route_", route_nodes)
	collect_prefixed(menu, "Category_", category_nodes)
	check(route_nodes.size() == route_count and category_nodes.size() == category_count,
		"background adds no routes or categories")
	menu.attract_stage.clips = [sample, sample.merged({"id":"second","map":"crown-array"}, true)]
	var chapter_before: int = menu.attract_stage.chapter_index
	menu.attract_stage.advance_chapter()
	check(menu.attract_stage.chapter_index == (chapter_before + 1) % 2 and menu.attract_stage.world == null,
		"scripted replay advances chapters without loading an authority or GPU world in the headless fixture")
	menu.attract_stage.advance_chapter()
	check(menu.attract_stage.chapter_index == chapter_before,
		"scripted replay cycles back to its first chapter")
	if settings != null:
		settings.open_panel(true, menu.settings_button)
		menu.refresh_attract()
		check(not menu.attract_active, "Settings overlay pauses the background")
		settings.close_panel()
		menu.refresh_attract()
		check(menu.attract_active, "background resumes after closing Settings")
		settings.set_value("attract_demo_enabled", false, false)
		check(not menu.attract_active and not menu.attract_background.visible
			and menu.attract_stage.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED
			and menu.get_node("AttractBase").visible,
			"local animation toggle stops and hides the 3D renderer")
		settings.set_value("attract_demo_enabled", true, false)
		settings.set_value("reduced_motion", true, false)
		check(not menu.attract_active, "reduced motion stops the reel")
		settings.set_value("reduced_motion", false, false)
		check(menu.attract_active, "background resumes on settings change")
	menu.hide()
	check(not menu.attract_active, "hidden menu stops playback")
	menu.show()
	menu.refresh_attract()
	check(menu.attract_active, "menu resumes when visible")
	menu.stop_attract()
	check(not menu.attract_active, "scene leave stops playback")
	var pref_path: String = menu.preferences_path
	discard_menu(menu)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pref_path))
	if settings != null:
		for key: String in previous: settings.set_value(key, previous[key], false)

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
