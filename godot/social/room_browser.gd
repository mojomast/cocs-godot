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
var controls := BoxContainer.new()

var all_rooms: Array = []
# Sentinel true so the first `sync(false)` performs the disconnected transition.
var connected := true
var awaiting := false
var elapsed := 0.0
var dirty := true

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
	list_box.add_theme_constant_override("separation", 2)
	for node: Control in [caption, endpoint_label, status, controls, empty_note, list_box]:
		add_child(node)
	sync(false)
	rebuild()

func set_compact(compact: bool) -> void:
	controls.set_vertical(compact)

# The endpoint this browser is actually bound to (the open connection), not the
# editable field text. Set every frame by the lobby.
func set_endpoint(label: String) -> void:
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
	room_selected.emit(record)

func visible_rooms() -> Array:
	var filtered: Array = Model.filter_rooms(all_rooms, search.text, hide_started.button_pressed)
	return Model.sort_rooms(filtered, "name", true)

func rebuild() -> void:
	for child: Node in list_box.get_children():
		list_box.remove_child(child)
		child.queue_free()
	var rooms: Array = visible_rooms()
	if all_rooms.is_empty():
		empty_note.text = "" if awaiting or not connected else "No rooms to show."
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
	var details := Label.new()
	details.text = "%s · %s" % [name, Model.room_label(room)]
	details.tooltip_text = details.text
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(details)
	return row

func _process(delta: float) -> void:
	if dirty: rebuild()
	if awaiting:
		elapsed += delta
		if elapsed >= REQUEST_TIMEOUT:
			awaiting = false
			status.text = "Room list request timed out — press Refresh to retry."
