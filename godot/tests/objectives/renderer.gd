extends SceneTree
const Renderer = preload("res://objectives/renderer.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var renderer := Renderer.new()
	root.add_child(renderer)
	var state := {"config":{"mode":"ctf"},"actors":[{"id":0,"team":0}],"flags":[{"team":1,"state":"carried","carrier":0,"x":2,"y":3,"z":4}],"teamScores":{"0":0,"1":0}}
	renderer.apply_state(JSON.parse_string(JSON.stringify(state)), 0)
	check(renderer.markers.size() == 1, "JSON-decoded numeric team renders")
	renderer.apply_state(state, 0)
	check(renderer.markers.size() == 1, "one flag")
	var id: int = renderer.markers.flag_1.get_instance_id()
	check(renderer.markers.flag_1.position == Vector3(2,3,4), "exact source height")
	check("actor 0" in renderer.hud_text, "zero carrier valid")
	state.flags[0].carrier = 2
	state.flags[0].x = 8
	renderer.apply_state(state, 0)
	check(renderer.markers.flag_1.get_instance_id() == id, "stable identity")
	check(renderer.markers.flag_1.position.x == 8, "absent carrier uses source flag position")
	state.flags[0].state = "dropped"
	state.flags[0].carrier = null
	renderer.apply_state(state, 0)
	check("dropped" in renderer.hud_text, "drop status")
	state.flags = []
	renderer.apply_state(state, 0)
	check(renderer.markers.is_empty(), "removal")
	state.flags = [{"team":1,"state":"at-base","carrier":null,"x":72,"y":0,"z":0}]
	renderer.apply_state(state, 0)
	check(renderer.markers.size() == 1, "reappearance")
	state.flags[0].x = NAN
	renderer.apply_state(state, 0)
	check(renderer.markers.is_empty(), "nonfinite rejected")
	state.flags = "malformed"
	renderer.apply_state(state, 0)
	check(renderer.markers.is_empty(), "wrong shape rejected")
	var payload := {"config":{"mode":"payload"},"actors":[{"id":0,"team":0}],"objectives":{"kind":"payload","attacker":0,"defender":1,"payload":{"position":{"x":1,"y":7.25,"z":3},"distance":2,"total":100,"pushing":null,"contested":false,"delivered":false},"zones":[]}}
	renderer.apply_state(payload, 0)
	check(renderer.markers.size() == 1 and renderer.markers.has("cart"), "mode clears flag")
	check(renderer.markers.cart.position.y == 7.25, "cart exact height")
	check("IDLE" in renderer.hud_text, "authoritative idle")
	check(not "DELIVERED" in renderer.hud_text, "no inferred outcome")
	payload.objectives.payload.contested = true
	renderer.apply_state(payload, 0)
	check("CONTESTED" in renderer.hud_text, "authoritative contest")
	payload.objectives.payload.erase("position")
	renderer.apply_state(payload, 0)
	check(renderer.markers.is_empty(), "missing cart clears stale node")
	renderer.apply_state({}, 0)
	check(renderer.hud_text == "Objectives unavailable", "missing fields remain unknown")
	renderer.clear_round()
	check(renderer.markers.is_empty() and renderer.rendered.is_empty(), "reset")
	renderer.free()
	print("OBJECTIVE_TESTS checks=", checks, " failures=", failures, " synthetic=true")
	quit(1 if failures else 0)
