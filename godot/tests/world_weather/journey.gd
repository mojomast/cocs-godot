extends SceneTree
## Real production scenes, real websocket snapshots, ordinary input/settings and
## protocol restart. No fabricated actors/weather/geometry or authority writes.
var session: Node
var output := ""
var kind := ""
var failures: Array[String] = []
var records: Array = []
var latest: Dictionary = {}
var frames := 0
var finished := false
var started := 0

func _initialize() -> void:
	started = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--weather-output="): output = arg.trim_prefix("--weather-output=")
		if arg.begins_with("--weather-journey="): kind = arg.trim_prefix("--weather-journey=")
	call_deferred("run")

func _process(_dt: float) -> bool:
	if not finished and Time.get_ticks_msec() - started > 100000:
		check(false, "journey deadline")
		finish()
	return false

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("WORLD_WEATHER_JOURNEY_CHECK ", label)

func wait_for(predicate: Callable, label: String, seconds: float = 12.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline and not finished:
		if predicate.call(): return true
		await process_frame
	check(false, "timeout: " + label)
	return false

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func position() -> Vector3:
	var actor: Dictionary = session.presentation.local_actor
	return Vector3(actor.get("x",0), actor.get("y",0), actor.get("z",0))

func movement_diagnostic(boundary: String) -> void:
	if kind != "campaign": return
	var at := position()
	print("CAMPAIGN_MOVEMENT_WINDOW ",JSON.stringify({"boundary":boundary,
		"source_time":latest.get("time"),"position":[at.x,at.y,at.z],
		"epoch":session.client.input_epoch,"input_seq":session.client.input_seq,
		"ack":session.client.last_ack,"fifo":session.client.input_status.duplicate(true),
		"outstanding":session.client.outstanding_inputs.duplicate(),
		"gates":session.trace_input_gates()}))

func collision_signature() -> String:
	var rows: Array = []
	for node: Node in session.world.find_children("*", "CollisionObject3D", true, false):
		rows.append([str(session.world.get_path_to(node)),str(node.global_transform),node.collision_layer,node.collision_mask])
	for node: Node in session.world.find_children("*", "CollisionShape3D", true, false):
		rows.append([str(session.world.get_path_to(node)),str(node.transform),node.disabled,str(node.shape)])
	return JSON.stringify(rows).sha256_text()

func receipt(name: String) -> void:
	var weather = session.audiovisual.weather
	records.append({"name":name,"snapshots":frames,"map":session.current_id,"round":session.round_starts,
		"actor_id":session.client.actor_id,"spectating":session.client.spectating,"ack":session.client.last_ack,
		"time":latest.get("time"),"weather":weather.diagnostics(),"look":weather.look.diagnostics(),
		"collision_signature":collision_signature(),"position":str(position())})

func capture(name: String) -> void:
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "save " + name)
	receipt(name)

