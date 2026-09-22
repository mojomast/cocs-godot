extends SceneTree

# Observer/input driver around the SHIPPED session. No snapshot, camera, session
# controls, game clock, projectile or damage writes; only native Input events.
var session: Node
var output := ""
var route_file := ""
var observed := 0
var local_launches := 0
var explosions := 0
var rendered_samples := 0
var max_projectiles := 0
var saved := false
var capture: Dictionary = {}
var last_position := Vector3.ZERO
var moved := false
var ready_at := 0
var frames := 0
var route: Array = []
var waypoint := 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--route="): route_file = arg.trim_prefix("--route=")
	call_deferred("run")

func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func button(down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(800, 500)
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func look(yaw: float, pitch: float) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(-wrapf(yaw - session.yaw, -PI, PI) / 0.003, (session.pitch - pitch) / 0.003)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func fail(message: String) -> void:
	push_error(message)
	quit(2)

func wait_weapon(index: int) -> bool:
	var deadline := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if session.presentation.local_actor.get("weapon") == index: return true
	fail("Authority did not acknowledge native weapon selection")
	return false

func observe(frame: Dictionary) -> void:
	observed += 1
	var state: Dictionary = frame.state
	if state.mapId != session.current_id: fail("Wrong source map")
	if session.selected_mode == "rockets":
		for actor: Dictionary in state.actors:
			if actor.weapon != 1 or actor.ammo[1] != "∞": fail("Rocket mode lost authoritative pinned loadout")
		for pickup: Dictionary in state.pickups:
			if pickup.kind not in ["health", "armor"]: fail("Rocket supplies differ from source")
	var visuals: Node3D = session.combat.projectiles
	if not is_instance_valid(visuals): return
	max_projectiles = maxi(max_projectiles, visuals.markers.size())
	for item: Dictionary in state.rockets:
		if not visuals.markers.has(int(item.id)): fail("Missing real in-flight mesh")
		var marker: MeshInstance3D = visuals.markers[int(item.id)]
		if not marker.position.is_equal_approx(Vector3(item.pos.x,item.pos.y,item.pos.z)): fail("Mesh left source position")
		if not (-marker.basis.z).is_equal_approx(Vector3(item.dir.x,item.dir.y,item.dir.z).normalized()): fail("Mesh left source direction")
		rendered_samples += 1

func run() -> void:
	var deadline := Time.get_ticks_msec() + 55000
	session = load("res://world/session.tscn").instantiate()
	root.add_child(session)
	session.client.snapshot.connect(observe)
	session.client.events.connect(func(items: Array) -> void:
		for item: Dictionary in items:
			if item.type == "launch" and item.actor == session.client.actor_id: local_launches += 1
			if item.type == "explosion": explosions += 1)
	while not session.received_pose:
		await process_frame
		if Time.get_ticks_msec() > deadline: fail("Session connection deadline"); return
	last_position = session.camera.position
	button(true)
	button(false)
	if not route_file.is_empty():
		while not FileAccess.file_exists(route_file):
			await process_frame
			if Time.get_ticks_msec() > deadline: fail("Route file deadline"); return
		var route_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(route_file))
		if not route_value is Array or route_value.is_empty() or route_value.size() > 128:
			fail("Bounded ground-route planning failed"); return
		route = route_value
		while session.presentation.local_actor.ammo[1] == 0:
			if Time.get_ticks_msec() > deadline:
				print("PICKUP_ROUTE_TIMEOUT ", JSON.stringify({"waypoint":waypoint,"route":route,"position":[session.camera.position.x,session.camera.position.z],"focused":root.has_focus(),"captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"phase":session.phase}))
				fail("Real rocket pickup route timed out"); return
			if session.can_capture_pointer() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				button(true)
				button(false)
			var actor: Dictionary = session.presentation.local_actor
			var pos := Vector2(actor.x, actor.z)
			var target := Vector2(route[waypoint][0], route[waypoint][1])
			if pos.distance_to(target) < 0.45 and waypoint < route.size() - 1:
				waypoint += 1
				target = Vector2(route[waypoint][0], route[waypoint][1])
			look(atan2(-(target.x-pos.x), -(target.y-pos.y)), 0)
			# Slow at turns so source inertia plus delayed snapshots cannot orbit
			# a close waypoint indefinitely. This is an ordinary crouch key.
			key(KEY_CTRL, pos.distance_to(target) < 3.0)
			key(KEY_W, pos.distance_to(target) > 0.35)
			await create_timer(0.05).timeout
		key(KEY_W, false)
		key(KEY_CTRL, false)
		key(KEY_1, true)
		if not await wait_weapon(0): return
		key(KEY_1, false)
		key(KEY_2, true)
		if not await wait_weapon(1): return
		key(KEY_2, false)
		await create_timer(0.4).timeout
	ready_at = Time.get_ticks_msec()
	button(true)
	look(session.yaw, 0.08)
	key(KEY_W, true)
	while Time.get_ticks_msec() - ready_at < 14000:
		await process_frame
		frames += 1
		if Time.get_ticks_msec() > deadline: fail("Native play deadline"); return
		moved = moved or session.camera.position.distance_to(last_position) > 0.5
		if Time.get_ticks_msec() - ready_at > 1200: key(KEY_W, false)
		if session.can_capture_pointer() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			button(false)
			button(true)
		if not saved and is_instance_valid(session.combat.projectiles):
			for marker: MeshInstance3D in session.combat.projectiles.markers.values():
				if marker.get_meta("owner") != session.client.actor_id or marker.get_meta("weapon") != 1: continue
				var distance: float = marker.position.distance_to(session.camera.position)
				if distance < 2.0 or distance > 14.0 or session.camera.is_position_behind(marker.position): continue
				var pixel: Vector2 = session.camera.unproject_position(marker.position)
				if not Rect2(200,180,880,440).has_point(pixel): continue
				await RenderingServer.frame_post_draw
				if not is_instance_valid(marker): break
				pixel = session.camera.unproject_position(marker.position)
				capture = {"projectile":marker.name,"position":[marker.position.x,marker.position.y,marker.position.z],"pixel":[pixel.x,pixel.y],"distance":marker.position.distance_to(session.camera.position),"launches":local_launches}
				saved = root.get_texture().get_image().save_png(output) == OK
				break
	button(false)
	key(KEY_W, false)
	var result := {"map":session.current_id,"mode":session.selected_mode,"smoke":session.smoke,"snapshots":observed,"ack":session.client.last_ack,"local_launches":local_launches,"combat_local_launches":session.combat.local_launches,"shots":session.combat.shots,"explosions":explosions,"rendered_projectile_samples":rendered_samples,"max_projectiles":max_projectiles,"moved":moved,"saved":saved,"capture":capture,"frames":frames,"play_wall_ms":Time.get_ticks_msec()-ready_at,"trace_complete":false}
	var ok: bool = saved and moved and local_launches >= 3 and rendered_samples > 10 and explosions > 0 and not session.smoke and session.client.last_ack > 100
	print("PORT_PROJECTILE_LIVE_", "OK " if ok else "FAIL ", JSON.stringify(result))
	session.client.disconnect_server()
	# Let queued one-shot audio finish its bounded tail before destroying the
	# viewport; this also allows AudioServer to retire playback references.
	await create_timer(0.4).timeout
	quit(0 if ok else 2)
