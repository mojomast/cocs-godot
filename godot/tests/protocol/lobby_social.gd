extends SceneTree
# Native social surface: room browser + room-scoped chat. Offline and synthetic
# (no network, no authority): the LobbyMenu is driven with a fake session summary
# and the real network client's decode path, so the wire contract, the honesty
# states, the UTF-16 ceiling and the typing guard are checked without a seat. A
# short real-Session section at the end proves `browse_rooms` validation and
# `social_capturing` wiring. No generated content assets are required.
const LobbyMenu = preload("res://ui/lobby_menu.gd")
const Session = preload("res://world/session.gd")
const Network = preload("res://net/client.gd")
const Model = preload("res://social/social_model.gd")
const Catalog = preload("res://world/catalog.gd")

class Probe extends Network:
	var sent: Array = []
	func send_frame(frame: Dictionary) -> Error:
		sent.append(frame.duplicate(true))
		return OK

class SessionDouble extends Node:
	var catalog := Catalog.new()
	var endpoint := "ws://127.0.0.1:9"
	var current_id := "meridian-exchange"
	var selected_mode := "deathmatch"
	var phase := -3
	var client := Probe.new()
	var label := Label.new()
	var calls: Array = []
	var host_allowed := false
	func _ready() -> void:
		# Hand-built registry: deterministic and independent of generated assets.
		catalog.entries = {
			"meridian-exchange":{"name":"Meridian Exchange","modes":["deathmatch","teamdeathmatch"]},
			"verdant-reliquary":{"name":"Verdant Reliquary","modes":["deathmatch","teamdeathmatch"]},
		}
		add_child(client)
		client.set_process(false)
		add_child(label)
	func lobby_host_allowed() -> bool: return host_allowed
	func lobby_connect(url: String, player_name: String, room: String, map_id: String, mode: String, guest: bool, character: String = "", harness: String = "") -> void:
		calls.append({"call":"lobby_connect", "room":room, "guest":guest, "map":map_id, "mode":mode})
	func lobby_start() -> void: calls.append({"call":"lobby_start"})
	func lobby_leave() -> void: calls.append({"call":"lobby_leave"})
	func request_restart() -> void: calls.append({"call":"request_restart"})
	func spectator_status() -> String: return "Read-only fixed view"
	func release_pointer() -> void: pass

class CaptureStub extends CanvasLayer:
	var value := false
	func capturing_input() -> bool: return value

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("SOCIAL " + message)

func _initialize() -> void: call_deferred("run")

func settle() -> void: await create_timer(0.08).timeout

func row_detail(row: Node) -> String:
	return (row.get_child(1) as Label).text if row.get_child_count() > 1 else ""

func row_code(row: Node) -> String:
	return (row.get_child(0) as Button).text if row.get_child_count() > 0 else ""

func find_row(list: Node, code: String) -> Node:
	for child: Node in list.get_children():
		if row_code(child) == code: return child
	return null

