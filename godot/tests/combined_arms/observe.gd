extends SceneTree
## Acceptance commands only: native physical keys/mouse; never authority writes.
const Demo = preload("res://combined_arms/demo.gd")
var demo
var age := 0.0
var stage := "setup"
var stage_at := 0.0
var capture_dir := ""
var attached := false
var route: Array[Vector2] = []
var waypoint := 0
var mounted_origin := Vector2.ZERO
var exit_origin := Vector2.ZERO
var screenshot_busy := false
var shot960 := false
var shot1280 := false
var last_seq := -1

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence="): capture_dir = arg.trim_prefix("--evidence=")
	demo = Demo.new()
	root.add_child.call_deferred(demo)

func key(code: int, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)
	print("CA_EVENT ", JSON.stringify({"seconds":age,"key":code,"pressed":pressed}))

func tap(code: int) -> void:
	key(code, true)
	key(code, false)

func change(next: String) -> void:
	for code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_SHIFT, KEY_E]: key(code, false)
	stage = next
	stage_at = age
	print("CA_STAGE ", JSON.stringify({"seconds":age,"stage":stage}))

func turn_towards(point: Vector2) -> void:
	var a: Dictionary = demo.actor
	var delta := point-Vector2(a.x, a.z)
	var wanted := atan2(-delta.x, -delta.y)
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(-wrapf(wanted-demo.yaw, -PI, PI)/0.003, demo.pitch/0.003)
	Input.parse_input_event(mouse)

func sample() -> void:
	if demo.net.last_snapshot_seq == last_seq: return
	last_seq = demo.net.last_snapshot_seq
	var roots: Dictionary = {}
	for id: Variant in demo.fleet.nodes:
		var p: Vector3 = demo.fleet.nodes[id].position
		roots[str(id)] = [p.x, p.y, p.z]
	for id: Variant in demo.fleet.secondary:
		var p: Vector3 = demo.fleet.secondary[id].position
		roots[str(id)] = [p.x, p.y, p.z]
	print("CA_SAMPLE ", JSON.stringify({"seconds":age,"stage":stage,"seq":last_seq,"ack":demo.net.last_ack,"actor_id":demo.net.actor_id,"actor":demo.actor,"vehicle":demo.vehicle,"render":roots,"camera":[demo.world.camera.position.x,demo.world.camera.position.y,demo.world.camera.position.z],"engaged":demo.controls.engaged,"eligible":demo.eligible()}))

func capture(size: Vector2i, label: String) -> void:
	screenshot_busy = true
	root.size = size
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var code := root.get_texture().get_image().save_png(capture_dir+"/"+label+".png")
	print("CA_SCREENSHOT ", JSON.stringify({"label":label,"result":code,"size":[size.x,size.y]}))
	screenshot_busy = false
	if code != OK: quit(1)

func _process(delta: float) -> bool:
	age += delta
	if age > 115:
		push_error("Combined-arms 115 second acceptance deadline at "+stage)
		quit(1)
		return false
	if not is_instance_valid(demo) or not demo.is_node_ready(): return false
	if not attached:
		attached = true
		demo.input_queued.connect(func(seq: int, p: Dictionary, result: int) -> void:
			print("CA_QUEUE ", JSON.stringify({"seconds":age,"stage":stage,"seq":seq,"packet":p,"result":result})))
	if demo.phase == "error":
		push_error(demo.error)
		quit(1)
		return false
	if demo.actor.is_empty(): return false
	sample()
	var a: Dictionary = demo.actor
	var pos := Vector2(a.x, a.z)
	match stage:
		"setup":
			if not demo.eligible(): return false
			# Authored west spawn corridor -> road -> source Puma, unseeded spawn.
			route = [Vector2(-80, pos.y), Vector2(-80, -10), Vector2(-62, -10), Vector2(-62, -6)]
			change("walk")
			tap(KEY_ENTER)
		"walk":
			if pos.distance_to(route[waypoint]) < 0.6:
				waypoint += 1
				key(KEY_W, false)
				if waypoint == route.size():
					change("mount-request")
					tap(KEY_E)
					return false
			turn_towards(route[waypoint])
			if not demo.controls.keys.has(KEY_W): key(KEY_W, true)
		"mount-request":
			if not demo.vehicle.is_empty():
				mounted_origin = Vector2(demo.vehicle.x, demo.vehicle.z)
				change("mounted")
				tap(KEY_ENTER)
			elif age-stage_at > 3:
				push_error("Source mount receipt did not produce driver relation")
				quit(1)
		"mounted":
			if age-stage_at > 0.5 and not shot960:
				shot960 = true
				capture.call_deferred(Vector2i(960, 600), "mounted-960")
			if shot960 and not screenshot_busy and age-stage_at > 1.3:
				change("drive")
				key(KEY_W, true)
		"drive":
			if Vector2(demo.vehicle.x, demo.vehicle.z).distance_to(mounted_origin) >= 11:
				change("brake")
				key(KEY_SPACE, true)
				key(KEY_S, true)
		"brake":
			if age-stage_at > 0.2 and demo.controls.keys.has(KEY_SPACE): key(KEY_SPACE, false)
			if Vector2(demo.vehicle.vx, demo.vehicle.vz).length() < 1:
				change("released")
				tap(KEY_ESCAPE)
		"released":
			if age-stage_at > 0.7 and not shot1280:
				shot1280 = true
				capture.call_deferred(Vector2i(1280, 800), "released-1280")
			if shot1280 and not screenshot_busy and age-stage_at > 1.5:
				change("exit-request")
				tap(KEY_ENTER)
				tap(KEY_E)
		"exit-request":
			if a.get("vehicleId") == null:
				exit_origin = pos
				change("exit-neutral")
				# No Enter yet: fresh key alone must not resume infantry.
				key(KEY_W, true)
		"exit-neutral":
			if age-stage_at > 0.7:
				change("infantry-fresh")
				tap(KEY_ENTER)
				# Walk away along the source exit side, not through the chassis.
				turn_towards(pos+Vector2(0, -8))
				key(KEY_W, true)
		"infantry-fresh":
			if pos.distance_to(exit_origin) > 3:
				change("final-release")
				tap(KEY_ESCAPE)
		"final-release":
			if age-stage_at > 0.8:
				print("CA_COMPLETE ", JSON.stringify({"seconds":age,"stage":stage,"source_vehicle": "sunscar-0-puma"}))
				quit()
	return false
