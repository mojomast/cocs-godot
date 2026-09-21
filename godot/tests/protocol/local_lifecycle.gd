extends SceneTree
const Presentation = preload("res://world/presentation.gd")
var checks: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		quit(1)
		assert(ok, message)
func _initialize() -> void:
	# Explicit synthetic snapshot transitions, not live respawn evidence.
	var view := Presentation.new()
	var actor: Dictionary = {"id":7,"x":1.0,"y":2.0,"z":3.0,"dead":0.0,"yaw":0.0}
	var state: Dictionary = {"actors":[actor],"over":false}
	check(not view.lifecycle.can_control(), "waiting gates controls")
	view.apply_state(state, 7)
	check(view.lifecycle.can_control() and view.lifecycle.reseed_look, "initial pose seeds look")
	view.apply_state(state, 7)
	check(not view.lifecycle.reseed_look, "normal snapshots preserve mouse look")
	actor.dead = 3.25
	view.apply_state(state, 7)
	check(not view.lifecycle.can_control(), "dead controls neutral")
	check(view.lifecycle.death_transitions == 1, "one death transition")
	check("3.2s" in view.hud_text, "authoritative respawn timer")
	actor.dead = 1.0
	view.apply_state(state, 7)
	check(view.lifecycle.death_transitions == 1 and view.lifecycle.respawn_remaining == 1.0, "dead update no duplicate death")
	# Genuine wire rounding boundary reproduced in native live run 4b4af664:
	# zero timer with zero health is still dead, not a healthy respawn.
	actor.health = 0.0
	actor.dead = 0.0
	view.apply_state(state, 7)
	check(not view.lifecycle.can_control() and not view.lifecycle.reseed_look, "zero-health timer boundary remains gated")
	check(view.lifecycle.respawn_transitions == 0, "timer rounding cannot consume respawn transition")
	view.apply_state(state, -1)
	check(not view.actors[7].visible, "remote zero-health actor stays hidden")
	view.apply_state(state, 7)
	actor.health = 100.0
	actor.x = 50.0
	view.apply_state(state, 7)
	check(view.lifecycle.respawn_transitions == 1 and view.lifecycle.reseed_look, "respawn reseeds camera look")
	check(view.eye_position().x == 50.0, "respawn source position")
	state.over = true
	view.apply_state(state, 7)
	check(not view.lifecycle.can_control() and view.lifecycle.status == "results", "results controls disabled")
	state.over = false
	state.actors = []
	view.apply_state(state, 7)
	check(view.lifecycle.status == "waiting" and not view.lifecycle.can_control(), "missing local actor gates controls")
	view.clear_round()
	check(view.lifecycle.death_transitions == 0 and view.lifecycle.respawn_transitions == 0 and not view.lifecycle.reseed_look, "round resets lifecycle")
	view.free()
	print("PORT_LOCAL_LIFECYCLE_OK synthetic_checks=", checks)
	quit(0)
