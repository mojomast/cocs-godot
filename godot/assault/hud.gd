extends "res://ui/objective_hud.gd"

func bind_session(target: Node) -> void:
	super.bind_session(target)
	var box := stack(objective_panel)
	session.objective_label.reparent(box)
	session.objective_label.add_theme_color_override("font_color", INK)
	layout_objective()

func refresh_status() -> void:
	super.refresh_status()
	if not is_instance_valid(session): return
	objective_panel.visible = session.phase in [3, 4]
	session.objective_label.add_theme_font_size_override("font_size", 14 if compact() else 16)
	layout_objective()

func objective_text() -> String:
	var text: String = session.assault.text(session.presentation.local_actor.get("team"), session.phase == 4)
	if compact():
		text = text.replace("Team 0 attacks / Team 1 defends", "T0 attacks / T1 defends")
		text = text.replace(" · Defend alone: full drain · Both:", " · Defend: full drain\nBoth:")
	if session.phase == 3: text += "\nSource clock: %.1fs remaining" % session.source_remaining
	return text
