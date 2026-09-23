extends SceneTree
# Lobby surface: operator/harness rows stay popup-free, guests may pick their own
# pair, the authority echo (not the local pick) drives the roster, and geometry
# fits 960x640 and 1280x800. Uses a synthetic session double for the offline UI
# path (clearly labelled, no network).
const LobbyMenu = preload("res://ui/lobby_menu.gd")
const Catalog = preload("res://world/catalog.gd")
const Network = preload("res://net/client.gd")
const Loadout = preload("res://ui/loadout.gd")
var checks := 0
var failures := 0

class SessionDouble extends Node:
	var catalog := Catalog.new()
	var endpoint := "ws://127.0.0.1:9"
	var current_id := "meridian-exchange"
	var selected_mode := "deathmatch"
	var phase := -3
	var client := Network.new()
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
		calls.append({"call":"lobby_connect", "url":url, "name":player_name, "room":room, "map":map_id, "mode":mode, "guest":guest, "character":character, "harness":harness})
	func lobby_start() -> void: calls.append({"call":"lobby_start"})
	func lobby_leave() -> void: calls.append({"call":"lobby_leave"})
	func request_restart() -> void: calls.append({"call":"request_restart"})
	func spectator_status() -> String: return "Read-only fixed view"

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("LOADOUT_LOBBY " + message)

func _initialize() -> void: call_deferred("run")

func settle() -> void: await create_timer(0.08).timeout

func key(code: int, shift := false) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.shift_pressed = shift
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()

func click(control: Control) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()

func popup_nodes(node: Node) -> int:
	var count := 0
	for child: Node in node.get_children(true):
		if child is OptionButton or child is PopupMenu or child is Window: count += 1
		count += popup_nodes(child)
	return count

