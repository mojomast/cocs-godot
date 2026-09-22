extends CanvasLayer

const Setup = preload("res://ui/match_setup.gd")
const Names = preload("res://ui/scoreboard.gd")
var session: Node
var panel := PanelContainer.new()
var form := VBoxContainer.new()
var endpoint := LineEdit.new()
var player_name := LineEdit.new()
var room := LineEdit.new()
var role := OptionButton.new()
var maps := OptionButton.new()
var modes := OptionButton.new()
var status := Label.new()
var roster := Label.new()
var connect_button := Button.new()
var start_button := Button.new()
var back_button := Button.new()
var leave_button := Button.new()
var restart_button := Button.new()
var entries: Dictionary = {}
var last_frame: Dictionary = {}

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
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 6)
	scroll.add_child(form)
	var title := Label.new()
	title.text = "NATIVE MULTIPLAYER · 60s rounds · 2 bots"
	title.add_theme_font_size_override("font_size", 24)
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
	for id: String in entries:
		maps.add_item(str(entries[id].name) + (" — pending" if id not in Setup.MAPS else ""))
		maps.set_item_metadata(maps.item_count - 1, id)
		if id == session.current_id: maps.select(maps.item_count - 1)
	field("Host mode (guests use authority's mode)", modes)
	maps.item_selected.connect(func(_i: int) -> void: populate_modes())
	populate_modes()
	for item: Label in [status, roster]:
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		form.add_child(item)
	connect_button.text = "Connect / Create / Join"
	start_button.text = "Start match"
	back_button.text = "Back / Leave room"
	for button: Button in [connect_button, start_button, back_button]:
		button.custom_minimum_size.y = 36
		form.add_child(button)
	connect_button.pressed.connect(func() -> void: session.lobby_connect(endpoint.text.strip_edges(), player_name.text.strip_edges(), room.text.strip_edges() if role.selected == 1 else "", str(maps.get_selected_metadata()), str(modes.get_selected_metadata()), role.selected == 1))
	start_button.pressed.connect(func() -> void: session.lobby_start())
	back_button.pressed.connect(func() -> void: session.lobby_leave())
	leave_button.text = "Leave match"
	restart_button.text = "Restart round"
	add_child(leave_button)
	add_child(restart_button)
	leave_button.pressed.connect(func() -> void: session.lobby_leave())
	restart_button.pressed.connect(func() -> void: session.request_restart())
	get_viewport().size_changed.connect(resize_panel)
	resize_panel()
	refresh()

func populate_modes() -> void:
	modes.clear()
	for mode: String in entries[str(maps.get_selected_metadata())].modes:
		modes.add_item(Setup.MODE_NAMES.get(mode, mode) + (" — pending" if mode not in Setup.MODES else ""))
		modes.set_item_metadata(modes.item_count - 1, mode)
		if mode == session.selected_mode: modes.select(modes.item_count - 1)

func resize_panel() -> void:
	var viewport := get_viewport().get_visible_rect().size
	panel.size = Vector2(minf(700, viewport.x - 32), viewport.y - 32)
	panel.position = (viewport - panel.size) / 2
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
		lines.append(Names.plain(player.get("name"), "Player", 32) + tags)
	roster.text = "\n".join(lines)

func refresh() -> void:
	var phase: int = session.phase
	var playing := phase in [3, 4, 20]
	panel.visible = not playing
	leave_button.visible = playing and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	restart_button.visible = phase == 4 and session.lobby_host_allowed()
	var editable := phase in [-3, -1]
	for control: LineEdit in [endpoint, player_name, room]: control.editable = editable
	for control: OptionButton in [role, maps, modes]: control.disabled = not editable
	modes.disabled = not editable or role.selected == 1
	room.editable = editable and role.selected == 1
	connect_button.visible = editable
	connect_button.text = "Retry with these settings" if phase == -1 else ("Join lobby" if role.selected == 1 else "Create lobby")
	start_button.visible = phase == 12
	start_button.disabled = not session.lobby_host_allowed()
	back_button.visible = phase != -3
	var messages := {-3:"Disconnected · choose settings and connect explicitly.", 0:"Connecting…", 1:"Creating room…", 2:"Configuring…", 10:"Joining…", 11:"Waiting for host. Active-room joins are spectators; use a fresh lobby to play again.", 12:"Lobby ready · share room code, wait for guests, then Start."}
	status.text = session.label.text if phase == -1 else str(messages.get(phase, ""))
	if phase == -3:
		roster.text = "No room joined. Native maps/modes marked pending cannot be started."
		var problem := Setup.validate(entries, str(maps.get_selected_metadata()), str(modes.get_selected_metadata()))
		if not problem.is_empty() and role.selected == 0: status.text += "\n" + problem

func _process(_delta: float) -> void:
	refresh()
