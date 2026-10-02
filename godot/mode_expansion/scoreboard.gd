extends "res://ui/scoreboard.gd"
## Mode-scoped ranking/columns layered over the shared responsive scoreboard.
var score_heading := "FRAGS"

func apply_state(state: Dictionary, local_id: int, is_results: bool = false) -> void:
	super.apply_state(state, local_id, is_results)
	var mode: String = str(state.get("config", {}).get("mode", ""))
	var actors: Array = state.get("actors", [])
	var objective: Dictionary = state.get("objectives") if state.get("objectives") is Dictionary else {}
	score_heading = "POINTS" if mode == "juggernaut" else ("ESCORT" if mode == "vip-escort" else "FRAGS")
	for entry: Dictionary in entries:
		var source: Dictionary = actors[entry.order]
		var stats: Dictionary = source.get("scoreStats", {})
		if mode == "juggernaut":
			var points := float(source.get("points", 0))
			entry.frags = "%.1f" % points
			entry.objective_mode = true
			entry.objective_known = true
			entry.objective_rank = [points, float(source.get("frags", 0)), 0.0]
			if bool(source.get("juggernaut", false)): entry.player_name += " · CROWN"
		elif mode == "vip-escort":
			entry.frags = "%.1fs" % float(stats.get("objectiveTime", 0))
			entry.objective_mode = true
			entry.objective_known = true
			entry.objective_rank = [float(stats.get("objectiveCaptures", 0)), float(stats.get("objectiveTime", 0)), float(source.get("frags", 0))]
	entries.sort_custom(ranked_before)
	if mode == "juggernaut": objective_rank_text = "Crown points / frags · source ranking"
	elif mode == "vip-escort": objective_rank_text = "Extraction captures / escort time / frags"
	elif mode == "team-elimination":
		var lives: Dictionary = objective.get("lives", {})
		team_score_text = "Team lives · Red %s · Blue %s" % [str(lives.get("0", 0)), str(lives.get("1", 0))]
	if is_results: objective_rank_text = preload("res://mode_expansion/state.gd").result_text(state) + " · " + objective_rank_text
	dirty = true

func roster_label() -> String:
	# The VIP is a friendly objective NPC, never an enemy-count label.
	var vip_count := entries.filter(func(entry: Dictionary) -> bool: return bool(entry.npc)).size()
	if vip_count == 0: return super.roster_label()
	return "%d combatants · %d VIP" % [entries.size() - vip_count, vip_count]

func render() -> void:
	set_row(header_row, ["#", "PLAYER", "TEAM", score_heading, "DEATHS"], MUTED)
	super.render()