func run() -> void:
	var session := SessionDouble.new()
	root.add_child(session)
	await settle()
	var menu: Node = LobbyMenu.new()
	session.add_child(menu)
	await settle()

	# Rows exist, sourced from the mirrored table, still popup-free.
	check(menu.operator.item_count == 9 and menu.harness.item_count == 7, "lobby lists the full source roster")
	check(str(menu.operator.get_selected_metadata()) == "chatgpt" and str(menu.harness.get_selected_metadata()) == "openclaw", "lobby opens on the source defaults")
	check(popup_nodes(menu) == 0, "no OptionButton/PopupMenu/Window in the lobby")

	# Host path: user keys change the row, the click passes the pair to the session.
	menu.operator.grab_focus()
	await key(KEY_RIGHT)
	check(menu.operator.get_selected_metadata() == "claude", "right arrow moves the operator row")
	check(menu.harness.disabled and str(menu.harness.get_selected_metadata()) == "claudecode", "claude locks the lobby harness row")
	await key(KEY_RIGHT)
	check(menu.operator.get_selected_metadata() == "grok", "rowing past claude unlocks the harness")
	check(not menu.harness.disabled and str(menu.harness.get_selected_metadata()) == "claudecode", "locked harness is kept while legal")
	menu.harness.grab_focus()
	await key(KEY_RIGHT)
	check(str(menu.harness.get_selected_metadata()) == "codex", "harness row cycles")
	menu.endpoint.text = "ws://127.0.0.1:9"
	menu.player_name.text = "Host"
	menu.role.select(0)
	await settle()
	session.calls.clear()
	await click(menu.connect_button)
	check(session.calls.size() == 1 and session.calls[0].call == "lobby_connect", "connect button calls lobby_connect once: " + str(session.calls))
	check(session.calls[0].character == "grok" and session.calls[0].harness == "codex", "host click passes the chosen pair: " + str(session.calls))
	check(session.calls[0].guest == false and session.calls[0].room == "", "host click keeps the existing guest/room contract")

	# Guest path: own pair is selectable; host mode stays disabled.
	menu.role.next.pressed.emit()
	await settle()
	check(menu.role.selected == 1, "guest role selected")
	session.phase = -3
	await settle()
	check(menu.modes.disabled and menu.room.editable, "guest keeps the existing mode/room contract")
	check(not menu.operator.disabled and not menu.harness.disabled, "guest may still choose an operator and harness")
	menu.select_operator("deepseek")
	menu.select_harness("hermes")
	menu.room.text = "room-code"
	await settle()
	session.calls.clear()
	await click(menu.connect_button)
	check(session.calls.size() == 1 and session.calls[0].guest == true and session.calls[0].room == "room-code", "guest click passes room and guest flag: " + str(session.calls))
	check(session.calls[0].character == "deepseek" and session.calls[0].harness == "hermes", "guest click passes the guest pair: " + str(session.calls))

	# The authority echo drives the roster, never the local pick.
	menu.select_operator("kimi")
	menu.select_harness("roo")
	menu.show_roster({"roomId":"room-code", "hostId":1, "config":{"mode":"deathmatch"}, "mapId":"meridian-exchange", "players":[
		{"peerId":1, "name":"Host", "connected":true, "spectate":false, "actorId":0, "character":"grok", "harness":"codex"},
		{"peerId":2, "name":"Guest", "connected":true, "spectate":false, "actorId":1, "character":"deepseek", "harness":"hermes"}]})
	check(menu.roster.text.contains("DeepSeek · Hermes"), "roster shows the authority guest pair: " + menu.roster.text)
	check(menu.roster.text.contains("Grok · Codex"), "roster shows the authority host pair")
	check(not menu.roster.text.contains("Kimi"), "roster never shows the unsent local pick")
	check(menu.roster.text.contains("Host") and menu.roster.text.contains("Guest"), "roster keeps the existing name lines")

	# A future authority identity renders without inventing a name.
	menu.show_roster({"roomId":"room-code", "hostId":1, "players":[{"peerId":1, "name":"Future", "connected":true, "spectate":false, "actorId":0, "character":"future-model", "harness":"future-harness"}]})
	check(menu.roster.text.contains("future-model · future-harness"), "unknown authority identity stays visible: " + menu.roster.text)
	menu.show_roster({"roomId":"room-code", "hostId":1, "players":[{"peerId":1, "name":"Old", "connected":true, "spectate":false, "actorId":0}]})
	check(menu.roster.text.contains(Loadout.player_label({})), "identity-free roster row falls back to the defaults label")

	# Connected phase: rows lock with the rest of the form; the authority echo is
	# the only remaining identity source.
	menu.select_operator("grok")
	menu.select_harness("codex")
	session.phase = 12
	session.host_allowed = true
	await settle()
	check(menu.operator.disabled and menu.harness.disabled, "connected rows are locked like map and mode")
	check(menu.start_button.visible and not menu.start_button.disabled, "host start still available")
	menu.select_operator("qwen")
	check(menu.operator.get_selected_metadata() == "grok", "locked rows refuse programmatic change after connect")
	session.calls.clear()
	menu.start_button.pressed.emit()
	check(session.calls.size() == 1 and session.calls[0].call == "lobby_start", "start still routes through the session")

	# Restart and spectator safety are unchanged.
	session.phase = 4
	await settle()
	check(menu.restart_button.visible, "host restart visible at results")
	session.host_allowed = false
	await settle()
	check(not menu.restart_button.visible, "restart hidden without host rights")
	session.client.spectating = true
	session.phase = 3
	await settle()
	check(not menu.panel.visible, "playing phase hides the lobby form")
	check(menu.roster.text != "", "spectator refresh keeps the roster text")
	session.client.spectating = false

	# Geometry: the panel fits both supported sizes and the loadout rows are
	# reachable inside it through the focus-following scroll container.
	session.phase = -3
	await settle()
	for size: Vector2i in [Vector2i(960, 640), Vector2i(1280, 800)]:
		root.size = size
		await settle()
		var viewport := Rect2(Vector2.ZERO, Vector2(size))
		check(viewport.encloses(menu.panel.get_global_rect()), "lobby panel inside " + str(size) + " rect=" + str(menu.panel.get_global_rect()))
		menu.harness.grab_focus()
		await settle()
		check(menu.panel.get_global_rect().encloses(menu.harness.get_global_rect()), "harness row visible inside the panel at " + str(size))
		menu.operator.grab_focus()
		await settle()
		check(menu.panel.get_global_rect().encloses(menu.operator.get_global_rect()), "operator row visible inside the panel at " + str(size))
		print("LOADOUT_LOBBY_GEOMETRY ", str(size), " panel=", str(menu.panel.size), " position=", str(menu.panel.position))

	print("PORT_LOADOUT_LOBBY_OK checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
