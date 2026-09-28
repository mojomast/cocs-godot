extends CanvasLayer
## Runtime-only view of the active source connection. No profile or credential
## enters local settings, menu preferences, command line or diagnostic output.
const Projection = preload("res://career/profile.gd")
var catalog: Dictionary = {}
var owner: WeakRef
var profile: Dictionary = {}
var panel: Control
var details: VBoxContainer
var state_label: Label
var heading: Label
var return_focus: Control
var category := "gear"
var was_open := false

func _ready() -> void:
	layer = 99
	var file := FileAccess.open("res://career/catalog.json", FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary and parsed.get("schema") == 1 and parsed.get("items") is Array: catalog = parsed
	build_panel()

func active() -> bool:
	return panel != null and panel.visible

func clear_connection(client: Node) -> void:
	if owner != null and owner.get_ref() == client:
		owner = null
		profile.clear()
		refresh()

func receive(client: Node, frame: Dictionary) -> void:
	if not is_instance_valid(client): return
	# A queued reply from a closed room cannot resurrect a disconnected career.
	if not ("room_id" in client) or str(client.room_id).is_empty(): return
	if frame.get("type") == "welcome":
		# Only the seated connection's source welcome owns an identity.
		owner = weakref(client)
		profile = Projection.project(frame.get("profile"))
	elif frame.get("type") == "progression" and owner != null and owner.get_ref() == client and not profile.is_empty():
		var next: Dictionary = Projection.project(frame.get("profile"))
		if next.get("id") != profile.get("id"): return
		profile = next
	else: return
	refresh()

func open_panel(focus: Control = null) -> void:
	var settings := get_tree().root.get_node_or_null("LocalSettings")
	if active() or (settings != null and settings.overlay_open()): return
	return_focus = focus
	var scene := get_tree().current_scene
	if scene != null:
		if scene.has_method("world_neutral"): scene.world_neutral()
		elif scene.has_method("release_pointer"): scene.release_pointer()
		elif scene.has_method("release"): scene.release()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	panel.show()
	refresh()
	var back := panel.find_child("CareerBack", true, false) as Button
	back.grab_focus()

func close_panel() -> void:
	if not active(): return
	panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(return_focus): return_focus.grab_focus()
	return_focus = null

func _process(_delta: float) -> void:
	if owner != null and not is_instance_valid(owner.get_ref()):
		owner = null
		profile.clear()
		refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if active() and event.keycode == KEY_ESCAPE:
		close_panel()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F9:
		var settings := get_tree().root.get_node_or_null("LocalSettings")
		if settings != null and settings.overlay_open(): return
		if active(): close_panel()
		else: open_panel()
		get_viewport().set_input_as_handled()

func build_panel() -> void:
	panel = Control.new()
	panel.name = "CareerPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.055, 0.075, 0.98)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 24)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	details = VBoxContainer.new()
	details.custom_minimum_size.x = 280
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 12)
	scroll.add_child(details)
	heading = Label.new()
	heading.text = "CAREER / ARSENAL"
	heading.add_theme_font_size_override("font_size", 26)
	details.add_child(heading)
	state_label = Label.new()
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(state_label)
	var back := Button.new()
	back.name = "CareerBack"
	back.text = "BACK (Esc)"
	back.custom_minimum_size.y = 44
	back.pressed.connect(close_panel)
	details.add_child(back)
	var tabs := HFlowContainer.new()
	details.add_child(tabs)
	for entry: Dictionary in [{"id":"gear", "label":"GEAR"}, {"id":"attachment", "label":"MODS"}, {"id":"finish", "label":"FINISHES"}, {"id":"crosshair", "label":"RETICLES"}]:
		var id: String = entry.id
		var button := Button.new()
		button.text = entry.label
		button.custom_minimum_size.y = 44
		button.pressed.connect(func() -> void: category = id; refresh())
		tabs.add_child(button)
	var list := VBoxContainer.new()
	list.name = "CatalogRows"
	list.add_theme_constant_override("separation", 12)
	details.add_child(list)
	panel.hide()
	refresh()

func add_line(parent: Node, text: String, size: int = 16) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)

func refresh() -> void:
	if details == null or state_label == null: return
	if profile.is_empty():
		state_label.text = "NO CONNECTED CAREER · Browse the source Arsenal below. A career appears here after joining a source-server room in a live session (F9). Home has no active room; no progress has been loaded."
	else:
		var parts := []
		for field: String in ["level", "xp", "prestige", "matches", "wins", "kills"]:
			parts.append(field.to_upper() + " " + (str(profile[field]) if profile.has(field) else "UNKNOWN"))
		state_label.text = "CONNECTED SOURCE CAREER · " + "  ·  ".join(parts) + "\nRead-only · source room session only. Career gear is persistent in that server; it is separate from match-scoped REQ."
		var modes: Dictionary = profile.get("byMode", {})
		if modes.is_empty(): state_label.text += "\nMODE HISTORY · No per-mode totals reported. Individual match history is not keyed by career identity on this wire."
		else:
			state_label.text += "\nMODE TOTALS (source profile):"
			for mode: String in modes:
				var stats: Dictionary = modes[mode]
				state_label.text += "\n%s · %s matches · %s wins · %s kills" % [mode, str(stats.get("matches", "?")), str(stats.get("wins", "?")), str(stats.get("kills", "?"))]
	if catalog.is_empty(): state_label.text += "\nSource Arsenal catalog unavailable. Regenerate from the source modules."
	var list := details.find_child("CatalogRows", true, false) as VBoxContainer
	if list == null: return
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for item: Dictionary in catalog.get("items", []):
		if item.kind != category: continue
		var box := VBoxContainer.new()
		list.add_child(box)
		add_line(box, "%s · %s · %s" % [item.name, item.slot if not item.slot.is_empty() else item.kind, Projection.item_state(profile, item)], 19)
		add_line(box, item.description)
		var spec := []
		for key: String in item.modifiers: spec.append(key + " " + str(item.modifiers[key]))
		for part: String in item.spec: spec.append(part)
		if item.kind == "attachment": spec.append("ALL WEAPONS" if item.weapons.is_empty() else "Weapon indices " + str(item.weapons))
		if not spec.is_empty(): add_line(box, " · ".join(spec), 14)
