extends SceneTree

const Session = preload("res://world/session.gd")
const Network = preload("res://net/client.gd")
const Selection = preload("res://world/weapon_selection.gd")

class WireProbe extends Network:
	var packets: Array[Dictionary] = []
	func send_frame(frame: Dictionary) -> Error:
		packets.append(frame.duplicate(true))
		return OK

class SessionProbe extends Session:
	func _ready() -> void:
		for node: Node in [camera,label,selector,client,presentation,pickups,combat,combat_label,sun,environment]: add_child(node)
		for control: Control in [label, selector, combat_label]: control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)
		client.set_process(false)
		presentation.set_process(false)

var checks: int = 0
var session: SessionProbe
var wire: WireProbe

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error("Weapon selection: " + message)
		quit(1)
		assert(ok, message)

func key(code: int, down: bool = true, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func wheel(button: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func pose(weapon: int = 0, health: int = 100) -> void:
	session.on_snapshot({"state":{"actors":[{"id":1,"x":0,"y":0,"z":0,"yaw":0,"pitch":0,"health":health,"dead":0,"weapon":weapon,"ammo":["∞",6,0,0,4,0,0,0,0,2]}],"pickups":[],"t":1}})

func capture() -> void:
	await process_frame
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(800, 500)
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(800, 500)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	check(session.weapon_controls_active(), "fresh capture is active (eligible=%s focused=%s mode=%s age=%s)" % [session.can_capture_pointer(), root.has_focus(), Input.mouse_mode, session.snapshot_watch.age])

func tick() -> Dictionary:
	session._process(1.0 / 60.0)
	return wire.packets.back().input

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Uses the real session input dispatch, eligibility and send cadence; only
	# the final transport is synthetic. Run on a private graphical display.
	session = SessionProbe.new()
	session.client.free()
	wire = WireProbe.new()
	session.client = wire
	root.add_child(session)
	await process_frame
	check(root.has_focus(), "graphical test window focused")
	session.phase = 3
	wire.actor_id = 1
	pose()
	await capture()
	var original := session.presentation.local_actor.duplicate(true)
	key(KEY_2)
	check(tick().get("weapon") == 1, "physical 2 queues rocket via production send_input")
	check(wire.packets.back().seq == 1 and wire.input_seq == 1, "real protocol sequence assigned")
	check(session.presentation.local_actor == original, "request does not mutate authority")
	check(tick().get("weapon") == 1, "pending request survives latest-packet coalescing")
	wire.last_ack = wire.input_seq
	check(not tick().has("weapon"), "applied ACK terminates even authority refusal")
	key(KEY_2, true, true)
	check(not tick().has("weapon"), "held key echo cannot rearm")
	key(KEY_2, false)
	key(KEY_2)
	key(KEY_2, false)
	check(not tick().has("weapon"), "release before cadence cancels queued key")
	key(KEY_3)
	check(not tick().has("weapon"), "zero-ammo unowned rail suppressed")
	key(KEY_3, false)
	key(KEY_0)
	check(tick().get("weapon") == 9, "physical 0 selects SMG index 9")
	key(KEY_0, false)
	wheel(MOUSE_BUTTON_WHEEL_DOWN)
	wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check(tick().get("weapon") == 4, "rapid wheel starts at pending and skips empty slots")
	pose(4)
	check(not tick().has("weapon"), "authority confirmation clears pending")
	wheel(MOUSE_BUTTON_WHEEL_UP)
	check(tick().get("weapon") == 1, "wheel up moves backward")
	pose(1)
	wheel(MOUSE_BUTTON_WHEEL_UP)
	check(tick().get("weapon") == 0, "infinite Pulse is available, never skipped")
	pose(0)
	wheel(MOUSE_BUTTON_WHEEL_UP)
	check(tick().get("weapon") == 9, "wheel wraps 0 to 9")
	session.release_pointer()
	check(not tick().has("weapon"), "pointer release cancels wheel request")
	wheel(MOUSE_BUTTON_WHEEL_DOWN)
	key(KEY_2)
	await capture()
	key(KEY_2, true, true)
	check(not tick().has("weapon"), "inactive input never resumes on capture")
	key(KEY_2, false)
	key(KEY_2)
	session._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not tick().has("weapon"), "focus loss cancels queued selection")
	session._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await capture()
	key(KEY_2, true, true)
	check(not tick().has("weapon"), "focus recovery requires fresh press")
	key(KEY_2, false)
	key(KEY_2)
	pose(0, 0)
	check(not tick().has("weapon"), "health-zero death cancels queued request")
	pose()
	await capture()
	check(not tick().has("weapon"), "respawn does not resume held request")
	key(KEY_2, false)
	key(KEY_2)
	session.snapshot_watch.advance(1.0)
	check(not tick().has("weapon"), "stale snapshot suppresses queued request")
	pose()
	session.release_pointer()
	await capture()
	key(KEY_2, false)
	key(KEY_2)
	session.on_started({})
	check(not tick().has("weapon"), "round restart discards selection")
	pose()
	await capture()
	check(not tick().has("weapon"), "fresh round capture cannot resume old held key")
	key(KEY_2, false)
	key(KEY_2)
	for i in range(20): tick()
	check(not wire.packets.back().input.has("weapon"), "unacknowledged request expires, no endless queue")
	key(KEY_2, false)
	pose()
	await capture()
	key(KEY_2)
	check(tick().get("weapon") == 1, "new request after timeout is possible")
	wheel(MOUSE_BUTTON_WHEEL_UP)
	check(tick().get("weapon") == 0, "reversing an in-flight switch explicitly restores current weapon")
	check(tick().get("weapon") == 0, "pre-command snapshot cannot falsely confirm in-flight reversal")
	wire.last_ack = wire.input_seq
	check(not tick().has("weapon"), "reversal finishes on its own applied ACK")
	key(KEY_2, false)
	key(KEY_2)
	session.presentation.local_actor.ammo[1] = 0 # Explicit synthetic depletion stimulus.
	check(not tick().has("weapon"), "new authoritative ammo depletion cancels request")
	key(KEY_2, false)
	pose()
	key(KEY_2)
	session.phase = 4
	var before: int = wire.packets.size()
	session._process(1.0 / 60.0)
	check(wire.packets.size() == before and session.weapon_selection.pending == -1, "results phase neither sends nor retains selection")
	session.phase = 3
	key(KEY_2, false)
	key(KEY_2)
	wire.actor_id = 2
	session.on_lobby({})
	check(not tick().has("weapon"), "actor ownership reassignment cancels old inventory request")
	key(KEY_2, false)
	check(not session.trace_input({"x":0}, OK).controls.has("weapon"), "trace omits absent command")
	check(session.trace_input({"weapon":1}, OK).controls.weapon == 1, "trace includes genuine command")
	for index in range(10):
		var code: int = KEY_0 if index == 9 else KEY_1 + index
		check(Selection.key_index(code) == index, "all ten fixed number mappings")
		check(not Selection.weapon_name(index).is_empty(), "all ten source names")
	check(not Selection.available({"ammo":[0]}, 0), "no invented default ownership")
	check(not Selection.available({"ammo":[null, "6"]}, 1), "malformed numeric strings are unavailable")
	check(not Selection.available({}, 0), "missing inventory fails closed")
	session.queue_free()
	await process_frame
	print("PORT_WEAPON_SELECTION_OK checks=", checks, " actual_session=true synthetic_transport=true")
	quit(0)
