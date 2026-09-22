extends SceneTree
## Native CharacterBody3D / collision acceptance. Walk segments use physical-key events.
const DEMO = preload("res://showcase/demo.tscn")
var scene: Node3D
var player: CharacterBody3D
var failures: Array[String] = []
var checks: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks.append(description)
	if not ok:
		failures.append(description)
		push_error("PRISM_PHYSICS_FAIL " + description)

func frames(count: int) -> void:
	for frame in count: await physics_frame

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)

func walk_to(target: Vector3, max_frames: int = 600) -> bool:
	player.clear_controls()
	player.rotation.y = 0
	for frame in max_frames:
		var offset := target - player.position
		if Vector2(offset.x, offset.z).length() < 0.25:
			player.clear_controls()
			await frames(8)
			return true
		key(KEY_D, offset.x > 0.13)
		key(KEY_A, offset.x < -0.13)
		key(KEY_S, offset.z > 0.13)
		key(KEY_W, offset.z < -0.13)
		await physics_frame
	player.clear_controls()
	return false

func run() -> void:
	var original_msaa := root.msaa_3d
	scene = DEMO.instantiate()
	root.add_child(scene)
	player = scene.player
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await frames(12)
	check(player.is_on_floor() and absf(player.position.y) < 0.08, "spawn settles on native floor")
	var spawn := player.position
	key(KEY_W, true)
	await frames(45)
	key(KEY_W, false)
	await frames(8)
	check(player.position.z < spawn.z - 3.0 and player.is_on_floor(), "physical W walks forward with floor contact")
	key(KEY_W, true)
	key(KEY_SHIFT, true)
	await frames(8)
	var sprint_start := player.position.z
	await frames(18)
	key(KEY_W, false)
	key(KEY_SHIFT, false)
	player.clear_controls()
	check(sprint_start - player.position.z > 1.9, "physical Shift increases native movement speed")
	var before_jump := player.position.y
	key(KEY_SPACE, true)
	await frames(12)
	key(KEY_SPACE, false)
	check(player.position.y > before_jump + 0.65, "space produces native ballistic jump")
	await frames(60)
	check(player.is_on_floor(), "jump lands on collision floor")
	# Ground-to-upper loop by ramp, around all four sides, back down opposite ramp.
	check(await walk_to(Vector3(10.5, 0, 8.3)), "walk to east ramp foot")
	check(await walk_to(Vector3(10.5, 4, -12.4)), "ascend east ramp via CharacterBody move_and_slide")
	check(player.position.y > 3.9 and player.is_on_floor(), "ramp reaches 4 m upper landing")
	check(await walk_to(Vector3(10.5, 4, -14.5)), "join north mezzanine")
	check(await walk_to(Vector3(15.3, 4, -14.5)), "north to east mezzanine corner")
	check(await walk_to(Vector3(15.3, 4, 0)), "traverse upper east catwalk")
	check(await walk_to(Vector3(33.4, 4, 0)), "walk through upper portal to exterior deck")
	check(player.position.y > 3.9 and player.is_on_floor(), "exterior deck supports native player")
	check(await walk_to(Vector3(33.4, 4, 1.8)), "walk around telescope toward exterior guard")
	key(KEY_D, true)
	await frames(90)
	key(KEY_D, false)
	check(player.position.x < 36.3 and player.position.x > 35.7, "exterior guard collision prevents walking out of bounds")
	check(await walk_to(Vector3(24, 4, 1.8)), "leave exterior guard along clear deck aisle")
	check(await walk_to(Vector3(15.3, 4, 0)), "return from exterior deck")
	check(await walk_to(Vector3(15.3, 4, 14.5)), "east to south upper corner")
	check(await walk_to(Vector3(-15.3, 4, 14.5)), "cross south upper bridge")
	check(await walk_to(Vector3(-15.3, 4, -14.5)), "walk full west upper catwalk")
	check(await walk_to(Vector3(-10.5, 4, -14.5)), "west to north upper corner")
	check(await walk_to(Vector3(-10.5, 4, -12.4)), "join west ramp landing")
	check(await walk_to(Vector3(-10.5, 0, 8.3)), "descend west ramp to floor")
	check(player.position.y < 0.1 and player.is_on_floor(), "descending ramp returns to ground")
	# Other connected rooms reached on foot, keeping clear of the reactor plinth.
	check(await walk_to(Vector3(-15.3, 0, 8.3)), "cross under west mezzanine")
	check(await walk_to(Vector3(-15.3, 0, 0)), "approach turbine portal")
	check(await walk_to(Vector3(-29.5, 0, 0)), "walk into turbine hall")
	check(await walk_to(Vector3(-23.0, 0, 0)), "leave turbine equipment aisle")
	check(await walk_to(Vector3(-15.3, 0, 0)), "return to atrium")
	check(await walk_to(Vector3(-15.3, 0, -16)), "walk north ground perimeter")
	check(await walk_to(Vector3(0, 0, -16)), "approach coolant portal")
	check(await walk_to(Vector3(0, 0, -30)), "walk into coolant garden")
	check(player.is_on_floor(), "garden walkway supports player")
	# A room wall is solid, not just the railing proxy.
	check(await walk_to(Vector3(0, 0, -20.8)), "return along garden center walkway")
	check(await walk_to(Vector3(10.7, 0, -20.8)), "reach garden east wall aisle without crossing raised basin")
	key(KEY_D, true)
	await frames(60)
	key(KEY_D, false)
	check(player.position.x < 12.0, "garden wall blocks capsule")
	# Falling and lateral world-bound errors reset deterministically.
	var resets: int = player.reset_count
	player.position = Vector3(50, 1, 0)
	player.velocity = Vector3.ZERO
	await frames(95)
	check(player.reset_count == resets + 1 and player.position.distance_to(player.spawn_position) < 0.2, "native gravity fall outside platform resets to spawn")
	player.position = Vector3(70, 0, 0)
	await frames(3)
	check(player.reset_count == resets + 2, "lateral out-of-bounds resets")
	player.position = Vector3(8, 0, 12)
	key(KEY_R, true)
	await frames(2)
	key(KEY_R, false)
	check(player.position.distance_to(player.spawn_position) < 0.2, "physical R returns to arrival")
	# Focus notifications use the same branch as OS window focus loss.
	key(KEY_W, true)
	key(KEY_SHIFT, true)
	key(KEY_SPACE, true)
	player.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(player.keys.is_empty() and not player.jump_pending and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "focus loss clears movement sprint jump and releases capture")
	click()
	await frames(1)
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "left click recaptures mouse")
	key(KEY_ESCAPE, true)
	await frames(1)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and player.keys.is_empty(), "escape releases mouse and clears controls")
	click()
	await frames(1)
	var yaw := player.rotation.y
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(30, -10)
	Input.parse_input_event(motion)
	await frames(1)
	check(player.rotation.y < yaw - 0.04 and player.camera.rotation.x > 0, "captured relative mouse controls yaw and pitch")
	key(KEY_P, true)
	await frames(2)
	key(KEY_P, false)
	check(scene.tour_index == 0 and not player.controls_enabled and player.keys.is_empty(), "photo view clears movement and selects separate camera")
	key(KEY_P, true)
	await frames(2)
	key(KEY_P, false)
	check(scene.tour_index == -1 and player.controls_enabled and player.camera.current, "P returns to same physical explorer")
	var stable_nodes: int = scene._node_count(scene)
	await frames(180)
	check(scene._node_count(scene) == stable_nodes, "animated machinery causes no per-frame node churn")
	var weak_scene: WeakRef = weakref(scene)
	var weak_player: WeakRef = weakref(player)
	var weak_camera: WeakRef = weakref(player.camera)
	scene.queue_free()
	await frames(4)
	check(weak_scene.get_ref() == null and weak_player.get_ref() == null and weak_camera.get_ref() == null, "scene teardown frees map player cameras and children")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "teardown leaves cursor released")
	check(root.msaa_3d == original_msaa, "teardown restores caller viewport antialiasing")
	print("PRISM_PHYSICS_RESULT ", JSON.stringify({"checks": checks.size(), "failures": failures, "details": checks}))
	quit(0 if failures.is_empty() else 1)
