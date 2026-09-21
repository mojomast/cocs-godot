extends "res://world/viewer.gd"

const Client = preload("res://net/client.gd")
const Presentation = preload("res://world/presentation.gd")
var client := Client.new()
var presentation := Presentation.new()
var phase: int = 0
var elapsed: float = 0
var send_elapsed: float = 0
var yaw: float = 0
var pitch: float = 0
var received_pose: bool = false
var smoke: bool = false
var initial_position := Vector3.ZERO
var moved: bool = false
var fired: bool = false

func _ready() -> void:
	super._ready()
	if not catalog.entries.has("meridian-exchange"): return
	load_map("meridian-exchange")
	selector.disabled = true
	add_child(client)
	add_child(presentation)
	presentation.interpolate_remote = true
	camera.rotation_order = EULER_ORDER_YXZ
	var endpoint: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--endpoint="): endpoint = arg.trim_prefix("--endpoint=")
	smoke = "--session-smoke" in OS.get_cmdline_user_args()
	client.connection_error.connect(on_error)
	client.lobby.connect(on_lobby)
	client.started.connect(func(_f: Dictionary) -> void:
		presentation.clear_round()
		received_pose = false
		phase = 3)
	client.snapshot.connect(on_snapshot)
	client.results.connect(func(f: Dictionary) -> void:
		presentation.apply_state(f.state, client.actor_id)
		phase = 4
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		label.text = presentation.hud_text + "\nEnter: restart")
	if endpoint.is_empty() or client.connect_server(endpoint, catalog.entries, current_id) != OK:
		on_error("A local launcher endpoint is required")
		return
	label.text = "Connecting to isolated Node authority…"

func on_error(message: String) -> void:
	phase = -1
	label.text = message
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if smoke:
		push_error(message)
		get_tree().quit(1)

func on_lobby(frame: Dictionary) -> void:
	if phase == 1:
		phase = 2
		client.configure_match("deathmatch", 2)
	elif phase == 2 and frame.get("config") != null:
		phase = 20
		client.send_frame({"type":"start"})

func on_snapshot(frame: Dictionary) -> void:
	presentation.apply_state(frame.state, client.actor_id)
	var actor: Dictionary = presentation.local_actor
	if actor.is_empty(): return
	camera.position = presentation.eye_position()
	if not received_pose:
		yaw = float(actor.yaw)
		pitch = float(actor.pitch)
		initial_position = camera.position
		received_pose = true
	moved = moved or camera.position.distance_to(initial_position) > 0.5
	fired = fired or int(actor.get("shots", 0)) > 0
	label.text = "NODE-AUTHORITATIVE PROTOTYPE · diagnostic geometry, no prediction\n" + presentation.hud_text + "\nClick: capture/fire · Esc: release · WASD: move · Space: jump · R: reload\nShift: sprint · Ctrl: crouch · E: interact · F: mobility | ACK %d" % client.last_ack
	if smoke and moved and fired and client.last_ack > 10 and presentation.actors.size() == 3 and presentation.rendered_remote_poses > 10:
		print("PORT_SESSION_SMOKE_OK actors=3 camera=authoritative movement=true shots=true ack=", client.last_ack, " snapshots=", presentation.applied, " remote_poses=", presentation.rendered_remote_poses)
		client.disconnect_server()
		get_tree().quit(0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if event.keycode == KEY_ENTER and phase == 4:
			phase = 20
			client.send_frame({"type":"start"})
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and phase == 3:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.003
		pitch = clampf(pitch - event.relative.y * 0.003, -1.45, 1.45)

func _process(delta: float) -> void:
	elapsed += delta
	if smoke and elapsed > 20:
		on_error("Session smoke timeout")
		return
	if phase == 0 and client.peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		phase = 1
		client.create_room()
	if phase != 3 or not received_pose: return
	camera.rotation = Vector3(pitch, yaw, 0)
	send_elapsed += delta
	if send_elapsed < 1.0 / 60.0: return
	send_elapsed = fmod(send_elapsed, 1.0 / 60.0)
	var active: bool = smoke or (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and get_window().has_focus())
	var forward: float = 1.0 if smoke else float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	var right: float = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var controls: Dictionary = {"x": (-sin(yaw) * forward + cos(yaw) * right) if active else 0.0, "z": (-cos(yaw) * forward - sin(yaw) * right) if active else 0.0, "yaw":yaw, "pitch":pitch, "fire":active and (smoke or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))}
	for binding: Array in [["jump",KEY_SPACE],["reload",KEY_R],["sprint",KEY_SHIFT],["crouch",KEY_CTRL],["interact",KEY_E],["mobility",KEY_F]]:
		controls[binding[0]] = active and Input.is_physical_key_pressed(binding[1])
	client.send_input(controls)

func _exit_tree() -> void:
	client.disconnect_server()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
