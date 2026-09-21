extends SceneTree
# Signal association adapted from native_trace_correlation/observe.gd at fbc8345.
# Instantiates the shipped scene; no overrides or session/control-state writes.
# Stimulus uses the real physical-key/mouse Input.parse_input_event path.
var session: Node
var elapsed := 0.0
var sample_elapsed := 0.0
var started_at := -1.0
var stimulated := false
var dead_seen := false
var respawn_at := -1.0
var fresh_click := false
var motion_sent := false
var ended := false

func _initialize() -> void:
	call_deferred("begin")

func begin() -> void:
	session = load("res://world/session.tscn").instantiate()
	root.add_child(session)
	if not session.catalog.entries.has("meridian-exchange") or session.current_id != "meridian-exchange":
		push_error("Harness prerequisite: semantic map not loaded")
		quit(3)
	session.client.started.connect(func(frame: Dictionary):
		print("CORRELATION_OBSERVE " + JSON.stringify({"event":"start", "mapId":frame.mapId,"roundRevision":frame.get("roundRevision"),"actor":session.client.actor_id}))
		started_at = elapsed)
	session.client.snapshot.connect(func(frame: Dictionary):
		var actor: Dictionary = {}
		for item: Dictionary in frame.state.actors:
			if int(item.id) == session.client.actor_id: actor = item
		# First print stays directly adjacent to the runtime trace in this synchronous signal.
		print("CORRELATION_OBSERVE " + JSON.stringify({"event":"snapshot","seq":frame.seq,"actor":session.client.actor_id,"ack":session.client.last_ack,"health":actor.get("health"),"dead":actor.get("dead"),"pose":[actor.get("x"),actor.get("y"),actor.get("z")],"eyeHeight":actor.get("eyeHeight",1.45),"yaw":actor.get("yaw"),"pitch":actor.get("pitch"),"time":frame.state.time,"over":frame.state.over,"camera_rotation":[session.camera.rotation.x,session.camera.rotation.y,session.camera.rotation.z]}))
		if float(actor.get("dead",0)) > 0: dead_seen = true
		elif dead_seen and float(actor.get("health",0)) > 0 and respawn_at < 0: respawn_at = elapsed)

func key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_CTRL
	event.physical_keycode = KEY_CTRL
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(640,400)
	event.global_position = event.position
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func mark(kind: String) -> void:
	print("HARNESS_STIMULUS " + JSON.stringify({"kind":kind,"seconds":elapsed,"trace_next":session.trace_count,"physical_ctrl":Input.is_physical_key_pressed(KEY_CTRL),"mouse_left":Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),"window_focus":session.get_window().has_focus(),"pointer_captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED}))

func _process(delta: float) -> bool:
	elapsed += delta
	sample_elapsed += delta
	if not is_instance_valid(session): return false
	if not stimulated and started_at >= 0 and session.received_pose and elapsed-started_at > 0.5:
		key(true)
		mouse(true)
		stimulated = true
		mark("held_ctrl_and_mouse_down")
	if stimulated and not motion_sent and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(190,-350)
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
		motion_sent = true
		mark("look_away_motion")
	if respawn_at >= 0 and elapsed-respawn_at > 2.0 and not fresh_click:
		# Mouse stays held across death and the 2s respawn gate. Only now release/repress.
		mouse(false)
		mouse(true)
		fresh_click = true
		mark("fresh_click_after_respawn")
	if sample_elapsed >= 0.5:
		sample_elapsed = 0.0
		print("HARNESS_SAMPLE " + JSON.stringify({"seconds":elapsed,"phase":session.phase,"pose":session.received_pose,"actor":session.client.actor_id,"starts":session.round_starts,"trace_next":session.trace_count,"physical_ctrl":Input.is_physical_key_pressed(KEY_CTRL),"mouse_left":Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),"window_focus":session.get_window().has_focus(),"pointer_captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"camera_position":[session.camera.position.x,session.camera.position.y,session.camera.position.z],"camera_rotation":[session.camera.rotation.x,session.camera.rotation.y,session.camera.rotation.z],"yaw":session.yaw,"pitch":session.pitch}))
	if not ended and ((respawn_at >= 0 and elapsed-respawn_at > 3.5) or (started_at >= 0 and elapsed-started_at > 105.0) or session.phase == -1 or session.phase == 4):
		ended = true
		key(false)
		mouse(false)
		mark("release_before_harness_stop")
		print("HARNESS_BOUNDARY " + JSON.stringify({"reason":"post_respawn_window" if respawn_at >= 0 else "bounded_no_respawn","seconds":elapsed,"native_completion_proven":false}))
		quit(0)
	return false
