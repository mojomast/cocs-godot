extends "res://ui/game_hud.gd"

func refresh_status() -> void:
	super.refresh_status()
	if is_instance_valid(client) and client.spectating:
		status_title.text = "SPECTATING" if not is_instance_valid(session) or session.phase != 4 else "SPECTATOR · ROUND COMPLETE"
		status_detail.text = "Read-only view · Host restart keeps your spectator seat"
		controls.text = "Tab: scores · Leave / Home to choose a new match"

func apply_state(state: Dictionary, local_id: int) -> void:
	super.apply_state(state, local_id)
	var mode: String = str(state.get("config", {}).get("mode", ""))
	var objective: Dictionary = state.get("objectives") if state.get("objectives") is Dictionary else {}
	if mode == "juggernaut":
		var points: Dictionary = objective.get("points", {})
		score_label.text = "CROWN POINTS %.1f" % float(points.get(str(local_id), 0)) if local_id >= 0 else "CROWN HUNT"
	elif mode == "team-elimination":
		var lives: Dictionary = objective.get("lives", {})
		score_label.text = "LIVES · RED %s / BLUE %s" % [str(lives.get("0", 0)), str(lives.get("1", 0))]
	elif mode == "vip-escort":
		score_label.text = "EXTRACTION %.1f / %.1fs" % [float(objective.get("progress", 0)), float(objective.get("captureSeconds", 4))]
