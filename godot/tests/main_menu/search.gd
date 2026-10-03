extends SceneTree
## Native-pending contract checks for the catalog-backed, non-authoritative
## Home search. These exercise real route/map data rather than a duplicate fixture.

const Registry = preload("res://ui/route_registry.gd")
const Search = preload("res://ui/route_search.gd")
var failed := false

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
	print(("PASS " if ok else "FAIL ") + message)

func _initialize() -> void:
	var registry = Registry.new()
	check(registry.open(), "search loads the production route registry")
	if not registry.error.is_empty():
		quit(1)
		return
	var campaign := Search.search(registry, "  THE\tQUIET  ")
	check(_has(campaign, "campaign", "route", ""), "case-folded whitespace search finds the Campaign title")
	var description := Search.search(registry, "four linked solo chapters")
	check(_has(description, "campaign", "route", ""), "route description text is searchable")
	var named_map := Search.search(registry, " PRISM   FOUNDRY ")
	check(_has(named_map, "native-dm", "map", "prism-foundry"), "real map display name resolves to its declared option id")
	var map_id := Search.search(registry, "prism-foundry")
	check(_has(map_id, "native-dm", "map", "prism-foundry"), "canonical map id is searchable")
	check(Search.search(registry, "no-such-destination").is_empty(), "unknown query returns no results")
	var hidden := Search.search(registry, "cheats-native-dm", false)
	check(not _has(hidden, "cheats-native-dm", "route", "")
		and not _has(hidden, "cheats-native-dm", "map", ""), "debug-only routes and their maps stay hidden outside debug mode")
	var visible := Search.search(registry, "cheats-native-dm", true)
	check(_has(visible, "cheats-native-dm", "route", ""), "debug route search is available only when debug is enabled")
	print("HOME_SEARCH_OK" if not failed else "HOME_SEARCH_FAILED")
	quit(1 if failed else 0)

func _has(results: Array, route_id: String, kind: String, map_id: String) -> bool:
	for result: Dictionary in results:
		if str(result.get("route_id", "")) == route_id and str(result.get("kind", "")) == kind:
			if map_id.is_empty() or str(result.get("map_id", "")) == map_id: return true
	return false
