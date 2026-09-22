extends "res://ui/scoreboard.gd"
## Horde-owned layout specialization. Shared contents, lifecycle, input behavior and
## the measured safe-band geometry (vitals/weapon/help rects) are inherited; this
## board only reserves the actual Horde strip and keeps the compact columns, summary
## and help that read best under it.

func top_edge() -> float:
	var parent := get_parent()
	if parent != null and "horde_label" in parent:
		return maxf(224, parent.horde_label.position.y + parent.horde_label.size.y + 12)
	return 224.0

func layout_top() -> float:
	return top_edge()

func row_cell_widths() -> Array:
	# Horde has no team column worth 80 px; keep the name column wide instead.
	return [28, 0, 52, 50, 60]

func row_separation() -> int:
	return 8

func summary_text(prefix: String, roster: String) -> String:
	# Two lines keep the truthful roster count readable under the Horde strip.
	return "%s\n%s" % [prefix, roster]

func help_text(first: int) -> String:
	# Keep the action and the paging hint inside the compact footer.
	var text: String = super.help_text(first)
	text = text.replace("Waiting for player scores  ·  ", "Scores pending · ")
	text = text.replace("  ·  ", " · ")
	return text
