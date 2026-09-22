extends SceneTree
## Review-lane graphical capture for the native DM arenas.
##
## Runs the real native DM session scene against a live Node authority on a
## private Xvfb display, injects ordinary player input events (keyboard +
## mouse motion/buttons through Input.parse_input_event), and captures the
## framebuffer at the requested sizes. Also raycasts Godot physics at the local
## player's own position to compare the visible floor with the collider floor.
##
## Usage (from repository root, with the authority endpoint already running):
##   DISPLAY=:N $GODOT_BIN --path godot --audio-driver Dummy \
##     --rendering-method gl_compatibility \
##     --script res://tests/native_arena_review/capture_review.gd -- \
##     --map=prism-foundry --endpoint=ws://127.0.0.1:PORT/native-arenas \
##     --bots=3 --round-seconds=180 --autostart \
##     --capture-root=/path/to/captures --sizes=960x640,1280x800
##
## Read-only: it never writes repository files outside the capture root.
var session: Node3D
var output := "/tmp/opencode/native-dm-review-captures"
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
				sizes.append(Vector2i(int(parts[0]), int(parts[1])))

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

func capture(name: String, size: Vector2i) -> void:
	var path: String = "%s/%s-%dx%d.png" % [output, name, size.x, size.y]
	var image := root.get_texture().get_image()
	image.save_png(path)
	var eye: Vector3 = session.camera.global_position
	var feet := {}
	var actor: Variant = session.presentation.local_actor
	if actor != null and actor is Dictionary:
		feet = {"x": actor.get("x"), "y": actor.get("y"), "z": actor.get("z")}
	print("NATIVE_REVIEW_CAPTURE ", JSON.stringify({"map": session.current_id, "path": path, "size": [size.x, size.y],
		"eye": [eye.x, eye.y, eye.z], "actor": feet, "snapshots": session.presentation.applied,
		"actors": session.presentation.actors.size(), "phase": session.phase,
		"geometryHash": session.world.get_meta("native_geometry_hash"),
		"firstPerson": session.first_person.rig.showing, "pointer": Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"physics": probe_physics(eye)}))

func probe_physics(eye: Vector3) -> Dictionary:
	var space := session.get_world_3d().direct_space_state
	var down := PhysicsRayQueryParameters3D.create(eye, eye + Vector3(0, -30, 0))
	down.collision_mask = 1
	var hit := space.intersect_ray(down)
	var probe := {"downDistance": null, "downY": null, "downCollider": null, "horizontal": {}}
	if hit.has("position"):
		probe.downDistance = eye.y - hit.position.y
		probe.downY = hit.position.y
		var collider: Object = hit.get("collider")
		probe.downCollider = String(collider.name) if collider != null else "?"
	for pair: Array in [["forward", Vector3.FORWARD], ["back", Vector3.BACK], ["left", Vector3.LEFT], ["right", Vector3.RIGHT]]:
		var query := PhysicsRayQueryParameters3D.create(eye, eye + (pair[1] as Vector3) * 4.0)
		query.collision_mask = 1
		var result := space.intersect_ray(query)
		probe.horizontal[pair[0]] = eye.distance_to(result.position) if result.has("position") else null
	return probe

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
		capture("standing", size)
		# Ordinary player input: move forward, strafe, fire and look around.
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
		for i in 30:
			await process_frame
			motion(-3.0, 2.0)
		capture("look", size)
		# Look straight down at the local player's own position.
		session.pitch = -1.35
		input_helper.active = false
		for i in 30: await process_frame
		capture("feet", size)
		session.pitch = 0.0
		input_helper.active = true
		key_event(KEY_W, false)
		for i in 10: await process_frame
	session.client.disconnect_server()
	quit(0)
