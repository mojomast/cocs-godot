extends SceneTree
## N supplemental: real scene, real authority, physical input only; read-only state.
var session: Node
var kind := "combined"
var output := ""
var failures: Array[String] = []
var observations: Array = []
var capture_attempts := 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--view-route="): kind = arg.trim_prefix("--view-route=")
		if arg.begins_with("--evidence-out="): output = arg.trim_prefix("--evidence-out=")
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); printerr("ORDINARY_VEHICLE_FAIL ", label)

func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(code: int) -> void:
	key(code, true)
	key(code, false)

func actor() -> Dictionary:
	return session.actor if kind == "combined" else session.presentation.local_actor

func vehicle() -> Dictionary:
	return session.vehicle if kind == "combined" else session.vehicle_bridge.vehicle

func position() -> Vector2:
	var a := actor()
	return Vector2(float(a.get("x", 0)), float(a.get("z", 0)))

func camera() -> Camera3D:
	return session.world.camera if kind == "combined" else session.camera

func aim(point: Vector2) -> void:
	var delta := point - position()
	var wanted := atan2(-delta.x, -delta.y)
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(-wrapf(wanted - float(session.yaw), -PI, PI) / 0.003, float(session.pitch) / 0.003)
	event.screen_relative = event.relative
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func engage() -> void:
	if kind == "combined": tap(KEY_ENTER)
	else:
		capture_attempts += 1
		print("VEHICLE_CAPTURE_BEFORE ", JSON.stringify({"attempt":capture_attempts,"phase":session.phase,"eligible":session.can_capture_pointer(),"gates":session.trace_input_gates()}))
		print("VEHICLE_RELEASE_LEDGER ",JSON.stringify(session.combat_actions.bindings.down))
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		# Center-left is the released-pointer ability scroll pane at 960x600.
		# Click the unobstructed world, not a UI control that owns that click.
		event.position = Vector2(root.size) * Vector2(0.85, 0.5)
		event.global_position = event.position
		event.pressed = true
		Input.parse_input_event(event)
		event = event.duplicate()
		event.pressed = false
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		print("VEHICLE_CAPTURE_AFTER ", JSON.stringify({"attempt":capture_attempts,"gates":session.trace_input_gates()}))

func wait_for(predicate: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await process_frame
	return false

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "capture " + label)
	observations.append({"stage":label,"actor":actor().duplicate(true),"vehicle":vehicle().duplicate(true),
		"camera":str(camera().global_transform),"pointer":Input.mouse_mode,"yaw":session.yaw})

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(960, 600)
	# Sunscar's admitted world/session-derived route is Objectives/Payload;
	# generic Combat deliberately rejects this map in MatchSetup.MAPS.
	change_scene_to_file("res://combined_arms/demo.tscn" if kind == "combined" else "res://objectives/demo.tscn")
	await scene_changed
	session = current_scene
	if kind == "world": session.trace_enabled = true
	if not await wait_for(func() -> bool: return not actor().is_empty(), 25):
		check(false, "actual source actor arrival; phase=" + str(session.phase))
		finish(); return
	engage()
	await process_frame
	var route: Array[Vector2] = [Vector2(-80, position().y), Vector2(-80, -10), Vector2(-62, -10), Vector2(-62, -6)]
	for point in route:
		var deadline := Time.get_ticks_msec() + 20000
		while position().distance_to(point) > 0.8 and Time.get_ticks_msec() < deadline:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				key(KEY_W, false)
				engage()
				await process_frame
			aim(point)
			key(KEY_W, true)
			# Near a waypoint use discrete human-like taps and let the authoritative
			# neutral packet settle; frame-sized full-speed reversals overshoot on
			# software renderers. Never change actor coordinates or source clocks.
			if position().distance_to(point) < 5.0:
				await create_timer(0.1).timeout
				key(KEY_W, false)
				await create_timer(0.3).timeout
			else: await process_frame
		key(KEY_W, false)
		if position().distance_to(point) > 0.8:
			check(false, "ordinary approach " + str(point) + " actual " + str(position()))
			await capture("approach-failure"); finish(); return
	await capture("infantry-approach")
	tap(KEY_E)
	if not await wait_for(func() -> bool: return not vehicle().is_empty(), 5):
		check(false, "ordinary E mounts source vehicle"); finish(); return
	check(actor().get("vehicleSeat") == "driver", "source driver relationship")
	engage()
	for first: bool in [false, true]:
		var rig = session.chase if kind == "combined" else session.vehicle_camera
		if rig.first_person != first: tap(KEY_F4)
		await process_frame
		check(rig.first_person == first, "ordinary F4 view selection")
		var before := position()
		key(KEY_W, true)
		await create_timer(0.8).timeout
		key(KEY_W, false)
		check(position().distance_to(before) > 0.1, "ordinary mounted W moves authority actor")
		var yaw_before: float = session.yaw
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(35, 0)
		motion.screen_relative = motion.relative
		Input.parse_input_event(motion)
		await process_frame
		check(absf(wrapf(float(session.yaw) - yaw_before, -PI, PI)) > 0.02, "ordinary mounted look")
		await capture("first-person" if first else "third-person")
	tap(KEY_E)
	check(await wait_for(func() -> bool: return actor().get("vehicleId") == null, 5), "ordinary E demounts")
	await capture("demounted")
	tap(KEY_ESCAPE)
	tap(KEY_F12)
	await process_frame
	var leave: Button = root.get_node("LocalSettings").find_child("LeaveMatch", true, false)
	check(leave != null and leave.is_visible_in_tree(), "ordinary F12 exposes Return Home")
	if leave != null and leave.is_visible_in_tree():
		for down: bool in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = down
			click.position = leave.get_global_rect().get_center()
			click.global_position = click.position
			Input.parse_input_event(click)
			Input.flush_buffered_events()
		check(await wait_for(func() -> bool: return current_scene != null and current_scene.scene_file_path == "res://ui/main_menu.tscn", 5), "ordinary Return Home click")
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(output.path_join("home.png"))
	finish()

func finish() -> void:
	var result := {"passed":failures.is_empty(),"failures":failures,"route":kind,"observations":observations,
		"classification":"ordinary physical input through actual production client and unmodified source authority"}
	FileAccess.open(output.path_join("native.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "  "))
	print("ORDINARY_VEHICLE_RESULT ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
