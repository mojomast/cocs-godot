extends SceneTree
const Captions = preload("res://experience/caption_model.gd")
const Combat = preload("res://experience/combat_info.gd")
const Settings = preload("res://ui/local_settings.gd")
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error("EXPERIENCE_FAIL " + message)
		quit(1)
		assert(ok, message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experience/source_fixture.json"))
	var model := Captions.new()
	for row: Dictionary in fixture.samples:
		check(model.text_for(row.event) == row.expected, "source caption " + JSON.stringify(row.event))
	for row: Dictionary in fixture.replacement:
		var expected: Dictionary = row.expected if row.expected is Dictionary else {}
		check(Captions.accept(row.current, row.candidate, float(row.at)) == expected, "source replacement " + JSON.stringify(row))
	for row: Dictionary in fixture.badges:
		check(Array(Combat.badges(row.entry if row.entry is Dictionary else {})) == row.expected, "source badges " + JSON.stringify(row.entry))
	model.consume([{"type":"mission-lost"}, {"type":"shot","actor":0}], 1, 0, true)
	check(model.line(1) == "Mission failed", "mission failure survives same-batch weapon chatter")
	model.consume([{"type":"shot","actor":0}], 2, 0, true)
	check(model.line(2) == "Mission failed", "automatic fire cannot replace protected line")
	check(model.line(3.3).is_empty(), "caption expires without repeat extension")
	model.clear()
	model.consume([{"type":"damage","actor":1}, {"type":"shot","actor":1}], 4, 0, true)
	check(model.line(4).is_empty(), "remote personal events are not local damage or gunfire captions")
	model.consume([{"type":"shot","actor":0}], 4, 0, true)
	model.consume([{"type":"shot","actor":0}], 5, 0, true)
	check(float(model.current.at) == 4, "identical machinegun captions do not reset lifetime")
	model.consume([], 5, 0, false)
	check(model.current.is_empty(), "turning off captions clears history")
	var old := Settings.normalize({"mute":true,"ui_scale":150,"announcer_enabled":false})
	check(old.mute and old.ui_scale == 150 and not old.announcer_enabled and not old.captions, "additive migration preserves preferences")
	check(old.caption_scale == 100 and old.caption_position == "bottom" and old.caption_background == "dim", "source caption defaults")
	var bad := Settings.normalize({"captions":"true","caption_scale":999,"caption_position":"left","caption_background":"neon"})
	check(not bad.captions and bad.caption_scale == 160 and bad.caption_position == "bottom" and bad.caption_background == "dim", "strict normalization and clamp")
	var info := Combat.new()
	info.snapshot({"time":10,"actors":[{"id":0,"health":100,"name":"Local"},{"id":1,"name":"Visible attacker","weapon":2,"x":999}]}, 0)
	check(not info.actors[1].has("x"), "retained actor information excludes positions")
	for i: int in range(4): info.events([{"type":"damage","actor":0,"source":1,"amount":i+10}])
	check(info.hits.size() == 3 and info.hits[0].amount == 11 and info.hits[2].amount == 13, "three newest incoming authoritative hits")
	check(info.recap().is_empty(), "recap stays out of live aiming HUD")
	info.events([{"type":"death","actor":0}])
	check(info.recap().contains("Visible attacker") and info.recap().contains("13 damage"), "death shows read-only attribution")
	info.events([{"type":"spawn","actor":0}])
	check(info.hits.is_empty() and not info.dead, "respawn clears previous life")
	info.events([{"type":"damage","actor":0,"source":99,"amount":40}])
	check(info.hits[0].name == "Unknown source" and info.hits[0].detail.is_empty(), "hidden attacker has no invented identity or weapon")
	info.snapshot({"time":11,"actors":[{"id":2,"health":100}]},2)
	check(info.hits.is_empty(), "seat handoff clears ledger")
	info.events([{"type":"death","actor":3,"killer":2,"overkill":55}])
	check(info.latest_kill.contains("OVERKILL"), "received local kill overkill badge")
	info.clear()
	check(info.latest_kill.is_empty() and info.actors.is_empty(), "round/reconnect reset clears all cached attribution")
	print("EXPERIENCE_CONTRACTS_OK checks=", checks)
	quit()
