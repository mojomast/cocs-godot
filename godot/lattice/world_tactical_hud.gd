extends Control
## In-world presentation only. Every fact comes from the current recipient
## projection or an exact local action card; no collision, targeting or orders.
const Model = preload("res://lattice/world_tactical_model.gd")
const Feedback = preload("res://lattice/world_feedback.gd")
## Below this logical width the two instrument cards stack and compress so a
## 150%-scaled 760x520 viewport (roughly 507x347 logical) still shows every
## essential source-backed fact without overlap. The command deck keeps the
## full copy, so only supplemental prose is dropped here.
const NARROW_WIDTH := 720.0
var goal := Label.new()
var directive := Label.new()
var objective := Label.new()
var progress := Label.new()
var progress_detail := Label.new()
var health := Label.new()
var economy := Label.new()
var intel := Label.new()
var receipt := Label.new()
var delta := Label.new()
var combat := Label.new()
var objective_card := PanelContainer.new()
var status_card := PanelContainer.new()
var bottom := PanelContainer.new()
var control_hint := Label.new()
var objective_column: VBoxContainer
var status_column: VBoxContainer
var bottom_column: VBoxContainer
var objective_eyebrow := Label.new()
var status_caption := Label.new()
var epoch := ""
var last_sequence: Variant = null
var last_req: Variant = null
var delta_expires := 0
var narrowed := false
var narrowed_ready := false

func style(background: String, accent: String, margin: int = 14) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(background)
	box.border_color = Color(accent)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(margin)
	return box

func add_line(parent: Node, item: Label, size_px: int, color: String) -> void:
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size", size_px)
	item.add_theme_color_override("font_color", Color(color))
	parent.add_child(item)

func card(parent: Node, panel: PanelContainer, accent: String) -> VBoxContainer:
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", style("091826ed", accent))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	return column

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_column = card(self, objective_card, "498d95")
	objective_eyebrow.text = "01 / FIELD DIRECTIVE"
	add_line(objective_column, objective_eyebrow, 12, "7de2d6")
	add_line(objective_column, goal, 22, "f4f9f4")
	add_line(objective_column, objective, 13, "83dfd3")
	add_line(objective_column, directive, 14, "bfd2da")
	status_column = card(self, status_card, "436b7b")
	status_caption.text = "02 / LIVE MISSION"
	add_line(status_column, status_caption, 12, "7de2d6")
	add_line(status_column, progress, 18, "f4f9f4")
	add_line(status_column, progress_detail, 13, "b5cad4")
	var rule := HSeparator.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_column.add_child(rule)
	add_line(status_column, health, 14, "f1c88b")
	add_line(status_column, economy, 15, "81e7d9")
	add_line(status_column, intel, 13, "e4ba7a")
	bottom_column = card(self, bottom, "2d5964")
	add_line(bottom_column, receipt, 14, "e4f3f0")
	add_line(bottom_column, delta, 13, "9dd4c9")
	add_line(bottom_column, combat, 13, "f1c88b")
	receipt.hide()
	delta.hide()
	combat.hide()
	control_hint.text = "C  COMMAND DECK   ·   TAB  SCORES   ·   ESC  RELEASE POINTER   ·   F12 SETTINGS"
	add_line(bottom_column, control_hint, 12, "a2b8c4")
	resized.connect(layout)
	layout()
	hide()

## Compress fonts, spacing and card padding for the narrow logical case. Only
## supplemental prose disappears; goal/objective/progress/HQ/HP/REQ/FLUX stay.
func apply_scale(narrow: bool) -> void:
	if narrowed_ready and narrow == narrowed:
		return
	narrowed_ready = true
	narrowed = narrow
	var pad := 8 if narrow else 14
	objective_card.add_theme_stylebox_override("panel", style("091826ed", "498d95", pad))
	status_card.add_theme_stylebox_override("panel", style("091826ed", "436b7b", pad))
	bottom.add_theme_stylebox_override("panel", style("091826ed", "2d5964", pad))
	var sep := 4 if narrow else 6
	objective_column.add_theme_constant_override("separation", sep)
	status_column.add_theme_constant_override("separation", sep)
	bottom_column.add_theme_constant_override("separation", sep)
	objective_eyebrow.add_theme_font_size_override("font_size", 11 if narrow else 12)
	status_caption.add_theme_font_size_override("font_size", 11 if narrow else 12)
	goal.add_theme_font_size_override("font_size", 17 if narrow else 22)
	objective.add_theme_font_size_override("font_size", 12 if narrow else 13)
	directive.add_theme_font_size_override("font_size", 12 if narrow else 14)
	progress.add_theme_font_size_override("font_size", 16 if narrow else 18)
	progress_detail.add_theme_font_size_override("font_size", 12 if narrow else 13)
	health.add_theme_font_size_override("font_size", 13 if narrow else 14)
	economy.add_theme_font_size_override("font_size", 13 if narrow else 15)
	intel.add_theme_font_size_override("font_size", 12 if narrow else 13)
	receipt.add_theme_font_size_override("font_size", 12 if narrow else 14)
	delta.add_theme_font_size_override("font_size", 12 if narrow else 13)
	combat.add_theme_font_size_override("font_size", 12 if narrow else 13)
	control_hint.add_theme_font_size_override("font_size", 11 if narrow else 12)

