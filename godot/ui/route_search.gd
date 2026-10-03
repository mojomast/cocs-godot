extends RefCounted
## Pure, catalog-backed Home search. Results contain only destinations/maps
## already exposed by route params; this helper never creates launch arguments.

static func normalize_query(value: String) -> String:
	var clean := value.to_lower().replace("\t", " ").replace("\r", " ").replace("\n", " ").strip_edges()
	return " ".join(clean.split(" ", false))

static func search(registry: Variant, query: String, debug_enabled: bool = false) -> Array:
	var needle := normalize_query(query)
	var results: Array = []
	if needle.is_empty(): return results
	for route: Dictionary in registry.routes:
		var category := str(route.get("category", ""))
		if category == "cheats" and not debug_enabled: continue
		var route_id := str(route.get("id", ""))
		var route_label := str(route.get("label", ""))
		var route_text := normalize_query(route_id + " " + route_label + " " + str(route.get("description", "")))
		if route_text.contains(needle):
			results.append({"kind":"route", "route_id":route_id, "route_label":route_label,
				"category_id":category, "map_id":"", "map_label":""})
		var map_key := str(registry.map_param_key(route))
		if map_key.is_empty(): continue
		var map_param: Dictionary = {}
		for param: Dictionary in registry.params_of(route):
			if str(param.get("key", "")) == map_key:
				map_param = param
				break
		# Map selectors in the catalog expose a fixed values list. Do not guess
		# from capability metadata or union unrelated per-map option tables.
		var map_ids: Array = registry.choice_values(map_param, "")
		for raw_map_id: Variant in map_ids:
			var map_id := str(raw_map_id)
			var map_label := str(registry.map_display_name(map_id))
			if normalize_query(map_id + " " + map_label).contains(needle):
				results.append({"kind":"map", "route_id":route_id, "route_label":route_label,
					"category_id":category, "map_id":map_id, "map_label":map_label})
	return results
