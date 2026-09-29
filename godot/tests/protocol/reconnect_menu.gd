extends SceneTree
const LobbyMenu = preload("res://ui/lobby_menu.gd")
const Client = preload("res://net/client.gd")

class SessionDouble extends Node:
	var catalog := {"entries":{"meridian-exchange":{"name":"Meridian Exchange", "modes":["deathmatch"]}}}
	var endpoint := "ws://127.0.0.1:9"
	var current_id := "meridian-exchange"
	var selected_mode := "deathmatch"
	var phase := -5
	var label := Label.new()
	var client := Client.new()
	var retried := 0
	var left := 0
	func _ready() -> void:
		add_child(label)
		add_child(client)
		client.set_process(false)
	func lobby_host_allowed() -> bool: return false
	func lobby_retry_reconnect() -> void: retried += 1
	func lobby_leave() -> void: left += 1
	func lobby_connect(_a: String, _b: String, _c: String, _d: String, _e: String, _f: bool, _g: String = "", _h: String = "") -> void: pass
	func lobby_start() -> void: pass
	func request_restart() -> void: pass
	func spectator_status() -> String: return "Read-only"
	func release_pointer() -> void: pass

func _initialize() -> void: call_deferred("run")

func verify(ok: bool, reason: String) -> void:
	if not ok:
		push_error("Reconnect menu: " + reason)
		quit(1)
		assert(ok)

func run() -> void:
	var session := SessionDouble.new()
	root.add_child(session)
	var menu := LobbyMenu.new()
	session.add_child(menu)
	session.label.text = "Connection lost. Retry or Leave."
	session.client.reconnect_ticket.remember("private-fixture", session.endpoint, session.current_id, "room-fixture", 1, false, true)
	session.client.reconnect_ticket.dropped()
	menu.refresh()
	verify(menu.panel.visible and menu.reconnect_button.visible and not menu.reconnect_button.disabled, "retry visible and available")
	verify(menu.back_button.visible and menu.back_button.text == "Leave", "explicit Leave visible")
	verify(not menu.status.text.contains("private-fixture") and not menu.roster.text.contains("private-fixture"), "token absent from UI")
	menu.reconnect_button.pressed.emit()
	verify(session.retried == 1, "retry invokes explicit action")
	session.phase = -6
	menu.refresh()
	verify(not menu.reconnect_button.visible and menu.back_button.visible, "pending attempt retains Leave")
	menu.back_button.pressed.emit()
	verify(session.left == 1, "Leave invokes explicit clear path")
	session.phase = -5
	session.client.reconnect_ticket.expires_at = Time.get_ticks_msec() - 1
	menu.refresh()
	verify(menu.reconnect_button.disabled, "expired ticket cannot retry")
	session.free()
	print("PORT_RECONNECT_MENU_OK native_controls=true")
	quit(0)
