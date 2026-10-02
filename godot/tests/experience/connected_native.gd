extends SceneTree
## Command-driven connected native proof. All gameplay/camera/menu stimuli enter
## Input.parse_input_event; source staging is exclusively owned by the Node runner.
var session: Node
var peer: Node
var settings: Node
var info: Node
var endpoint := ""
var out := ""
var name_id := ""
var scene_path := ""
var family := ""
var compact := false
var failures: Array[String] = []
var accepted: Dictionary = {}
var received_events: Array = []
var source_starts := 0
var source_results := 0
var began := 0
var done := false
var home_only := false
var leave_after_report := false
var watch_free_motion := false
var last_free_position := Vector3.ZERO

func _initialize() -> void:
	began = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--journey-control="): endpoint = arg.trim_prefix("--journey-control=")
		if arg.begins_with("--journey-out="): out = arg.trim_prefix("--journey-out=")
		if arg.begins_with("--journey-name="): name_id = arg.trim_prefix("--journey-name=")
		if arg.begins_with("--journey-scene="): scene_path = arg.trim_prefix("--journey-scene=")
		if arg.begins_with("--journey-family="): family = arg.trim_prefix("--journey-family=")
		if arg == "--journey-compact": compact = true
		if arg == "--journey-home": home_only = true
	call_deferred("run")

func _process(_delta: float) -> bool:
	if watch_free_motion and is_instance_valid(info.spectator_camera.camera):
		var point: Vector3 = info.spectator_camera.camera.position
		check(point.distance_to(last_free_position) <= 64.0 * minf(maxf(_delta, 0), 0.1) + 0.1, "free camera continuous across source snapshot callbacks")
		last_free_position = point
	if not done and Time.get_ticks_msec() - began > 260000:
		check(false, "native watchdog 260s")
		finish()
	return false

func check(ok: bool, note: String) -> void:
	if not ok:
		failures.append(note)
		printerr("SPECTATOR_JOURNEY_FAIL ", note)

func wait_for(predicate: Callable, note: String, seconds: float = 15) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while not done and Time.get_ticks_msec() < end:
		if predicate.call(): return true
		await process_frame
	check(false, "timeout " + note)
	return false

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func tap(code: int) -> void:
	key(code, true)
	key(code, false)

