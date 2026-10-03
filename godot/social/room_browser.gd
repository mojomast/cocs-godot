extends VBoxContainer
## Room browser for the native lobby. It only ever asks the existing selected
## endpoint for its advertised rooms (`list` -> `rooms`); there is no scanning,
## probing or discovery of any other address. The panel is popup-free and every
## row is a plain control so untrusted names render without RichText/BBCode.
##
## Honesty states: it never shows an empty list while a request is in flight and
## never invents a room's map/mode/player count/lifecycle the authority omitted.

signal refresh_requested
# The full normalized record, so the lobby can populate the advertised map/mode
# as well as the room code (not just the code).
signal room_selected(room: Dictionary)

const Model = preload("res://social/social_model.gd")
const REQUEST_TIMEOUT := 6.0

var caption := Label.new()
var endpoint_label := Label.new()
var status := Label.new()
var refresh_button := Button.new()
var search := LineEdit.new()
var hide_started := CheckButton.new()
var list_box := VBoxContainer.new()
var empty_note := Label.new()
var clear_filters_button := Button.new()
var controls := BoxContainer.new()

var all_rooms: Array = []
# Sentinel true so the first `sync(false)` performs the disconnected transition.
var connected := true
var awaiting := false
var elapsed := 0.0
var dirty := true
# The room the user last selected, kept only for the in-list highlight. It is
# never used to auto-join and is cleared on disconnect like the advertised list.
var selected_room_id := ""

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	caption.text = "ROOMS ON THIS SERVER"
	caption.add_theme_font_size_override("font_size", 14)
	endpoint_label.text = "Endpoint: not connected"
	endpoint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	endpoint_label.add_theme_color_override("font_color", Color(0.68, 0.76, 0.82))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color(0.68, 0.76, 0.82))
	controls.add_theme_constant_override("separation", 6)
	refresh_button.text = "Browse / Refresh"
	refresh_button.tooltip_text = "Connect to the entered endpoint and list its rooms"
	refresh_button.pressed.connect(func() -> void: refresh_requested.emit())
	controls.add_child(refresh_button)
	search.placeholder_text = "Search rooms"
	search.custom_minimum_size.x = 120
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(_text: String) -> void: dirty = true)
	search.tooltip_text = "Filter by code, name, map or mode"
	controls.add_child(search)
	hide_started.text = "Hide in progress"
	hide_started.toggled.connect(func(_on: bool) -> void: dirty = true)
	controls.add_child(hide_started)
	empty_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_note.add_theme_color_override("font_color", Color(0.68, 0.76, 0.82))
	clear_filters_button.text = "Clear filters"
	clear_filters_button.tooltip_text = "Clear the room search and the in-progress filter"
	clear_filters_button.visible = false
	clear_filters_button.pressed.connect(clear_filters)
	list_box.add_theme_constant_override("separation", 2)
	for node: Control in [caption, endpoint_label, status, controls, clear_filters_button, empty_note, list_box]:
		add_child(node)
	sync(false)
	rebuild()

func set_compact(compact: bool) -> void:
	controls.set_vertical(compact)

# True when the user has narrowed the list: a search query and/or the
# "Hide in progress" toggle. Drives the truthful empty-filter note.
func filter_active() -> bool:
	return not search.text.strip_edges().is_empty() or hide_started.button_pressed

# One explicit, focusable recovery path for a filtered-to-empty list. It only
# clears the browser's own filters: it never selects a room, changes role or
# touches the current join selection, and it keeps the typed query in place until
# the user chooses to clear it.
func clear_filters() -> void:
	search.text = ""
	hide_started.set_pressed_no_signal(false)
	dirty = true
	search.grab_focus()

# The endpoint this browser is actually bound to (the open connection), not the
# editable field text. Set every frame by the lobby; only writes on a change so a
# stable endpoint does not re-shape the label every frame.
func set_endpoint(label: String) -> void:
	if endpoint_label.text == label: return
	endpoint_label.text = label

# Called every frame by the lobby with the live connection state. Status text is
# updated only on a transition so the browser never flickers.
func sync(open: bool) -> void:
	if open == connected: return
	connected = open
	awaiting = false
	elapsed = 0.0
	if not connected:
		all_rooms.clear()
		selected_room_id = ""
		status.text = "Not connected — press Browse / Refresh to connect to the entered endpoint."
	else:
		status.text = "Connected · press Browse / Refresh to list rooms on this server."
	dirty = true

