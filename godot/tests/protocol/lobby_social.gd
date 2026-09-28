extends SceneTree
# Native social surface: room browser + room-scoped chat. Offline and synthetic
# (no network, no authority): the LobbyMenu is driven with a fake session and the
# real network client's decode path, so the wire contract, the honesty states and
# the typing guard are checked without a live seat. A short real-Session section
# at the end proves `browse_rooms` validation and `social_capturing` wiring.
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
		if not catalog.open(): push_error("synthetic catalog unavailable")
		add_child(client)
		client.set_process(false)
		add_child(label)
	func lobby_host_allowed() -> bool: return host_allowed
	func lobby_connect(url: String, player_name: String, room: String, map_id: String, mode: String, guest: bool, character: String = "", harness: String = "") -> void:
		calls.append({"call":"lobby_connect", "room":room, "guest":guest})
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

func run() -> void:
	# --- Pure model: source ceiling, honest unknowns, ordering ---------------
	check(Model.sanitize("  a\u0007b\u001fc  ", 200) == "abc", "sanitize strips control chars and trims")
	check(Model.sanitize("x".repeat(260), 200).length() == 200, "sanitize applies the 200-char ceiling")
	var empty := Model.normalize_room({"playerCount": 3})
	check(empty.is_empty(), "a room record without a roomId is unusable")
	var unknown := Model.normalize_room({"roomId":"ZZZZ"})
	check(int(unknown.players) == -1 and unknown.started == null and not unknown.modeKnown, "missing fields stay explicit unknowns")
	check(Model.map_label(unknown) == "map unknown" and Model.mode_label(unknown) == "mode unknown", "unknown labels are worded, never invented")
	check(Model.players_label(unknown) == "player count unknown" and Model.status_label(unknown) == "STATUS UNKNOWN", "unknown count/status are worded")
	var started := Model.normalize_room({"roomId":"AAAA","players":2,"started":true,"mapId":"exchange","config":{"mode":"ctf"}})
	check(Model.status_label(started).contains("SPECTATOR"), "a started room tells the truth about the spectator seat")
	check(Model.players_label(started) == "2 players" and Model.players_label(Model.normalize_room({"roomId":"B","players":1})) == "1 player", "player count is worded singular/plural")
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

	# A live rooms reply renders code/name/map/mode/players/status, skips garbage.
	var rows: Array = [
		{"roomId":"AB12","name":"Alpha","mapId":"meridian-exchange","players":2,"started":false,"config":{"mode":"teamdeathmatch"}},
		{"roomId":"CD34","name":"Bravo","mapId":"forge","players":1,"started":true,"config":{"mode":"ctf"}},
		"not-a-record",
		{"name":"no code"},
	]
	session.client.rooms.emit(rows)
	await settle()
	var list: Node = menu.room_browser.list_box
	check(list.get_child_count() == 2, "two valid room rows render, malformed records are skipped")
	check(row_code(list.get_child(0)).begins_with("AB") or row_code(list.get_child(0)).begins_with("CD"), "rows carry the room code")
	var detail := row_detail(list.get_child(0)) + row_detail(list.get_child(1))
	check(detail.contains("players") and detail.contains("unknown") == false, "rows show a real player count")
	check(detail.contains("Alpha") or detail.contains("Bravo"), "rows show the room name")
	check(detail.contains("IN PROGRESS") or detail.contains("OPEN"), "rows show the lifecycle status")

	# Unknown fields must not be turned into false availability.
	session.client.rooms.emit([{"roomId":"EF56"}])
	await settle()
	var unknown_detail := row_detail(menu.room_browser.list_box.get_child(0))
	check(unknown_detail.contains("map unknown") and unknown_detail.contains("mode unknown") and unknown_detail.contains("STATUS UNKNOWN"), "browser never infers missing source fields")

	# Selecting a row only fills the explicit guest join fields.
	session.client.rooms.emit(rows)
	await settle()
	var selector: Node = menu.room_browser.list_box.get_child(0).get_child(0)
	selector.pressed.emit()
	await settle()
	check(selection_is(session, menu), "room selection fills the guest fields without auto-joining")

	# Unknown/malformed social replies are non-fatal and reported.
	session.client.rooms.emit([{"roomId":"GH78"}])
	await settle()
	check(session.client.decode_text('{"type":"rooms","rooms":"nope"}'), "malformed rooms reply is not a teardown")
	check(session.client.error.is_empty(), "malformed rooms reply keeps the connection")
	check(menu.room_browser.status.text.to_lower().contains("malformed"), "malformed rooms reply is reported")
	check(session.client.decode_text('{"type":"error","message":"not in a room"}'), "out-of-room chat refusal is not a teardown")
	check(session.client.error.is_empty(), "out-of-room chat refusal keeps the connection")

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

	# Room scope: a line arriving with no seat, or after a room change, is dropped.
	session.client.room_id = ""
	await settle()
	check(log.get_child_count() == 0, "leaving the room clears the cached chat log")
	check(not menu.capturing_input(), "chat closes when the seat is gone")
	session.client.chat.emit({"peerId":5,"name":"Host","text":"late leak"})
	await settle()
	check(log.get_child_count() == 0, "a late chat frame with no seat never renders")
	menu.chat_panel.close()

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
	real.browse_rooms("http://bad")
	check(real.phase == -1 and real.label.text.contains("ws://"), "browse refuses a non-ws endpoint honestly")
	real.browse_rooms("ws://127.0.0.1:1")
	check(real.phase == 0 and real.browsing, "browse connects to the selected endpoint without seating")
	real.free()

	print("PORT_SOCIAL_OK checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

func selection_is(session: Node, menu: Node) -> bool:
	var guest_selected: bool = menu.role.selected == 1
	var code: String = menu.room.text
	var known: bool = code in ["AB12", "CD34", "EF56", "GH78"]
	return guest_selected and known and session.calls.is_empty()

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
