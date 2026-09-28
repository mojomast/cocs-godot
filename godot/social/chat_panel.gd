extends Control
## Room-scoped text chat for the native multiplayer route (lobby + live round).
##
## It rides the one existing connection: it sends the source `chat` verb and only
## renders the authority's broadcast (including this client's own line), never an
## optimistic local echo. The log is cleared whenever the seated room changes or
## the connection drops, so chat can never leak across rooms or sessions, and the
## panel is modal while open so typing suspends movement/fire for the round.
##
## Not an autoload and not a new project hook: the lobby scene owns one instance,
## so a single-player route never grows an inert chat surface.

const Model = preload("res://social/social_model.gd")
const Names = preload("res://ui/scoreboard.gd")
const PENDING_TIMEOUT_MS := 2500

signal opened
signal closed

var toggle_button := Button.new()
var shade := ColorRect.new()
var panel := PanelContainer.new()
var title := Label.new()
var status := Label.new()
var scroll := ScrollContainer.new()
var log_box := VBoxContainer.new()
var input := LineEdit.new()
var send_button := Button.new()
var hint := Label.new()

var session: Node
var bound_room := ""
var pending_text := ""
var pending_at := -1
var last_send_ms := -1

func bind(target: Node) -> void:
	session = target
	var client: Node = session.get("client") if session != null else null
	if client == null: return
	if client.has_signal("chat"): client.chat.connect(_on_chat)
	if client.has_signal("social_error"): client.social_error.connect(_on_social_error)
	if client.has_signal("connection_error"): client.connection_error.connect(_on_connection_error)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0.02, 0.035, 0.05, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.hide()
	toggle_button.text = "Chat"
	toggle_button.custom_minimum_size = Vector2(110, 36)
	toggle_button.tooltip_text = "Open room chat (typing releases movement/fire)"
	toggle_button.pressed.connect(toggle)
	build_panel()
	add_child(shade)
	add_child(toggle_button)
	add_child(panel)
	panel.hide()
	get_viewport().size_changed.connect(layout)
	layout()

func build_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101925")
	for edge: String in ["left", "right", "top", "bottom"]:
		style.set("content_margin_" + edge, 10.0)
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	title.text = "ROOM CHAT"
	title.add_theme_font_size_override("font_size", 16)
	column.add_child(title)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color(0.68, 0.76, 0.82))
	column.add_child(status)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	column.add_child(scroll)
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_box.add_theme_constant_override("separation", 2)
	scroll.add_child(log_box)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	input.max_length = Model.CHAT_TEXT_LIMIT
	input.placeholder_text = "Message…"
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.text_submitted.connect(func(_text: String) -> void: send())
	line.add_child(input)
	send_button.text = "Send"
	send_button.pressed.connect(send)
	line.add_child(send_button)
	column.add_child(line)
	hint.text = "Enter sends · Esc closes · typing suspends controls"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.68, 0.76, 0.82))
	column.add_child(hint)

func capturing_input() -> bool:
	return panel != null and panel.visible

func toggle() -> void:
	if capturing_input(): close()
	else: open()

func open() -> void:
	if session == null: return
	var client: Node = session.get("client")
	if client == null or str(client.get("room_id")).is_empty(): return
	shade.show()
	panel.show()
	if session.has_method("release_pointer"): session.release_pointer()
	input.grab_focus()
	opened.emit()

func close() -> void:
	if not capturing_input(): return
	panel.hide()
	shade.hide()
	status.text = ""
	if is_instance_valid(toggle_button): toggle_button.grab_focus()
	closed.emit()

func _input(event: InputEvent) -> void:
	if not capturing_input(): return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		close()
		get_viewport().set_input_as_handled()

func send() -> void:
	if session == null: return
	var client: Node = session.get("client")
	var clean := Model.sanitize(input.text, Model.CHAT_TEXT_LIMIT)
	if clean.is_empty():
		status.text = "Type a message first."
		return
	var now := Time.get_ticks_msec()
	if last_send_ms >= 0 and now - last_send_ms < Model.CHAT_COOLDOWN_MS:
		# Mirror the source's 300 ms floor, but say so instead of dropping the
		# line silently the way the authority does.
		status.text = "Rate-limited locally — wait a moment, then send again."
		return
	var result: Error = client.send_chat(clean)
	if result != OK:
		status.text = "Message could not be queued; the connection is not open."
		return
	last_send_ms = now
	pending_text = clean
	pending_at = now
	status.text = "Sending…"
	input.text = ""

func _on_chat(frame: Dictionary) -> void:
	if session == null: return
	var client: Node = session.get("client")
	# Room scope: never render a line when this connection has no seat, or when
	# it arrived after the seated room changed (late frame).
	if str(client.get("room_id")).is_empty(): return
	var line: Dictionary = Model.chat_line(frame, int(client.get("peer_id")))
	if line.is_empty(): return
	if pending_at >= 0 and line.get("self", false) == true and str(line.get("text", "")) == pending_text:
		pending_text = ""
		pending_at = -1
		status.text = ""
	append_line(line)

func _on_social_error(message: String) -> void:
	status.text = message

func _on_connection_error(_message: String) -> void:
	clear_log()
	bound_room = ""
	status.text = ""

func append_line(line: Dictionary) -> void:
	var label := Label.new()
	label.text = Names.plain(Model.chat_log_label(line), "Player", 256)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_box.add_child(label)
	while log_box.get_child_count() > Model.CHAT_LOG_LIMIT:
		var oldest: Node = log_box.get_child(0)
		log_box.remove_child(oldest)
		oldest.queue_free()
	scroll.ensure_control_visible.call_deferred(label)

func clear_log() -> void:
	for child: Node in log_box.get_children():
		log_box.remove_child(child)
		child.queue_free()
	pending_text = ""
	pending_at = -1
	last_send_ms = -1

func _process(_delta: float) -> void:
	if session == null: return
	var client: Node = session.get("client")
	var room := str(client.get("room_id"))
	if room != bound_room:
		# A new seat (join, leave, reconnect) always starts a clean log so one
		# room's history can never appear against another.
		clear_log()
		bound_room = room
		if room.is_empty() and capturing_input(): close()
	var in_room := not room.is_empty()
	toggle_button.visible = in_room
	if not in_room and capturing_input(): close()
	if pending_at >= 0 and Time.get_ticks_msec() - pending_at >= PENDING_TIMEOUT_MS:
		pending_text = ""
		pending_at = -1
		status.text = "No server confirmation (rate-limited or dropped by the authority)."

func layout() -> void:
	var viewport := get_viewport().get_visible_rect().size
	shade.position = Vector2.ZERO
	shade.size = viewport
	# Top-right, in the same column as the lobby's Leave/Restart actions and
	# clear of the HUD vitals/weapon panels; the open panel is modal on top.
	toggle_button.position = Vector2(maxf(8, viewport.x - 150), 28)
	var width := minf(560, viewport.x - 40)
	var height := minf(420, viewport.y - 96)
	panel.size = Vector2(width, height)
	panel.position = Vector2(maxf(8, viewport.x - width - 20), 66)
	if panel.position.y + height > viewport.y - 8:
		panel.position.y = maxf(66, viewport.y - height - 8)
