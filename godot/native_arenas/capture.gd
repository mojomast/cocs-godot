extends SceneTree
## Composition-owned graphical capture for the native Deathmatch scene.
##
## Runs the real scene against a live Node authority on a graphical display
## (private Xvfb in the runner), injects ordinary player input events, and saves
## the actual framebuffer at the requested sizes. It is read-only: nothing here
## changes gameplay state or writes inside the repository.
##
##   DISPLAY=:N $GODOT_BIN --path godot --rendering-method gl_compatibility \
##     --audio-driver Dummy --script res://native_arenas/capture.gd -- \
##     --map=<id> --endpoint=ws://127.0.0.1:PORT/native-arenas --bots=3 \
##     --round-seconds=180 --autostart --capture-root=<dir> --sizes=960x640,1280x800
var session: Node3D
var output := "/tmp/opencode/native-dm-captures"
var sizes: Array = [Vector2i(960, 640), Vector2i(1280, 800)]
var input_helper: Node

class InputHelper extends Node:
	var session: Node
	var active := false
	func _process(_delta: float) -> void:
		if active and session != null and session.can_capture_pointer() and session.phase == 3:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			session.combat_actions.captured()
			session.first_person.refresh()

func _initialize() -> void:
	call_deferred("run")

func parse_options() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-root="): output = arg.trim_prefix("--capture-root=")
		elif arg.begins_with("--sizes="):
			sizes = []
			for size: String in arg.trim_prefix("--sizes=").split(","):
				var parts := size.split("x")
				if parts.size() == 2: sizes.append(Vector2i(int(parts[0]), int(parts[1])))

func key_event(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func button_event(button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)

func motion(dx: float, dy: float) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(dx, dy)
	Input.parse_input_event(event)

func probe_physics(eye: Vector3) -> Dictionary:
	var space := session.get_world_3d().direct_space_state
	var down := PhysicsRayQueryParameters3D.create(eye, eye + Vector3(0, -30, 0))
	down.collision_mask = 1
	var hit := space.intersect_ray(down)
	if hit.has("position"):
		return {"downDistance": eye.y - hit.position.y, "downY": hit.position.y,
			"collider": String(hit.get("collider").name) if hit.get("collider") != null else "?"}
	return {"downDistance": null, "downY": null, "collider": null}

func recipe() -> Dictionary:
	for child: Node in session.world.get_children():
		var value: Variant = child.get("recipe")
		if value is Dictionary and not value.is_empty(): return value
	return {}

func aim_at(target: Vector3) -> void:
	var eye: Vector3 = session.camera.global_position
	var dx := target.x - eye.x
	var dz := target.z - eye.z
	var distance := maxf(0.001, sqrt(dx * dx + dz * dz))
	session.yaw = atan2(-dx, -dz)
	session.pitch = clampf(atan2(target.y - eye.y, distance), -0.6, 0.6)

func capture(name: String, size: Vector2i) -> void:
	var path: String = "%s/%s-%s-%dx%d.png" % [output, session.current_id, name, size.x, size.y]
	var image := root.get_texture().get_image()
	image.save_png(path)
	var eye: Vector3 = session.camera.global_position
	var actor: Variant = session.presentation.local_actor
	var feet := {}
	if actor != null and actor is Dictionary:
		feet = {"x": actor.get("x"), "y": actor.get("y"), "z": actor.get("z")}
	print("NATIVE_DM_CAPTURE ", JSON.stringify({"map": session.current_id, "mode": "deathmatch",
		"path": path, "size": [size.x, size.y], "eye": [eye.x, eye.y, eye.z], "actor": feet,
		"snapshots": session.presentation.applied, "actors": session.presentation.actors.size(),
		"phase": session.phase, "geometryHash": session.world.get_meta("native_geometry_hash"),
		"firstPerson": session.first_person.rig.showing,
		"pointer": Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"framebuffer": [image.get_width(), image.get_height()],
		"physics": probe_physics(eye)}))

func run() -> void:
	parse_options()
	DirAccess.make_dir_recursive_absolute(output)
	session = load("res://native_arenas/demo.tscn").instantiate()
	root.add_child(session)
	input_helper = InputHelper.new()
	input_helper.session = session
	input_helper.process_priority = 1000
	root.add_child(input_helper)
	root.msaa_3d = Viewport.MSAA_DISABLED
	var deadline := Time.get_ticks_msec() + 150000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not session.startup_error.is_empty():
			push_error("Capture startup: " + session.startup_error)
			quit(1)
			return
		if session.phase != 3 or not session.received_pose: continue
		if session.presentation.applied < 5: continue
		if not is_instance_valid(session.first_person): continue
		break
	if session.phase != 3 or not session.received_pose:
		push_error("Native DM session never reached live play: " + JSON.stringify({"phase": session.phase,
			"startup": session.startup_error}))
		quit(1)
		return
	input_helper.active = true
	for size: Vector2i in sizes:
		root.size = size
		root.grab_focus()
		var stable := 0
		for i in 240:
			await process_frame
			if not root.has_focus(): root.grab_focus()
			await RenderingServer.frame_post_draw
			stable = stable + 1 if (session.first_person.rig.showing and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED) else 0
			if stable >= 3: break
		if not session.first_person.rig.showing:
			push_error("Capture needs a visible first-person rig: " + JSON.stringify({"phase": session.phase,
				"focus": root.has_focus(), "pointer": Input.mouse_mode, "stale": session.snapshot_watch.stale()}))
			quit(1)
			return
		# Aim across the arena from the player's real position before the action pass.
		var arena := recipe()
		var bounds: Dictionary = arena.get("arena", {}).get("bounds", {})
		if not bounds.is_empty():
			aim_at(Vector3((float(bounds.get("minX", 0.0)) + float(bounds.get("maxX", 0.0))) * 0.5, 1.5,
				(float(bounds.get("minZ", 0.0)) + float(bounds.get("maxZ", 0.0))) * 0.5))
		for i in 12: await process_frame
		capture("arena", size)
		# Ordinary player input through the shared session: move, strafe, look, fire.
		button_event(MOUSE_BUTTON_RIGHT, true)
		key_event(KEY_W, true)
		for i in 90:
			await process_frame
			motion(4.0, 0.0)
			if i == 20: button_event(MOUSE_BUTTON_LEFT, true)
			if i == 50: key_event(KEY_D, true)
			if i == 70: key_event(KEY_SPACE, true)
		capture("action", size)
		key_event(KEY_D, false)
		key_event(KEY_SPACE, false)
		button_event(MOUSE_BUTTON_LEFT, false)
		button_event(MOUSE_BUTTON_RIGHT, false)
		key_event(KEY_W, false)
		for i in 20: await process_frame
	session.client.disconnect_server()
	quit(0)
