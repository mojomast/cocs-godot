extends SceneTree
## Engine input-path acceptance of the real command-line scene, no state writes.
var demo: Node
var output := ""
var checks := 0
var failures := 0
var started := 0
var last_seq := -1
var initial := Vector3.ZERO
var maximum_distance := 0.0

func _initialize() -> void:
	started = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--world-output="): output = arg.trim_prefix("--world-output=")
	call_deferred("run")

func record(event: String, details: Dictionary = {}) -> void:
	details.event = event
	details.ms = Time.get_ticks_msec() - started
	print("WORLD_NATIVE ", JSON.stringify(details))

func check(value: bool, message: String) -> bool:
	checks += 1
	if not value: failures += 1; push_error(message)
	record("check", {"ok":value,"message":message})
	return value

func wait_for(condition: Callable, message: String, seconds: float = 15) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not condition.call() and Time.get_ticks_msec() < deadline: await process_frame
	return check(condition.call(), message)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func click() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = root.size * 0.5
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func look_at_point(point: Vector2) -> void:
	var actor: Dictionary = demo.presentation.local_actor
	var yaw_target := atan2(-(point.x - actor.x), -(point.y - actor.z))
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(-wrapf(yaw_target - demo.yaw, -PI, PI) / 0.003, demo.pitch / 0.003)
	Input.parse_input_event(event)
	await process_frame

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "saved " + name)

func coords(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func _process(_delta: float) -> bool:
	if not is_instance_valid(demo) or not demo.received_pose or demo.client.last_snapshot_seq == last_seq: return false
	last_seq = demo.client.last_snapshot_seq
	var a: Dictionary = demo.presentation.local_actor
	maximum_distance = maxf(maximum_distance, initial.distance_to(Vector3(a.x,a.y,a.z)))
	var rendered := []
	for id: int in demo.presentation.actors:
		var visual: Node3D = demo.presentation.actors[id]
		rendered.append({"id":id,"position":coords(visual.position),"visible":visual.visible})
	record("pose", {"seq":last_seq,"ack":demo.client.last_ack,"actor":demo.client.actor_id,"own":[a.x,a.y,a.z],"eyeHeight":a.get("eyeHeight",1.45),"camera":coords(demo.camera.position),"rendered":rendered,"captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED})
	return false

func run() -> void:
	await process_frame
	demo = current_scene
	if not check(demo != null and demo.scene_file_path == "res://lattice/world_demo.tscn", "real standalone scene loaded"): quit(1); return
	if not await wait_for(func() -> bool: return demo.can_capture_pointer(), "normal host receives owned actor"): quit(1); return
	var a: Dictionary = demo.presentation.local_actor
	initial = Vector3(a.x,a.y,a.z)
	maximum_distance = 0.0
	var map: Dictionary = demo.catalog.resolve_map(demo.current_id)
	check(demo.world.get_meta("semantic_block_count") == map.blocks.size() and demo.world.get_meta("semantic_triangle_count") == map.terrain.support_triangles.size(), "full authored geometry retained")
	record("geometry", {"blocks":map.blocks.size(),"triangles":map.terrain.support_triangles.size(),"landmarks":map.landmarks})
	var landmark_matches := 0
	for landmark: Dictionary in map.landmarks:
		for child: Node in demo.world.find_children("*", "Label3D", true, false):
			if child.text == landmark.label and child.position.is_equal_approx(Vector3(landmark.x,landmark.y+0.5,landmark.z)):
				landmark_matches += 1
	check(landmark_matches == map.landmarks.size(), "authored landmark labels match exact source anchors")
	await capture("startup")
	await click()
	if not check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "mouse click captures pointer"): quit(1); return
	var target: Dictionary = {}
	for node: Dictionary in demo.client.projection.nodes:
		if node.id == "front-%d" % int(demo.client.projection.team): target = node
	if not check(not target.is_empty(), "own-front public target available"): quit(1); return
	var target_point := Vector2(target.x,target.z)
	var before: float = demo.yaw
	await look_at_point(target_point)
	check(absf(wrapf(demo.yaw-before,-PI,PI)) > 0.001, "native mouse motion changes look")
	await key(KEY_W, true)
	await create_timer(2.0).timeout
	await key(KEY_W, false)
	await create_timer(0.4).timeout
	var walked: Vector3 = demo.camera.position
	check(Vector2(walked.x-initial.x,walked.z-initial.z).length() > 2.0, "W produces authoritative displacement")
	await key(KEY_ESCAPE,true)
	await key(KEY_ESCAPE,false)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape releases pointer")
	await key(KEY_W,true)
	await click()
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "held movement prevents recapture")
	await create_timer(0.6).timeout
	check(demo.camera.position.distance_to(walked) < 0.1, "released controls send neutral and stop displacement")
	await key(KEY_W,false)
	await click()
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "fresh click resumes after key release")
	# Every ordinary movement key traverses the inherited physical-key path.
	for code: Key in [KEY_A,KEY_S,KEY_D]:
		await key(code,true)
		await create_timer(0.2).timeout
		await key(code,false)
	# Normal-rate local approach, bounded; route input never writes pose or sim.
	# Both HQ walls have a central doorway at z=0. Follow authored portals
	# rather than indefinitely pressing into a wall on the direct node bearing.
	# These are observer-only waypoints; the playable scene has no autopilot.
	var route: Array[Vector2] = [Vector2(-98,0),Vector2(-84,0),Vector2(-70,target_point.y)]
	route.append(target_point)
	var waypoint := 0
	var deadline := Time.get_ticks_msec() + 20000
	await key(KEY_W,true)
	while Time.get_ticks_msec() < deadline and demo.can_capture_pointer():
		a = demo.presentation.local_actor
		if Vector2(a.x,a.z).distance_to(route[waypoint]) < 2.0:
			waypoint += 1
			if waypoint == route.size(): break
		await look_at_point(route[waypoint])
		await create_timer(0.1).timeout
	await key(KEY_W,false)
	await create_timer(0.5).timeout
	a = demo.presentation.local_actor
	var remaining := Vector2(a.x,a.z).distance_to(target_point)
	record("approach", {"target":target.id,"distance":remaining,"maxDisplacement":maximum_distance,"own":[a.x,a.y,a.z],"node":target,"captureClaim":false})
	var objective_markers := []
	for id: String in demo.lattice_hud.markers:
		objective_markers.append({"id":id,"anchor":coords(demo.lattice_hud.markers[id].position)})
	record("objective-markers", {"markers":objective_markers,"nodes":demo.client.projection.nodes})
	check(maximum_distance > 5.0, "resume continues source movement")
	await capture("walk")
	# Observe automatic public progression briefly; never issue HOLD or claim
	# local completion from an order or an unrelated team's capture.
	await create_timer(4.0).timeout
	for node: Dictionary in demo.client.projection.nodes:
		if node.id == target.id: record("objective-observed", {"node":node,"ownDistance":remaining})
	await key(KEY_ESCAPE,true)
	await key(KEY_ESCAPE,false)
	await capture("released")
	check(demo.client.actions.is_empty(), "walk sent no HOLD/economy commands")
	record("result", {"checks":checks,"failures":failures,"maxDisplacement":maximum_distance,"targetDistance":remaining})
	demo.client.disconnect_server()
	quit(0 if failures == 0 else 1)
