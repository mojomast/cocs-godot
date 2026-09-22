extends SceneTree

const Scoreboard = preload("res://ui/scoreboard.gd")
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		quit(1)
		assert(ok, message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var board := Scoreboard.new()
	root.add_child(board)
	await process_frame
	# Synthetic UI cases, deliberately different totals from individual frags:
	# source suicides can reduce personal frags without reducing team totals.
	var state := {"config":{"mode":"teamdeathmatch"}, "teamScores":{"0":8, "1":5},
		"actors":[{"id":0,"name":"[b]Local[/b]","team":0.0,"frags":2,"deaths":1},
		{"id":1,"name":"Opponent","team":1.0,"frags":4,"deaths":1}]}
	board.apply_state(state, 0)
	board.tab_held = true
	board.refresh_visibility()
	board.render()
	check(board.team_score_text == "Team totals  ·  Red 8  ·  Blue 5", "totals come from snapshot, never actor sums")
	check(board.team_score_text in board.summary.text, "team totals rendered")
	check(board.rows[0].cells[2].text == "Blue" and board.rows[1].cells[2].text == "Red", "wire float team IDs readable")
	check(board.rows[1].cells[1].text == "[b]Local[/b]  · YOU", "plain actor labels and local marker preserved")
	board.apply_state(state, 0)
	check(not board.dirty, "unchanged team snapshot avoids rendering")
	state.teamScores["1"] = 6
	board.apply_state(state, 0)
	check(board.dirty, "team-only score changes invalidate UI")
	board.render()
	check("Blue 6" in board.summary.text, "team-only update rendered")
	board.apply_state(state, 0, true)
	board.render()
	check(board.finished and board.panel.visible and "Red 8" in board.summary.text, "results retain authoritative totals")
	state.teamScores = {"0":NAN, "1":"8"}
	board.apply_state(state, 0)
	check(board.team_score_text == "Team totals  ·  Red —  ·  Blue —", "malformed totals never fabricate zero")
	state.erase("teamScores")
	board.apply_state(state, 0)
	check(board.team_score_text == "Team totals  ·  Red —  ·  Blue —", "missing totals never fall back to actor sum")
	for mode: String in ["deathmatch", "instagib", "rockets"]:
		state.config.mode = mode
		state.teamScores = {"0":8,"1":6}
		board.apply_state(state, 0)
		board.render()
		check(board.team_score_text.is_empty() and not "Team totals" in board.summary.text, "FFA does not display source's always-present teamScores")
	check(Scoreboard.team_label(null) == "—" and Scoreboard.team_label(0.5) == "—", "invalid team is not coerced into Red")
	state.config.mode = "teamdeathmatch"
	board.apply_state(state, 0)
	board.clear_round()
	check(board.team_score_text.is_empty() and board.entries.is_empty(), "round clear removes team totals")
	print("PORT_TEAM_SCORES_OK checks=", checks, " synthetic_ui_cases=true")
	board.queue_free()
	await process_frame
	quit(0)
