extends Control
const Guidance = preload("res://sports/guidance.gd")
const Progression = preload("res://sports/progression.gd")
const SoccerGuidance = preload("res://sports/soccer_guidance.gd")
const Practice = preload("res://sports/practice.gd")
## Passive presentation of accepted state. text remains an observer-friendly summary.
var text := ""
var title: Label
var phase_label: Label
var detail: Label
var speed_label: Label
var status: Label
var hints: Label
var progress_label: Label
var soccer_label: Label
var result_panel: PanelContainer
var result_label: Label
var top_panel: Control
var bottom_panel: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	var top := panel(false)
	top_panel = top.get_parent() as Control
	var heading := HBoxContainer.new()
	top.add_child(heading)
	title = label(heading, 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phase_label = label(heading, 18)
	var metrics := HBoxContainer.new()
	top.add_child(metrics)
	detail = label(metrics, 24)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speed_label = label(metrics, 24)
	progress_label = label(top, 16)
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	soccer_label = label(top, 16)
	soccer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	soccer_label.hide()
	var bottom := panel(true)
	bottom_panel = bottom.get_parent() as Control
	status = label(bottom, 18)
	hints = label(bottom, 16)
	hints.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_panel = PanelContainer.new()
	add_child(result_panel)
	result_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.075, 0.97)
	style.border_color = Color(0.35, 1, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(20)
	result_panel.add_theme_stylebox_override("panel", style)
	result_label = label(result_panel, 21)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_panel.hide()
	resized.connect(layout_results)
	layout_results()
	make_passive(self)

func layout_results() -> void:
	if result_panel == null or result_label == null: return
	# Control.size is the scaled canvas extent, including UI150 and live resize.
	# Results own the screen while visible; every standings/restart line fits
	# within the available rectangle instead of a fixed 680px panel.
	var width := minf(680.0, maxf(200.0, size.x - 24.0))
	var height := minf(400.0, maxf(180.0, size.y - 24.0))
	result_panel.offset_left = -width * 0.5
	result_panel.offset_right = width * 0.5
	result_panel.offset_top = -height * 0.5
	result_panel.offset_bottom = height * 0.5
	var compact := width < 560.0 or height < 300.0
	top_panel.offset_left = 12 if compact else 16
	top_panel.offset_right = -12 if compact else -16
	top_panel.offset_bottom = 166 if compact else 136
	bottom_panel.offset_left = 12 if compact else 16
	bottom_panel.offset_right = -12 if compact else -16
	result_label.add_theme_font_size_override("font_size", 16 if compact else 21)
	title.add_theme_font_size_override("font_size", 16 if compact else 20)
	phase_label.add_theme_font_size_override("font_size", 14 if compact else 18)
	detail.add_theme_font_size_override("font_size", 18 if compact else 24)
	speed_label.add_theme_font_size_override("font_size", 18 if compact else 24)

func panel(bottom: bool) -> VBoxContainer:
	var p := PanelContainer.new()
	add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE)
	p.offset_left = 16
	p.offset_right = -16
	p.offset_top = -112 if bottom else 16
	p.offset_bottom = -16 if bottom else 136
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.075, 0.94)
	style.border_color = Color(0.25, 0.65, 0.8, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	p.add_child(rows)
	return rows

func label(parent: Node, font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(0.94, 0.97, 1))
	parent.add_child(l)
	return l

func make_passive(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.focus_mode = Control.FOCUS_NONE
	for child: Node in node.get_children(): make_passive(child)

static func integer(value: Variant, fallback: String = "—") -> String:
	if (value is float or value is int) and is_finite(float(value)):
		return str(maxi(0, int(value)))
	return fallback

static func describe(view: Dictionary) -> Dictionary:
	var soccer: bool = view.get("mode", "") == "puma-soccer"
	var state: Dictionary = view.get("state", {})
	var race: Dictionary = state.get("race", {})
	var v: Dictionary = view.get("vehicle", {})
	var phase: String = view.get("phase", "connecting")
	var sports_phase: String = race.get("phase", "")
	var map_id := str(view.get("map_id", ""))
	var venue := str(view.get("map_name", "")).strip_edges()
	if venue.is_empty() and state.get("mapId") == map_id:
		venue = str(state.get("mapName", "")).strip_edges()
	if venue.is_empty():
		venue = {"ion-speedway":"Ion Speedway", "aurora-stadium":"Aurora Stadium"}.get(map_id, "Puma Arena")
	var heading: String = "%s · Puma %s" % [venue, "Soccer" if soccer else "Race"]
	var phase_text := "Connecting…"
	var status_text := "RELEASED · Waiting for the server"
	var instructions := "Controls become available after the countdown."
	var color := Color(1, 0.8, 0.4)
	var detail_text := "Red  —     Blue  —" if soccer else "Lap — / —   ·   Checkpoint — / —"
	if soccer:
		var scores: Dictionary = race.get("scores", {})
		detail_text = "Red  %s     Blue  %s" % [integer(scores.get("0", scores.get(0))), integer(scores.get("1", scores.get(1)))]
	else:
		for row: Dictionary in race.get("standings", []):
			if row.get("actorId", -2) != view.get("actor_id", -1): continue
			var lap := integer(row.get("lap"))
			if lap != "—" and integer(race.get("laps")) != "—": lap = str(mini(int(lap), int(race.laps)))
			var gate := integer(row.get("nextGate"))
			if gate != "—": gate = str(int(gate) + 1)
			detail_text = "Lap %s / %s   ·   Checkpoint %s / %s" % [lap, integer(race.get("laps")), gate, integer(race.gates.size()) if race.get("gates") is Array else "—"]
	var speed_text := "— m/s"
	if v.has("vx") and v.has("vz"):
		speed_text = "%.1f m/s" % Vector2(float(v.vx), float(v.vz)).length()
	if phase == "error":
		phase_text = "Connection error"
		status_text = "ERROR · Controls released"
		instructions = "%s · Close this window and relaunch the demo." % view.get("error", "Connection lost")
		color = Color(1, 0.5, 0.45)
	elif phase == "results":
		phase_text = "Full time" if soccer else ("Time expired" if state.get("overReason") == "time" else "Race complete")
		status_text = "RELEASED · Round complete"
		instructions = "F5: start a new round"
	elif phase == "starting":
		phase_text = "Starting…"
		status_text = "RELEASED · Waiting for the new round"
	elif phase == "active":
		phase_text = {"racing":"Racing", "playing":"Ball in play", "finished":"Race complete", "over":"Full time"}.get(sports_phase, "Waiting for state…")
		if float(view.get("age", 999)) >= 0.5:
			phase_text = "Snapshots delayed"
			status_text = "STALLED · Controls released"
			instructions = "Waiting for fresh server state; then press Enter to engage again."
		elif sports_phase in ["countdown", "kickoff"]:
			phase_text = "%s · %s" % ["Kickoff" if soccer else "Start in", integer(ceili(maxf(1, float(race.get("countdown", 0)))))]
			status_text = "RELEASED · Countdown"
			instructions = "Wait for %s, then press Enter to engage." % ("kickoff" if soccer else "the start")
		elif state.get("over", false) or sports_phase in ["finished", "over"]:
			status_text = "RELEASED · Waiting for results"
			instructions = "Restart becomes available when results arrive."
		elif not view.get("focused", true):
			status_text = "RELEASED · Window unfocused"
			instructions = "Return to this window, then press Enter and fresh movement keys."
		elif not view.get("eligible", false):
			status_text = "RELEASED · Waiting for your active Puma"
			instructions = "When your vehicle is ready, press Enter to engage."
		else:
			var engaged: bool = view.get("engaged", false)
			status_text = "ENGAGED · Escape to release" if engaged else "RELEASED · Enter to engage, then fresh movement keys"
			color = Color(0.4, 1, 0.75) if engaged else color
			instructions = preload("res://input_bindings/hints.gd").resolve("W/S: forward/reverse · A/D: steer · Space: brake · Shift: boost") + " · F4: vehicle view"
			if not soccer: instructions += "\nR: request race reset (server wait)"
	return {"title":heading, "phase":phase_text, "detail":detail_text, "speed":speed_text, "status":status_text, "hints":instructions, "color":color}

func reset() -> void:
	text = ""
	if not is_node_ready(): return
	for item: Label in [title, phase_label, detail, speed_label, status, hints, progress_label, soccer_label, result_label]: item.text = ""
	soccer_label.hide()
	result_panel.hide()
	top_panel.show()
	bottom_panel.show()

func update(view: Dictionary) -> void:
	var parts := describe(view)
	var state: Dictionary = view.get("state", {})
	var race: Dictionary = state.get("race", {})
	var soccer: bool = view.get("mode") == "puma-soccer"
	var progress := "Elapsed %s" % Progression.clock(race.get("elapsed"))
	var limit: Variant = race.get("timeLimit", state.get("config", {}).get("timeLimit"))
	if limit != null: progress += " / " + Progression.clock(limit)
	var guidance := Guidance.describe(race, int(view.get("actor_id", -1)), view.get("vehicle", {}))
	if not guidance.is_empty() and view.get("phase") == "active" and float(view.get("age", 999)) < 0.5 and not state.get("over", false): progress += " · " + guidance
	if not str(view.get("message", "")).is_empty(): progress += " · " + str(view.message)
	var results := Progression.results(state, int(view.get("actor_id", -1)), soccer) if view.get("phase") == "results" else ""
	text = "%s · %s\n%s · %s\n%s\n%s\n%s" % [parts.title, parts.phase, parts.detail, parts.speed, progress, parts.status, parts.hints]
	if not results.is_empty(): text += "\n" + results
	var soccer_text := SoccerGuidance.describe(view.get("soccer_guidance", {})) if soccer and view.get("phase") == "active" and float(view.get("age", 999)) < 0.5 and not state.get("over", false) else ""
	if not soccer_text.is_empty(): soccer_text += "\n" + Practice.describe(view.soccer_guidance, race.get("pitch", {}))
	if not soccer_text.is_empty(): text += "\n" + soccer_text
	if not is_node_ready(): return
	title.text = parts.title
	phase_label.text = parts.phase
	detail.text = parts.detail
	speed_label.text = parts.speed
	status.text = parts.status
	status.add_theme_color_override("font_color", parts.color)
	hints.text = parts.hints
	progress_label.text = progress
	soccer_label.text = soccer_text
	soccer_label.visible = not soccer_text.is_empty()
	result_panel.visible = not results.is_empty()
	top_panel.visible = results.is_empty()
	bottom_panel.visible = results.is_empty()
	result_label.text = results
