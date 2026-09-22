extends "res://ui/scoreboard.gd"
## Horde-owned layout specialization. Shared scoreboard contents, lifecycle and
## input behavior are inherited; reserve the actual Horde strip, including results.
var reserved := 224.0

func top_edge() -> float:
	var parent := get_parent()
	if parent != null and "horde_label" in parent:
		return maxf(224, parent.horde_label.position.y + parent.horde_label.size.y + 12)
	return 224.0

func resize() -> void:
	reserved = top_edge()
	var viewport := get_viewport().get_visible_rect().size
	var team_height := 0 if team_score_text.is_empty() else 28
	page_size = clampi(int((viewport.y - reserved - 24 - 190 - team_height) / ROW_HEIGHT), 3, MAX_VISIBLE)
	panel.size.x = minf(760, viewport.x - 48)
	change_page(0)
	dirty = true
	position_panel()

func position_panel() -> void:
	var viewport := get_viewport().get_visible_rect().size
	panel.position = Vector2((viewport.x - panel.size.x) / 2, maxf(top_edge(), (viewport.y - panel.size.y) / 2))

func _process(delta: float) -> void:
	if not is_equal_approx(reserved, top_edge()): resize()
	super._process(delta)
