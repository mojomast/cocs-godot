extends SceneTree
## Source-only ordinary-input gate for the Relay Journal node. Native execution
## is authorized separately; parse with gdparse in the source slot. The test
## feeds real InputEventKey objects through the unhandled route and proves the
## toggle guards (phase, text field, other modal) and cursor release.
const Journal = preload("res://campaign/journal.gd")
var failures := 0

class Session extends Node:
	var phase := 3
	var startup_error := ""
	var application_focused := true
	var action_pending := false
	var released := 0
	var solo_cheats: Node
	func release_pointer() -> void:
		released += 1
	func social_capturing() -> bool:
		return false

class Cheats extends Node:
	var overlay := Control.new()
	func _init() -> void:
		add_child(overlay)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var session := Session.new()
	root.add_child(session)
	var journal := Journal.new()
	root.add_child(journal)
	journal.bind_session(session)
	check(not journal.available(), "transport phase alone is not a campaign snapshot")

	journal.observe(state("rootfall-verge", "playing", 2, beats(2, true, 0, false), story(["rootfall-verge-arrival"])))
	check(journal.available(),"journal available with playing campaign state")
	check(journal.model.chapter == "rootfall-verge", "observed chapter is the public map id")

	journal._unhandled_input(key(KEY_I))
	check(journal.open and journal.visible, "I opens the journal through unhandled input")
	check(session.released == 1, "opening releases the pointer exactly once")
	check(journal.route.text.contains("Rootfall Verge"), "route text renders chapter titles")
	check(journal.workshop_list.get_child_count() == 2, "both optional workshops are listed")
	check(journal.crew.text.contains("Mara") and journal.crew.text.contains("Patch"), "crew renders rescued companions")
	var first_row := journal.workshop_list.get_child(0).get_instance_id()
	for i in 12:
		var update := state("rootfall-verge","playing",2,beats(2,true,0,false),story(["rootfall-verge-arrival"]))
		update.elapsed = 11.5+i
		journal.observe(update)
	check(journal.workshop_list.get_child_count()==2 and journal.workshop_list.get_child(0).get_instance_id()==first_row,"timer updates reuse workshop nodes")

	var cancel := InputEventKey.new()
	cancel.keycode = KEY_ESCAPE
	cancel.pressed = true
	journal._unhandled_input(cancel)
	check(not journal.open, "ui_cancel closes the open journal")

	journal._unhandled_input(key(KEY_I))
	check(journal.open, "I reopens the journal")
	journal._unhandled_input(key(KEY_I))
	check(not journal.open, "I toggles the journal closed")
	var bindings := root.get_node_or_null("InputBindings")
	if bindings != null:
		var original: Dictionary = bindings.values.duplicate(true)
		bindings.apply_bindings(preload("res://input_bindings/model.gd").rebind(original,"fire","KeyI"))
		journal._unhandled_input(key(KEY_I))
		check(not journal.open and not journal.shortcut_available(),"rebound I is owned by gameplay")
		journal.open_panel()
		check(journal.open,"button access remains functional when I is rebound")
		journal.close_panel()
		bindings.apply_bindings(original)

	session.phase = 4
	journal._unhandled_input(key(KEY_I))
	check(not journal.open, "a terminal phase cannot open the journal")
	session.phase = 3

	var field := LineEdit.new()
	root.add_child(field)
	field.grab_focus()
	journal._unhandled_input(key(KEY_I))
	check(not journal.open, "a focused text field blocks the toggle")
	field.release_focus()

	var cheats := Cheats.new()
	cheats.overlay.visible = true
	root.add_child(cheats)
	session.solo_cheats = cheats
	journal._unhandled_input(key(KEY_I))
	check(not journal.open, "an open cheat modal blocks the toggle")
	cheats.overlay.visible = false

	journal.observe(state("rootfall-verge", "level-complete", 5, beats(2, true, 2, true, "b"), story(["rootfall-verge-arrival"], 2)))
	check(journal.model.cleared("rootfall-verge"), "observed level-complete reaches the route strip")
	check(journal.model.crew().pets == 2, "authoritative pet count reaches the journal")
	journal.observe(state("rootfall-verge", "playing", 0, beats(0, false, 0, false), story([])))
	check(_workshops_open(journal), "restart regression reopens the retained workshop")
	check(not journal.model.cleared("rootfall-verge"), "restart regression clears the current route mark")

	journal.free()
	field.free()
	cheats.free()
	session.free()
	print("CAMPAIGN_JOURNAL_INPUT_OK" if failures == 0 else "CAMPAIGN_JOURNAL_INPUT_FAILED")
	quit(0 if failures == 0 else 1)

# Restart regression is represented honestly: the chapter is playing again, so
# its retained workshop and route mark both fall back to the fresh authority.
func _workshops_open(journal: Control) -> bool:
	return not journal.model.workshops()[0].completed

func key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("JOURNAL_INPUT: ", message)

func beats(stage_a: int, done_a: bool, stage_b: int, done_b: bool, choice: String = "") -> Dictionary:
	return {"version": 1, "beats": [
		{"id":"nursery", "title":"Mara’s seed nursery", "family":"link", "theme":"nursery", "actions":["Connect battery","Start rotor"], "hint":"Follow the cable.", "result":"+35 armor.", "stage":stage_a, "completed":done_a, "choice":null},
		{"id":"canopy", "title":"Ivo’s canopy receiver", "family":"align", "theme":"receiver", "actions":["Lock signal","Rescue frequency"], "hint":"Face the receiver.", "result":"+ammo.", "stage":stage_b, "completed":done_b, "choice":choice if not choice.is_empty() else null}],
		"prompt":null, "feedback":null}

func story(completed: Array, pets: int = 0) -> Dictionary:
	return {"version":1, "entities":[
		{"id":"mara","kind":"operator","name":"Mara","character":"claude","x":0.0,"y":0.0,"z":0.0,"yaw":0.0,"pose":"wave","active":true,"reactionSerial":0},
		{"id":"patch","kind":"puppy","name":"Patch","x":1.0,"y":0.0,"z":1.0,"yaw":0.0,"pose":"sit","active":true,"reactionSerial":0}],
		"completed":completed, "pets":pets, "caption":null, "prompt":null}

func state(map_id: String, phase: String, step: int, interludes: Dictionary, story_value: Dictionary) -> Dictionary:
	return {"id":"quiet-relay", "mapId":map_id, "title":"Rootfall Verge", "objective":"Recover archive",
		"detail":"Follow the signal", "phase":phase, "checkpoint":step,
		"marker":{"x":1.0,"y":2.0,"z":3.0,"radius":4.0}, "transmission":{"speaker":"ECHO","text":"Help."},
		"stepIndex":step, "stepCount":6, "enemiesRemaining":0, "holdProgress":0.0, "kills":0,
		"elapsed":10, "totalElapsed":10, "interludes":interludes, "story":story_value, "nextMapId":"siltwake-crossing"}
