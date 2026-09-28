extends CanvasLayer
## Runtime-only view of the active source connection. No profile or credential
## enters local settings, menu preferences, command line or diagnostic output.
const CareerProfile = preload("res://career/profile.gd")
const Actions = preload("res://career/actions_model.gd")
var catalog: Dictionary = {}
var connection_owner: WeakRef
var profile: Dictionary = {}
var panel: Control
var details: VBoxContainer
var state_label: Label
var heading: Label
var return_focus: Control
var return_settings := false
var return_settings_menu := false
var category := "gear"
var pending: Dictionary = {}
var action_status := ""
var last_send_ms := -1000
var cooldown_refresh := false

func _ready() -> void:
	layer = 99
	var file := FileAccess.open("res://career/catalog.json", FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if valid_catalog(parsed): catalog = parsed
	build_panel()

static func valid_catalog(raw: Variant) -> bool:
	if not raw is Dictionary or raw.get("schema") != 1 or not raw.get("items") is Array: return false
	if raw.items.size() < 1 or raw.items.size() > 128: return false
	var ids := {}
	for entry: Variant in raw.items:
		if not entry is Dictionary: return false
		if entry.get("kind") not in ["gear", "attachment", "finish", "crosshair"]: return false
		for field: String in ["id", "unlockId", "name", "description", "slot"]:
			if not entry.get(field) is String or entry[field].length() > (600 if field == "description" else 128): return false
		if entry.id.is_empty() or entry.name.is_empty() or entry.description.is_empty(): return false
		if not entry.get("level") is int and not entry.get("level") is float: return false
		if not is_finite(float(entry.level)) or float(entry.level) != floorf(float(entry.level)) or entry.level < 1 or entry.level > 60: return false
		if not entry.get("modifiers") is Dictionary or not entry.get("spec") is Array or not entry.get("weapons") is Array: return false
		if not entry.get("weaponNames") is Array or entry.weaponNames.size() > 16 or entry.spec.size() > 16 or entry.modifiers.size() > 16: return false
		for value: Variant in entry.spec:
			if not value is String or value.length() > 80: return false
		for value: Variant in entry.weaponNames:
			if not value is String or value.length() > 80: return false
		for value: Variant in entry.modifiers.values():
			if not (value is float or value is int) or not is_finite(float(value)): return false
		var key: String = str(entry.kind) + ":" + str(entry.id)
		if ids.has(key): return false
		ids[key] = true
	return true

func active() -> bool:
	return panel != null and panel.visible

func clear_connection(client: Node) -> void:
	if connection_owner != null and connection_owner.get_ref() == client:
		connection_owner = null
		profile.clear()
		pending.clear()
		last_send_ms = -1000
		cooldown_refresh = false
		action_status = "Disconnected · pending selection unconfirmed."
		refresh()

func receive(client: Node, frame: Dictionary) -> void:
	if not is_instance_valid(client): return
	# A queued reply from a closed room cannot resurrect a disconnected career.
	if not ("room_id" in client) or str(client.room_id).is_empty() or not client.career_seated or not client.career_wire_open(): return
	if frame.get("type") == "welcome":
		# Only the seated connection's source welcome owns an identity.
		pending.clear()
		last_send_ms = -1000
		cooldown_refresh = false
		action_status = ""
		connection_owner = weakref(client)
		profile = CareerProfile.project(frame.get("profile"))
	elif frame.get("type") == "progression" and connection_owner != null and connection_owner.get_ref() == client and not profile.is_empty():
		var next: Dictionary = CareerProfile.project(frame.get("profile"))
		if next.get("id") != profile.get("id"): return
		if not pending.is_empty():
			var outcome: String = Actions.outcome(pending, frame, next)
			if outcome != "pending":
				action_status = "Source confirmed selection · saved for next match." if outcome == "applied" else "Source adjusted/refused selection · see confirmed equipment below."
				pending.clear()
		profile = next
	else: return
	refresh()

func open_panel(focus: Control = null, from_settings: bool = false, settings_menu: bool = false) -> void:
	var settings := get_tree().root.get_node_or_null("LocalSettings")
	if active() or (settings != null and settings.overlay_open() and not from_settings): return
	return_focus = focus
	return_settings = from_settings
	return_settings_menu = settings_menu
	if settings != null: settings.release_controls()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	panel.show()
	refresh()
	var back := panel.find_child("CareerBack", true, false) as Button
	back.grab_focus()

func close_panel() -> void:
	if not active(): return
	panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if return_settings:
		var settings := get_tree().root.get_node_or_null("LocalSettings")
		if settings != null: settings.open_panel(return_settings_menu, return_focus)
	elif is_instance_valid(return_focus): return_focus.grab_focus()
	return_focus = null
	return_settings = false
	return_settings_menu = false

func _process(_delta: float) -> void:
	if connection_owner != null and not is_instance_valid(connection_owner.get_ref()):
		connection_owner = null
		profile.clear()
		pending.clear()
		last_send_ms = -1000
		cooldown_refresh = false
		action_status = "Disconnected · pending selection unconfirmed."
		refresh()
	if cooldown_refresh and Time.get_ticks_msec() - last_send_ms >= 550:
		cooldown_refresh = false
		refresh()
	if not pending.is_empty() and not pending.get("timed_out", false) and Time.get_ticks_msec() - int(pending.get("sent_at", 0)) > Actions.TIMEOUT_MS:
		pending.timed_out = true
		action_status = "No source confirmation · outcome unknown. Reconnect before another selection."
		refresh()

func select_item(item: Dictionary, clear: bool = false) -> void:
	if not pending.is_empty() or profile.is_empty() or connection_owner == null: return
	if Time.get_ticks_msec() - last_send_ms < 550:
		action_status = "Source gear cooldown · wait a moment and select again."
		refresh()
		return
	var client: Node = connection_owner.get_ref()
	if not is_instance_valid(client) or not client.career_wire_open() or not client.career_seated or str(client.room_id).is_empty() or client.spectating: return
	# A complete loadout is sent on every write: omitted gear would clear slots.
	var frame: Dictionary = Actions.request(profile, item, clear)
	if frame.is_empty(): return
	if client.send_frame(frame) != OK:
		action_status = "Selection could not be sent; confirmed equipment unchanged."
	else:
		last_send_ms = Time.get_ticks_msec()
		cooldown_refresh = true
		pending = {"identity":profile.id, "frame":frame, "sent_at":Time.get_ticks_msec()}
		action_status = "Selection sent · awaiting source confirmation (next match)."
	refresh()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if active() and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		close_panel()
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
	var back := Button.new()
	back.name = "CareerBack"
	back.text = "BACK (Esc)"
	back.custom_minimum_size.y = 44
	back.pressed.connect(close_panel)
	details.add_child(back)
	details.add_child(state_label)
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
		state_label.text = "NO CONNECTED CAREER · Join a room to see your source profile and equip unlocked items."
	else:
		var parts := []
		for field: String in ["level", "xp", "prestige"]:
			parts.append(field.to_upper() + " " + (str(profile[field]) if profile.has(field) else "UNKNOWN"))
		state_label.text = "CONNECTED SOURCE CAREER · " + " · ".join(parts) + "\nEquip for next match · Unlocks come from level and source progression."
		var modes: Dictionary = profile.get("byMode", {})
		state_label.text += "\nMATCHES %s · WINS %s · KILLS %s" % [str(profile.get("matches", "?")), str(profile.get("wins", "?")), str(profile.get("kills", "?"))]
		if not modes.is_empty():
			var mode_parts := []
			for mode: String in modes:
				var stats: Dictionary = modes[mode]
				mode_parts.append("%s %s/%s" % [mode, str(stats.get("wins", "?")), str(stats.get("matches", "?"))])
			state_label.text += "\nMODE WINS/MATCHES · " + " · ".join(mode_parts)
	if not action_status.is_empty(): state_label.text += "\n" + action_status
	if category == "crosshair": state_label.text += "\nReticles are view-only: this server's GEAR wire does not carry a crosshair selection."
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
		add_line(box, "%s · %s · %s" % [item.name, item.slot if not item.slot.is_empty() else item.kind, CareerProfile.item_state(profile, item)], 19)
		add_line(box, item.description)
		var spec := []
		for key: String in item.modifiers: spec.append(key + " " + str(item.modifiers[key]))
		for part: String in item.spec: spec.append(part)
		if item.kind == "attachment": spec.append("ALL WEAPONS" if item.weapons.is_empty() else "FITS " + ", ".join(item.get("weaponNames", [])))
		if not spec.is_empty(): add_line(box, " · ".join(spec), 14)
		if item.kind != "crosshair":
			var button := Button.new()
			button.name = "Equip_" + str(item.unlockId)
			button.set_meta("catalog_id", item.id)
			button.set_meta("catalog_kind", item.kind)
			var equipped: bool = CareerProfile.item_state(profile, item) == "EQUIPPED"
			button.text = "UNEQUIP · NEXT MATCH" if equipped else "EQUIP · NEXT MATCH"
			button.custom_minimum_size.y = 44
			var client: Node = connection_owner.get_ref() if connection_owner != null else null
			button.disabled = not pending.is_empty() or Time.get_ticks_msec() - last_send_ms < 550 or not is_instance_valid(client) or not client.career_wire_open() or not client.career_seated or client.spectating or not Actions.complete(profile) or not Actions.available(profile, item)
			button.pressed.connect(select_item.bind(item, equipped))
			box.add_child(button)
