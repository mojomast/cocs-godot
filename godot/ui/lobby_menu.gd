extends CanvasLayer

const Setup = preload("res://ui/match_setup.gd")
const Names = preload("res://ui/scoreboard.gd")
const Choice = preload("res://ui/lobby_choice.gd")
const Loadout = preload("res://ui/loadout.gd")
const RoomBrowser = preload("res://social/room_browser.gd")
const ChatPanel = preload("res://social/chat_panel.gd")
const EquippedModel = preload("res://career/equipped_model.gd")
var session: Node
var panel := PanelContainer.new()
var form := VBoxContainer.new()
var endpoint := LineEdit.new()
var player_name := LineEdit.new()
var room := LineEdit.new()
var role := Choice.new()
var maps := Choice.new()
var modes := Choice.new()
var operator := Choice.new()
var harness := Choice.new()
var status := Label.new()
var roster := Label.new()
var loadout_summary := Label.new()
var arsenal_button := Button.new()
var connect_button := Button.new()
var start_button := Button.new()
var back_button := Button.new()
var leave_button := Button.new()
var restart_button := Button.new()
var reconnect_button := Button.new()
var entries: Dictionary = {}
var last_frame: Dictionary = {}
var room_browser
var chat_panel
var browser_phase: int = -999
var previous_phase: int = -999
var actions: BoxContainer
# Sticky browsed-room note, kept visible under the per-phase status text until
# the user connects, clears the room, or changes role.
var selection_note := ""
# Fingerprint of the read-only catalog projection last rendered into the map
# row. A same-size replacement that changes ids/names/modes still differs here.
var catalog_fingerprint := ""
# Observer counter: increments only when room.editable actually changes. A
# per-frame owner must leave this flat while the role/phase is stable.
var room_editable_writes := 0

# Catalog access is total: a failed `catalog.open()` leaves the shared entries
# dictionary empty (and the manifest error on the catalog), so every lookup here
# must survive a missing id, a non-dictionary entry or an absent `modes` array
# without an invalid-dictionary error. None of these helpers mutate the catalog.
func map_entry(map_id: String) -> Dictionary:
	if map_id.is_empty() or not entries.has(map_id): return {}
	var entry: Variant = entries[map_id]
	return entry if entry is Dictionary else {}

func offered_modes(map_id: String) -> Array:
	return Setup.valid_modes(map_entry(map_id))

func catalog_ready() -> bool:
	return not entries.is_empty()

func selected_entry() -> Dictionary:
	return map_entry(str(maps.get_selected_metadata()))

# Host/join/start need an advertised map that resolves to a real entry with at
# least one mode. A non-empty but malformed/mode-less catalog disables the launch
# path instead of letting the session reject it after a click.
func launchable() -> bool:
	var map_id := str(maps.get_selected_metadata())
	return catalog_ready() and not map_entry(map_id).is_empty() and not offered_modes(map_id).is_empty()

# The catalog's own failure string, surfaced verbatim. `world/catalog.gd` sets
# `error` on a failed open() but later resolve_map() calls can overwrite it and a
# successful resolve never clears it, so this is best-effort original text, not a
# guarantee of freshness. It is never replaced by a generic guess.
func catalog_error_text() -> String:
	var message := ""
	if session != null and "catalog" in session:
		var live: Variant = session.get("catalog")
		if live is Dictionary:
			message = str(live.get("error", ""))
		elif live is Object:
			message = str(live.get("error"))
	if message.is_empty():
		return "The locked map catalog is empty; maps, modes and hosting are unavailable."
	return "Locked catalog unavailable: " + message

# Read-only projection of the catalog content the map/mode rows depend on:
# sorted ids plus each entry's name and validated modes. Same-size replacements
# that change other ids, names or the selected map's modes still differ.
func catalog_signature() -> String:
	var ids: Array = entries.keys()
	ids.sort()
	var parts := PackedStringArray()
	for raw: Variant in ids:
		var id := str(raw)
		parts.append("%s\u001f%s\u001f%s" % [id, str(map_entry(id).get("name", "")), "\u001e".join(PackedStringArray(offered_modes(id)))])
	return "\u001d".join(parts)

