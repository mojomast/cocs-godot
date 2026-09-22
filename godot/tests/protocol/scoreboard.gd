extends SceneTree

const Scoreboard = preload("res://ui/scoreboard.gd")
const HordeScoreboard = preload("res://horde/scoreboard.gd")
const GameHUD = preload("res://ui/game_hud.gd")
const Client = preload("res://net/client.gd")
var checks := 0

class SessionStub extends Node:
	var client := Client.new()
	var phase := 3
	var join_room_id := ""
	var round_starts := 0
	func _ready() -> void:
		add_child(client)
		client.started.connect(func(_frame: Dictionary) -> void:
			round_starts += 1
			phase = 3)
		client.results.connect(func(_frame: Dictionary) -> void: phase = 4)
		client.connection_error.connect(func(_message: String) -> void: phase = -1)

class HordeHost extends Node3D:
	# Minimal product-shaped host: the Horde strip position and the shared GameHUD.
	var horde_label := Label.new()
	func _ready() -> void:
		horde_label.position = Vector2(20, 190)
		horde_label.size = Vector2(240, 78)
		add_child(horde_label)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		quit(1)
		assert(ok, message)

func key(code: Key, pressed: bool, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	return event

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var session := SessionStub.new()
	var board := Scoreboard.new()
	session.add_child(board)
	root.add_child(session)
	await process_frame
	check(board.client == session.client and not board.panel.visible, "deferred binding; hidden before start")
	board._input(key(KEY_TAB, true))
	check(not board.panel.visible, "Tab cannot expose inactive panel")
	session.client.started.emit({})
	session.client.actor_id = 2
	var state := {"mapName":"Meridian Exchange", "modeName":"Deathmatch", "time":83.9,
		"actors":[{"id":0,"name":"Zulu","frags":4,"deaths":2},
		{"id":1,"name":"Alpha","frags":4,"deaths":1,"team":0},
		{"id":2,"name":"[b]YOU[/b]\nPlayer","frags":7,"deaths":3,"team":"Blue"}]}
	session.client.snapshot.emit({"state":state})
	check(not board.panel.visible and board.round_number == 1, "live snapshots do not auto-open")
	check(board.entries[0].local and board.entries[1].player_name == "Alpha", "sort by frags then deaths; local identity")
	board._input(key(KEY_TAB, true, true))
	check(not board.panel.visible, "key repeat ignored")
	var pointer_mode := Input.mouse_mode
	board._input(key(KEY_TAB, true))
	await process_frame
	check(board.panel.visible and Input.mouse_mode == pointer_mode, "Tab opens without changing capture")
	check(board.rows[0].cells[1].text == "[b]YOU[/b] Player  · YOU", "plain Label preserves markup literally, collapses newline")
	check(board.clock_text == "Elapsed 1:23" and board.entries[1].team == "Red", "authoritative elapsed seconds and readable numeric team zero")
	var row_id: int = board.rows[0].node.get_instance_id()
	board.dirty = false
	session.client.snapshot.emit({"state":state})
	check(not board.dirty, "identical presentation skips label updates")
	for i: int in range(100):
		state.actors[1].frags = i
		session.client.snapshot.emit({"state":state})
	check(board.rows[0].node.get_instance_id() == row_id and board.rows_box.get_child_count() == board.MAX_VISIBLE, "snapshot churn reuses fixed row pool")
	check(board.entries[0].player_name == "Alpha", "changed scores reorder")
	board._input(key(KEY_TAB, false))
	check(not board.panel.visible, "Tab release hides live panel")
	board._input(key(KEY_TAB, true))
	board._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not board.panel.visible and not board.tab_held, "focus loss clears held state")
	session.client.results.emit({"state":state})
	await process_frame
	check(board.panel.visible and board.finished and "Enter" in board.footer.text, "results auto-open with host restart hint")
	board._input(key(KEY_TAB, false))
	check(board.panel.visible, "Tab release cannot dismiss results")
	session.phase = 20
	await process_frame
	check("authoritative round start" in board.footer.text, "restart pending message")
	session.client.started.emit({})
	check(not board.panel.visible and board.entries.is_empty() and board.round_number == 2, "round restart clears rows and visibility")
	board.guest = true
	session.client.results.emit({"state":state})
	await process_frame
	check("Waiting for host" in board.footer.text, "guest never offered Enter restart")
	session.phase = -1
	await process_frame
	check(not board.panel.visible and board.entries.is_empty(), "local session error clears overlay without client signal")
	session.phase = 3
	session.client.started.emit({})
	state.actors = []
	for i: int in range(100): state.actors.append({"id":i,"name":"Player %d" % i,"frags":i,"deaths":0})
	session.client.snapshot.emit({"state":state})
	board._input(key(KEY_TAB, true))
	board._input(key(KEY_PAGEDOWN, true))
	await process_frame
	check(board.entries.size() == 64 and board.page == 1 and "capped at 64" in board.footer.text, "bounded roster and keyboard pagination")
	state.actors = [null, {"name":{}, "id":null, "frags":NAN, "deaths":"?", "team":[]}, {}]
	session.client.snapshot.emit({"state":state})
	check(board.entries.size() == 2 and board.page == 0 and not board.entries[0].local, "sparse/malformed fields handled and page clamped")
	check(board.entries[0].frags == "—" and board.entries[0].team == "—", "missing stats not invented")
	session.client.connection_error.emit("synthetic disconnect")
	check(not board.panel.visible and board.entries.is_empty(), "client disconnect clears scoreboard")
	check(passive_controls(board), "all overlay controls ignore mouse and keyboard focus")
	# Roster wording is derived from the wire roster, never from the actor count
	# alone: bots and Horde NPCs must not be reported as players.
	board.apply_state({"actors":[{"id":0,"name":"Human","frags":1,"deaths":0},
		{"id":1,"name":"Bot","frags":0,"deaths":1,"bot":{"state":"roam"}},
		{"id":2,"name":"Bot","frags":0,"deaths":2,"bot":{"state":"roam"}}]}, 0)
	board.render()
	check(board.summary.text.ends_with("3 combatants  ·  1 player  ·  2 bots"), "bot rosters are named, not counted as players")
	board.apply_state({"actors":[{"id":0,"name":"Human","frags":1,"deaths":0},
		{"id":1,"name":"Husk","frags":0,"deaths":1,"isNpc":true},
		{"id":2,"name":"Spitter","frags":0,"deaths":2,"isNpc":true}]}, 0)
	board.render()
	check(board.summary.text.ends_with("3 actors  ·  1 player  ·  2 enemies"), "NPC rosters are named as enemies")
	board.apply_state({"actors":[{"id":0,"name":"Human","frags":1,"deaths":0}]}, 0)
	board.render()
	check(board.summary.text.ends_with("1 player") and not "players" in board.summary.text, "a single human keeps singular wording")
	board.apply_state({"actors":[{"id":0,"name":"One"},{"id":1,"name":"Two"}]}, 0)
	board.render()
	check(board.summary.text.ends_with("2 players"), "all-human rosters keep the legacy player wording")
	# The Horde specialization must stay clear of the real shared-HUD panels at
	# both target resolutions; measured from the live control rects, not by eye.
	for size: Vector2i in [Vector2i(960, 640), Vector2i(1280, 800)]:
		var geometry: Dictionary = await horde_geometry(size)
		check(not geometry.panel.intersects(geometry.vitals), "horde board clear of the vitals at %d" % size.x)
		check(not geometry.panel.intersects(geometry.weapon), "horde board clear of the weapon panel at %d" % size.x)
		check(geometry.viewport.encloses(geometry.panel), "horde board inside the viewport at %d" % size.x)
	# Replay stored authoritative snapshots: separately identified from synthetic cases.
	var capture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/protocol/captured.json"))
	var replayed := 0
	for record: Dictionary in capture.frames:
		if record.direction == "server" and record.client == 1 and record.frame.type in ["snapshot", "results"]:
			board.apply_state(record.frame.state, 0, record.frame.type == "results")
			replayed += 1
	check(replayed > 0 and board.entries.size() == 4, "captured snapshot actor schema")
	print("PORT_SCOREBOARD_OK checks=", checks, " recorded_frames=", replayed, " synthetic_cases=true")
	session.queue_free()
	await process_frame
	quit(0)

