extends SceneTree
## Scripted native keyboard/mouse -> ordinary client -> real source authority.
## Oracle is dynamically loaded from test-only resources (never production).
var session: Node
var operator := ""
var out := ""
var observed: Array = []
var poses: Array = []
var models: Array = []
var max_cables := 0
var deadline := 0.0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--operator="): operator = arg.trim_prefix("--operator=")
		if arg.begins_with("--evidence="): out = arg.trim_prefix("--evidence=")
	call_deferred("run")

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func aim(yaw: float, pitch: float) -> void:
	var motion := InputEventMouseMotion.new()
	var sensitivity := preload("res://ui/settings_access.gd").sensitivity()
	motion.relative = Vector2((session.yaw - yaw) / (0.003 * sensitivity), (session.pitch - pitch) / (0.003 * sensitivity))
	Input.parse_input_event(motion)

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(operator + "-" + label + ".png"))

func _process(delta: float) -> bool:
	deadline += delta
	if deadline > 35.0:
		push_error("second pass native deadline")
		quit(2)
	if is_instance_valid(session) and session.has_node("PlayerGameplay"):
		max_cables = maxi(max_cables, session.get_node("PlayerGameplay").cues.slots.size())
	return false

func run() -> void:
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/player_gameplay/second_pass_oracle.json"))
	var plan: Dictionary = oracle.plans[operator]
	session = load("res://world/session.tscn").instantiate()
	root.add_child(session)
	current_scene = session
	session.client.events.connect(func(items: Array) -> void:
		for event: Dictionary in items:
			if event.get("actor") == session.client.actor_id: observed.append(event))
	session.client.snapshot.connect(func(frame: Dictionary) -> void:
		for actor: Dictionary in frame.state.actors:
			if actor.id == session.client.actor_id: poses.append(actor.duplicate(true)))
	while session.phase != 3 or not session.received_pose: await process_frame
	await create_timer(0.4).timeout
	root.grab_focus()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = root.get_visible_rect().size * Vector2(0.5, 0.65)
	click.global_position = click.position
	click.pressed = true
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await process_frame
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await create_timer(0.25).timeout
	print("GAMEPLAY_INPUT_ELIGIBILITY ", JSON.stringify({"capture":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"eligible":session.can_capture_pointer(),"focused":session.application_focused,"stale":session.snapshot_watch.stale(),"hover":str(root.gui_get_hovered_control())}))
	aim(float(plan.aim.yaw), float(plan.aim.pitch))
	await capture("wide-before")
	key(KEY_Q, true)
	key(KEY_Q, false)
	await create_timer(0.3).timeout
	var elapsed := 0.0
	var keys := {"jump":KEY_SPACE, "crouch":KEY_CTRL, "mobility":KEY_X}
	for change: Array in plan.changes:
		var delay := float(change[0]) - elapsed
		if delay > 0.0: await create_timer(delay).timeout
		key(keys[change[1]], change[2])
		elapsed = float(change[0])
		models.append(session.get_node("PlayerGameplay").model.duplicate(true))
		if elapsed > 0.3: await capture("state-" + str(models.size()))
	await create_timer(maxf(0.2, float(plan.seconds) - elapsed)).timeout
	key(KEY_Q, true)
	key(KEY_Q, false)
	await create_timer(0.2).timeout
	await capture("wide-after")
	root.size = Vector2i(960, 600)
	await create_timer(0.2).timeout
	await capture("compact-after")
	var expected: Dictionary = {}
	for result: Dictionary in oracle.results:
		if result.operator == operator: expected = result
	var ok := true
	for event: Dictionary in expected.events:
		if event.type not in ["move-start", "charge-release", "slam-impact"]: continue
		var found := false
		for actual: Dictionary in observed:
			if actual.type == event.type and actual.get("reason") == event.get("reason"): found = true
		ok = ok and found
	var power_count := 0
	for event: Dictionary in observed:
		if event.type == "power": power_count += 1
	ok = ok and power_count == 1
	var model: Dictionary = session.get_node("PlayerGameplay").model
	ok = ok and not model.is_empty()
	var result := {"operator":operator,"ok":ok,"events":observed,"poses":poses,"models":models,"model":model,"max_cables":max_cables,"scripted":true,"human":false}
	var file := FileAccess.open(out.path_join(operator + "-native.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	print("SECOND_PASS_NATIVE ", JSON.stringify({"operator":operator,"ok":ok,"max_cables":max_cables}))
	quit(0 if ok else 1)
