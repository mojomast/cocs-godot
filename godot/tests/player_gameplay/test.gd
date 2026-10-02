extends SceneTree
const Actions = preload("res://world/combat_actions.gd")
const Status = preload("res://player_gameplay/status.gd")
const Cues = preload("res://player_gameplay/world_cues.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func key(code: int, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	return event
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var input := Actions.new()
	input.record(key(KEY_X, true), true)
	input.record(key(KEY_X, false), true)
	check(input.sample(0, 0, true).mobility, "short X tap survives sample")
	check(input.sample(0, 0, true).mobility, "busy queue retains tap")
	input.queued()
	check(not input.sample(0, 0, true).mobility, "queued tap drains")
	for boundary in ["focus", "pause", "death", "spectator", "mode", "vehicle"]:
		input.record(key(KEY_X, true), true)
		input.clear()
		input.record(key(KEY_X, true), true)
		check(not input.sample(0, 0, true).mobility, boundary + " requires release")
		input.record(key(KEY_X, false), false)
		input.record(key(KEY_X, true), true)
		check(input.sample(0, 0, true).mobility, boundary + " fresh press")
		input.record(key(KEY_X, false), true)
		input.queued()
	var fixtures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/player_gameplay/fixtures.json"))
	var projector := Status.new()
	for row: Dictionary in fixtures.states:
		var actor: Dictionary = row.state.actors[0]
		var model := projector.project(actor, row.state.config)
		check(not model.is_empty() and model.power.cooldown > 0, row.operator + " authoritative cooldown")
		check(not model.passive.is_empty() and not model.mobility.name.is_empty(), row.operator + " full kit")
		check(projector.project(actor, {}, false).is_empty(), row.operator + " suspended")
		var dead := actor.duplicate(true)
		dead.health = 0
		check(projector.project(dead).is_empty(), row.operator + " dead")
		check(projector.project(actor, {"mode":"instagib"}).power.state == "MODE DISABLED", row.operator + " instagib")
		check(projector.project(actor, {"mode":"puma-race"}).power.state == "MODE DISABLED", row.operator + " race")
		var carrier := actor.duplicate(true)
		carrier.carryingFlag = true
		check(projector.project(carrier).power.state == "CARRIER LOCK", row.operator + " flag lock")
		actor.vehicleId = "test-vehicle"
		check(projector.project(actor).power.state == "IN VEHICLE", row.operator + " mounted")
	var cues := Cues.new()
	root.add_child(cues)
	cues.apply_state(fixtures.rope)
	check(cues.slots.size() == 1, "source anchor renders shared cable")
	var start: Vector3 = cues.slots.values()[0].marker.position
	check(absf(start.y - 0.15) < 0.001, "boarding marker uses source feet convention plus visual lift")
	cues.apply_state({"actors":[]})
	check(cues.slots.is_empty(), "absent rope removed")
	var events := [{"id":1,"type":"power","harness":"codex","pos":{"x":0,"y":1.45,"z":0}}]
	cues.apply_events(events, false)
	cues.apply_events(events, true)
	check(cues.bursts.is_empty(), "suspended event cannot replay")
	events[0].id = 2
	cues.apply_events(events, true)
	cues.apply_events(events, true)
	check(cues.bursts.size() == 1, "event dedup")
	cues.advance(1)
	check(cues.bursts.is_empty(), "burst expires")
	cues.clear_round()
	cues.free()
	var binding := preload("res://player_gameplay/session_binding.gd").new()
	var public_frame := {"actors":[{"id":1}],"time":5}
	binding.snapshot = public_frame
	binding.clear_round()
	check(public_frame.has("actors"), "round reset never mutates received frame")
	binding.cues.free()
	binding.panel.free()
	binding.free()
	print("GAMEPLAY_TEST ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(0 if failures == 0 else 1)
