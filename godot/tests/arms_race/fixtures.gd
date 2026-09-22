extends SceneTree
const Progress = preload("res://arms_race/progress.gd")
const Fresh = preload("res://arms_race/fresh_input.gd")
const Demo = preload("res://arms_race/demo.gd")
const Board = preload("res://arms_race/scoreboard.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func state(rung: Variant, weapon: Variant = 0) -> Dictionary:
	return {"actors":[{"id":0,"name":"Local","ladder":rung,"weapon":weapon,"frags":3}]}

func _initialize() -> void:
	var p := Progress.new()
	p.apply_state(state(0), 0)
	check(p.rung == 0 and "1 / 10" in p.current and "Rocket Launcher" in p.next, "Initial rung is zero; human label is one")
	p.apply_state(state(2, 2), 0)
	check("+2" in p.transition and "Rail Lance" in p.current, "Bonus promotion reads source rung")
	p.apply_state(state(1, 1), 0)
	check("DEMOTED" in p.transition and "Rocket Launcher" in p.current, "Demotion updates weapon")
	p.apply_state(state(9, 9), 0)
	check("one more kill" in p.next and p.outcome.is_empty(), "Final weapon alone is not victory")
	for invalid: Variant in [null, "3", true, -1, 1.5, 11, INF]:
		p.apply_state(state(invalid), 0)
		check(p.rung == -1 and "unavailable" in p.current, "Reject malformed/missing rung %s" % str(invalid))
	p.apply_state(state(1, 99), 0)
	check("unavailable" in p.current, "Unknown weapon is not invented")
	p.apply_state(state(1, 1), 1)
	check(p.rung == -1 and p.transition.is_empty(), "Identity loss clears local progress")
	var final := {"over":true,"winner":1,"actors":[{"id":0,"name":"Frag leader","ladder":9,"frags":99},{"id":1,"name":"Finisher","ladder":10,"frags":10}]}
	check("Finisher wins" in Progress.result_text(final), "Explicit finisher outranks frags")
	final.winner = null
	final.actors[1].ladder = 9
	check("Frag leader" in Progress.result_text(final), "Frags break a rung tie")
	final.actors[1].frags = 99
	check("Frag leader, Finisher" in Progress.result_text(final), "Timed ties preserved")
	final.actors = [{"id":0,"ladder":0,"frags":0}]
	check("Draw" in Progress.result_text(final), "Zero score is a draw")
	var fresh := Fresh.new()
	var w := InputEventKey.new()
	w.physical_keycode = KEY_W
	w.pressed = true
	fresh.observe(w)
	fresh.boundary()
	check(not fresh.capture_allowed(), "Held movement blocks recapture")
	w.pressed = false
	fresh.observe(w)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	fresh.observe(click)
	check(fresh.capture_allowed(), "Fresh click after releases can capture")
	for boundary: String in ["focus", "death", "respawn", "round", "stale"]:
		fresh.boundary()
		check(not fresh.capture_allowed(), "Held fire blocked at " + boundary)
		click.pressed = false
		fresh.observe(click)
		check(fresh.capture_allowed(), "Release clears boundary latch")
		click.pressed = true
		fresh.observe(click)
	var demo := Demo.new()
	check(not demo.weapon_controls_active(), "Arms Race never permits selection")
	# Detached session owns unparented nodes until ready; explicitly free them.
	for node: Node in [demo.camera,demo.sun,demo.environment,demo.label,demo.selector,demo.combat_label,demo.client,demo.presentation,demo.combat,demo.pickups]: node.free()
	demo.free()
	var board := Board.new()
	root.add_child.call_deferred(board)
	call_deferred("board_checks", board)

func board_checks(board: Node) -> void:
	board.apply_state({"actors":[{"id":0,"name":"Fragger","ladder":1,"frags":99,"deaths":0},{"id":1,"name":"Climber","ladder":3,"frags":2,"deaths":8}]}, 0, true)
	board.render()
	check(board.entries[0].player_name == "Climber" and board.entries[0].team == "4/10", "Shared scoreboard subclass ranks ladder first")
	board.clear_round()
	check(board.entries.is_empty() and board.result.is_empty() and not board.panel.visible, "Restart clears results")
	print("ARMS_FIXTURES ", JSON.stringify({"failures":failures,"release_safe":true}))
	quit(1 if failures else 0)
