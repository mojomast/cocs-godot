extends SceneTree
const Adapter = preload("res://zone_modes/adapter.gd")
const Demo = preload("res://zone_modes/demo.gd")
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		quit(1)
		assert(ok, message)

func _initialize() -> void:
	var state: Dictionary = JSON.parse_string('{"mapId":"verdant-reliquary","config":{"mode":"koth","timeLimit":60},"time":20,"over":false,"winner":null,"actors":[{"id":0,"team":0,"x":8,"y":0,"z":-4,"health":100}],"teamScores":{"0":2.5,"1":1},"objectives":{"kind":"koth","winner":null,"zones":[{"id":"alpha","x":8,"y":0,"z":-4,"radius":4,"progress":35,"captureSeconds":5,"owner":null,"captureTeam":0,"contested":false}]}}')
	var model := Adapter.new()
	check(model.apply(state, 0, "verdant-reliquary", "koth"), "JSON floats are valid team IDs")
	check("FRIENDLY capturing" in model.text().detail and "INSIDE" in model.text().hint and "2.5 : 1.0" in model.text().title, "team zero, progress and fractional score")
	for field: String in ["owner", "captureTeam", "contested", "y", "radius"]:
		var missing := state.duplicate(true)
		missing.objectives.zones[0].erase(field)
		check(not model.apply(missing, 0, "verdant-reliquary", "koth") and model.projection.is_empty(), "missing " + field + " clears stale objective")
	for bad: Variant in ["0", true, 0.5, 2, NAN]:
		var invalid := state.duplicate(true)
		invalid.actors[0].team = bad
		check(not model.apply(invalid, 0, "verdant-reliquary", "koth"), "reject non-team numbers/types")
	check(not model.apply(state, 9, "verdant-reliquary", "koth"), "missing recipient")
	check(not model.apply(state, 0, "meridian-exchange", "koth"), "map identity")
	check(not model.apply(state, 0, "verdant-reliquary", "domination"), "mode identity")
	state.objectives.zones[0].contested = true
	state.objectives.zones[0].owner = 1.0
	check(model.apply(state, 0, "verdant-reliquary", "koth") and "CONTESTED" in model.text().detail, "contested source state")
	var renderer := preload("res://zone_modes/renderer.gd").new()
	renderer.apply(model.projection)
	check(renderer.markers.alpha.position == Vector3(8,0,-4), "source marker pose")
	check(is_equal_approx(renderer.markers.alpha.get_node("Radius").mesh.outer_radius,4.08), "source ring radius")
	state.objectives.zones[0].id = "bravo"
	state.objectives.zones[0].x = -20.0
	state.objectives.zones[0].y = 3.0
	model.apply(state, 0, "verdant-reliquary", "koth")
	renderer.apply(model.projection)
	check(not renderer.markers.has("alpha") and renderer.markers.bravo.position == Vector3(-20,3,-4), "rotation replaces exact source marker")
	state.over = true
	state.winner = 0.0
	model.apply(state, 0, "verdant-reliquary", "koth")
	check("VICTORY" in model.text().title, "top-level timed winner used even if objective winner null")
	renderer.clear_round()
	check(renderer.markers.is_empty() and renderer.rendered.is_empty(), "round reset")
	renderer.free()
	var catalog := preload("res://world/catalog.gd").new()
	check(catalog.open() and catalog.entries.size() == 9, "all nine locked maps preserved")
	for id: String in catalog.entries:
		for mode: String in ["koth", "domination"]:
			check(Demo.validate_options(catalog.entries,id,mode) == (mode in catalog.entries[id].modes), "locked mode map matrix")
	check(not Demo.validate_options(catalog.entries,"crosswire","koth"), "legacy unsupported map rejected")
	check(not Demo.validate_options(catalog.entries,"meridian-exchange","payload"), "foreign mode rejected")
	print("ZONE_UNIT_OK checks=", checks)
	quit()