func field(title: String, control: Control) -> void:
	var caption := Label.new()
	caption.text = title
	form.add_child(caption)
	form.add_child(control)

func _ready() -> void:
	layer = 12
	session = get_parent()
	entries = session.catalog.entries
	add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101925")
	for edge: String in ["left", "right", "top", "bottom"]:
		style.set("content_margin_" + edge, 16.0)
	panel.add_theme_stylebox_override("panel", style)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	panel.add_child(layout)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 6)
	scroll.add_child(form)
	var title := Label.new()
	title.text = "NATIVE MULTIPLAYER · 60s rounds · 2 bots"
	title.add_theme_font_size_override("font_size", 24)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(title)
	endpoint.text = session.endpoint
	endpoint.placeholder_text = "ws://127.0.0.1:PORT"
	player_name.text = "Godot player"
	player_name.max_length = 32
	room.max_length = 128
	role.add_item("Host — create a new room")
	role.add_item("Guest — join an existing lobby")
	field("Server WebSocket endpoint", endpoint)
	field("Display name", player_name)
	field("Role", role)
	field("Room code (guest)", room)
	field("Map / expected host map", maps)
	rebuild_map_choices(session.current_id)
	catalog_fingerprint = catalog_signature()
	field("Host mode (guests use authority's mode)", modes)
	maps.item_selected.connect(func(_i: int) -> void:
		populate_modes()
		apply_choice_enablement())
	populate_modes()
	# Operator/harness rows match the shared popup-free choice. A guest picks
	# their own pair; after connecting the authority echo is the only source.
	build_loadout_rows()
	var loadout_columns := HBoxContainer.new()
	loadout_columns.add_theme_constant_override("separation", 12)
	loadout_columns.add_child(operator)
	loadout_columns.add_child(harness)
	field("Operator / harness (yours)", loadout_columns)
	# Room browser sits with the join fields inside the scrolling form. It only
	# ever reads the authority's advertised rooms on this endpoint (no scanning).
	room_browser = RoomBrowser.new()
	room_browser.refresh_requested.connect(request_rooms)
	room_browser.room_selected.connect(select_room)
	form.add_child(room_browser)
	# Saved-loadout summary: a single wrapping line, never a horizontal scroller,
	# so it cannot push the form wider than the viewport. It only ever reflects
	# the seated owner's confirmed profile.
	loadout_summary.name = "LoadoutSummary"
	loadout_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(loadout_summary)
	for item: Label in [status, roster]:
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		form.add_child(item)
	connect_button.text = "Connect / Create / Join"
	start_button.text = "Start match"
	back_button.text = "Back / Leave room"
	# Open Arsenal sits with the summary inside the scrolling form rather than in
	# the pinned action row: it adds no minimum width to that row, so Join/Create/
	# Leave/Retry keep their pinned geometry at every supported size.
	arsenal_button.text = "Open Arsenal"
	arsenal_button.custom_minimum_size.y = 36
	arsenal_button.pressed.connect(open_arsenal)
	form.add_child(arsenal_button)
	# Actions stay pinned below the scroll area: reachable at 960x640 and
	# 1280x800 without scrolling, and never clipped by the form.
	actions = BoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	for button: Button in [connect_button, start_button, reconnect_button, back_button]:
		button.custom_minimum_size.y = 36
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	layout.add_child(actions)
	connect_button.pressed.connect(func() -> void: session.lobby_connect(endpoint.text.strip_edges(), player_name.text.strip_edges(), room.text.strip_edges() if role.selected == 1 else "", str(maps.get_selected_metadata()), str(modes.get_selected_metadata()), role.selected == 1, selected_character(), selected_harness()))
	start_button.pressed.connect(func() -> void: session.lobby_start())
	reconnect_button.text = "Retry / Reconnect"
	reconnect_button.pressed.connect(func() -> void: session.lobby_retry_reconnect())
	back_button.pressed.connect(leave_room)
	leave_button.text = "Leave match"
	restart_button.text = "Restart round"
	add_child(leave_button)
	add_child(restart_button)
	leave_button.pressed.connect(leave_room)
	restart_button.pressed.connect(func() -> void: session.request_restart())
	# Room chat rides the same connection and shows in both the lobby and the live
	# round. It is modal while open so typing cannot move or fire.
	chat_panel = ChatPanel.new()
	add_child(chat_panel)
	chat_panel.bind(session)
	if session.client.has_signal("rooms"): session.client.rooms.connect(room_browser.accept)
	if session.client.has_signal("social_error"): session.client.social_error.connect(room_browser.fail)
	get_viewport().size_changed.connect(resize_panel)
	resize_panel()
	refresh()

