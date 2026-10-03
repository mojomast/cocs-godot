extends Control
## Relay Journal: a read-only, focus-navigable summary of the current chapter.
## It renders only public snapshot state through JournalModel and never sends an
## authority message. Opening releases the pointer like the existing HUD menu, so
## it reuses the established campaign cursor lifecycle rather than grabbing
## gameplay keys. The toggle is an unhandled-input route and is ignored while a
## text field or another modal (settings/career/cheats/world commands) is active.
const Model = preload("res://campaign/journal_model.gd")
const Settings = preload("res://ui/settings_access.gd")
const ScrollKeys = preload("res://experience/scroll_keys.gd")
const TOGGLE_KEY := KEY_I

var model := Model.new()
var session: Node
var open := false
var signature := ""

var shade := ColorRect.new()
var panel := PanelContainer.new()
var stack := VBoxContainer.new()
var title := Label.new()
var route := Label.new()
var body_scroll := ScrollContainer.new()
var body := VBoxContainer.new()
var objective := Label.new()
var detail := Label.new()
var progress := Label.new()
var workshops_heading := Label.new()
var workshop_list := VBoxContainer.new()
var crew := Label.new()
var footer := Label.new()
var close := Button.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	shade.color = Color(0.01, 0.02, 0.03, 0.86)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	shade.mouse_filter = MOUSE_FILTER_STOP
	add_child(shade)
	add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.11, 0.13, 0.98)
	style.border_color = Color("2f5b66")
	style.set_border_width_all(1)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(stack)
	stack.add_theme_constant_override("separation", 8)
	for label: Label in [title, route, objective, detail, progress, workshops_heading, crew, footer]: _style(label)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("9ff0d4"))
	route.add_theme_color_override("font_color", Color("ffd479"))
	workshops_heading.text = "OPTIONAL WORKSHOPS"
	workshops_heading.add_theme_color_override("font_color", Color("9ff0d4"))
	stack.add_child(title)
	stack.add_child(route)
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.focus_mode = Control.FOCUS_ALL
	body_scroll.follow_focus = true
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ScrollKeys.bind(body_scroll)
	body_scroll.gui_input.connect(_scroll_input)
	body_scroll.add_child(body)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	body.add_child(objective)
	body.add_child(detail)
	body.add_child(progress)
	body.add_child(workshops_heading)
	workshop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workshop_list.add_theme_constant_override("separation", 10)
	body.add_child(workshop_list)
	body.add_child(crew)
	stack.add_child(body_scroll)
	stack.add_child(footer)
	close.text = "Close journal"
	close.custom_minimum_size.y = 40
	close.pressed.connect(close_panel)
	stack.add_child(close)
	footer.text = "I or Esc closes · Tab / stick moves focus · arrows or page keys scroll"
	get_viewport().size_changed.connect(resize)
	resize()
	hide()

func _style(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color("ecf5f4"))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)

# Keyboard arrows/page keys are owned by ScrollKeys. Add the D-pad route so a
# controller can scroll the body after focus reaches it, without inventing a new
# action or binding.
func _scroll_input(event: InputEvent) -> void:
	if not event is InputEventJoypadButton or not event.pressed: return
	var bar := body_scroll.get_v_scroll_bar()
	if event.is_action_pressed("ui_up"): bar.value -= bar.page * 0.5
	elif event.is_action_pressed("ui_down"): bar.value += bar.page * 0.5
	else: return
	body_scroll.accept_event()

func bind_session(value: Node) -> void:
	session = value

func available() -> bool:
	if not is_instance_valid(session): return false
	if not str(session.get("startup_error")).is_empty(): return false
	if int(session.get("phase", -1)) != 3: return false
	return not blocked()

func blocked() -> bool:
	if Settings.overlay_open(): return true
	if "social_capturing" in session and session.social_capturing(): return true
	if "solo_cheats" in session:
		var cheats: Variant = session.get("solo_cheats")
		if is_instance_valid(cheats) and cheats.overlay.visible: return true
	for key: String in ["world_commands", "session_panel"]:
		var panel_node: Variant = session.get(key) if key in session else null
		if panel_node is Control and panel_node.is_visible_in_tree(): return true
	return false

func text_field_focused() -> bool:
	var owner := get_viewport().gui_get_focus_owner()
	return owner is LineEdit or owner is TextEdit

func observe(state: Variant) -> void:
	model.observe(state)
	if open: refresh()

func open_panel() -> void:
	if open: return
	open = true
	if is_instance_valid(session) and session.has_method("release_pointer"): session.release_pointer()
	show()
	refresh()
	body_scroll.grab_focus()

func close_panel() -> void:
	if not open: return
	open = false
	hide()

func toggle_panel() -> void:
	if open: close_panel()
	elif available(): open_panel()

