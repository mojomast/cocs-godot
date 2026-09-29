extends SceneTree
## Engine-dispatched keyboard focus and modal/back sequence on the offline lobby
## surface. The network/session double is intentional; hosted source reconnect is
## covered by the separate protocol/product journey harnesses.
const Lobby = preload("res://ui/lobby_menu.gd")
const Client = preload("res://net/client.gd")
const Catalog = preload("res://world/catalog.gd")
var failed := false

class SessionDouble extends Node:
	var catalog := Catalog.new()
	var endpoint := "ws://127.0.0.1:9"
	var current_id := "meridian-exchange"
	var selected_mode := "deathmatch"
	var phase := -3
	var client := Client.new()
	var label := Label.new()
	var leaves := 0
	func _ready() -> void:
		catalog.open()
		add_child(client)
		client.set_process(false)
		add_child(label)
	func lobby_host_allowed() -> bool: return true
	func lobby_leave() -> void:
		leaves += 1
		phase = -3
	func lobby_connect(_a: String, _b: String, _c: String, _d: String, _e: String, _f: bool, _g: String = "", _h: String = "") -> void: pass
	func lobby_start() -> void: pass
	func request_restart() -> void: pass
	func lobby_retry_reconnect() -> void: pass
	func spectator_status() -> String: return "Read-only"
	func release_pointer() -> void: pass

func check(ok: bool, reason: String) -> void:
	if not ok:
		failed = true
		push_error("PLAYER_FLOW_CONTROLS " + reason)

func key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(760, 520)
	var settings := root.get_node("LocalSettings")
	settings.set_value("ui_scale", 150, false)
	var session := SessionDouble.new()
	root.add_child(session)
	var menu := Lobby.new()
	session.add_child(menu)
	await process_frame
	check(menu.actions.vertical, "760x520 / 150% pinned lobby actions reflow")
	check(menu.panel.get_global_rect().position.x >= 0 and menu.panel.get_global_rect().end.x <= root.get_visible_rect().size.x, "lobby panel fits at 150%")
	check(menu.actions.get_global_rect().end.y <= root.get_visible_rect().size.y, "pinned actions remain in viewport")
	menu.select_room({"roomId":"picked", "mapId":"meridian-exchange", "mode":"deathmatch"})
	check(menu.connect_button.has_focus() and menu.room.text == "picked" and menu.role.selected == 1, "browser pick focuses explicit Join")
	session.phase = 12
	menu.refresh()
	await process_frame
	check(menu.start_button.has_focus(), "host lobby focuses Start")
	session.phase = -5
	session.client.reconnect_ticket.remember("fixture-token", session.endpoint, session.current_id, "picked", 1, false, true)
	session.client.reconnect_ticket.dropped()
	menu.refresh()
	await process_frame
	check(menu.reconnect_button.has_focus() and not menu.reconnect_button.disabled, "drop focuses eligible retry")
	await key(KEY_ESCAPE)
	check(session.leaves == 1 and not settings.overlay_open(), "Escape on dropped seat explicitly leaves")
	await key(KEY_ESCAPE)
	check(settings.overlay_open() and session.leaves == 1, "Escape on disconnected lobby opens Settings/Leave")
	check(settings.rows.back.get_global_rect().end.y <= root.get_visible_rect().size.y, "Settings Back pinned in viewport")
	check(settings.rows.leave.get_global_rect().end.x <= root.get_visible_rect().size.x and settings.rows.leave.get_global_rect().end.y <= root.get_visible_rect().size.y, "Settings Leave pinned at 760x520 / 150%")
	await key(KEY_ESCAPE)
	check(not settings.overlay_open() and menu.connect_button.has_focus(), "Settings Escape returns focus to lobby")
	menu.chat_panel.open() # No active room; must not capture.
	check(not menu.capturing_input(), "chat cannot capture without a room")
	session.phase = 3
	menu.refresh()
	await key(KEY_ESCAPE)
	check(session.leaves == 1 and not settings.overlay_open(), "live Escape never leaves or opens a modal")
	root.size = Vector2i(960, 640)
	await process_frame
	check(not menu.actions.vertical and menu.panel.get_global_rect().end.x <= root.get_visible_rect().size.x, "960x640 / 150% action rail fits")
	session.free()
	var home: Control = load("res://ui/main_menu.tscn").instantiate()
	home.preferences_path = "user://player_flow_controls_menu.json"
	root.add_child(home)
	current_scene = home
	await process_frame
	root.size = Vector2i(760, 520)
	await process_frame
	home.settings_button.grab_focus()
	await process_frame
	await process_frame
	check(home.settings_button.has_focus() and home.content_scroll.get_global_rect().grow(1).encloses(home.settings_button.get_global_rect()), "Home keyboard scroll exposes Settings at compact scale")
	await key(KEY_F12)
	check(settings.overlay_open() and not settings.rows.leave.visible and not home.quitting, "Home F12 opens Settings without leaving")
	await key(KEY_ESCAPE)
	check(not settings.overlay_open() and home.settings_button.has_focus() and not home.quitting, "Home Settings Escape restores focus")
	current_scene = null
	home.free()
	settings.set_value("ui_scale", 100, false)
	print("PLAYER_FLOW_CONTROLS_OK actual_engine_keys=true synthetic_session=true" if not failed else "PLAYER_FLOW_CONTROLS_FAILED")
	quit(1 if failed else 0)