# Room-list request. If already connected on the entered endpoint, queue the
# source `list` verb over that live connection. If the endpoint field was edited
# while unseated, reconnect explicitly to the new text instead of silently
# listing the old connection. A seated connection keeps its bound endpoint (the
# field is locked while seated).
func request_rooms() -> void:
	var url := endpoint.text.strip_edges()
	var open: bool = session.client.peer.get_ready_state() == WebSocketPeer.STATE_OPEN
	if open:
		if url != session.endpoint:
			if session.phase in [-3, -1, -4] and session.has_method("browse_rooms"):
				room_browser.fail("Endpoint changed — reconnecting to %s…" % url)
				browser_phase = -999
				session.browse_rooms(url)
			else:
				room_browser.fail("Leave the room before changing the endpoint.")
			return
		room_browser.mark_refreshing()
		if session.client.request_rooms() != OK:
			room_browser.fail("Room list request could not be queued.")
		return
	if session.has_method("browse_rooms") and session.phase in [-3, -1, -4]:
		room_browser.fail("Connecting to browse rooms…")
		session.browse_rooms(url)
	else:
		room_browser.fail("Connect before refreshing rooms on this server.")

# Selecting a row fills the explicit guest join fields AND the advertised
# map/mode when this build's registry supports them. The connect step stays
# user-driven, so an in-progress room still seats the joiner as a spectator.
func select_room(record: Dictionary) -> void:
	if record.is_empty(): return
	var room_id := str(record.get("roomId", ""))
	if room_id.is_empty(): return
	role.select(1)
	room.text = room_id
	room.editable = true
	var map_id := str(record.get("mapId", ""))
	var mode := str(record.get("mode", ""))
	var map_supported: bool = not map_entry(map_id).is_empty()
	var offered: Array = offered_modes(map_id)
	var mode_supported: bool = map_supported and mode in offered
	if map_supported: select_map(map_id)
	if mode_supported: select_mode(mode)
	var note := "Selected room %s" % room_id
	if not map_supported:
		note += " — advertised map '%s' is not in this build's registry; choose a supported map manually." % (map_id if not map_id.is_empty() else "unknown")
	elif not mode_supported:
		note += " — advertised mode '%s' is not supported for %s; the authority's mode is adopted on join." % [mode if not mode.is_empty() else "unknown", map_id]
	else:
		note += " — %s / %s. Press Join lobby" % [map_id, mode]
		if record.get("started") == true: note += " (in progress — you will join as a spectator)."
		else: note += "."
	selection_note = note
	status.text = note
	connect_button.grab_focus()

func leave_room() -> void:
	selection_note = ""
	session.lobby_leave()
	connect_button.grab_focus()

func focus_phase(expected: int, button: Button) -> void:
	if session.phase != expected or not button.visible or button.disabled: return
	const SettingsAccess = preload("res://ui/settings_access.gd")
	if not SettingsAccess.overlay_open() and not capturing_input(): button.grab_focus()

