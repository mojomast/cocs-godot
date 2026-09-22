extends SceneTree
## Graphical observer/input driver around the shipped scene. Only native events.
var session: Node
var output := ""
var route_file := ""
var saved := false
var waypoints: Array = []
var waypoint := 0
var reason := ""
var samples := 0
var capture_proven := false
var held_proven := false
var source_results := false
var checks := 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--route="): route_file = arg.trim_prefix("--route=")
	call_deferred("run")

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		push_error(message)
		quit(2)
	return ok

func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func click() -> void:
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = Vector2(750,450)
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func look(target: Vector2, pos: Vector2) -> void:
	var angle := atan2(-(target.x-pos.x), -(target.y-pos.y))
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(-wrapf(angle-session.yaw,-PI,PI)/0.003,(session.pitch+0.06)/0.003)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func observe(frame: Dictionary) -> void:
	if session.phase != 3: return
	for zone: Dictionary in frame.state.objectives.zones:
		if not session.zone_renderer.markers.has(zone.id): continue
		var marker: Node3D = session.zone_renderer.markers[zone.id]
		check(marker.position.is_equal_approx(Vector3(zone.x,zone.y,zone.z)), "rendered marker source coordinates")
		samples += 1
	var actor: Dictionary = session.presentation.local_actor
	if actor.is_empty(): return
	capture_proven = capture_proven or actor.scoreStats.objectiveCaptures > 0
	held_proven = held_proven or actor.scoreStats.objectiveTime >= 1

func screenshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output + "/" + name + ".png") == OK, "screenshot save")
	var panel: Control = session.zone_hud.zone_panel
	check(Rect2(Vector2.ZERO,root.size).encloses(panel.get_global_rect()), "compact zone HUD fits viewport")

func run() -> void:
	var deadline := Time.get_ticks_msec() + 85000
	session = load("res://zone_modes/demo.tscn").instantiate()
	root.add_child(session)
	session.client.snapshot.connect(observe)
	session.client.results.connect(func(_frame: Dictionary) -> void: source_results = true)
	while not session.can_capture_pointer() or not FileAccess.file_exists(route_file):
		await process_frame
		if Time.get_ticks_msec() > deadline: check(false,"initial authority/route deadline"); return
	var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(route_file))
	if route.has("error"): reason = JSON.stringify(route)
	else: waypoints = route.waypoints
	key(KEY_W,true)
	click()
	if not check(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED,"held movement blocks initial capture"): return
	key(KEY_W,false)
	click()
	if not check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"fresh click captures"): return
	key(KEY_ESCAPE,true)
	key(KEY_ESCAPE,false)
	if not check(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED,"Escape releases"): return
	click()
	while session.phase == 3:
		if Time.get_ticks_msec() > deadline: check(false,"natural results deadline"); return
		var actor: Dictionary = session.presentation.local_actor
		if not actor.is_empty() and not session.zones.projection.is_empty():
			var time: float = session.zones.projection.time
			# First source hill only: follow subsequent rotations visually, without
			# pretending a stale route is the current source target.
			var route_current: bool = not route.has("error") and session.zones.projection.zones.any(func(z: Dictionary) -> bool: return z.id == route.zone.id and z.x == route.zone.x and z.z == route.zone.z)
			if route_current and not waypoints.is_empty() and time < 45 and session.can_capture_pointer():
				if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
					key(KEY_W,false)
					key(KEY_CTRL,false)
					click()
				var pos := Vector2(actor.x,actor.z)
				var target := Vector2(waypoints[waypoint][0],waypoints[waypoint][1])
				if pos.distance_to(target) < 0.55 and waypoint < waypoints.size()-1:
					waypoint += 1
					target = Vector2(waypoints[waypoint][0],waypoints[waypoint][1])
				look(target,pos)
				key(KEY_CTRL,pos.distance_to(target)<3)
				key(KEY_W,pos.distance_to(target)>0.4)
			else:
				key(KEY_W,false)
				key(KEY_CTRL,false)
			if not saved and (held_proven or time > 24):
				await screenshot("gameplay")
				saved = true
				print("ZONE_APPROACH ",JSON.stringify({"source_time":time,"actor":actor,"route":route,"waypoint":waypoint,"captured":capture_proven,"held":held_proven}))
		await create_timer(0.05).timeout
	key(KEY_W,false)
	key(KEY_CTRL,false)
	if not check(source_results and session.phase == 4 and not session.can_capture_pointer() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED,"natural results release controls"): return
	await create_timer(0.15).timeout
	await screenshot("results")
	key(KEY_W,true)
	key(KEY_ENTER,true)
	key(KEY_ENTER,false)
	while session.round_starts < 2 or not session.can_capture_pointer():
		await process_frame
		if Time.get_ticks_msec() > deadline: check(false,"restart deadline"); return
	if not check(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED,"restart has no inherited capture"): return
	click()
	if not check(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED,"held movement blocks restart capture"): return
	key(KEY_W,false)
	click()
	if not check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"fresh restart capture"): return
	print("ZONE_LIVE_OK ",JSON.stringify({"capture":capture_proven,"held_score":held_proven,"results":source_results,"rounds":session.round_starts,"rendered_samples":samples,"checks":checks,"route_error":reason,"final_position":session.presentation.local_actor,"normal_rate":true}))
	session.client.disconnect_server()
	await create_timer(0.4).timeout
	quit()
