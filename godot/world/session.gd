extends "res://world/viewer.gd"

const Client = preload("res://net/client.gd")
const ControlMath = preload("res://world/control_math.gd")

func can_capture_pointer() -> bool:
	return application_focused and phase == 3 and received_pose and not snapshot_watch.stale() and presentation.lifecycle.can_control()

func update_look(relative: Vector2) -> void:
	if not can_capture_pointer() or not relative.is_finite(): return
	var angles := ControlMath.look(yaw - relative.x * 0.003, pitch - relative.y * 0.003)
	yaw = angles.x
	pitch = angles.y

const SnapshotWatch = preload("res://net/snapshot_watch.gd")
var snapshot_watch := SnapshotWatch.new()
const Presentation = preload("res://world/presentation.gd")
const Pickups = preload("res://world/pickups.gd")
const CombatFeedback = preload("res://world/combat_feedback.gd")
var combat := CombatFeedback.new()
var combat_label := Label.new()
var pickups := Pickups.new()
var client := Client.new()
var presentation := Presentation.new()
# Guest phases: 10 waits for join acknowledgement; 11 waits for host start.
var join_room_id: String = ""
var phase: int = 0
# Opt-in program-state evidence, never a claim of graphical acceptance.
var trace_enabled: bool = false
var trace_count: int = 0
const TRACE_LIMIT: int = 10000