func _unhandled_input(event: InputEvent) -> void:
	if text_field_focused(): return
	if event.is_action_pressed("ui_cancel"):
		if open:
			close_panel()
			get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or event.echo or not event.pressed: return
	if event.keycode == TOGGLE_KEY:
		if not open and not available(): return
		toggle_panel()
		get_viewport().set_input_as_handled()

func resize() -> void:
	var view := get_viewport_rect().size
	var compact := view.y < 540 or view.x < 800
	panel.size = Vector2(minf(680, view.x - 24), minf(560, view.y - 24))
	panel.position = (view - panel.size) * 0.5
	title.add_theme_font_size_override("font_size", 20 if compact else 26)
	for label: Label in [objective, detail, progress, workshops_heading, crew, footer]:
		label.add_theme_font_size_override("font_size", 15 if compact else 19)
	route.add_theme_font_size_override("font_size", 13 if compact else 16)
	close.add_theme_font_size_override("font_size", 14 if compact else 18)
	var width := panel.size.x - 52
	for label: Label in [title, route, objective, detail, progress, workshops_heading, crew, footer]: label.custom_minimum_size.x = width
	for label: Label in workshop_list.get_children():
		if label is Label: label.custom_minimum_size.x = width - 12
	body.custom_minimum_size.x = width

func refresh() -> void:
	var next := _signature()
	if next == signature and workshop_list.get_child_count() > 0: return
	signature = next
	var model_objective := model.objective()
	title.text = "RELAY JOURNAL\n%s" % (model_objective.title if not str(model_objective.title).is_empty() else "The Quiet Relay")
	route.text = _route_text()
	objective.text = str(model_objective.objective)
	detail.text = str(model_objective.detail)
	var metrics: Array[String] = []
	if int(model_objective.step_count) > 0: metrics.append("Step %d of %d" % [int(model_objective.step) + 1, int(model_objective.step_count)])
	if int(model_objective.enemies) > 0: metrics.append("Robots %d" % int(model_objective.enemies))
	if float(model_objective.hold) > 0.0: metrics.append("Link %d%%" % roundi(float(model_objective.hold) * 100))
	if int(model_objective.kills) > 0: metrics.append("Disabled %d" % int(model_objective.kills))
	metrics.append("Time %d:%02d" % [int(model_objective.elapsed) / 60, int(model_objective.elapsed) % 60])
	progress.text = " · ".join(metrics)
	_rebuild_workshops()
	var model_crew := model.crew()
	var names: Array[String] = []
	for entry: Dictionary in model_crew.entities: names.append("%s (%s)" % [entry.name, "companion" if entry.kind == "puppy" else "operator"])
	crew.text = "WITH YOU\n%s\nStory beats recovered: %d · Patch pets: %d" % [", ".join(names) if not names.is_empty() else "—", int(model_crew.beats), int(model_crew.pets)]
	resize()

func _route_text() -> String:
	var parts: Array[String] = []
	for entry: Dictionary in model.route():
		var mark := "◆" if entry.status == "current" else ("✓" if entry.status == "cleared" else "○")
		parts.append("%s %d %s" % [mark, int(entry.index) + 1, entry.title])
	return "ROUTE  " + "   ".join(parts)

func _rebuild_workshops() -> void:
	for child: Node in workshop_list.get_children(): child.queue_free()
	for beat: Dictionary in model.workshops():
		var label := Label.new()
		_style(label)
		var mark := "✓" if beat.completed else ("◐" if int(beat.stage) == 1 else "○")
		var kind := "OPTIONAL WORKSHOP"
		if beat.completed: kind = "RESTORED"
		elif int(beat.stage) == 1: kind = "CONNECT THE FAR CONTROL"
		var body_text := str(beat.result) if beat.completed and not str(beat.result).is_empty() else str(beat.hint)
		var actions: Array = beat.actions
		var action_text := ""
		if actions.size() == 2: action_text = "%s / %s" % [str(actions[0]), str(actions[1])]
		label.text = "%s %s · %s\n%s%s" % [mark, beat.title, kind, body_text, ("\nActions: " + action_text) if not action_text.is_empty() and not beat.completed else ""]
		label.add_theme_font_size_override("font_size", 13 if get_viewport_rect().size.x < 800 else 16)
		workshop_list.add_child(label)

func _signature() -> String:
	var parts: Array[String] = []
	var model_objective := model.objective()
	for key: String in ["title", "objective", "detail", "step", "step_count", "enemies", "hold", "kills", "elapsed", "phase"]:
		parts.append(str(model_objective.get(key, "")))
	for entry: Dictionary in model.route(): parts.append("%s:%s" % [entry.id, entry.status])
	for beat: Dictionary in model.workshops(): parts.append("%s:%s:%s" % [beat.id, beat.completed, beat.stage])
	var model_crew := model.crew()
	parts.append("crew:%d:%d:%d" % [model_crew.entities.size(), int(model_crew.beats), int(model_crew.pets)])
	return "|".join(parts)
