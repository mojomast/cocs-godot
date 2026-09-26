extends Control
## In-world presentation only. Every fact comes from the current recipient
## projection or an exact local action card; no collision, targeting or orders.
const Model = preload("res://lattice/world_tactical_model.gd")
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
var epoch := ""
var last_sequence: Variant = null
var last_req: Variant = null
var delta_expires := 0

func style(background: String, accent: String) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(background)
	box.border_color = Color(accent)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(14)
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
	var left := card(self, objective_card, "498d95")
	var eyebrow := Label.new()
	eyebrow.text = "01 / FIELD DIRECTIVE"
	add_line(left, eyebrow, 12, "7de2d6")
	add_line(left, goal, 22, "f4f9f4")
	add_line(left, objective, 13, "83dfd3")
	add_line(left, directive, 14, "bfd2da")
	var right := card(self, status_card, "436b7b")
	var caption := Label.new()
	caption.text = "02 / LIVE MISSION"
	add_line(right, caption, 12, "7de2d6")
	add_line(right, progress, 18, "f4f9f4")
	add_line(right, progress_detail, 13, "b5cad4")
	var rule := HSeparator.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(rule)
	add_line(right, health, 14, "f1c88b")
	add_line(right, economy, 15, "81e7d9")
	add_line(right, intel, 13, "e4ba7a")
	var bottom_column := card(self, bottom, "2d5964")
	add_line(bottom_column, receipt, 14, "e4f3f0")
	add_line(bottom_column, delta, 13, "9dd4c9")
	add_line(bottom_column, combat, 13, "f1c88b")
	receipt.hide()
	delta.hide()
	combat.hide()
	control_hint.text = "C  COMMAND DECK   ·   TAB  SCORES   ·   ESC  RELEASE POINTER"
	add_line(bottom_column, control_hint, 12, "a2b8c4")
	resized.connect(layout)
	layout()
	hide()

func layout() -> void:
	var compact := size.x < 950
	objective_card.position = Vector2(16, 14)
	objective_card.size = Vector2(minf(520, size.x * (0.53 if compact else 0.43)), 0)
	status_card.size = Vector2(minf(360, size.x * (0.39 if compact else 0.30)), 0)
	status_card.position = Vector2(size.x - status_card.size.x - 16, 14)
	bottom.size = Vector2(minf(550, size.x - 32), 0)
	bottom.position = Vector2(16, size.y - bottom.get_combined_minimum_size().y - 16)

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
	receipt.text = Model.buy_receipt(actions)
	receipt.visible = not receipt.text.is_empty()
	combat.text = combat_text.left(160)
	combat.visible = not combat.text.is_empty()
	control_hint.text = "RELEASED  ·  RELEASE CONTROLS, THEN CLICK WORLD TO RESUME   ·   C DECK" if controls == "released" else "C  COMMAND DECK   ·   TAB  SCORES   ·   ESC  RELEASE POINTER"
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

func _process(_delta: float) -> void:
	if not delta.text.is_empty() and Time.get_ticks_msec() >= delta_expires:
		delta.text = ""
		delta.hide()
		layout()
	if visible: layout()