# Escape backs out of the room/browse seat; from the disconnected form it
# opens the existing Settings/Leave path to Home. Modal Escape is owned by its
# overlay, and no Back operation pauses or captures a running match.
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode != KEY_ESCAPE and event.physical_keycode != KEY_ESCAPE: return
	const SettingsAccess = preload("res://ui/settings_access.gd")
	if SettingsAccess.overlay_open() or capturing_input(): return
	if session.phase in [-3, -1]:
		SettingsAccess.open_panel(false, connect_button)
	elif session.phase not in [3, 4, 20]:
		leave_room()
	else:
		return # Live Escape releases pointer in the session, never leaves a match.
	get_viewport().set_input_as_handled()

func map_index(id: String) -> int:
	for index: int in maps.item_count:
		if str(maps.get_item_metadata(index)) == id: return index
	return -1

func mode_index(id: String) -> int:
	for index: int in modes.item_count:
		if str(modes.get_item_metadata(index)) == id: return index
	return -1

# Selects an advertised map/mode only when the registry explicitly offers it.
func select_map(id: String) -> bool:
	var index := map_index(id)
	if index < 0: return false
	maps.select(index)
	populate_modes()
	apply_choice_enablement()
	return true

func select_mode(id: String) -> bool:
	var index := mode_index(id)
	if index < 0: return false
	modes.select(index)
	return true

func capturing_input() -> bool:
	return is_instance_valid(chat_panel) and chat_panel.capturing_input()

func build_loadout_rows() -> void:
	for entry: Dictionary in Loadout.CHARACTERS:
		operator.add_item(str(entry.name))
		operator.set_item_metadata(operator.item_count - 1, str(entry.id))
	for entry: Dictionary in Loadout.HARNESSES:
		harness.add_item(str(entry.name))
		harness.set_item_metadata(harness.item_count - 1, str(entry.id))
	operator.item_selected.connect(on_operator_selected)
	var pair := initial_pair()
	select_operator(pair.character)
	if not harness.disabled: select_harness(pair.harness)

func selected_character() -> String:
	return str(operator.get_selected_metadata())

func selected_harness() -> String:
	return str(harness.get_selected_metadata())

# The session owns the pair before the first connect (CLI or setup route). The
# synthetic UI double in the offline tests has no such member, so the documented
# defaults are used there.
func initial_pair() -> Dictionary:
	var character := Loadout.DEFAULT_CHARACTER
	var harness_id := Loadout.DEFAULT_HARNESS
	if session != null:
		if "selected_character" in session: character = str(session.get("selected_character"))
		if "selected_harness" in session: harness_id = str(session.get("selected_harness"))
	return Loadout.resolve(character, harness_id)

func operator_index(id: String) -> int:
	for index: int in operator.item_count:
		if str(operator.get_item_metadata(index)) == id: return index
	return -1

func harness_index(id: String) -> int:
	for index: int in harness.item_count:
		if str(harness.get_item_metadata(index)) == id: return index
	return -1

func select_operator(id: String) -> void:
	if operator.disabled: return
	var index := operator_index(id)
	if index < 0: return
	operator.select(index)
	apply_harness_lock()

func select_harness(id: String) -> void:
	if harness.disabled: return
	var index := harness_index(id)
	if index < 0: return
	if not Loadout.valid(selected_character(), id): return
	harness.select(index)

func select_harness_index(index: int) -> void:
	if index >= 0 and index < harness.item_count: harness.select(index)

# Single owner of harness.disabled: locked only while the operator requires it
# and the form is editable.
func apply_harness_lock() -> void:
	var editable: bool = session.phase in [-3, -1, -4]
	var locked := Loadout.locked_harness(selected_character())
	if locked.is_empty():
		harness.disabled = not editable
		if not Loadout.valid(selected_character(), selected_harness()):
			select_harness_index(harness_index(Loadout.DEFAULT_HARNESS))
		return
	select_harness_index(harness_index(locked))
	harness.disabled = true

func on_operator_selected(_index: int) -> void:
	if operator.disabled: return
	apply_harness_lock()