func passive_controls(node: Node) -> bool:
	if node is Control and (node.mouse_filter != Control.MOUSE_FILTER_IGNORE or node.focus_mode != Control.FOCUS_NONE): return false
	for child: Node in node.get_children():
		if not passive_controls(child): return false
	return true

func horde_geometry(size: Vector2i) -> Dictionary:
	# Actual Horde board + actual shared GameHUD layout at the requested size.
	root.size = size
	var host := HordeHost.new()
	var hud := GameHUD.new()
	hud.name = "GameHUD"
	host.add_child(hud)
	var board := HordeScoreboard.new()
	host.add_child(board)
	root.add_child(host)
	await process_frame
	await process_frame
	hud.resize()
	var actors: Array = [{"id":0,"name":"Operator","frags":3,"deaths":0}]
	for i: int in range(12):
		actors.append({"id":i + 1,"name":"Husk","frags":0,"deaths":1,"isNpc":true,"npcType":"husk"})
	board.apply_state({"mapName":"Meridian Exchange","modeName":"Horde","time":83.9,
		"config":{"mode":"horde"},"actors":actors}, 0)
	board.tab_held = true
	board.refresh_visibility()
	board.resize()
	await process_frame
	await process_frame
	var result := {"panel":board.panel.get_global_rect(), "vitals":hud.vitals.get_global_rect(),
		"weapon":hud.weapon_panel.get_global_rect(), "viewport":Rect2(Vector2.ZERO, Vector2(size)),
		"page_size":board.page_size, "footer":board.footer.text}
	root.remove_child(host)
	host.free()
	await process_frame
	return result
