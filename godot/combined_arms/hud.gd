extends Control
var title := Label.new()
var info := Label.new()
var help := Label.new()
var prompt := Label.new()
var aim := Label.new()
var top_scroll := ScrollContainer.new()
var bottom_scroll := ScrollContainer.new()
var top_rows := VBoxContainer.new()
var bottom_rows := VBoxContainer.new()
var scroll_hint := Label.new()
var was_captured := false
# Logical pixels: LocalSettings' bottom-right F12 hint occupies the last 27.
const FOOTER_SAFE := 36.0
const HUD_MARGIN := 16.0
const HUD_GAP := 12.0
const SOURCE_SEATS := {"puma":4, "hornet":3, "titan":3, "scout":2, "transport":6}

func vehicle_card(v: Dictionary, seat: Variant) -> String:
	var kind := str(v.get("kind", ""))
	var occupants := 0
	for role: String in ["driver", "gunner"]:
		if v.get(role) != null: occupants += 1
	var passengers: Variant = v.get("passengers", [])
	if passengers is Array:
		for passenger: Variant in passengers:
			if passenger != null: occupants += 1
	# An absent field is not a measured zero; only the source snapshot may
	# provide hull or heat telemetry (particularly around reconnect boundaries).
	var hull := "%.0f / %.0f" % [float(v.health), float(v.maxHealth)] if (v.get("health") is float or v.get("health") is int) and (v.get("maxHealth") is float or v.get("maxHealth") is int) else "—"
	var heat := "%.0f%%" % (float(v.heat) * 100.0) if v.get("heat") is float or v.get("heat") is int else "—"
	var result := "%s / %s  •  Seats %d/%d  •  Hull %s  •  Heat %s" % [kind.to_upper(), str(seat), occupants, SOURCE_SEATS.get(kind, 0), hull, heat]
	if v.get("overheated", false): result += "  •  OVERHEATED"
	if (v.get("health") is float or v.get("health") is int) and float(v.health) <= 0: result += "  •  DESTROYED"
	if (v.get("respawnTimer") is float or v.get("respawnTimer") is int) and float(v.respawnTimer) > 0: result += "  •  Respawn %.1fs" % float(v.respawnTimer)
	return result
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for label in [title, info, help, prompt, aim, scroll_hint]:
		add_child(label)
		label.add_theme_color_override("font_color", Color("f9eed7"))
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 24)
	# Wrapping rows share bounded scroll regions instead of fixed overlapping
	# offsets. This remains reachable at compact UI150 with released controls.
	for scroll: ScrollContainer in [top_scroll, bottom_scroll]:
		add_child(scroll)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.focus_mode = Control.FOCUS_ALL
		scroll.follow_focus = true
		preload("res://experience/scroll_keys.gd").bind(scroll)
		var rows := top_rows if scroll == top_scroll else bottom_rows
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(rows)
		for label: Label in ([title, info] if scroll == top_scroll else [prompt, help]):
			label.reparent(rows)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 22)
	scroll_hint.text = "Esc releases · Tab selects text · ↑/↓ / PgUp/PgDn scroll"
	scroll_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll_hint.hide()
	top_scroll.focus_next = top_scroll.get_path_to(bottom_scroll)
	top_scroll.focus_previous = top_scroll.focus_next
	bottom_scroll.focus_next = bottom_scroll.get_path_to(top_scroll)
	bottom_scroll.focus_previous = bottom_scroll.focus_next
	aim.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	aim.offset_left = -10
	aim.offset_right = 10
	aim.offset_top = -12
	aim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aim.text = "+"
	get_viewport().size_changed.connect(layout)
	layout()

func layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var width := maxf(1.0, view.x - 40.0)
	scroll_hint.size.x = width
	var top_needed := top_rows.get_combined_minimum_size().y
	var bottom_needed := bottom_rows.get_combined_minimum_size().y
	var available := maxf(0.0, view.y - HUD_MARGIN - FOOTER_SAFE - HUD_GAP)
	var overflow := top_needed + bottom_needed > available
	var hint_height := scroll_hint.get_combined_minimum_size().y + HUD_GAP if overflow else 0.0
	available = maxf(0.0, available - hint_height)
	# Share genuinely constrained space, but let either region use the other's
	# unused share. At compact UI150 ordinary text fits without scrolling.
	var top_height := minf(top_needed, maxf(available * 0.45, available - bottom_needed))
	var bottom_height := minf(bottom_needed, maxf(0.0, available - top_height))
	top_scroll.position = Vector2(20, HUD_MARGIN)
	top_scroll.size = Vector2(width, top_height)
	bottom_scroll.position = Vector2(20, view.y - FOOTER_SAFE - hint_height - bottom_height)
	bottom_scroll.size = Vector2(width, bottom_height)
	scroll_hint.visible = overflow
	scroll_hint.position = Vector2(20, view.y - FOOTER_SAFE - hint_height + HUD_GAP)

func _process(_delta: float) -> void:
	# Containers remeasure after width, text, bindings or accessibility changes.
	# Use those wrapped minimums instead of physical window pixels/font scaling.
	layout()
	var released := Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	if not released and not was_captured:
		top_scroll.scroll_vertical = 0
		bottom_scroll.scroll_vertical = 0
		for scroll: ScrollContainer in [top_scroll, bottom_scroll]: scroll.release_focus()
	was_captured = not released
	for scroll: ScrollContainer in [top_scroll, bottom_scroll]:
		scroll.mouse_filter = Control.MOUSE_FILTER_STOP if released else Control.MOUSE_FILTER_IGNORE
		scroll.focus_mode = Control.FOCUS_ALL if released else Control.FOCUS_NONE

func update(a: Dictionary, v: Dictionary, near: Dictionary, engaged: bool, phase: String, age: float, error: String) -> void:
	title.text = "SUNSCAR CONVOY  /  COMBINED ARMS"
	var mounted := not v.is_empty()
	aim.visible = not mounted and engaged
	info.text = "Infantry  •  HP %.0f  •  Team %s" % [a.get("health", 0), a.get("team", "—")]
	if mounted:
		info.text = vehicle_card(v, a.get("vehicleSeat", ""))
	help.text = preload("res://input_bindings/hints.gd").resolve("WASD move  •  Mouse look / LMB fire  •  E mount / exit\nSpace %s  •  Shift %s\nEnter capture controls  •  Esc release  •  Fresh Enter + keys after seat change" % ["lift" if mounted and v.get("kind") == "hornet" else ("brake tap" if mounted else "jump"), "boost" if mounted else "sprint"])
	if mounted and a.get("vehicleSeat") != "driver":
		help.text = preload("res://input_bindings/hints.gd").resolve("Seat: %s  •  E exit  •  Mouse look / LMB fire\nEnter capture controls  •  Esc release" % str(a.get("vehicleSeat", "")).capitalize())
	prompt.text = "E  •  Exit vehicle" if mounted else ("E  •  Board %s" % str(near.kind).to_upper() if not near.is_empty() else "")
	if phase != "active": prompt.text = error if not error.is_empty() else phase.capitalize()
	elif age >= 0.5: prompt.text = "Snapshots stale — controls released"
	elif not engaged: prompt.text = "Enter  •  Capture fresh controls"

func objective(state: Dictionary, host: bool) -> void:
	var objective_state: Variant = state.get("objectives")
	if objective_state is Dictionary and objective_state.get("kind") == "domination":
		var scores: Dictionary = state.get("teamScores", {})
		var zones: Array = objective_state.get("zones", [])
		var line := "ZONE CONTROL  %s : %s  /  %s limit  •  %d zones" % [scores.get("0", scores.get(0, "?")), scores.get("1", scores.get(1, "?")), state.get("config", {}).get("fragLimit", "?"), zones.size()]
		info.text += "\n" + line
	if phase_text_results(state):
		prompt.text = "Results · Enter to request rematch" if host else "Results · Waiting for host rematch"

func phase_text_results(state: Dictionary) -> bool:
	return state.get("over", false) == true
