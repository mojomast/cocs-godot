extends SceneTree
## Debug-panel contract test. The socket-level authority behaviour is proven by
## the node harness (port/native-arenas/tests/debug.test.mjs +
## port/native-horde/debug.test.mjs); this file proves the CLIENT contract:
## off-by-default gating, the authority echo, keyboard control, the round
## boundary, the room boundary, and that the weapon selector really offers all
## ten slots for the unlocked snapshot shape the authority emits.
const SessionProbe = preload("res://tests/debug/session_probe.gd")
const WeaponSelection = preload("res://world/weapon_selection.gd")

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("debug panel: " + message)

func echo() -> Dictionary:
	return {"enabled":true, "version":1,
		"live":{"godMode":false, "playerIncomingScale":1, "unlockAllWeapons":false, "damage":1, "difficulty":"easy"},
		"queued":{}, "constructed":{}, "restart":{"botCount":[1, 7], "startingWeapon":[0, 9]},
		"restores":0, "applied":1, "rejected":0, "lastReject":null}

func key_event(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event

func actor(ammo: Array, weapon: int = 0) -> Dictionary:
	return {"id":0, "health":100, "maxHealth":100, "dead":0, "weapon":weapon, "ammo":ammo,
		"frags":0, "deaths":0, "shots":0, "x":0, "y":0, "z":0, "yaw":0, "pitch":0, "eyeHeight":1.45}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check("--debug-panel" in OS.get_cmdline_user_args(), "test process runs with the explicit debug flag")
	var session := SessionProbe.new()
	root.add_child(session)
	await process_frame
	check(session.debug_requested(), "explicit flag enables the debug facility")
	check(session.debug_available(), "a local single-human route is eligible")
	check(not is_instance_valid(session.debug_panel), "no panel exists before the authority echo")
	check(session.debug_send({"type":"debug", "v":1, "godMode":true}) == ERR_UNAUTHORIZED,
		"nothing is sent before the authority echo")

	# The authority echo creates the panel and unlocks the channel.
	session.on_lobby({"players":[], "config":null, "debug":echo()})
	var panel: CanvasLayer = session.debug_panel
	check(is_instance_valid(panel), "authority echo creates the panel")
	check(panel.authority_ready and panel.badge.visible, "badge is visible once bound")
	check("DEBUG" in panel.badge.text, "badge reads DEBUG")
	check("LIVE" in panel.god_toggle.text and "human seat" in panel.god_toggle.text,
		"god mode is labelled LIVE and human-seat only")
	check("RESTART" in panel.bot_spin.get_parent().get_child(0).text, "bot count is labelled RESTART")
	check("debug-only" in panel.incoming_option.get_parent().get_child(0).text + panel.incoming_option.get_parent().get_parent().get_child(2).text,
		"the incoming scale is labelled debug-only")
	check(panel.panel.visible == false, "panel body starts closed; only the badge shows")

	# Keyboard control through the real input pipeline.
	Input.parse_input_event(key_event(KEY_F3))
	Input.flush_buffered_events()
	await process_frame
	check(panel.panel.visible, "F3 opens the panel")
	Input.parse_input_event(key_event(KEY_F4))
	Input.flush_buffered_events()
	await process_frame
	check(panel.god_toggle.button_pressed, "F4 toggles god mode")
	check(session.client.writes.back().type == "debug" and session.client.writes.back().godMode == true,
		"the god-mode frame went through the session's guarded send")
	Input.parse_input_event(key_event(KEY_F5))
	Input.flush_buffered_events()
	await process_frame
	check(session.client.writes.back().unlockAllWeapons == true, "F5 requests unlock-all")
	Input.parse_input_event(key_event(KEY_F6))
	Input.flush_buffered_events()
	await process_frame
	check(session.client.writes.back().difficulty == "normal", "F6 cycles the live difficulty")
	Input.parse_input_event(key_event(KEY_F3))
	Input.flush_buffered_events()
	await process_frame
	check(not panel.panel.visible, "F3 closes the panel")

	# Panel controls send the documented fields.
	session.client.writes.clear()
	panel.damage_option.item_selected.emit(3)
	check(session.client.writes.back().damage == 2.0, "damage option sends the source multiplier")
	panel.bot_spin.value = 5
	check(session.client.writes.back().botCount == 5, "bot spin queues a restart knob")
	panel.restart_button.pressed.emit()
	check(session.phase != 20, "restart is refused outside the results screen")
	check("results" in panel.status.text, "the panel says plainly when a restart is unavailable")
	panel.god_toggle.button_pressed = false
	check(session.client.writes.back().godMode == false, "god mode is reversible from the panel")

	# A route without construction-time knobs (solo Horde) disables them plainly.
	var horde_echo := echo()
	horde_echo.restart = {}
	panel.acknowledge(horde_echo)
	check(panel.bot_spin.editable == false and panel.restart_button.disabled,
		"a route with no restart knobs disables the bot row")
	panel.acknowledge(echo())
	check(panel.bot_spin.editable and not panel.restart_button.disabled,
		"the native route re-enables the bot row with its advertised bounds")

	# Snapshot echo drives the displayed authority values.
	session.phase = 3
	session.on_snapshot({"state":{"config":{"damage":2, "difficulty":"hard", "respawn":4, "mutators":["turbo", "oneShot"]},
		"actors":[actor(["∞",0,0,0,0,0,0,0,0,0])], "pickups":[], "t":1}})
	check(panel.applied.get("damage") == 2 and panel.applied.get("difficulty") == "hard",
		"the panel reads the applied config from the public snapshot")
	check("turbo" in str(panel.applied.get("_mutators")), "mutator echo is displayed")

	# Round boundary: the authority clears god mode, and the panel mirrors it.
	panel.god_toggle.set_pressed_no_signal(true)
	session.on_started({"mapId":"prism-foundry"})
	check(not panel.god_toggle.button_pressed, "the round boundary clears the god toggle")

	# Unlock-all: the selector offers exactly the ten slots the authority grants.
	var default_actor := actor(["∞",0,0,0,0,0,0,0,0,0])
	var unlocked_actor := actor(["∞","∞","∞","∞","∞","∞","∞","∞","∞","∞"])
	var default_available := 0
	var unlocked_available := 0
	for index in range(10):
		if WeaponSelection.available(default_actor, index): default_available += 1
		if WeaponSelection.available(unlocked_actor, index): unlocked_available += 1
	check(default_available == 1, "the default belt only offers the starting weapon")
	check(unlocked_available == 10, "the unlocked belt offers all ten weapons")
	for index: int in range(10):
		unlocked_actor.weapon = -1
		unlocked_actor.ammo = ["∞","∞","∞","∞","∞","∞","∞","∞","∞","∞"]
		var request := WeaponSelection.new()
		request.request(index, 0, unlocked_actor)
		check(request.pending == index, "weapon %d is selectable with the unlocked belt" % index)

	# Room boundary: the panel never exists for the multi-human lobby/guest path.
	var lobby_session := SessionProbe.new()
	lobby_session.lobby_enabled = true
	root.add_child(lobby_session)
	await process_frame
	lobby_session.on_lobby({"players":[], "config":null, "debug":echo()})
	check(not is_instance_valid(lobby_session.debug_panel), "no panel in the multi-human lobby")
	check(not lobby_session.debug_available(), "the lobby route is never debug-eligible")
	check(lobby_session.debug_send({"type":"debug", "v":1}) == ERR_UNAUTHORIZED, "the lobby route cannot send")
	var guest_session := SessionProbe.new()
	guest_session.join_room_id = "ROOM-1"
	root.add_child(guest_session)
	await process_frame
	guest_session.on_lobby({"players":[], "config":null, "debug":echo()})
	check(not is_instance_valid(guest_session.debug_panel), "no panel in the guest route")
	check(not guest_session.debug_available(), "a guest join is never debug-eligible")

	session.queue_free()
	lobby_session.queue_free()
	guest_session.queue_free()
	await process_frame
	print("DEBUG_PANEL_TESTS checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
