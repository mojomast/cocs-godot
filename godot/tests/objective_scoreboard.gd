extends SceneTree
const Board = preload("res://ui/scoreboard.gd")
var checks := 0

func check(ok: bool, context: String) -> void:
	checks += 1
	if not ok:
		push_error(context)
		quit(1)
		assert(ok, context)

func actor(id: int, frags: int, captures: int, time: float, contests: int) -> Dictionary:
	return {"id":id,"name":"Operator %d" % id,"team":id % 2,"frags":frags,"deaths":0,
		"scoreStats":{"objectiveCaptures":captures,"objectiveTime":time,"objectiveContests":contests}}

func state(mode: String, actors: Array) -> Dictionary:
	return {"mapId":"meridian-exchange", "config":{"mode":mode}, "time":12,
		"actors":actors, "teamScores":{"0":3,"1":4}}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(960, 640)
	var board := Board.new()
	root.add_child(board)
	var actors := [actor(0,40,0,1.0,0), actor(1,1,2,8.5,3)]
	for mode: String in ["uplink","assault"]:
		board.apply_state(state(mode,actors), 0)
		check(board.entries[0].order == 1, mode + " objective rank precedes frags")
		check(board.objective_rank_text.contains("Objective order"), mode + " ordering explained")
	board.apply_state(state("holdout",[actor(0,40,2,1.0,3),actor(1,1,0,8.5,0)]), 0)
	check(board.entries[0].order == 1, "holdout ranks by exact fractional objective time")
	board.render()
	check(Rect2(Vector2.ZERO, root.size).encloses(board.panel.get_rect()), "compact objective scoreboard fits 960×640 viewport")
	var unknown := actors.duplicate(true)
	unknown[1].erase("scoreStats")
	board.apply_state(state("uplink",unknown), 0)
	check(board.entries[0].order == 0 and board.objective_rank_text.contains("pending"), "missing metric never implies frag ordering")
	board.apply_state(state("deathmatch",actors), 0)
	check(board.entries[0].order == 0 and board.objective_rank_text.is_empty(), "ordinary frag board unchanged")
	board.clear_round()
	check(board.entries.is_empty() and board.objective_rank_text.is_empty(), "restart clears objective ranking")
	print("OBJECTIVE_SCOREBOARD_OK checks=",checks)
	quit()