func run() -> void:
	# --- Pure model: source ceiling, UTF-16, honest unknowns, strict types ----
	check(Model.sanitize("  a\u0007b\u001fc  ", 200) == "abc", "sanitize strips control chars and trims")
	check(Model.utf16_length("😀") == 2 and Model.utf16_length("a😀b") == 4, "UTF-16 length counts surrogate pairs")
	check(Model.sanitize("x".repeat(260), 200).length() == 200, "sanitize applies the 200-unit ceiling")
	var emoji := Model.sanitize("😀".repeat(150), 200)
	check(emoji.length() == 100 and Model.utf16_length(emoji) == 200, "emoji ceiling stops at 200 UTF-16 units without splitting a pair")
	check(Model.sanitize("\u00a0\ufeff hi \u00a0\u3000", 200) == "hi", "JS whitespace (NBSP/FEFF/ideographic) is trimmed")
	check(Model.sanitize(123, 200) == "" and Model.sanitize(null, 200) == "" and Model.sanitize(["x"], 200) == "", "non-string values are dropped, never coerced")
	check(Model.normalize_room({"roomId": 123}).is_empty(), "a non-string roomId is not coerced into a usable room")
	var empty := Model.normalize_room({"playerCount": 3})
	check(empty.is_empty(), "a room record without a roomId is unusable")
	var fractional := Model.normalize_room({"roomId":"A","players":2.5})
	check(int(fractional.players) == -1, "a fractional player count stays unknown, never floored")
	check(int(Model.normalize_room({"roomId":"A","players":2}).players) == 2 and int(Model.normalize_room({"roomId":"A","players":2.0}).players) == 2, "whole counts are accepted")
	var unknown := Model.normalize_room({"roomId":"ZZZZ"})
	check(int(unknown.players) == -1 and unknown.started == null and not unknown.modeKnown, "missing fields stay explicit unknowns")
	check(Model.map_label(unknown) == "map unknown" and Model.mode_label(unknown) == "mode unknown", "unknown labels are worded, never invented")
	check(Model.players_label(unknown) == "player count unknown" and Model.status_label(unknown) == "STATUS UNKNOWN", "unknown count/status are worded")
	var started := Model.normalize_room({"roomId":"AAAA","players":2,"started":true,"mapId":"exchange","config":{"mode":"ctf"}})
	check(Model.status_label(started).contains("SPECTATOR"), "a started room tells the truth about the spectator seat")
	check(Model.players_label(started) == "2 players" and Model.players_label(Model.normalize_room({"roomId":"B","players":1})) == "1 player", "player count is worded singular/plural")
	check(Model.chat_line({"peerId":2.5,"text":"x"}, 2).is_empty() == false and Model.chat_line({"peerId":2.5,"text":"x"}, 2).self == false, "a fractional peer id never claims self")
	check(Model.chat_line({"peerId":2,"text":5}, 2).is_empty(), "non-string chat text is dropped")
	check(str(Model.chat_line({"peerId":2,"name":9,"text":"hi"}, 2).name) == "", "non-string chat name is blank, not coerced")
	var sorted := Model.sort_rooms([started, Model.normalize_room({"roomId":"BBBB","name":"Bravo","players":3})], "players", false)
	check(sorted[0].roomId == "BBBB", "descending player sort puts the largest first")
	var filtered := Model.filter_rooms([started, Model.normalize_room({"roomId":"CCCC","name":"Charlie","mapId":"forge"})], "ctf")
	check(filtered.size() == 1 and filtered[0].roomId == "AAAA", "search covers mode")

	# --- Lobby menu: room browser + chat -------------------------------------
	var session := SessionDouble.new()
	root.add_child(session)
	await settle()
	var menu: Node = LobbyMenu.new()
	session.add_child(menu)
	await settle()
	check(is_instance_valid(menu.room_browser) and is_instance_valid(menu.chat_panel), "lobby builds the room browser and chat panel")
	check(menu.room_browser.status.text.contains("Not connected"), "browser is honest before any connection")
	check(menu.room_browser.endpoint_label.text.contains("not connected"), "browser labels the unbound endpoint honestly")

	# A rooms reply renders code/name/map/mode/players/status, skips garbage.
	var rows: Array = [
		{"roomId":"AB12","name":"Alpha","mapId":"meridian-exchange","players":2,"started":false,"config":{"mode":"teamdeathmatch"}},
		{"roomId":"CD34","name":"Bravo","mapId":"verdant-reliquary","players":1,"started":true,"config":{"mode":"teamdeathmatch"}},
		{"roomId":"EF56","name":"Echo","players":2.5},
		"not-a-record",
		{"name":"no code"},
		{"roomId": 123},
	]
	session.client.rooms.emit(rows)
	await settle()
	var list: Node = menu.room_browser.list_box
	check(list.get_child_count() == 3, "three valid room rows render, malformed/non-string records are skipped: " + str(list.get_child_count()))
	check(row_detail(find_row(list, "AB12")).contains("Alpha") and row_detail(find_row(list, "AB12")).contains("2 players"), "rows show the room name and a real count")
	check(row_detail(find_row(list, "CD34")).contains("IN PROGRESS"), "a started room is shown as in progress")
	check(row_detail(find_row(list, "EF56")).contains("player count unknown"), "a fractional count is shown unknown")

	# Selecting a Meridian room fills the code AND the advertised map/mode.
	find_row(list, "AB12").get_child(0).pressed.emit()
	await settle()
	check(menu.role.selected == 1 and menu.room.text == "AB12", "selection fills the guest code without auto-joining")
	check(str(menu.maps.get_selected_metadata()) == "meridian-exchange" and str(menu.modes.get_selected_metadata()) == "teamdeathmatch", "selection populates the advertised map and mode")
	check(menu.status.text.contains("meridian-exchange / teamdeathmatch"), "selection states the map/mode it populated")
	check(session.calls.is_empty(), "selection never connects on its own")

	# The original defect: a Verdant room must switch the map off the default.
	find_row(list, "CD34").get_child(0).pressed.emit()
	await settle()
	check(str(menu.maps.get_selected_metadata()) == "verdant-reliquary", "selecting a Verdant room moves the map dropdown off Meridian")
	check(menu.status.text.to_lower().contains("spectator"), "an in-progress selection warns about the spectator seat")

	# An unsupported advertised map is reported, never silently faked.
	session.client.rooms.emit([{"roomId":"ZZ99","name":"Zed","mapId":"atlantis","config":{"mode":"deathmatch"}}])
	await settle()
	find_row(menu.room_browser.list_box, "ZZ99").get_child(0).pressed.emit()
	await settle()
	check(menu.status.text.contains("not in this build's registry"), "an unsupported advertised map is reported honestly")
	check(str(menu.maps.get_selected_metadata()) == "verdant-reliquary", "unsupported selection leaves the manual map choice untouched")

	# Unknown fields must not be turned into false availability.
	session.client.rooms.emit([{"roomId":"EF56"}])
	await settle()
	var unknown_detail := row_detail(menu.room_browser.list_box.get_child(0))
	check(unknown_detail.contains("map unknown") and unknown_detail.contains("mode unknown") and unknown_detail.contains("STATUS UNKNOWN"), "browser never infers missing source fields")

	# Unknown/malformed social replies are non-fatal and reported.
	check(session.client.decode_text('{"type":"rooms","rooms":"nope"}'), "malformed rooms reply is not a teardown")
	check(session.client.error.is_empty(), "malformed rooms reply keeps the connection")
	check(menu.room_browser.status.text.to_lower().contains("malformed"), "malformed rooms reply is reported")
	check(session.client.decode_text('{"type":"error","message":"not in a room"}'), "out-of-room chat refusal is not a teardown")
	check(session.client.error.is_empty(), "out-of-room chat refusal keeps the connection")
	check(session.client.decode_text('{"type":"error","message":"unknown message type: chat"}'), "a server without chat is not a teardown")
	check(session.client.error.is_empty(), "missing chat capability keeps the connection")
	check(menu.room_browser.status.text.contains("unknown message type"), "missing chat capability is reported honestly")

	# A disconnect clears the advertised cache: no stale room survives.
	session.client.rooms.emit([{"roomId":"IJ90","name":"Cached"}])
	await settle()
	check(menu.room_browser.list_box.get_child_count() == 1, "browser shows the advertised room before disconnect")
	# The synthetic client peer is already closed, so model the live→closed edge
	# explicitly (the fixture cannot open a real socket).
	menu.room_browser.connected = true
	menu.room_browser.sync(false)
	await settle()
	check(menu.room_browser.list_box.get_child_count() == 0, "disconnect clears the cached room list")
	check(menu.room_browser.status.text.contains("Not connected"), "disconnect state is worded")

	# --- Chat: send, source ACK renders, cooldown, scope clearing ------------
	session.client.room_id = "AB12"
	session.client.peer_id = 5
	await settle()
	menu.chat_panel.open()
	await settle()
	check(menu.capturing_input(), "open chat captures typing so gameplay input is suspended")
	menu.chat_panel.close_button.pressed.emit()
	await settle()
	check(not menu.capturing_input(), "the panel Close button releases typing capture")
	menu.chat_panel.open()
	await settle()
	check(menu.capturing_input(), "the toggle reopens chat")
	var log: Node = menu.chat_panel.log_box
	check(log.get_child_count() == 0, "a fresh seat starts with an empty chat log")
	menu.chat_panel.input.text = "  hello [b]room[/b]  "
	menu.chat_panel.send()
	await settle()
	check(session.client.sent.size() == 1 and session.client.sent[0].type == "chat", "send queues exactly one source chat frame")
	check(session.client.sent[0].text == "hello [b]room[/b]", "the draft is source-sanitized before send")
	check(menu.chat_panel.status.text == "Sending…", "a line is only pending until the authority echoes it")
	check(menu.chat_panel.input.text.is_empty(), "the draft clears after a successful queue")
	menu.chat_panel.input.text = "again"
	menu.chat_panel.send()
	await settle()
	check(session.client.sent.size() == 1, "a second send inside the 300 ms floor is refused locally")
	check(menu.chat_panel.status.text.contains("Rate-limited locally"), "the local rate refusal is worded, not silent")

	# The authority's own broadcast (including our line) is the display source.
	await create_timer(0.35).timeout
	session.client.chat.emit({"peerId":5,"name":"Host","text":"hello [b]room[/b]"})
	await settle()
	check(log.get_child_count() == 1, "the source chat ACK renders exactly one line")
	var line_text := (log.get_child(0) as Label).text
	check(line_text.contains("hello [b]room[/b]"), "untrusted chat text renders literally, never as RichText")
	check(line_text.contains("you"), "the local player's own echoed line is tagged")
	check(menu.chat_panel.status.text == "", "a confirmed line clears the pending state")

	# An emoji line is bounded identically by client and model, so the echo
	# resolves the pending state (the UTF-16 ceiling the source uses).
	await create_timer(0.35).timeout
	session.client.sent.clear()
	menu.chat_panel.input.text = "😀".repeat(150)
	menu.chat_panel.send()
	await settle()
	check(session.client.sent.size() == 1 and Model.utf16_length(str(session.client.sent[0].text)) == 200, "an emoji draft is bounded to 200 UTF-16 units before send")
	session.client.chat.emit({"peerId":5,"name":"Host","text":str(session.client.sent[0].text)})
	await settle()
	check(menu.chat_panel.status.text == "" and log.get_child_count() == 2, "the emoji echo matches the pending line and renders")

	# Room scope: a line arriving with no seat, or after a room change, is dropped.
	session.client.room_id = ""
	await settle()
	check(log.get_child_count() == 0, "leaving the room clears the cached chat log")
	check(not menu.capturing_input(), "chat closes when the seat is gone")
	session.client.chat.emit({"peerId":5,"name":"Host","text":"late leak"})
	await settle()
	check(log.get_child_count() == 0, "a late chat frame with no seat never renders")
	menu.chat_panel.close()

	# A welcome-poll edge: the first line of a new room must survive the room
	# change clear (sync bound_room before appending).
	session.client.room_id = "NEW1"
	session.client.chat.emit({"peerId":7,"name":"Peer","text":"first of the room"})
	await settle()
	check(log.get_child_count() == 1, "the first chat of a newly seated room is not erased by the room-change clear")

	# An unconfirmed send is reported after the timeout, never silently dropped.
	session.client.sent.clear()
	menu.chat_panel.open()
	menu.chat_panel.input.text = "no ack"
	menu.chat_panel.send()
	await settle()
	check(session.client.sent.size() == 1 and session.client.sent[0].text == "no ack", "the unconfirmed draft was queued")
	menu.chat_panel.pending_at = Time.get_ticks_msec() - 3000
	await settle()
	check(menu.chat_panel.status.text.contains("No server confirmation"), "an unconfirmed line is reported, not dropped silently")

	# A disconnect clears the draft and closes the modal.
	menu.chat_panel.input.text = "leaky draft"
	session.client.connection_error.emit("Disconnected")
	await settle()
	check(menu.chat_panel.input.text.is_empty(), "a disconnect clears the unsent draft")
	check(not menu.capturing_input(), "a disconnect closes the chat modal")

	# --- Compact geometry at 150% interface scale ----------------------------
	for size: Vector2i in [Vector2i(960, 640), Vector2i(1280, 800)]:
		root.content_scale_factor = 1.5
		root.size = size
		await settle()
		menu.chat_panel.layout()
		await settle()
		var viewport := Rect2(Vector2.ZERO, menu.get_viewport().get_visible_rect().size)
		check(viewport.encloses(menu.chat_panel.toggle_button.get_global_rect()), "chat toggle fits at " + str(size) + " @150%")
		check(viewport.encloses(menu.chat_panel.panel.get_global_rect()), "chat panel fits at " + str(size) + " @150%")
		print("SOCIAL_GEOMETRY ", str(size), " toggle=", str(menu.chat_panel.toggle_button.get_global_rect()), " panel=", str(menu.chat_panel.panel.get_global_rect()))
	root.content_scale_factor = 1.0
	session.free()

	# --- Real Session: browse validation + typing-guard wiring ---------------
	var real := real_session()
	var stub := CaptureStub.new()
	stub.value = true
	real.lobby_menu = stub
	check(real.social_capturing(), "social_capturing follows the lobby chat surface")
	stub.value = false
	check(not real.social_capturing(), "closed chat does not capture")
	real.lobby_menu = null
	stub.free()
	real.browse_rooms("http://bad")
	check(real.phase == -1 and real.label.text.contains("ws://"), "browse refuses a non-ws endpoint honestly")
	real.browse_rooms("ws://127.0.0.1:1")
	check(real.phase == 0 and real.browsing, "browse connects to the selected endpoint without seating")
	real.phase = -4
	real.browsing = true
	real.browse_rooms("ws://127.0.0.1:2")
	check(real.phase == 0 and real.browsing and real.endpoint == "ws://127.0.0.1:2", "re-browsing from a live browse seat reconnects to the new endpoint")
	real.free()

	print("PORT_SOCIAL_OK checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

# Mirrors the proven lobby_flow offline Session construction.
func real_session() -> Session:
	var s := Session.new()
	s.client.free()
	var probe := Probe.new()
	s.client = probe
	for node: Node in [s.camera, s.label, s.selector, s.environment, s.sun, s.client, s.presentation, s.pickups, s.combat, s.combat_label]:
		s.add_child(node)
	s.lobby_enabled = true
	s.phase = -3
	s.current_id = "meridian-exchange"
	s.catalog.entries = {s.current_id:{"modes":["deathmatch","teamdeathmatch","rockets"]}}
	s.client.allowlist = s.catalog.entries
	s.client.requested_map = s.current_id
	return s
