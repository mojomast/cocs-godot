extends "res://ui/scoreboard.gd"
## Horde-owned layout specialization. Shared scoreboard contents, lifecycle and
## input behavior are inherited; reserve the actual Horde strip, including results.
##
## The shared 760 px card reaches over the bottom vitals/weapon panels at 960x640,
## and the Horde board is opened with Tab during live play. This board keeps to the
## horizontal gap the shared HUD leaves between those panels, stops above the help
## line and paginates inside the measured band, so it never covers health or ammo.
const HUD_GAP := 12.0
const MIN_BAND_WIDTH := 260.0
var reserved := 224.0

func top_edge() -> float:
	var parent := get_parent()
	if parent != null and "horde_label" in parent:
		return maxf(224, parent.horde_label.position.y + parent.horde_label.size.y + 12)
	return 224.0

func hud_control(field: String) -> Control:
	# Read-only geometry of the shared HUD panels this board must not cover.
	var parent := get_parent()
	if parent == null: return null
	var hud: Node = parent.get_node_or_null("GameHUD")
	if hud == null: return null
	var control: Control = hud.get(field)
	if control == null or not is_instance_valid(control): return null
	return control if control.size.x > 0.0 and control.size.y > 0.0 else null

func layout_band() -> Rect2:
	var viewport := get_viewport().get_visible_rect().size
	var top := top_edge()
	var bottom := viewport.y - 24
	var help := hud_control("controls")
	if help != null: bottom = minf(bottom, help.get_global_rect().position.y - HUD_GAP)
	var blockers: Array[Rect2] = []
	var vitals := hud_control("vitals")
	var weapon := hud_control("weapon_panel")
	if vitals != null: blockers.append(vitals.get_global_rect())
	if weapon != null: blockers.append(weapon.get_global_rect())
	var left := 16.0
	var right := viewport.x - 16.0
	if blockers.size() >= 2:
		blockers.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
		var gap_left: float = blockers[0].end.x + HUD_GAP
		var gap_right: float = blockers[blockers.size() - 1].position.x - HUD_GAP
		if gap_right - gap_left >= MIN_BAND_WIDTH:
			left = gap_left
			right = gap_right
		else:
			# No usable middle gap: stay fully above the bottom panels instead.
			var panel_top := INF
			for blocker: Rect2 in blockers: panel_top = minf(panel_top, blocker.position.y)
			bottom = minf(bottom, panel_top - HUD_GAP)
	return Rect2(Vector2(left, top), Vector2(maxf(0.0, right - left), maxf(0.0, bottom - top)))

func layout_top() -> float:
	return top_edge()

func layout_min_rows() -> int:
	# One row is still readable; the shared three-row floor would cover the vitals.
	return 1

func layout_width() -> float:
	return minf(760.0, layout_band().size.x)

func layout_bottom() -> float:
	# Everything below the band plus the panel's measured fixed content, so the
	# shared page-size formula cannot make the card taller than the band.
	var viewport := get_viewport().get_visible_rect().size
	return maxf(0.0, viewport.y - layout_band().end.y) + panel_chrome()

func position_panel() -> void:
	var band := layout_band()
	var viewport := get_viewport().get_visible_rect().size
	var lowest := maxf(band.position.y, band.end.y - panel.size.y)
	panel.position = Vector2(band.position.x + (band.size.x - panel.size.x) / 2,
		clampf((viewport.y - panel.size.y) / 2, band.position.y, lowest))

func row_cell_widths() -> Array:
	# Compact numeric columns keep player names readable in the narrower band.
	return [28, 0, 52, 50, 60]

func row_separation() -> int:
	return 8

func summary_text(prefix: String, roster: String) -> String:
	# The compact band is narrower than the shared 760 px card; a second line keeps
	# the truthful roster count readable instead of clipped.
	return "%s\n%s" % [prefix, roster]

func help_text(first: int) -> String:
	var text: String = super.help_text(first)
	# Keep the action and the paging hint inside the compact footer.
	text = text.replace("Waiting for player scores  ·  ", "Scores pending · ")
	text = text.replace("  ·  ", " · ")
	return text

func _process(delta: float) -> void:
	if not is_equal_approx(reserved, top_edge()): resize()
	super._process(delta)
