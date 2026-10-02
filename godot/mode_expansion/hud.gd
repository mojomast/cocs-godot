extends "res://ui/objective_hud.gd"

func bind_session(target: Node) -> void:
	super.bind_session(target)
	if not is_instance_valid(session): return
	if session.mode_panel.get_parent() != objective_panel: session.mode_panel.reparent(objective_panel)
	session.mode_card.hide()
	arrange_mode()

func arrange_mode() -> void:
	if not is_instance_valid(session) or not is_instance_valid(objective_panel): return
	var small := compact()
	var width := get_viewport().get_visible_rect().size.x - (40 if small else 80)
	width = minf(width, 648)
	for item: Label in [session.objective_label, session.connection_label]:
		item.custom_minimum_size.x = width
		item.size.x = width
		item.add_theme_font_size_override("font_size", 12 if small else 14)
	# Room/actions remain reachable with the released cursor. Captured compact
	# play leads with objective, vitals and source ability state, not room chrome.
	var details: bool = not small or (Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and session.presentation.lifecycle.can_control())
	session.connection_label.visible = details
	session.restart_button.get_parent().visible = details
	objective_panel.visible = session.phase in [3, 4]
	controls.tooltip_text = full_controls
	status_title.visible = not (small and status_title.text == "ELIMINATED")
	if not status_title.visible and not status_detail.text.begins_with("ELIMINATED"):
		status_detail.text = "ELIMINATED · " + status_detail.text.replace("  ·  Waiting for server", "")
		status_detail.add_theme_font_size_override("font_size", 14)
	layout_objective()
	if small:
		var view := get_viewport().get_visible_rect().size
		controls.text = "Esc: details · Tab: scores"
		controls.position = Vector2(10, view.y - 28)
		controls.size = Vector2(maxf(80, view.x - 240), 22)
		controls.add_theme_font_size_override("font_size", 12)

func refresh_status() -> void:
	super.refresh_status()
	if is_instance_valid(client) and client.spectating:
		status_title.text = "SPECTATING" if not is_instance_valid(session) or session.phase != 4 else "SPECTATOR · ROUND COMPLETE"
		status_detail.text = "Read-only view · Host restart keeps your spectator seat"
		controls.text = "Tab: scores · Leave / Home to choose a new match"
	arrange_mode()

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
