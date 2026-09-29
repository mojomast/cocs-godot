extends SceneTree
const Adapter = preload("res://zone_modes/adapter.gd")
const Demo = preload("res://zone_modes/demo.gd")
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error(message)
		quit(1)
		assert(condition, message)

func zone(id: String, x: float) -> Dictionary:
	return {"id":id,"x":x,"y":1.0,"z":-4.0,"radius":4.0,"progress":0.0,"captureSeconds":4.0,"owner":null,"captureTeam":null,"contested":false}

func state(mode: String, map_id: String) -> Dictionary:
	var objective := {"kind":"koth" if mode == "uplink" else "domination", "winner":null,
		"zones":[zone("hill", 12.0)] if mode == "uplink" else [zone("alpha", 2.0),zone("bravo", 12.0),zone("charlie", 25.0)]}
	if mode == "holdout":
		for entry: Dictionary in objective.zones: entry.captureSeconds = 6.0
	if mode == "uplink": objective.merge({"stage":0,"stageCount":3,"stageCaptures":{"0":0,"1":0}})
	else: objective.merge({"holdCount":2,"holdSeconds":30,"holdProgress":{"0":0.0,"1":0.0},"holdTeam":null})
	return {"mapId":map_id,"config":{"mode":mode,"timeLimit":900,"fragLimit":1},"time":1.0,"over":false,"winner":null,
		"actors":[{"id":7,"team":0,"x":0.0,"y":1.0,"z":-4.0,"health":100}],"teamScores":{"0":1.0,"1":2.0},"objectives":objective}

func _initialize() -> void:
	var root := (ProjectSettings.globalize_path("res://") + "../game/").simplify_path() + "/"
	var source_config := FileAccess.get_file_as_string(root + "config.mjs")
	var source_objectives := FileAccess.get_file_as_string(root + "objectives.mjs")
	var source_snapshot := FileAccess.get_file_as_string(root + "core.mjs")
	check("captureSeconds:4,sequence:3" in source_config and "holdCount:2,holdSeconds:30" in source_config, "source rule constants")
	check("updateUplink(match" in source_objectives and "updateHoldout(match" in source_objectives and "state.holdProgress" in source_objectives, "source lifecycle")
	check("stageCaptures:{...(this.objectiveState.stageCaptures" in source_snapshot and "holdTeam:this.objectiveState.holdTeam" in source_snapshot, "source snapshot fields")
	var catalog := preload("res://world/catalog.gd").new()
	check(catalog.open(), "catalog")
	for map_id: String in ["meridian-exchange", "verdant-reliquary", "ember-crucible"]:
		for mode: String in ["uplink", "holdout"]:
			check(Demo.validate_options(catalog.entries, map_id, mode), "eligible map " + map_id + " " + mode)
	var adapter := Adapter.new()
	var renderer := preload("res://zone_modes/renderer.gd").new()
	var uplink := state("uplink", "meridian-exchange")
	check(adapter.apply(uplink,7,uplink.mapId,"uplink"), "initial source hill")
	renderer.apply(adapter.projection)
	check(renderer.markers.hill.position == Vector3(12,1,-4), "initial source geometry")
	check("COMPLETED 0" in adapter.text().detail and "3 total captures" in adapter.text().hint, "initial relay guidance")
	uplink.objectives.stage = 1
	uplink.objectives.stageCaptures["0"] = 1
	uplink.objectives.zones[0] = zone("uplink-2", -16.0)
	check(adapter.apply(uplink,7,uplink.mapId,"uplink") and adapter.target().x == -16.0 and "BANKED 1 : 0" in adapter.text().detail, "rotated source relay and banked count")
	renderer.apply(adapter.projection)
	check(not renderer.markers.has("hill") and renderer.markers["uplink-2"].position == Vector3(-16,1,-4), "stage marker replaced at source coordinates")
	uplink.objectives.stage = 3
	uplink.objectives.stageCaptures["1"] = 2
	uplink.objectives.zones[0] = zone("uplink-3", 4.0)
	uplink.over = true
	uplink.winner = 1
	uplink.objectives.winner = 0
	check(adapter.apply(uplink,7,uplink.mapId,"uplink") and "DEFEAT" in adapter.text().title and "COMPLETED 3" in adapter.text().detail, "source final winner remains sole authority even if objective metadata disagrees")
	var malformed := uplink.duplicate(true)
	malformed.objectives.stageCaptures["1"] = -1
	check(not adapter.apply(malformed,7,uplink.mapId,"uplink") and adapter.projection.is_empty(), "invalid bank clears prior result")
	renderer.apply(adapter.projection)
	check(renderer.markers.is_empty() and renderer.rendered.is_empty(), "invalid source clears markers")
	var holdout := state("holdout", "verdant-reliquary")
	holdout.objectives.zones[0].owner = 0
	holdout.objectives.zones[1].owner = 0
	holdout.objectives.holdProgress["0"] = 16.0
	check(adapter.apply(holdout,7,holdout.mapId,"holdout") and "16.0/30s" in adapter.text().detail and adapter.text().progress > 50, "continuous hold projection")
	holdout.objectives.zones[1].owner = 1
	holdout.objectives.holdProgress["0"] = 0.0
	check(adapter.apply(holdout,7,holdout.mapId,"holdout") and adapter.text().progress == 0 and adapter.target().id != "alpha", "source quorum reset and capture guidance")
	holdout.over = true
	holdout.winner = 1
	holdout.objectives.winner = 1
	holdout.objectives.holdTeam = null
	check(adapter.apply(holdout,7,holdout.mapId,"holdout") and "DEFEAT" in adapter.text().title, "clock winner with no completed hold")
	malformed = holdout.duplicate(true)
	malformed.objectives.holdTeam = 0
	check(not adapter.apply(malformed,7,holdout.mapId,"holdout") and adapter.projection.is_empty(), "invalid winner-only hold team clears stale")
	check(not adapter.apply(holdout,7,"ember-crucible","holdout"), "map mismatch clears projection")
	var combined := holdout.duplicate(true)
	combined.config.mode = "combined-arms"
	combined.objectives.erase("holdCount")
	combined.objectives.erase("holdSeconds")
	combined.objectives.erase("holdProgress")
	combined.objectives.erase("holdTeam")
	check(adapter.apply(combined,7,combined.mapId,"combined-arms") and "COMBINED ARMS" in adapter.text().title, "exact combined-arms config accepts source domination objective")
	check(not adapter.apply(combined,7,combined.mapId,"domination") and adapter.projection.is_empty(), "cannot alias combined-arms snapshot as domination")
	renderer.free()
	print("ZONE_VARIANTS_OK checks=", checks)
	quit()