# (Re)build the mode row for the selected map. `preferred` wins when supplied;
# otherwise the map row never resets a user's mode on an unrelated catalog
# change: the currently selected mode is kept whenever it is still offered, and
# only an invalid/absent current mode falls back to the session's mode (or the
# first offered mode).
func populate_modes(preferred: String = "") -> void:
	var keep := preferred if not preferred.is_empty() else str(modes.get_selected_metadata())
	if keep.is_empty() or keep == "<null>": keep = session.selected_mode
	modes.clear()
	var offered := offered_modes(str(maps.get_selected_metadata()))
	for mode: String in offered:
		modes.add_item(Setup.MODE_NAMES.get(mode, mode) + (" — pending" if mode not in Setup.MODES else ""))
		modes.set_item_metadata(modes.item_count - 1, mode)
		if mode == keep: modes.select(modes.item_count - 1)

# Single owner of the four top-level choice enabled states. Called once per
# refresh after any catalog reconciliation, and again immediately after a user
# map change so the mode row is correct before the next frame. Each property is
# written exactly once per call; the setters are idempotent across calls.
func apply_choice_enablement() -> void:
	var editable: bool = session.phase in [-3, -1, -4]
	var ready := catalog_ready()
	var offered := offered_modes(str(maps.get_selected_metadata()))
	role.disabled = not editable
	maps.disabled = not editable or not ready
	modes.disabled = not editable or role.selected == 1 or offered.is_empty()
	operator.disabled = not editable

# Rebuild the map row from the live catalog, keeping the current selection by
# metadata and falling back to the session's current map. Rebuilding is what
# makes a newly added key (absent from the old rows) selectable again.
func rebuild_map_choices(preferred: String = "") -> void:
	var previous := preferred if not preferred.is_empty() else str(maps.get_selected_metadata())
	maps.clear()
	for raw: Variant in entries.keys():
		var id := str(raw)
		var entry := map_entry(id)
		maps.add_item(str(entry.get("name", id)) + (" — pending" if id not in Setup.MAPS else ""))
		maps.set_item_metadata(maps.item_count - 1, id)
	if not previous.is_empty() and map_index(previous) >= 0:
		maps.select(map_index(previous))
	elif not session.current_id.is_empty() and map_index(session.current_id) >= 0:
		maps.select(map_index(session.current_id))

# Rebuild the map/mode rows only when the catalog content actually changed; a
# stable frame performs no work, while a same-size replacement that changes other
# ids, names or the selected map's modes is picked up and its selection kept.
func sync_map_choices() -> void:
	var signature := catalog_signature()
	if signature == catalog_fingerprint: return
	catalog_fingerprint = signature
	rebuild_map_choices()
	populate_modes()

func resize_panel() -> void:
	var viewport := get_viewport().get_visible_rect().size
	# The visible rect is in canvas coordinates after UI scale. Budget against
	# both it and the physical window so pinned actions stay inside either size.
	var scale := get_window().content_scale_factor
	viewport = viewport.min(Vector2(get_window().size) / maxf(scale, 0.01))
	var desired_width := minf(700, viewport.x - 32)
	if actions != null: actions.set_vertical(desired_width < 600)
	if is_instance_valid(room_browser): room_browser.set_compact(desired_width < 600)
	panel.size = Vector2(desired_width, viewport.y - 32)
	panel.position = (viewport - panel.size) / 2
	# At 150% UI scale the logical width of a 760px window is about 507px.
	leave_button.position = Vector2(viewport.x - 150, 70)
	restart_button.position = Vector2(viewport.x - 150, 112)

func show_roster(frame: Dictionary) -> void:
	last_frame = frame.duplicate(true)
	var lines := PackedStringArray()
	lines.append("Room: %s · %s" % [session.client.room_id, session.endpoint])
	if frame.get("config") is Dictionary:
		lines.append("%s / %s" % [str(frame.get("mapId", "")), str(frame.config.get("mode", ""))])
	for player: Dictionary in frame.get("players", []):
		var tags := " · YOU" if player.peerId == session.client.peer_id else ""
		if player.peerId == frame.get("hostId"): tags += " · HOST"
		if player.get("spectate", false): tags += " · spectator"
		elif player.get("actorId") != null: tags += " · actor %s" % str(player.actorId)
		else: tags += " · unassigned"
		if not player.get("connected", false): tags += " · disconnected"
		lines.append(Names.plain(player.get("name"), "Player", 32) + " · " + Loadout.player_label(player) + tags)
	roster.text = "\n".join(lines)

