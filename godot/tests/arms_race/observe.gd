extends SceneTree
## Test-only observer/driver. Reads public snapshots/map geometry, emits only
## Godot keyboard/mouse events. No packets, state writes, clocks or physics.
var demo: Node
var hud: Node
var age := 0.0
var directory := ""
var attempt := 0
var lifecycle := false
var captures: Dictionary = {}
var busy := false
var held: Dictionary = {}
var mouse_down := false
var state: Dictionary = {}
var events: Array = []
var control_age := 0.0
var promoted := false
var results_age := 0.0
var restart_age := 0.0
var restart_requested := false
var stage := 0
var origin := Vector3.ZERO
var fresh_moved := false
var map: Dictionary = {}
var grid := AStarGrid2D.new()

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-out="): directory = arg.trim_prefix("--evidence-out=")
		if arg.begins_with("--attempt="): attempt = int(arg.trim_prefix("--attempt="))
		if arg == "--check-lifecycle": lifecycle = true
	demo = load("res://arms_race/demo.tscn").instantiate()
	root.add_child.call_deferred(demo)
	call_deferred("bind")

func bind() -> void:
	hud = demo.get_node("GameHUD")
	demo.client.snapshot.connect(func(frame: Dictionary) -> void:
		state = frame.state
		print("ARMS_SNAPSHOT ", JSON.stringify({"seq":frame.seq,"round":demo.round_starts,"ack":demo.client.last_ack,"actor":demo.presentation.local_actor,"current":hud.progress.current,"next":hud.progress.next,"transition":hud.progress.transition,"captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED})))
	demo.client.events.connect(func(items: Array) -> void:
		for item: Dictionary in items:
			if item.type in ["armsrace-promote", "armsrace-demote", "armsrace-win", "death", "damage"]:
				events.append(item)
				print("ARMS_EVENT ", JSON.stringify(item)))
	map = demo.catalog.resolve_map(demo.current_id)
	if attempt:
		grid.region = Rect2i(-24, -20, 49, 41)
		grid.cell_size = Vector2(2, 2)
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.update()
		for x: int in range(-24, 25):
			for z: int in range(-20, 21):
				for b: Dictionary in map.get("blocks", []):
					if float(b.h) > 0.4 and absf(x*2-float(b.x)) < float(b.w)/2+0.9 and absf(z*2-float(b.z)) < float(b.d)/2+0.9:
						grid.set_point_solid(Vector2i(x,z))
						break

func key(code: int, down: bool) -> void:
	if held.get(code, false) == down: return
	held[code] = down
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(code: int) -> void:
	key(code, true)
	key(code, false)

func mouse(down: bool) -> void:
	if mouse_down == down: return
	mouse_down = down
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = root.size / 2
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func release() -> void:
	for code: int in held.keys(): key(code, false)
	mouse(false)
	tap(KEY_ESCAPE)

func pos() -> Vector3:
	var a: Dictionary = demo.presentation.local_actor
	return Vector3(a.get("x",0),a.get("y",0),a.get("z",0))

func capture(tag: String) -> void:
	if busy or captures.has(tag): return
	busy = true
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(directory.path_join(tag+".png")) != OK:
		fail("Screenshot save failed")
		return
	captures[tag] = {"seq":demo.client.last_snapshot_seq,"ack":demo.client.last_ack,"current":hud.progress.current,"next":hud.progress.next,"transition":hud.progress.transition,"outcome":hud.progress.outcome}
	print("ARMS_CAPTURE ", JSON.stringify({"tag":tag,"display":captures[tag]}))
	busy = false

func _process(delta: float) -> bool:
	age += delta
	if age > (177 if attempt else 85):
		fail("Observer wall deadline")
		return false
	if not is_instance_valid(demo) or not demo.is_node_ready(): return false
	if demo.phase == -1:
		fail(demo.label.text)
		return false
	if demo.phase == 3 and demo.received_pose and age > 3:
		capture("startup")
		if demo.catalog.entries.size() != 9: fail("Nine-map catalog lost")
	if attempt:
		for item: Dictionary in events:
			if item.type == "armsrace-promote" and item.actor == demo.client.actor_id and hud.progress.rung > 0 and demo.presentation.local_actor.get("frags",0) > 0:
				promoted = true
		if promoted:
			release()
			capture("promotion")
		if promoted and captures.has("promotion") or age > 174 or demo.phase == 4:
			release()
			capture("end")
			if captures.has("end") and not busy: finish()
			return false
		if demo.can_capture_pointer():
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				release()
				mouse(true)
			control_age += delta
			if control_age > 0.065:
				control_age = 0
				drive()
		else: release()
		return false
	if lifecycle:
		if demo.phase == 4:
			results_age += delta
			capture("results")
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or demo.presentation.lifecycle.can_control(): fail("Results controls active")
			if results_age > 1 and captures.has("results") and not restart_requested:
				key(KEY_W, true)
				tap(KEY_ENTER)
				restart_requested = true
		if demo.round_starts == 2 and demo.received_pose:
			restart_age += delta
			if stage == 0:
				origin = pos()
				mouse(true) # W held across round must prevent capture.
				stage = 1
			if stage == 1 and restart_age > 1:
				if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or pos().distance_to(origin) > 0.1: fail("Held W leaked over restart")
				release()
				mouse(true)
				mouse(false)
				key(KEY_W, true)
				stage = 2
			if stage == 2 and restart_age > 2:
				fresh_moved = pos().distance_to(origin) > 0.5
				if not fresh_moved: fail("Fresh native input did not move after restart")
				release()
				capture("restart")
				if captures.has("restart") and not busy: finish()
	elif age > 6 and captures.has("startup"):
		finish()
	return false

func finish() -> void:
	print("ARMS_ENDED ", JSON.stringify({"attempt":attempt,"promoted":promoted,"age":age,"rounds":demo.round_starts,"results":demo.round_results,"fresh_moved":fresh_moved,"captures":captures,"ack":demo.client.last_ack}))
	quit()

func free_cell(point: Vector2) -> Vector2i:
	var center := Vector2i((point/2).round())
	for radius: int in range(8):
		for x: int in range(center.x-radius, center.x+radius+1):
			for z: int in range(center.y-radius, center.y+radius+1):
				var cell := Vector2i(x,z)
				if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell): return cell
	return Vector2i.ZERO

func visible_target(a: Vector3, b: Vector3) -> bool:
	# Test-driver approximation from public solid boxes, not authoritative raycast.
	for block: Dictionary in map.get("blocks", []):
		var bounds := AABB(Vector3(block.x-block.w/2,0,block.z-block.d/2),Vector3(block.w,block.h,block.d))
		if bounds.intersects_segment(a,b) != null: return false
	return true

func drive() -> void:
	var a: Dictionary = demo.presentation.local_actor
	var eye: Vector3 = demo.presentation.eye_position()
	var target: Dictionary = {}
	var best := INF
	for other: Dictionary in state.get("actors", []):
		if other.id == demo.client.actor_id or other.health <= 0: continue
		var point := Vector3(other.x,other.y+1.0,other.z)
		var distance := eye.distance_to(point)
		var score := distance + (0 if visible_target(eye,point) else 100)
		if score < best:
			best = score
			target = other
	if target.is_empty():
		mouse(false)
		return
	var goal := Vector3(target.x,target.y+1.0,target.z)
	var visible := visible_target(eye,goal)
	var route_point := Vector2(goal.x,goal.z)
	if not visible:
		var path := grid.get_point_path(free_cell(Vector2(a.x,a.z)),free_cell(route_point))
		if path.size() > 1: route_point = path[1]
	var look := goal-eye if visible else Vector3(route_point.x-a.x,0,route_point.y-a.z)
	var desired_yaw := atan2(-look.x,-look.z)
	var desired_pitch := atan2(look.y,Vector2(look.x,look.z).length())
	# Public recoil is compensated only by ordinary mouse movement.
	if visible:
		desired_yaw -= float(a.get("punchYaw",0))
		desired_pitch -= float(a.get("punchPitch",0))
	var yaw_error := wrapf(desired_yaw-demo.yaw,-PI,PI)
	var pitch_error: float = desired_pitch-demo.pitch
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(-clampf(yaw_error,-0.25,0.25),-clampf(pitch_error,-0.2,0.2))/0.003
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	key(KEY_W, absf(yaw_error) < 0.4 and (not visible or eye.distance_to(goal) > 12))
	key(KEY_R, int(a.ammo[int(a.weapon)]) <= 0 and not a.get("reloading",false))
	mouse(visible and absf(yaw_error) < 0.12 and absf(pitch_error) < 0.12)