func pointer(position: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	var button := InputEventMouseButton.new()
	button.position = position
	button.global_position = position
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	Input.parse_input_event(button)

func world_click(pressed: bool) -> void:
	pointer(root.get_visible_rect().size * Vector2(0.8, 0.45), pressed)

func release_focus() -> void:
	var focus := root.gui_get_focus_owner()
	if focus != null: focus.release_focus()

func http(path: String, body: Variant = null) -> Dictionary:
	var request := HTTPRequest.new()
	root.add_child(request)
	request.timeout = 5
	var error := request.request(endpoint + path, ["Content-Type: application/json"], HTTPClient.METHOD_GET if body == null else HTTPClient.METHOD_POST, "" if body == null else JSON.stringify(body))
	if error != OK:
		check(false, "HTTP queue " + path)
		request.queue_free()
		return {}
	var response: Array = await request.request_completed
	request.queue_free()
	check(int(response[0]) == HTTPRequest.RESULT_SUCCESS and int(response[1]) == 200, "HTTP response " + path)
	var value: Variant = JSON.parse_string(response[3].get_string_from_utf8())
	return value if value is Dictionary else {}

func connect_scene() -> void:
	accepted.clear()
	received_events.clear()
	check(change_scene_to_file(scene_path) == OK, "normal scene handoff")
	await scene_changed
	session = current_scene
	peer = session.client if "client" in session else session.net
	peer.snapshot.connect(func(frame: Dictionary): accepted = frame.state.duplicate(true))
	peer.events.connect(func(items: Array):
		received_events.append_array(items)
		if received_events.size() > 512: received_events = received_events.slice(-512))
	peer.started.connect(func(_frame: Dictionary): source_starts += 1)
	peer.results.connect(func(_frame: Dictionary): source_results += 1)
	await process_frame

func run() -> void:
	var version := Engine.get_version_info()
	check(version.major == 4 and version.minor == 5 and version.patch == 2, "pinned Godot 4.5.2")
	settings = root.get_node("LocalSettings")
	info = settings.player_info
	root.size = Vector2i(760, 520) if compact else Vector2i(1280, 800)
	settings.set_value("ui_scale", 150 if compact else 100, false)
	settings.set_value("mute", true, false)
	settings.set_value("combat_readouts", true, false)
	settings.save()
	check(is_equal_approx(root.content_scale_factor, 1.5 if compact else 1.0), "real production content scale")
	root.grab_focus()
	if home_only:
		check(change_scene_to_file("res://ui/main_menu.tscn") == OK, "supervisor returns to actual Home")
		await scene_changed
		await process_frame
	else: await connect_scene()
	await http("/report/" + name_id, {"id":0, "ok":failures.is_empty(), "observation":observe(), "failures":failures})
	while not done:
		var command := await http("/poll/" + name_id)
		if command.has("action"):
			var before := failures.size()
			await execute(command)
			var observation := observe()
			await http("/report/" + name_id, {"id":command.id, "action":command.action, "ok":failures.size() == before, "observation":observation, "failures":failures})
			if leave_after_report:
				# Settings Leave intentionally quits; the production launcher then
				# opens Home. Node owns the same supervised handoff, not an override.
				tap(KEY_SPACE)
				await create_timer(3).timeout
				check(false, "ordinary Settings Leave did not exit")
				finish()
				return
			if command.action == "quit": finish(); return
		await create_timer(0.1).timeout

func live() -> bool:
	return is_instance_valid(session) and info.live() and info.ready_for_events and not info.stale()

func results_phase() -> bool:
	if not is_instance_valid(session): return false
	var value: Variant = session.get("phase")
	return value == "results" if value is String else ((value is int or value is float) and value == 4)

func privacy() -> void:
	if not is_instance_valid(peer) or not peer.spectating: return
	check(peer.actor_id == -1, "spectator wire identity is never target identity")
	check(info.gameplay_model.is_empty() and info.combat.hits.is_empty() and info.public_feed.marks.is_empty(), "no kit/recap/assist context on spectator seat")
	for meta: Dictionary in info.public_feed.metadata: check(meta.get("assist") != true, "no prior-seat ASSIST metadata")
	check(not info.ability.is_visible_in_tree() and not info.recap.is_visible_in_tree() and not info.kill.is_visible_in_tree(), "no local actor overlay on spectator seat")
	var allowed := ["id", "name", "health", "team", "x", "y", "z", "yaw", "pitch", "eyeHeight"]
	for actor: Dictionary in info.spectator_camera.model.actors:
		var source: Dictionary = {}
		for row: Dictionary in accepted.get("actors", []):
			if row.id == actor.id: source = row
		check(not source.is_empty(), "target actor exists in received public snapshot")
		for field: String in actor:
			check(field in allowed, "target allowlist " + field)
			if field != "name": check(source.get(field) == actor[field], "target equals recipient snapshot " + field)

func observe() -> Dictionary:
	privacy()
	var result := {"name":name_id, "family":family, "scene":current_scene.scene_file_path if is_instance_valid(current_scene) else "", "starts":source_starts, "results":source_results, "uiScale":settings.values.ui_scale, "contentScale":root.content_scale_factor, "window":[root.size.x,root.size.y], "viewport":[root.get_visible_rect().size.x,root.get_visible_rect().size.y], "pointer":Input.mouse_mode}
	if not is_instance_valid(session) or not is_instance_valid(peer):
		result.merge({"kit":info.gameplay_model,"hits":info.combat.hits,"targets":info.spectator_camera.model.actors,"held":info.spectator_camera.held.size()})
		return result
	var camera: Camera3D = session.camera if "camera" in session else session.world.camera
	result.merge({"peer":peer.peer_id,"actor":peer.actor_id,"spectating":peer.spectating,"phase":session.phase,"sourceTime":accepted.get("time"),"ready":info.ready_for_events,"role":info.role_key,"camera":[camera.position.x,camera.position.y,camera.position.z],"rotation":[camera.rotation.x,camera.rotation.y,camera.rotation.z],"target":info.spectator_camera.model.target_id,"mode":info.spectator_camera.model.mode,"held":info.spectator_camera.held.size(),"captured":info.spectator_camera.captured,"targets":info.spectator_camera.model.actors,"kit":info.gameplay_model,"hits":info.combat.hits,"marks":info.public_feed.marks,"feed":info.public_feed.text(),"feedMeta":info.public_feed.metadata,"feedRows":info.public_feed.rows,"recap":info.recap.text,"kill":info.kill.text,"caption":info.caption.text})
	return result

func capture(label: String) -> void:
	await create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	var bounds := []
	for control: Control in [info.spectator_camera.panel, info.spectator_camera.heading, info.caption, info.feed, info.ability, info.recap]:
		var rect := control.get_global_rect()
		bounds.append({"name":str(control.name),"visible":control.is_visible_in_tree(),"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"minimum":[control.get_combined_minimum_size().x,control.get_combined_minimum_size().y],"text":control.text if control is Label else ""})
		if control.is_visible_in_tree() and control == info.spectator_camera.panel:
			check(root.get_visible_rect().encloses(rect), "spectator scroll viewport inside logical viewport")
	if is_instance_valid(current_scene): scene_bounds(current_scene, bounds)
	check(root.get_texture().get_image().save_png(out.path_join(label + ".png")) == OK, "screenshot " + label)
	var file := FileAccess.open(out.path_join(label + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"observation":observe(),"bounds":bounds}, "\t"))

func scene_bounds(node: Node, bounds: Array) -> void:
	if bounds.size() >= 256: return
	if node is Control and node.is_visible_in_tree() and (node is Label or node is ScrollContainer or node is PanelContainer or node is Button):
		var rect: Rect2 = node.get_global_rect()
		var minimum: Vector2 = node.get_combined_minimum_size()
		bounds.append({"path":str(node.get_path()),"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"minimum":[minimum.x,minimum.y],"text":node.text if node is Label or node is Button else "","clip":node.clip_contents})
	for child: Node in node.get_children(): scene_bounds(child, bounds)

func home() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: tap(KEY_ESCAPE)
	if not settings.overlay_open(): tap(KEY_F12)
	if not await wait_for(func(): return settings.overlay_open(), "F12 leave surface"): return
	settings.rows.leave.grab_focus()
	await process_frame
	await capture("leave-settings")
	leave_after_report = true

func execute(command: Dictionary) -> void:
	var action: String = command.action
	root.grab_focus()
	if action == "live":
		await wait_for(live, "fresh authoritative live snapshot", 25)
	elif action == "start" or action == "restart":
		release_focus()
		tap(KEY_F5 if family == "sports" and action == "restart" else KEY_ENTER)
	elif action == "player-input":
		if session.has_method("eligible"):
			await wait_for(func(): return session.eligible(), "route actor control eligibility / sports countdown", 15)
		elif session.has_method("can_capture_pointer"):
			await wait_for(func(): return session.can_capture_pointer(), "route actor capture eligibility", 15)
		release_focus()
		tap(KEY_ENTER)
		world_click(true)
		await create_timer(0.2).timeout
		world_click(false)
		key(KEY_W, true)
		await create_timer(0.25).timeout
		key(KEY_W, false)
		tap(KEY_ESCAPE)
	elif action == "camera":
		check(peer.spectating and live(), "camera commands require real spectator seat")
		release_focus()
		var before: Variant = info.spectator_camera.model.target_id
		tap(KEY_BRACKETRIGHT)
		await process_frame
		check(info.spectator_camera.model.target_id != before, "ordinary keyboard target cycle")
		tap(KEY_BRACKETLEFT)
		await process_frame
		check(info.spectator_camera.model.target_id == before, "ordinary reverse target cycle")
		var next: Control = info.spectator_camera.buttons.get_child(1)
		pointer(next.get_global_rect().get_center(), true)
		pointer(next.get_global_rect().get_center(), false)
		await process_frame
		check(info.spectator_camera.model.target_id != before, "ordinary mouse target button")
		release_focus()
		tap(KEY_V)
		world_click(true)
		world_click(false)
		await process_frame
		check(info.spectator_camera.captured, "freecam ordinary world-click capture")
		var camera: Camera3D = info.spectator_camera.camera
		var origin := camera.position
		last_free_position = origin
		watch_free_motion = true
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(40, -20)
		Input.parse_input_event(motion)
		key(KEY_W, true)
		key(KEY_SPACE, true)
		key(KEY_SHIFT, true)
		await create_timer(0.3).timeout
		key(KEY_W, false)
		key(KEY_SPACE, false)
		key(KEY_SHIFT, false)
		watch_free_motion = false
		check(camera.position.distance_to(origin) > 0.1, "ordinary freecam input moves camera")
		await capture("free-captured")
		tap(KEY_ESCAPE)
		await process_frame
		check(not info.spectator_camera.captured and info.spectator_camera.held.is_empty(), "Esc clears camera capture/held keys")
		tap(KEY_V)
		await capture("follow")
	elif action == "modal":
		release_focus()
		tap(KEY_V)
		tap(KEY_ENTER)
		key(KEY_W, true)
		tap(KEY_F12)
		await create_timer(0.2).timeout
		check(settings.overlay_open(), "real F12 modal")
		key(KEY_Q, true)
		world_click(true)
		await create_timer(0.25).timeout
		key(KEY_W, false)
		key(KEY_Q, false)
		world_click(false)
		check(info.spectator_camera.held.is_empty() and not info.spectator_camera.captured, "modal clears camera held ledger")
		await capture("settings")
		tap(KEY_ESCAPE)
		await process_frame
		check(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "modal close cannot resume held input")
	elif action == "stale":
		await wait_for(func(): return info.stale(), "source transport starvation", 5)
		await create_timer(0.15).timeout
		check(info.spectator_camera.model.actors.is_empty() and info.spectator_camera.held.is_empty(), "stale clears target and input")
		check(not info.spectator_camera.captured and info.spectator_camera.velocity == Vector3.ZERO, "stale cancels freecam capture and velocity")
		key(KEY_W, false)
		await capture("stale")
	elif action == "hold-free":
		release_focus()
		if info.spectator_camera.model.mode != "free": tap(KEY_V)
		tap(KEY_ENTER)
		key(KEY_W, true)
		await process_frame
		check(info.spectator_camera.captured and info.spectator_camera.held.has(KEY_W), "held freecam stimulus before starvation")
	elif action == "focus-boundary":
		release_focus()
		tap(KEY_V)
		tap(KEY_ENTER)
		key(KEY_W, true)
		var was_embedded := root.gui_embed_subwindows
		root.gui_embed_subwindows = false
		var other := Window.new()
		other.title = "Experience acceptance focus boundary"
		other.size = Vector2i(280, 180)
		root.add_child(other)
		other.show()
		other.grab_focus()
		await wait_for(func(): return not root.has_focus(), "actual native window focus loss", 5)
		await create_timer(0.2).timeout
		check(info.spectator_camera.held.is_empty() and not info.spectator_camera.captured and info.spectator_camera.model.actors.is_empty(), "focus loss clears input and target")
		key(KEY_W, false)
		other.queue_free()
		await process_frame
		root.gui_embed_subwindows = was_embedded
		root.grab_focus()
		await wait_for(func(): return root.has_focus(), "native focus restored", 5)
		check(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "focus return does not recapture")
		await capture("focus-restored")
	elif action == "retry":
		check(family == "mode", "only mode route exposes native Retry seat UI")
		if family == "mode":
			await wait_for(func(): return session.phase == -5 and session.retry_button.visible, "reconnect button")
			session.retry_button.grab_focus()
			await process_frame
			tap(KEY_SPACE)
			await wait_for(live, "source reconnect admission")
	elif action == "select":
		release_focus()
		for index: int in range(64):
			if info.spectator_camera.model.target_id == command.target: break
			tap(KEY_BRACKETRIGHT)
			await process_frame
		check(info.spectator_camera.model.target_id == command.target, "ordinary cycle selects requested public target")
	elif action == "results-input":
		await wait_for(results_phase, "native natural results", 130)
		key(KEY_W, true)
		world_click(true)
		tap(KEY_Q)
		await create_timer(0.25).timeout
		world_click(false)
		key(KEY_W, false)
		await capture("results")
	elif action == "home": await home()
	elif action == "quit": pass
	elif action == "join": await connect_scene()
	elif action == "capture": await capture(str(command.get("label", "inspect")))
	elif action != "inspect": check(false, "unknown command " + action)

func finish() -> void:
	if done: return
	done = true
	var file := FileAccess.open(out.path_join("driver-final.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"failures":failures,"starts":source_starts,"results":source_results}, "\t"))
	quit(0 if failures.is_empty() else 1)