## Owner-gated saved-loadout projection: only the seated connection that welcome
## bound may expose a profile. A different client, endpoint or disconnected seat
## leaves the summary at the explicit connect prompt.
func loadout_connected() -> bool:
	var career := get_tree().root.get_node_or_null("Career")
	if career == null: return false
	if not career.owned(session.client): return false
	if not session.client.career_seated or not session.client.career_wire_open(): return false
	return not career.profile.is_empty()

func open_arsenal() -> void:
	var career := get_tree().root.get_node_or_null("Career")
	if career == null or not loadout_connected(): return
	career.open_panel(arsenal_button)

func refresh_loadout_summary() -> void:
	var career := get_tree().root.get_node_or_null("Career")
	if not loadout_connected():
		loadout_summary.text = "Connect to load source loadout."
		arsenal_button.disabled = true
		if is_instance_valid(restart_button): restart_button.tooltip_text = ""
		if is_instance_valid(leave_button): leave_button.tooltip_text = ""
		return
	var summary: Dictionary = career.equipment_summary()
	var line: String = "Saved loadout for next match · " + EquippedModel.short_line(summary)
	if not str(career.action_status).is_empty(): line += "\n" + str(career.action_status)
	loadout_summary.text = line
	arsenal_button.disabled = false
	if is_instance_valid(restart_button): restart_button.tooltip_text = "Next match applies: " + EquippedModel.short_line(summary)
	if is_instance_valid(leave_button): leave_button.tooltip_text = "Saved for next match: " + EquippedModel.short_line(summary)