func layout() -> void:
	var narrow := size.x < NARROW_WIDTH
	apply_scale(narrow)
	var margin := 12.0 if narrow else 16.0
	var top := 10.0 if narrow else 14.0
	# Supplemental-only copy is dropped at narrow width: card captions, the
	# field-directive prose and the wave-label/recon line. Every essential fact
	# (goal, legality/supply, progress, HQ/force, HP, REQ/FLUX) stays visible.
	objective_eyebrow.visible = not narrow
	status_caption.visible = not narrow
	directive.visible = not narrow
	intel.visible = not narrow and not intel.text.is_empty()
	if narrow:
		# Stack the directive above the live-mission card rather than shrinking
		# them onto one row, so no essential column is starved at ~507 logical px.
		objective_card.position = Vector2(margin, top)
		objective_card.size = Vector2(size.x - margin * 2.0, 0)
		var objective_height := maxf(objective_card.size.y, objective_card.get_combined_minimum_size().y)
		status_card.position = Vector2(margin, top + objective_height + 8.0)
		status_card.size = Vector2(size.x - margin * 2.0, 0)
	else:
		objective_card.position = Vector2(16, 14)
		objective_card.size = Vector2(minf(520, size.x * (0.53 if size.x < 950 else 0.43)), 0)
		status_card.size = Vector2(minf(360, size.x * (0.39 if size.x < 950 else 0.30)), 0)
		status_card.position = Vector2(size.x - status_card.size.x - 16, 14)
	bottom.size = Vector2(minf(550, size.x - margin * 2.0), 0)
	# The wrapped F12 hint may be one line taller than the frame's measured
	# minimum, so anchor the ribbon with the largest of the stored and combined
	# minimum heights; _process re-lays every frame to settle it.
	var ribbon_height := maxf(bottom.size.y, bottom.get_combined_minimum_size().y)
	bottom.position = Vector2(margin, size.y - ribbon_height - margin)

func clear() -> void:
	epoch = ""
	last_sequence = null
	last_req = null
	delta.text = ""
	delta.hide()
	delta_expires = 0
	hide()

func present(projection: Dictionary, target: Dictionary, topology: Dictionary, actor: Dictionary, actions: Array, combat_text: String = "", controls: String = "engaged") -> void:
	if projection.is_empty() or actor.is_empty():
		clear()
		return
	var model: Dictionary = Model.projection(projection, target, topology, actor)
	goal.text = model.goal
	objective.text = model.objective
	directive.text = model.direction
	progress.text = model.progress
	progress_detail.text = model.detail
	health.text = "OPERATOR HP  %s" % model.health
	economy.text = "PERSONAL REQ  %s     TEAM FLUX  %s" % [model.req, model.flux]
	intel.text = model.intel
	intel.visible = not intel.text.is_empty()
	var action_feedback := Feedback.receipt(actions, projection.get("context", {}).get("revision"))
	receipt.text = str(action_feedback.get("text", ""))
	receipt.add_theme_color_override("font_color", Color("f2b57a") if action_feedback.get("status") == "rejected" else Color("e4f3f0"))
	receipt.visible = not receipt.text.is_empty()
	combat.text = combat_text.left(160)
	combat.visible = not combat.text.is_empty()
	control_hint.text = "RELEASED  ·  RELEASE CONTROLS, THEN CLICK WORLD TO RESUME   ·   C DECK   ·   F12 SETTINGS" if controls == "released" else "C  COMMAND DECK   ·   TAB  SCORES   ·   ESC  RELEASE POINTER   ·   F12 SETTINGS"
	if controls != "released" and action_feedback.get("status") == "rejected":
		control_hint.text = "C DECK · " + str(action_feedback.get("recovery", ""))
	var context: Dictionary = projection.get("context", {})
	var identity := "%s/%s/%s" % [projection.get("map"), context.get("revision"), context.get("actor")]
	if identity != epoch:
		epoch = identity
		last_sequence = null
		last_req = null
		delta.text = ""
	var sequence: Variant = projection.get("source_sequence")
	var req: Variant = projection.get("req")
	if sequence != null and sequence != last_sequence:
		if (req is int or req is float) and (last_req is int or last_req is float):
			var change := float(req) - float(last_req)
			if change > 0: delta.text = "REQ +%s OBSERVED  ·  SOURCE WALLET" % Model.known(change)
			elif change < 0: delta.text = "REQ %s OBSERVED  ·  SOURCE WALLET" % Model.known(change)
			if change != 0: delta_expires = Time.get_ticks_msec() + 3200
		last_req = req
		last_sequence = sequence
	delta.visible = not delta.text.is_empty()
	show()
	layout()
	# One settled pass after the first width/height dependent reflow, so the
	# ribbon is placed from the reshaped minimum, not the previous frame's.
	call_deferred("layout")

func _process(_delta: float) -> void:
	if not delta.text.is_empty() and Time.get_ticks_msec() >= delta_expires:
		delta.text = ""
		delta.hide()
		layout()
	if visible: layout()