func trace_snapshot(reseeded: bool) -> Dictionary:
	var actor: Dictionary = presentation.local_actor
	return {"schema":1, "event":"snapshot", "round":round_starts,
		"actor_id":client.actor_id, "ack":client.last_ack, "phase":phase,
		"pose_present":received_pose, "health":actor.get("health", null),
		"dead":actor.get("dead", null), "lifecycle":presentation.lifecycle.status,
		"camera_reseeded":reseeded, "yaw":yaw, "pitch":pitch,
		"camera_position":[camera.position.x,camera.position.y,camera.position.z],
		"pointer_captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"control_eligible":can_capture_pointer(), "focused":application_focused}

func trace_input(controls: Dictionary, result: Error) -> Dictionary:
	var selected: Dictionary = {}
	for key: String in ["x", "z", "yaw", "pitch", "fire", "jump", "reload", "sprint", "crouch", "interact", "mobility"]:
		selected[key] = controls.get(key, null)
	return {"schema":1, "event":"input_queue", "round":round_starts,
		"actor_id":client.actor_id, "ack":client.last_ack, "phase":phase,
		"controls":selected, "queue_result":int(result), "queued":result == OK}

func emit_snapshot_trace(reseeded: bool) -> void:
	if not trace_enabled or trace_count >= TRACE_LIMIT: return
	emit_native_trace(trace_snapshot(reseeded))

func emit_native_trace(record: Dictionary) -> void:
	if not trace_enabled or trace_count >= TRACE_LIMIT: return
	record["sequence"] = trace_count
	record["monotonic_usec"] = Time.get_ticks_usec()
	print("PORT_NATIVE_TRACE ", JSON.stringify(record))
	trace_count += 1
	if trace_count == TRACE_LIMIT:
		print('PORT_NATIVE_TRACE {"schema":1,"event":"limit","complete":false}')

func begin_room() -> void:
	var result: Error = client.create_room() if join_room_id.is_empty() else client.join_room(join_room_id)
	if result != OK:
		on_error("Room request could not be queued. Relaunch to reconnect.")
		return
	phase = 1 if join_room_id.is_empty() else 10
var elapsed: float = 0
var send_elapsed: float = 0
var yaw: float = 0
var pitch: float = 0
var received_pose: bool = false
var pose_actor_id: int = -1
var smoke: bool = false
var initial_position := Vector3.ZERO
var moved: bool = false
var fired: bool = false
var lifecycle_smoke: bool = false
var round_starts: int = 0
var round_results: int = 0
var phase_elapsed: float = 0.0
var watched_phase: int = -999
const HANDSHAKE_TIMEOUT: float = 15.0

func request_restart() -> void:
	if phase != 4 or not join_room_id.is_empty(): return
	if client.send_frame({"type":"start"}) == OK:
		phase = 20
		label.text = "Waiting for authoritative round start…"
	else:
		label.text = presentation.hud_text + "\nRestart could not be queued. Enter: retry"

func release_pointer() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

var application_focused: bool = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		application_focused = false
		release_pointer()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		application_focused = true

func advance_handshake(delta: float) -> bool:
	if not is_finite(delta) or delta < 0.0: return false
	if phase != watched_phase:
		watched_phase = phase
		phase_elapsed = 0.0
	if phase not in [0, 1, 2, 10, 11, 20]: return true
	phase_elapsed += delta
	if phase_elapsed < (120.0 if phase == 11 else HANDSHAKE_TIMEOUT): return true
	on_error("Connection/round-start timed out. Relaunch to reconnect.")
	return false

func _ready() -> void:
	super._ready()
	if not catalog.entries.has("meridian-exchange"): return
	load_map("meridian-exchange")
	world.get_node("StaticPickupMarkers").hide()
	add_child(pickups)
	selector.disabled = true
	add_child(client)
	add_child(presentation)
	add_child(combat)
	label.get_parent().add_child(combat_label)
	combat_label.position = Vector2(24, 170)
	combat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	client.events.connect(func(items: Array) -> void:
		if phase == 3: combat.apply_events(items, client.actor_id))
	presentation.interpolate_remote = true
	camera.rotation_order = EULER_ORDER_YXZ
	var endpoint: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--endpoint="): endpoint = arg.trim_prefix("--endpoint=")
		if arg.begins_with("--join-room="):
			join_room_id = arg.trim_prefix("--join-room=").strip_edges()
			if join_room_id.is_empty():
				on_error("Join room ID must not be empty")
				return
	trace_enabled = "--native-trace" in OS.get_cmdline_user_args()
	smoke = "--session-smoke" in OS.get_cmdline_user_args()
	lifecycle_smoke = "--lifecycle-smoke" in OS.get_cmdline_user_args()
	if not join_room_id.is_empty() and (smoke or lifecycle_smoke):
		on_error("Guest mode cannot be combined with automatic smoke controls")
		return
	client.connection_error.connect(on_error)
	client.lobby.connect(on_lobby)
	client.started.connect(on_started)
	client.snapshot.connect(on_snapshot)
	client.results.connect(func(f: Dictionary) -> void:
		round_results += 1
		presentation.apply_state(f.state, client.actor_id)
		pickups.apply_state(f.state)
		phase = 4
		combat.clear_round()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		label.text = presentation.hud_text + ("\nEnter: restart" if join_room_id.is_empty() else "\nWaiting for host to restart")
		if lifecycle_smoke:
			if not bool(f.state.get("over", false)) or presentation.lifecycle.can_control():
				on_error("Results did not disable controls")
				return
			request_restart())
	if endpoint.is_empty() or client.connect_server(endpoint, catalog.entries, current_id) != OK:
		on_error("A local launcher endpoint is required")
		return
	label.text = "Connecting to isolated Node authority…"

func on_started(_frame: Dictionary) -> void:
	# A host can start a new round without this client visiting results.
	# Never carry interactive capture across an authoritative round boundary.
	release_pointer()
	round_starts += 1
	snapshot_watch.reset()
	presentation.clear_round()
	pickups.clear_round()
	combat.clear_round()
	received_pose = false
	send_elapsed = 0.0
	moved = false
	fired = false
	phase = 3

func on_error(message: String) -> void:
	snapshot_watch.reset()
	phase = -1
	presentation.clear_round()
	pickups.clear_round()
	combat.clear_round()
	received_pose = false
	client.disconnect_server()
	label.text = message
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if smoke or lifecycle_smoke:
		push_error(message)
		get_tree().quit(1)

func on_lobby(frame: Dictionary) -> void:
	# Identity has already been updated by the validated network roster.
	# Never use the previous actor's pose while waiting for the new snapshot.
	if received_pose and pose_actor_id != client.actor_id:
		received_pose = false
		send_elapsed = 0.0
		release_pointer()
	if phase == 10:
		phase = 11
		label.text = "Joined room. Waiting for host start (120-second limit)…"
		return
	if phase == 1:
		var queued: Error
		if lifecycle_smoke:
			queued = client.send_frame({"type":"host", "mapId":current_id, "config":{"mode":"deathmatch","botCount":2,"timeLimit":60,"fragLimit":100}})
		else:
			queued = client.configure_match("deathmatch", 2)
		if queued != OK:
			on_error("Match configuration could not be queued. Relaunch to reconnect.")
			return
		phase = 2
	elif phase == 2 and frame.get("config") != null:
		if client.send_frame({"type":"start"}) != OK:
			on_error("Initial round start could not be queued. Relaunch to reconnect.")
			return
		phase = 20

func on_snapshot(frame: Dictionary) -> void:
	if phase != 3: return
	snapshot_watch.observe()
	pickups.apply_state(frame.state)
	presentation.apply_state(frame.state, client.actor_id)
	var actor: Dictionary = presentation.local_actor
	if actor.is_empty():
		# Reset once on loss, not on every absent-actor snapshot: otherwise
		# frequent snapshots starve the neutral-input send cadence.
		if received_pose: send_elapsed = 0.0
		received_pose = false
		release_pointer()
		emit_snapshot_trace(false)
		return
	camera.position = presentation.eye_position()
	var reseeded: bool = not received_pose or presentation.lifecycle.reseed_look
	if reseeded:
		var angles := ControlMath.look(float(actor.yaw), float(actor.pitch))
		yaw = angles.x
		pitch = angles.y
		initial_position = camera.position
		received_pose = true
	pose_actor_id = client.actor_id
	# A respawn must not silently reactivate controls held before death.
	# Keep the pose for authoritative camera tracking, but require recapture.
	if not presentation.lifecycle.can_control(): release_pointer()
	emit_snapshot_trace(reseeded)
	moved = moved or camera.position.distance_to(initial_position) > 0.5
	fired = fired or int(actor.get("shots", 0)) > 0
	if lifecycle_smoke and round_starts == 2 and round_results == 1 and client.last_ack > 10:
		if presentation.lifecycle.status != "alive" or presentation.actors.size() != 3:
			on_error("Restart state invalid")
			return
		print("PORT_LIFECYCLE_LIVE_OK starts=", round_starts, " results=", round_results, " restarted_actors=", presentation.actors.size(), " restarted_ack=", client.last_ack, " map=", current_id, " normal_rate=true")
		client.disconnect_server()
		get_tree().quit(0)
	label.text = "NODE-AUTHORITATIVE PROTOTYPE · diagnostic geometry, no prediction\n" + presentation.hud_text + "\nClick: capture/fire · Esc: release · WASD: move · Space: jump · R: reload\nShift: sprint · Ctrl: crouch · E: interact · F: mobility | ACK %d" % client.last_ack
	if smoke and combat.shots > 0 and moved and fired and client.last_ack > 10 and presentation.actors.size() == 3 and presentation.rendered_remote_poses > 10 and not pickups.markers.is_empty() and not world.get_node("StaticPickupMarkers").visible:
		print("PORT_SESSION_SMOKE_OK actors=3 camera=authoritative movement=true shots=true ack=", client.last_ack, " snapshots=", presentation.applied, " remote_poses=", presentation.rendered_remote_poses, " pickups=", pickups.markers.size(), " static_pickups_hidden=true combat_shots=", combat.shots)
		client.disconnect_server()
		get_tree().quit(0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE: release_pointer()
		if event.keycode == KEY_ENTER: request_restart()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and can_capture_pointer():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		update_look(event.relative)

func _process(delta: float) -> void:
	if not advance_handshake(delta): return
	combat_label.text = combat.text()
	if phase == 3:
		var was_stale := snapshot_watch.stale()
		snapshot_watch.advance(delta)
		# Do not silently resume held controls when snapshots recover.
		if not was_stale and snapshot_watch.stale(): release_pointer()
		if snapshot_watch.stale(): combat_label.text = snapshot_watch.message()
	elapsed += delta
	if smoke and elapsed > 20:
		on_error("Session smoke timeout")
		return
	if lifecycle_smoke and elapsed > 90:
		on_error("Lifecycle smoke timeout")
		return
	if phase == 0 and client.peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		begin_room()
	if phase != 3: return
	camera.rotation = Vector3(pitch, yaw, 0)
	send_elapsed += delta
	if send_elapsed < 1.0 / 60.0: return
	send_elapsed = fmod(send_elapsed, 1.0 / 60.0)
	var active: bool = received_pose and not snapshot_watch.stale() and presentation.lifecycle.can_control() and (smoke or (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and get_window().has_focus()))
	var forward: float = 1.0 if smoke else float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	var right: float = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var direction := ControlMath.movement(yaw, forward, right) if active else Vector2.ZERO
	var controls: Dictionary = {"x":direction.x, "z":direction.y, "yaw":yaw, "pitch":pitch, "fire":active and (smoke or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))}
	for binding: Array in [["jump",KEY_SPACE],["reload",KEY_R],["sprint",KEY_SHIFT],["crouch",KEY_CTRL],["interact",KEY_E],["mobility",KEY_F]]:
		controls[binding[0]] = active and Input.is_physical_key_pressed(binding[1])
	var queue_result: Error = client.send_input(controls)
	if trace_enabled and trace_count < TRACE_LIMIT:
		emit_native_trace(trace_input(controls, queue_result))
	if queue_result != OK:
		on_error("Input could not be queued. Relaunch to reconnect.")

func _exit_tree() -> void:
	client.disconnect_server()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