func refresh() -> void:
	var phase: int = session.phase
	if phase != previous_phase:
		# Never steal focus from typing, Career, Settings, or live pointer input.
		if phase == -5: focus_phase.call_deferred(phase, reconnect_button)
		elif phase == 12 and session.lobby_host_allowed(): focus_phase.call_deferred(phase, start_button)
		elif phase == -3 and previous_phase != -999: focus_phase.call_deferred(phase, connect_button)
	previous_phase = phase
	var playing := phase in [3, 4, 20]
	panel.visible = not playing
	leave_button.visible = playing and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	restart_button.visible = phase == 4 and session.lobby_host_allowed()
	# Spectator presentation belongs to this opt-in lobby. Keep the shared HUD's
	# missing-player behavior intact for ordinary sessions and lost actor poses.
	if session.client.spectating and playing:
		var hud := session.get_node_or_null("GameHUD")
		if hud != null:
			hud.status_title.text = "ROUND COMPLETE · SPECTATOR" if phase == 4 else "SPECTATING · READ ONLY"
			hud.status_detail.text = session.spectator_status()
			# The shared HUD resets this panel for its one-line missing-player
			# message. Reserve room for both read-only guidance lines this frame.
			hud.status_panel.size.y = maxf(94.0, hud.status_panel.get_combined_minimum_size().y)
			hud.status_panel.show()
			hud.score_label.text = "SPECTATOR"
			hud.controls.hide()
	var editable := phase in [-3, -1, -4]
	# Conditional writes: the per-frame caller only touches a field when its value
	# actually changed, and the shared choice setters are themselves idempotent.
	# `room` is excluded here: it has its own single writer below (guest-only), so
	# leaving it in this loop would toggle a host field false->true->false.
	for control: LineEdit in [endpoint, player_name]:
		if control.editable != editable: control.editable = editable
	# A live, failed or re-run catalog can invalidate the map row between frames;
	# reconcile it before a missing/empty entry can reach populate_modes.
	sync_map_choices()
	var ready := catalog_ready()
	var entry := selected_entry()
	var offered := offered_modes(str(maps.get_selected_metadata()))
	var can_launch := launchable()
	# Exactly one writer per disabled property per refresh (apply_choice_enablement
	# owns role/maps/modes/operator; apply_harness_lock owns harness). The earlier
	# "not editable" loop followed by a second modes write made a stable guest or
	# empty-catalog frame render twice every frame.
	apply_choice_enablement()
	# Owner of harness.disabled for both states, so a stale lock never sticks.
	apply_harness_lock()
	# Sole writer of room.editable for this refresh (guest-only join field).
	var room_editable := editable and role.selected == 1
	if room.editable != room_editable:
		room.editable = room_editable
		room_editable_writes += 1
	connect_button.visible = editable
	connect_button.disabled = not editable or not can_launch
	connect_button.text = "Retry with these settings" if phase == -1 else ("Join lobby" if role.selected == 1 else "Create lobby")
	start_button.visible = phase == 12
	start_button.disabled = not session.lobby_host_allowed() or not can_launch
	reconnect_button.visible = phase == -5
	reconnect_button.disabled = phase == -5 and not session.client.reconnect_ticket.available(session.endpoint, session.current_id, session.client.reconnect_ticket.room_id)
	back_button.visible = phase != -3
	back_button.text = "Leave" if phase in [-5, -6] else ("Cancel browse" if phase == -4 else "Back / Leave room")
	var messages := {-3:"Disconnected · choose settings and connect explicitly.", -4:"Browsing server rooms · select a room, then Join lobby as guest.", 0:"Connecting…", 1:"Creating room…", 2:"Configuring…", 10:"Joining…", 11:"Waiting for host. Active-room joins stay read-only through restart. Leave and join between rounds to request play.", 12:"Lobby ready · share room code, wait for guests, then Start."}
	var page_status: String = session.label.text if phase in [-1, -5, -6] else str(messages.get(phase, ""))
	# A browsed-room note stays visible under the phase text only while the guest
	# form is editable; it is dropped once the user connects or changes role.
	if role.selected != 1 or phase not in [-3, -4]: selection_note = ""
	if phase in [-3, -4] and not selection_note.is_empty():
		page_status = (page_status + "\n" + selection_note) if not page_status.is_empty() else selection_note
	if phase == -3:
		var empty_roster := "No room joined. Native maps/modes marked pending cannot be started."
		if roster.text != empty_roster: roster.text = empty_roster
		var problem := Setup.validate(entries, str(maps.get_selected_metadata()), str(modes.get_selected_metadata()))
		if not problem.is_empty() and role.selected == 0:
			page_status = (page_status + "\n" + problem) if not page_status.is_empty() else problem
	# An empty/failed locked catalog is stated once, in the catalog's own words,
	# and disables the host/join/mode controls (back/retry stay usable).
	if not ready and phase in [-3, -4]:
		page_status = catalog_error_text()
	elif ready and entry.is_empty() and phase in [-3, -4]:
		page_status = "The selected map is not a valid locked catalog entry; choose another map."
	elif ready and offered.is_empty() and phase in [-3, -4]:
		page_status = "No modes are registered for the selected map; choose another map."
	if status.text != page_status: status.text = page_status
	# Room browser tracks the live connection and asks once when browse opens. The
	# endpoint label shows the connection the browser is actually bound to.
	if is_instance_valid(room_browser):
		var open: bool = session.client.peer.get_ready_state() == WebSocketPeer.STATE_OPEN
		room_browser.sync(open)
		room_browser.set_endpoint(("Endpoint: %s" % session.endpoint) if (open and not session.endpoint.is_empty()) else "Endpoint: not connected")
		if phase == -4 and browser_phase != -4: request_rooms()
	browser_phase = phase
	# The Arsenal entry is usable only with a seated source profile, so it never
	# opens an empty panel. It is pinned with the other actions and stays disabled
	# with a clear connect prompt before that.
	arsenal_button.visible = phase in [-3, -4, -1, 11, 12]
	refresh_loadout_summary()

func _process(_delta: float) -> void:
	refresh()
