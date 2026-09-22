extends SceneTree
## Harness-only native physical events. No server or snapshot mutation.
const Demo = preload("res://sports/demo.gd")
var demo
var age := 0.0
var sample_age := 0.0
var driving_age := -1.0
var stage := -1
var capture := ""
var captured := false
var stage_started := 0.0
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--sports-capture="): capture = arg.trim_prefix("--sports-capture=")
	demo = Demo.new()
	root.add_child.call_deferred(demo)
func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	print("SPORT_EVENT ", JSON.stringify({"seconds":age,"key":code,"pressed":down}))
func tap(code: int) -> void:
	key(code, true)
	key(code, false)
func change(next: int) -> void:
	stage_started = age
	stage = next
	for code in [KEY_W, KEY_S, KEY_A, KEY_D, KEY_SPACE, KEY_SHIFT, KEY_R]: key(code, false)
	match stage:
		0: tap(KEY_ENTER); key(KEY_W, true)
		1: key(KEY_W, true); key(KEY_D, true)
		2: key(KEY_SPACE, true)
		3: key(KEY_S, true)
		4: tap(KEY_ESCAPE); key(KEY_W, true)
		5: tap(KEY_ENTER); key(KEY_W, true); key(KEY_SHIFT, true)
		6:
			demo.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			key(KEY_W, true)
		7: demo.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN); key(KEY_W, true)
		8: tap(KEY_ENTER); key(KEY_W, true)
		9: key(KEY_R, true)
		10: tap(KEY_ESCAPE)
	print("SPORT_STAGE ", JSON.stringify({"stage":stage,"seconds":age}))
func _process(delta: float) -> bool:
	age += delta
	if age > 40:
		push_error("Live native deadline")
		quit(1)
		return false
	if not is_instance_valid(demo) or not demo.is_node_ready(): return false
	if demo.phase == "error":
		push_error(demo.error)
		quit(1)
		return false
	if driving_age < 0 and demo.eligible(): driving_age = 0
	if driving_age >= 0:
		driving_age += delta
		var next := mini(int(driving_age / 1.5), 10)
		if next != stage: change(next)
		if driving_age > 5 and not captured and not capture.is_empty():
			captured = true
			capture_image.call_deferred()
		if driving_age > 17:
			print("SPORT_OBSERVATION_ENDED no_native_completion_marker=true")
			quit()
	sample_age += delta
	if sample_age >= 0.2 and age - stage_started > 0.15 and not demo.vehicle.is_empty():
		sample_age = 0
		var v: Dictionary = demo.vehicle
		var n = demo.fleet.vehicle_node(v.id)
		print("SPORT_SAMPLE ", JSON.stringify({"seconds":age,"stage":stage,"actor":demo.net.actor_id,"ack":demo.net.last_ack,"seq":demo.net.last_snapshot_seq,"engaged":demo.controls.engaged,"focused":demo.controls.focused,"phase":demo.state.get("race",{}).get("phase"),"v":v,"render":[n.position.x,n.position.y,n.position.z],"camera":[demo.world.camera.position.x,demo.world.camera.position.y,demo.world.camera.position.z],"ball":demo.state.get("race",{}).get("ball")}))
	return false
func capture_image() -> void:
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(capture)
	print("SPORT_SCREENSHOT ", result)
	if result != OK: quit(1)
