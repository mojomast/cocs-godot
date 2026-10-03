extends SceneTree
## Source-only gate for the Relay Journal derivation. The model must reflect only
## public snapshot state, retain observed completions across death/retry, and
## clear a chapter only when the authority itself regresses it (restart). Native
## execution is authorized separately; parse with gdparse in the source slot.
const Model = preload("res://campaign/journal_model.gd")
var failures := 0

func _initialize() -> void:
	var model := Model.new()

	# A fresh chapter starts locked ahead of the current one and never invents a
	# completion the authority did not report.
	model.observe(state("rootfall-verge", "playing", 0, beats(0, false, 0, false), story([])))
	check(model.accepted and model.chapter == "rootfall-verge", "chapter accepted")
	check(model.objective().step == 0 and model.objective().step_count == 6, "authoritative step read")
	check(model.objective().title == "Rootfall Verge", "authoritative title read")
	var route := model.route()
	check(route.size() == 4, "route covers all four chapters")
	check(route[0].status == "current", "selected chapter is current")
	for i: int in [1, 2, 3]: check(route[i].status == "locked", "unvisited chapter stays locked")
	check(model.workshops().size() == 2 and not model.workshops()[0].completed, "workshops start open")
	check(model.crew().entities.size() == 2 and model.crew().entities[0].name == "Mara" and model.crew().entities[1].name == "Patch", "crew read from story entities")

	# Completing the optional workshop is retained even through death and retry.
	model.observe(state("rootfall-verge", "playing", 2, beats(2, true, 0, false), story(["rootfall-verge-arrival"])))
	check(model.workshops()[0].completed and int(model.workshops()[0].stage) == 2, "completed workshop observed")
	check(model.crew().beats == 1, "observed story beat retained")
	model.observe(state("rootfall-verge", "dead", 2, beats(2, true, 0, false), story(["rootfall-verge-arrival"])))
	check(model.workshops()[0].completed, "death does not erase a recovered workshop")
	model.observe(state("rootfall-verge", "playing", 2, beats(2, true, 0, false), story(["rootfall-verge-arrival"])))
	check(model.workshops()[0].completed and model.crew().beats == 1, "retry keeps the recovered record")

	# Restart is an observed authoritative regression; only this chapter clears.
	model.observe(state("rootfall-verge", "playing", 0, beats(0, false, 0, false), story([])))
	check(not model.workshops()[0].completed, "restart regression clears the workshop")
	check(model.crew().beats == 0, "restart regression clears observed story")

	# Level complete marks the chapter cleared for the route strip.
	model.observe(state("rootfall-verge", "playing", 5, beats(2, true, 2, true, "b"), story(["rootfall-verge-arrival"])))
	model.observe(state("rootfall-verge", "level-complete", 5, beats(2, true, 2, true, "b"), story(["rootfall-verge-arrival"])))
	check(model.cleared("rootfall-verge"), "level-complete is observed as cleared")
	model.observe(state("siltwake-crossing", "playing", 0, beats(0, false, 0, false), story([])))
	route = model.route()
	check(route[0].status == "cleared" and route[1].status == "current", "route advances after continue")
	check(model.workshops().size() == 2, "new chapter exposes its own workshops")

	# Pets accumulate only from the authoritative story count.
	model.observe(state("siltwake-crossing", "playing", 1, beats(0, false, 0, false), story([], 3)))
	check(model.crew().pets == 3, "authoritative pet count retained")

	# Foreign or malformed payloads are ignored without corrupting the record.
	model.observe({"id": "not-quiet-relay", "mapId": "rootfall-verge"})
	model.observe({"id": "quiet-relay", "mapId": "unknown-map"})
	check(model.chapter == "siltwake-crossing", "invalid state cannot replace the observed chapter")
	check(model.cleared("rootfall-verge"), "invalid state cannot erase the observed route")
	# Completion without any optional objectives must still clear on a fresh
	# playing snapshot. Optional-data disappearance is not restart evidence.
	model.observe(state("rootfall-verge","level-complete",5,beats(0,false,0,false),story([])))
	model.observe(state("rootfall-verge","playing",0,beats(0,false,0,false),story([])))
	check(not model.cleared("rootfall-verge"),"fresh playing state cannot retain a stale clear")
	var fractional := state("rootfall-verge","playing",0,beats(0,false,0,false),story([],1))
	fractional.elapsed = 65.75
	fractional.totalElapsed = 145.5
	model.observe(fractional)
	fractional.story.pets = 99
	check(model.objective().elapsed==65 and model.objective().total==145,"fractional authority clocks display whole seconds")
	check(model.crew().pets==1,"later caller mutation cannot change journal facts")

	print("CAMPAIGN_JOURNAL_MODEL_OK" if failures == 0 else "CAMPAIGN_JOURNAL_MODEL_FAILED")
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("JOURNAL_MODEL: ", message)

func beats(stage_a: int, done_a: bool, stage_b: int, done_b: bool, choice: String = "") -> Dictionary:
	return {"version": 1, "beats": [
		{"id":"nursery", "title":"Mara’s seed nursery", "family":"link", "theme":"nursery", "actions":["Connect nursery battery","Start the irrigation rotor"], "hint":"Follow the copper cable.", "result":"+35 armor.", "stage":stage_a, "completed":done_a, "choice":null},
		{"id":"canopy", "title":"Ivo’s canopy receiver", "family":"align", "theme":"receiver", "actions":["Lock signal","Rescue frequency"], "hint":"Face the gold receiver.", "result":"+ammo.", "stage":stage_b, "completed":done_b, "choice":choice if not choice.is_empty() else null}],
		"prompt":null, "feedback":null}

func story(completed: Array, pets: int = 0) -> Dictionary:
	return {"version":1, "entities":[
		{"id":"mara","kind":"operator","name":"Mara","character":"claude","x":0.0,"y":0.0,"z":0.0,"yaw":0.0,"pose":"wave","active":true,"reactionSerial":0},
		{"id":"patch","kind":"puppy","name":"Patch","x":1.0,"y":0.0,"z":1.0,"yaw":0.0,"pose":"sit","active":true,"reactionSerial":0}],
		"completed":completed, "pets":pets, "caption":null, "prompt":null}

func state(map_id: String, phase: String, step: int, interludes: Dictionary, story_value: Dictionary) -> Dictionary:
	return {"id":"quiet-relay", "mapId":map_id, "title":"Rootfall Verge" if map_id == "rootfall-verge" else "Siltwake Crossing",
		"objective":"Recover archive", "detail":"Follow the signal", "phase":phase, "checkpoint":step,
		"marker":{"x":1.0,"y":2.0,"z":3.0,"radius":4.0}, "transmission":{"speaker":"ECHO","text":"Help."},
		"stepIndex":step, "stepCount":6, "enemiesRemaining":0, "holdProgress":0.0, "kills":0,
		"elapsed":10, "totalElapsed":10, "interludes":interludes, "story":story_value, "nextMapId":"siltwake-crossing"}
