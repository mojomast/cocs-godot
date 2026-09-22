extends SceneTree

# Shipped native session; snapshots, actors and camera position are unmodified.
# Automated look/movement input approaches a real pickup and points at an actor.
var session: Node
var output: String

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func run() -> void:
	session = load("res://world/session.tscn").instantiate()
	root.add_child(session)
	var deadline: int = Time.get_ticks_msec() + 15000
	while not session.received_pose and Time.get_ticks_msec() < deadline:
		await process_frame
	if not session.received_pose:
		quit(1)
		return
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await process_frame
	click.pressed = false
	Input.parse_input_event(click)
	for mode: String in ["pickup", "actor"]:
		await create_timer(1.0).timeout
		var nearest: Node3D
		var distance: float = INF
		var nodes: Array = session.pickups.markers.values() if mode == "pickup" else session.presentation.actors.values()
		for node: Node3D in nodes:
			var d: float = node.global_position.distance_to(session.camera.global_position)
			if node.visible and d < distance:
				nearest = node
				distance = d
		if nearest == null:
			quit(2)
			return
		var direction: Vector3 = nearest.global_position - session.camera.global_position
		var desired_yaw: float = atan2(-direction.x, -direction.z)
		var desired_pitch: float = atan2(direction.y, Vector2(direction.x, direction.z).length())
		var mouse := InputEventMouseMotion.new()
		mouse.relative = Vector2(-wrapf(desired_yaw - session.yaw, -PI, PI) / 0.003, -(desired_pitch - session.pitch) / 0.003)
		Input.parse_input_event(mouse)
		if mode == "pickup":
			# Walk off the diagnostic spawn pillar through shipped controls.
			var forward := InputEventKey.new()
			forward.physical_keycode = KEY_W
			forward.keycode = KEY_W
			forward.pressed = true
			Input.parse_input_event(forward)
			await create_timer(0.55).timeout
			forward.pressed = false
			Input.parse_input_event(forward)
			await create_timer(0.15).timeout
		await process_frame
		await RenderingServer.frame_post_draw
		var result: Error = root.get_texture().get_image().save_png(output.path_join("native-" + mode + ".png"))
		print("PORT_ENTITY_NATIVE_CAPTURE ", JSON.stringify({"view": mode, "saved": result == OK, "snapshots": session.presentation.applied, "actors": session.presentation.actors.size(), "pickups": session.pickups.markers.size(), "target_distance": nearest.global_position.distance_to(session.camera.global_position), "phase": session.phase, "camera": str(session.camera.position), "healthy": session.presentation.lifecycle.can_control()}))
		if result != OK:
			quit(3)
			return
	session.client.disconnect_server()
	quit(0)