func run() -> void:
	root.size = Vector2i(960, 600)
	var settings: Node = root.get_node("LocalSettings")
	settings.set_value("mute", true, false)
	settings.set_value("weather_enabled", true, false)
	settings.set_value("weather_quality", 100, false)
	settings.set_value("reduced_motion", false, false)
	var scene: PackedScene = load("res://campaign/demo.tscn" if kind == "campaign" else ("res://objectives/demo.tscn" if kind == "source" else "res://multiplayer_worlds/demo.tscn"))
	session = scene.instantiate()
	root.add_child(session)
	current_scene = session
	session.client.snapshot.connect(func(frame: Dictionary) -> void:
		frames += 1
		latest = frame.state.duplicate(true))
	if kind == "campaign": session.launch_campaign()
	if not await wait_for(func() -> bool: return session.phase == 3 and (session.received_pose or session.client.spectating) and frames > 3, "production snapshots"):
		finish()
		return
	check(session.audiovisual.weather.look._owned != null, "production map atmosphere bound")
	check(session.audiovisual.weather.look.diagnostics().materials > 0, "production map materials bound")
	var collider_hash := collision_signature()
	await capture("round-one-player")
	if kind == "spectator":
		check(session.client.spectating and session.client.actor_id < 0, "late join is authority-confirmed spectator")
		check(not session.combat_controls_active(), "spectator has no controls")
		await boundaries(settings, collider_hash)
		return
	# Ordinary native key movement reaches authority and returns in public poses.
	root.grab_focus()
	await process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = root.size / 2
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await process_frame
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	# Software shader warm-up can cross the production stale boundary and release
	# capture. Retry fresh clicks after a real fresh feed; never bypass the gate.
	for attempt in 10:
		if session.combat_controls_active(): break
		await process_frame
		if not session.can_capture_pointer(): continue
		root.grab_focus()
		var retry := InputEventMouseButton.new()
		retry.position = root.size / 2
		retry.button_index = MOUSE_BUTTON_LEFT
		retry.pressed = false
		Input.parse_input_event(retry)
		retry = retry.duplicate()
		retry.pressed = true
		Input.parse_input_event(retry)
		Input.flush_buffered_events()
		await process_frame
		retry = retry.duplicate()
		retry.pressed = false
		Input.parse_input_event(retry)
		Input.flush_buffered_events()
	if kind == "campaign":
		var path: Array = session.world.recipe.campaign.criticalPath
		var target: Dictionary = path[mini(8, path.size() - 1)]
		var direction := Vector3(target.x, target.y, target.z) - position()
		var desired_yaw := atan2(-direction.x, -direction.z)
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(wrapf(float(session.yaw) - desired_yaw, -PI, PI), 0) / (0.003 * preload("res://ui/settings_access.gd").sensitivity())
		motion.screen_relative = motion.relative
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
	var before := position()
	check(session.combat_controls_active(), "native pointer capture admits movement")
	# Preserve actual submitted controls/queue results for the unresolved
	# campaign movement gate; ACK growth alone does not establish nonzero input.
	var prior_trace: bool = session.trace_enabled
	session.trace_enabled = true
	receipt("movement-input-before")
	movement_diagnostic("before-w-down")
	key(KEY_W, true)
	await create_timer(1.2).timeout
	key(KEY_W, false)
	await create_timer(0.3).timeout
	movement_diagnostic("after-w-up")
	session.trace_enabled = prior_trace
	check(position().distance_to(before) > 0.15, "real input moves public actor")
	receipt("moved")
	# A normal authoritative restart changes the source weather seed to revision 2.
	var old_round: int = session.round_starts
	if kind == "campaign": session.request_campaign_action("restart")
	else: session.client.send_frame({"type":"start"})
	if not await wait_for(func() -> bool: return session.round_starts > old_round and session.received_pose and session.phase == 3, "authoritative restart"):
		finish()
		return
	await create_timer(0.6).timeout
	check(session.audiovisual.weather.look._owned != null, "restart map bound")
	check(session.audiovisual.weather.diagnostics().weather != "clear", "revision two has source-selected weather")
	if kind == "source": check(session.audiovisual.weather.look.wetness > 0.0, "live wetness reaches source map materials")
	await capture("round-two-weather")
	if kind == "campaign":
		key(KEY_F3, true)
		await process_frame
		key(KEY_F3, false)
		await wait_for(func() -> bool: return latest.get("soloCheats", {}).get("paused", false), "authority pause acknowledgment")
		var paused_time: float = latest.get("time", -1.0)
		var weather_time: float = session.audiovisual.weather.diagnostics().elapsed
		await create_timer(0.5).timeout
		check(is_equal_approx(paused_time, float(latest.get("time", -2.0))), "paused authority clock stays fixed")
		check(is_equal_approx(weather_time, float(session.audiovisual.weather.diagnostics().elapsed)), "paused visual clock stays fixed")
		receipt("authority-paused")
		key(KEY_F3, true)
		await process_frame
		key(KEY_F3, false)
		await wait_for(func() -> bool: return not latest.get("soloCheats", {}).get("paused", true), "authority resume acknowledgment")
	await boundaries(settings, collider_hash)

func boundaries(settings: Node, collider_hash: String) -> void:
	if kind == "source":
		for code: int in [KEY_F8, KEY_F9]:
			for cycle in 3:
				key(code, true)
				await process_frame
				key(code, false)
			receipt("detail-cycle-%d" % code)
	# Real settings service invokes production callbacks; check exact restoration.
	settings.set_value("weather_enabled", false, false)
	await process_frame
	check(is_zero_approx(session.audiovisual.weather.look.wetness), "weather disable restores dry")
	await capture("disabled")
	settings.set_value("weather_enabled", true, false)
	settings.set_value("weather_quality", 0, false)
	await process_frame
	check(is_zero_approx(session.audiovisual.weather.look.wetness), "zero quality stays dry")
	settings.set_value("weather_quality", 100, false)
	settings.set_value("reduced_motion", true, false)
	await process_frame
	check(is_zero_approx(session.audiovisual.weather.look.wetness), "reduced motion stays dry")
	settings.set_value("reduced_motion", false, false)
	await create_timer(0.7).timeout
	# Focus and stale snapshots pass through the production session lifecycle.
	session._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var wet: float = session.audiovisual.weather.look.wetness
	await create_timer(0.35).timeout
	check(is_equal_approx(wet, session.audiovisual.weather.look.wetness), "focus freezes weather look")
	receipt("focus-out")
	session._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	session.client.set_process(false)
	await create_timer(1.5).timeout
	check(session.snapshot_watch.stale(), "real withheld socket polling triggers stale")
	wet = session.audiovisual.weather.look.wetness
	await create_timer(0.3).timeout
	check(is_equal_approx(wet, session.audiovisual.weather.look.wetness), "stale freezes weather look")
	receipt("stale")
	session.client.set_process(true)
	await wait_for(func() -> bool: return not session.snapshot_watch.stale() and session.audiovisual.fresh, "fresh feed recovery")
	await capture("recovered")
	check(collision_signature() == collider_hash, "weather/settings/restart preserve gameplay colliders")
	check(not session.audiovisual.weather.look.diagnostics().capped, "production material budget")
	finish()

func finish() -> void:
	if finished: return
	finished = true
	key(KEY_W, false)
	FileAccess.open(output.path_join("journey.json"), FileAccess.WRITE).store_string(JSON.stringify({"kind":kind,"records":records,"failures":failures},"\t"))
	if is_instance_valid(session):
		session.client.disconnect_server()
		session.free()
	print("WORLD_WEATHER_JOURNEY ", kind, " snapshots=",frames," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
