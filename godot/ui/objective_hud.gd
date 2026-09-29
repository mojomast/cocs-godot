extends "res://ui/game_hud.gd"
## Objective routes share one measured stack in logical (UI-scaled) pixels.
## Gameplay/input remain in the session; this only arranges passive presenters.
var objective_panel: PanelContainer
var full_controls := ""

func compact() -> bool:
	var size := get_viewport().get_visible_rect().size
	return size.x < 700 or size.y < 520

func build_ui() -> void:
	super.build_ui()
	full_controls = controls.text
	score_label.custom_minimum_size.x = 0
	for item: Label in [map_label, health_label, armor_label, weapon_label, ammo_label, controls]:
		item.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	score_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	objective_panel = panel()

func bind_session(target: Node) -> void:
	if is_instance_valid(client): return
	if target.has_method("weapon_controls_active"):
		full_controls += " · 1–9 / 0 / wheel: weapons"
	super.bind_session(target)
	# Optional startup help has no reserved objective space. Explicit F9/F10/F7
	# controls and measured telemetry still work; do not overprint live objectives.
	if is_instance_valid(session.combat.quality_controls):
		session.combat.quality_controls.set_shortcut_hint(false)

func refresh_status() -> void:
	super.refresh_status()
	if not is_instance_valid(session): return
	var ordinary_pause := status_title.text in ["CLICK TO PLAY", "CONTROLS PAUSED"]
	if compact():
		controls.text = ("Click play" if ordinary_pause else "WASD move") + " · Esc release · Tab scores · E interact"
		if ordinary_pause: status_panel.hide()
	else:
		controls.text = full_controls
	layout_objective()

func resize() -> void:
	super.resize()
	if is_instance_valid(objective_panel): layout_objective()

func fit_panel(item: PanelContainer, position: Vector2, width: float) -> void:
	item.position = position
	item.size.x = width
	# Pin wrapped labels before querying the height, including while hidden.
	var style := item.get_theme_stylebox("panel")
	var content_width := width - style.get_content_margin(SIDE_LEFT) - style.get_content_margin(SIDE_RIGHT)
	for child: Node in item.find_children("*", "Label", true, false):
		if child.get_parent() is VBoxContainer: child.size.x = content_width
	item.size.y = item.get_combined_minimum_size().y

func layout_objective() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var small := compact()
	var margin := 10.0 if small else 20.0
	var gap := 6.0 if small else 12.0
	root.size = viewport
	for item: PanelContainer in [top, vitals, weapon_panel, status_panel, objective_panel]:
		var style := item.get_theme_stylebox("panel") as StyleBoxFlat
		style.content_margin_left = 10 if small else 16
		style.content_margin_right = 10 if small else 16
		style.content_margin_top = 6 if small else 10
		style.content_margin_bottom = 6 if small else 10
	health_bar.visible = not small
	armor_bar.visible = not small
	weapon_detail.visible = not small or weapon_detail.text.begins_with("RELOADING")
	var sizes := {map_label:16, score_label:14, health_label:22, armor_label:17, weapon_label:20, ammo_label:23}
	for item: Label in sizes:
		item.add_theme_font_size_override("font_size", 14 if small else sizes[item])
	fit_panel(top, Vector2(margin, margin), viewport.x - margin * 2)
	var objective_y := top.position.y + top.size.y + gap
	fit_panel(objective_panel, Vector2(margin, objective_y), viewport.x - margin * 2 if small else minf(680, viewport.x - margin * 2))
	var next_y := objective_panel.position.y + objective_panel.size.y + gap if objective_panel.visible else objective_y
	if small:
		var column := (viewport.x - margin * 2 - gap) / 2
		fit_panel(vitals, Vector2(margin, next_y), column)
		fit_panel(weapon_panel, Vector2(margin + column + gap, next_y), column)
		if vitals.visible: next_y += maxf(vitals.size.y, weapon_panel.size.y) + gap
		fit_panel(status_panel, Vector2(margin, next_y), viewport.x - margin * 2)
		if status_panel.visible: next_y += status_panel.size.y + gap
		controls.position = Vector2(margin, next_y)
		controls.size = Vector2(viewport.x - margin * 2, 0)
	else:
		fit_panel(status_panel, Vector2(margin, next_y), minf(620, viewport.x - margin * 2))
		vitals.position = Vector2(margin, viewport.y - 188)
		vitals.size = Vector2(238, 108)
		weapon_panel.position = Vector2(viewport.x - 304, viewport.y - 188)
		weapon_panel.size = Vector2(284, 108)
		controls.position = Vector2(margin, viewport.y - 72)
		controls.size = Vector2(viewport.x - margin * 2, 0)
