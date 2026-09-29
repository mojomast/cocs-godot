extends SceneTree
## Match-setup (lobby) saved-loadout summary and Open Arsenal entry.
##
## Uses the same clearly-labelled synthetic session double as
## tests/loadouts/lobby_menu.gd: no network, no authority. The Career service is
## the real autoload and is seated on the double's client, so the summary is
## owner-gated and only a confirmed profile is shown.
const LobbyMenu = preload("res://ui/lobby_menu.gd")
const Catalog = preload("res://world/catalog.gd")
const Network = preload("res://net/client.gd")
var failed := false

class WireClient extends Network:
	func career_wire_open() -> bool: return true

class SessionDouble extends Node:
	var catalog := Catalog.new()
	var endpoint := "ws://127.0.0.1:9"
	var current_id := "meridian-exchange"
	var selected_mode := "deathmatch"
	var phase := -3
	var client := WireClient.new()
	var label := Label.new()
	func _ready() -> void:
		if not catalog.open(): push_error("synthetic catalog unavailable")
		add_child(client)
		client.set_process(false)
		add_child(label)
	func lobby_host_allowed() -> bool: return true
	func lobby_connect(_url: String, _name: String, _room: String, _map: String, _mode: String, _guest: bool, _character: String = "", _harness: String = "") -> void: pass
	func lobby_start() -> void: pass
	func lobby_leave() -> void: pass
	func request_restart() -> void: pass
	func spectator_status() -> String: return "Read-only fixed view"

func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("career loadout lobby: " + label)

func settle() -> void:
	await create_timer(0.08).timeout

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var service := root.get_node("Career")
	var session := SessionDouble.new()
	root.add_child(session)
	await settle()
	var menu: Node = LobbyMenu.new()
	session.add_child(menu)
	await settle()
	# Pre-connect: explicit prompt, no usable Arsenal entry, pinned actions intact.
	check(menu.loadout_summary.text == "Connect to load source loadout.", "preconnect summary prompts to connect the source")
	check(menu.arsenal_button.visible and menu.arsenal_button.disabled, "Open Arsenal visible but disabled before a seated profile")
	check(menu.connect_button.visible, "the Join/Create action is still pinned pre-connect")
	# Seat the owner on the double's client through the real service.
	session.client.room_id = "room-a"
	session.client.career_seated = true
	service.receive(session.client, {"type":"welcome", "profile":{"id":"player-one","level":4,"unlocks":{"attachment-red-dot":true},"gear":{"primary":"scope"},"attachments":{},"finish":null}})
	check(service.owned(session.client), "the session client owns the seated profile")
	session.phase = 12
	await settle()
	check(menu.loadout_summary.text.contains("next match") and menu.loadout_summary.text.contains("Precision Scope"), "connected lobby shows the confirmed saved loadout")
	check(not menu.arsenal_button.disabled and menu.arsenal_button.visible, "Open Arsenal is usable with a seated profile")
	check(menu.start_button.visible, "host Start stays visible beside Open Arsenal")
	# The modal button opens the real Career panel, then returns focus to the lobby.
	menu.arsenal_button.pressed.emit()
	await settle()
	check(service.active(), "Open Arsenal opens the modal Career panel")
	service.close_panel()
	await settle()
	check(not service.active(), "closing the Arsenal returns to the lobby")
	# No horizontal overflow and pinned actions stay inside the panel.
	var panel_rect: Rect2 = menu.panel.get_global_rect()
	var summary_rect: Rect2 = menu.loadout_summary.get_global_rect()
	check(summary_rect.position.x >= panel_rect.position.x - 1 and summary_rect.end.x <= panel_rect.end.x + 1, "summary wraps inside the panel width")
	check(menu.start_button.get_global_rect().end.y <= panel_rect.end.y + 1, "pinned Start stays inside the panel")
	# A different seated client cannot read this profile.
	var outsider := WireClient.new()
	root.add_child(outsider)
	outsider.room_id = "room-b"
	outsider.career_seated = true
	check(not service.owned(outsider), "a different client is not the owner")
	outsider.queue_free()
	# Disconnect restores the explicit prompt.
	service.clear_connection(session.client)
	session.phase = -3
	await settle()
	check(menu.loadout_summary.text == "Connect to load source loadout.", "disconnect restores the connect prompt")
	check(menu.arsenal_button.disabled, "Open Arsenal is disabled again after disconnect")
	print("CAREER_NEWLOADOUT_LOBBY_OK")
	quit(1 if failed else 0)
