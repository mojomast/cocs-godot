extends SceneTree

# Real scene lifecycle with stored authority frames and explicitly synthetic transitions.
const SessionScene = preload("res://world/session.tscn")
const WeaponNames = preload("res://ui/weapon_names.gd")

class InputProbe extends Node:
	var seen := false
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.physical_keycode == KEY_R: seen = true

func _initialize() -> void:
	call_deferred("run")

func check_passive(node: Node) -> void:
	if node is Control:
		assert(node.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HUD controls must pass pointer input")
		assert(node.focus_mode == Control.FOCUS_NONE, "HUD cannot take keyboard focus")
	for child: Node in node.get_children(): check_passive(child)

func run() -> void:
	var session := SessionScene.instantiate()
	root.add_child(session)
	await process_frame
	session.set_process(false) # Synthetic delivery, no outgoing inputs or handshake clock.
	var hud: CanvasLayer = session.get_node("GameHUD")
	var board: CanvasLayer = session.get_node("Scoreboard")
	assert(hud.client == session.client and hud.layer <= 3 and board.layer == 8)
	check_passive(hud)
	if "--setup" in OS.get_cmdline_user_args():
		assert(session.phase == -2 and session.setup_menu.visible and not hud.root.visible)
		hud.refresh_status()
		assert(session.setup_menu.visible and not hud.root.visible, "setup remains interactive")
		session.start_selected_match("meridian-exchange", "deathmatch")
		hud.refresh_status()
	if "--debug-hud" in OS.get_cmdline_user_args():
		assert(not hud.root.visible and session.label.visible and session.selector.visible)
		print("PORT_GAME_HUD_DEBUG_OK original_display=true")
		session.queue_free()
		await process_frame
		quit(0)
		return
	assert(session.phase == -1 and hud.root.visible and hud.status_panel.visible)
	assert(hud.status_detail.text == session.label.text and not session.label.visible, "visible error replacement")
	var capture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/protocol/captured.json"))
	var snapshot: Dictionary = {}
	var results: Dictionary = {}
	for record: Dictionary in capture.frames:
		if record.direction != "server" or record.client != 1: continue
		if record.frame.type == "snapshot" and snapshot.is_empty(): snapshot = record.frame.duplicate(true)
		if record.frame.type == "results": results = record.frame
	session.client.actor_id = 0
	session.client.started.emit({"mapId":"meridian-exchange"})
	assert(hud.status_title.text == "JOINING ROUND" and not hud.actor_present)
	session.client.snapshot.emit(snapshot)
	assert(hud.vitals.is_visible_in_tree() and hud.weapon_panel.is_visible_in_tree())
	assert(hud.health_label.text == "HEALTH  100" and hud.health_bar.value == 100)
	assert(hud.armor_label.text == "ARMOR  5" and hud.armor_bar.value == 5)
	assert(hud.weapon_label.text == "Pulse Rifle" and hud.ammo_label.text == "AMMO  ∞")
	assert(not session.label.visible and not session.selector.visible and not session.combat_label.visible)
	assert("HP 100" in session.label.text, "legacy text API retained, not a visible HUD assertion")
	var actor: Dictionary = snapshot.state.actors[0]
	actor.health = 23
	actor.armor = 0
	actor.weapon = 1
	actor.ammo[1] = 4
	actor.reloading = true
	actor.reloadTimer = 1.25
	actor.frags = 3
	actor.deaths = 1
	session.client.snapshot.emit(snapshot)
	assert(hud.health_label.text == "HEALTH  23" and hud.health_bar.value == 23)
	assert(hud.armor_label.text == "ARMOR  0" and hud.armor_bar.value == 0)
	assert(hud.weapon_label.text == "Rocket Launcher" and hud.ammo_label.text == "AMMO  4")
	assert(hud.weapon_detail.text.begins_with("RELOADING"))
	assert(hud.score_label.text == "FRAGS  3     DEATHS  1")
	actor.dead = 2.3
	actor.health = 0
	session.client.snapshot.emit(snapshot)
	assert(hud.status_title.text == "ELIMINATED" and "2.3s" in hud.status_detail.text)
	hud._process(0.3)
	assert("2.3s" in hud.status_detail.text, "respawn timer cannot predict authority")
	actor.dead = 0
	session.client.snapshot.emit(snapshot)
	assert(hud.status_title.text == "ELIMINATED", "rounded zero timer is not a respawn")
	actor.health = 100
	session.client.snapshot.emit(snapshot)
	assert(hud.status_title.text in ["CLICK TO PLAY", "CONTROLS PAUSED"])
	session.application_focused = false
	hud.refresh_status()
	assert(hud.status_title.text == "CONTROLS PAUSED")
	session.snapshot_watch.advance(1.1)
	hud.refresh_status()
	assert(hud.status_title.text == "CONNECTION STALLED" and "controls neutral" in hud.status_detail.text)
	session.client.snapshot.emit({"state":{"actors":[], "mapId":"meridian-exchange"}})
	assert(hud.status_title.text == "WAITING FOR PLAYER" and not hud.vitals.visible)
	session.client.results.emit(results)
	assert(hud.status_title.text == "ROUND COMPLETE" and "Enter:" in hud.status_detail.text)
	assert(board.panel.visible and not hud.vitals.visible, "results scoreboard owns the foreground")
	session.request_restart() # Disconnected client: actual local retry message, no signal.
	hud.refresh_status()
	assert("Enter: retry" in hud.status_detail.text)
	session.join_room_id = "synthetic-guest"
	session.label.text = "Waiting for host to restart"
	hud.refresh_status()
	assert(hud.status_detail.text == "Waiting for host to restart")
	session.phase = 20
	hud.refresh_status()
	assert(hud.status_title.text == "STARTING ROUND")
	session.client.started.emit({"mapId":"meridian-exchange"})
	assert(not hud.actor_present and hud.health_label.text == "HEALTH  —")
	session.on_error("Synthetic local connection error: relaunch to reconnect.")
	hud.refresh_status()
	assert(hud.status_panel.is_visible_in_tree() and hud.status_detail.text == session.label.text)
	assert(not session.label.visible and not board.panel.visible)
	var probe := InputProbe.new()
	root.add_child(probe)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_R
	event.pressed = true
	var mouse_mode := Input.mouse_mode
	Input.parse_input_event(event)
	await process_frame
	assert(probe.seen and Input.mouse_mode == mouse_mode, "overlay leaves input unhandled and capture untouched")
	assert(WeaponNames.ammo_text(null) == "—" and WeaponNames.ammo_text(-1) == "—")
	assert(WeaponNames.ammo_text("Infinity") == "—" and WeaponNames.display_name(99) == "Weapon unknown")
	print("PORT_GAME_HUD_SESSION_OK actual_scene=true captured_state=true synthetic_transitions=true passive_input=true")
	probe.queue_free()
	session.queue_free()
	await process_frame
	quit(0)