# Marks a request the lobby has already queued. Deliberately emits nothing: the
# request path must not re-enter the button signal.
func mark_refreshing() -> void:
	awaiting = true
	elapsed = 0.0
	status.text = "Refreshing room list…"

func accept(rows: Variant) -> void:
	awaiting = false
	elapsed = 0.0
	all_rooms = Model.normalize_rooms(rows)
	dirty = true
	if all_rooms.is_empty():
		status.text = "The server advertised no rooms."
	else:
		status.text = "%d room%s advertised." % [all_rooms.size(), "" if all_rooms.size() == 1 else "s"]

# A malformed reply or a transport-level social notice. Existing rows are kept:
# one bad reply must not erase a room list the authority already sent.
func fail(message: String) -> void:
	awaiting = false
	elapsed = 0.0
	status.text = message if not message.is_empty() else "Room list request failed."

func select_room(record: Dictionary) -> void:
	if record.is_empty(): return
	selected_room_id = str(record.get("roomId", ""))
	# Update the existing rows in place: the pressed row keeps focus and the
	# highlight appears immediately, without a rebuild and without re-emitting.
	apply_selection_mark()
	room_selected.emit(record)

func visible_rooms() -> Array:
	var filtered: Array = Model.filter_rooms(all_rooms, search.text, hide_started.button_pressed)
	return Model.sort_rooms(filtered, "name", true)

func rebuild() -> void:
	for child: Node in list_box.get_children():
		list_box.remove_child(child)
		child.queue_free()
	var rooms: Array = visible_rooms()
	var filtering := filter_active()
	# The clear path is offered whenever a filter is active, so it is reachable
	# even from a populated list, and it stays put while the result is empty.
	clear_filters_button.visible = filtering
	# Truthful empty state: an in-flight request and an unconnected browse stay
	# blank (their status line already explains them); an empty advertised list
	# is distinct from a filter that simply matched nothing.
	if awaiting or not connected:
		empty_note.text = ""
	elif all_rooms.is_empty():
		empty_note.text = "No rooms to show."
	elif rooms.is_empty():
		empty_note.text = "No rooms match the current filters."
	else:
		empty_note.text = ""
	var shown: int = mini(rooms.size(), Model.ROOM_ROWS_LIMIT)
	for index: int in shown:
		var room: Dictionary = rooms[index]
		list_box.add_child(row_for(room))
	if rooms.size() > shown:
		var more := Label.new()
		more.text = "+%d more room%s not listed (browsing is bounded)." % [rooms.size() - shown, "" if rooms.size() - shown == 1 else "s"]
		more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		more.add_theme_color_override("font_color", Color(0.68, 0.76, 0.82))
		list_box.add_child(more)
	# row_for() marks the current selection; re-assert after the batch so the
	# marker is consistent even if selected_room_id changed out of band.
	apply_selection_mark()
	dirty = false

func row_for(room: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var code := Button.new()
	code.text = str(room.get("roomId", ""))
	code.custom_minimum_size.x = 78
	code.tooltip_text = "Select room %s" % code.text
	code.pressed.connect(select_room.bind(room))
	row.add_child(code)
	var name := str(room.get("name", ""))
	if name.is_empty(): name = "(unnamed room)"
	var base := "%s · %s" % [name, Model.room_label(room)]
	var details := Label.new()
	# The unmarked base text is cached so apply_selection_mark() can toggle the
	# marker in place without rebuilding the row or dropping focus.
	details.set_meta("base_text", base)
	var selected := not selected_room_id.is_empty() and code.text == selected_room_id
	details.text = ("▸ " + base) if selected else base
	details.tooltip_text = details.text
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(details)
	return row

# Toggle the selected-room marker on the existing rows without rebuilding them,
# so a click keeps focus on the pressed row and the highlight updates at once.
func apply_selection_mark() -> void:
	for row: Node in list_box.get_children():
		if row.get_child_count() < 2: continue
		var code := row.get_child(0) as Button
		var details := row.get_child(1) as Label
		if code == null or details == null or not details.has_meta("base_text"): continue
		var base := str(details.get_meta("base_text"))
		var marked := not selected_room_id.is_empty() and code.text == selected_room_id
		var text := ("▸ " + base) if marked else base
		if details.text != text:
			details.text = text
			details.tooltip_text = text

func _process(delta: float) -> void:
	if dirty: rebuild()
	if awaiting:
		elapsed += delta
		if elapsed >= REQUEST_TIMEOUT:
			awaiting = false
			status.text = "Room list request timed out — press Refresh to retry."
