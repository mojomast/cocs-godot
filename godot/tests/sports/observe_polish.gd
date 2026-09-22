extends SceneTree
## Short real-server visual check. Only native key events; no state/time writes.
const Demo = preload("res://sports/demo.gd")
var demo
var age := 0.0
var active_age := 0.0
var stage := -1
var directory := ""
var captures: Dictionary = {}
var capture_busy := false

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--polish-out="): directory = arg.trim_prefix("--polish-out=")
	demo = Demo.new()
	root.add_child.call_deferred(demo)

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _process(delta: float) -> bool:
	age += delta
	if age > 25:
		push_error("Polish visual deadline")
		quit(1)
		return false
	if not is_instance_valid(demo) or not demo.is_node_ready(): return false
	if demo.phase == "error":
		push_error(demo.error)
		quit(1)
		return false
	if not demo.vehicle.is_empty() and not capture_busy:
		var sports_phase: String = demo.state.get("race", {}).get("phase", "")
		if sports_phase in ["countdown", "kickoff"] and age > 1 and not captures.has("countdown"):
			capture_image.call_deferred("countdown")
		elif demo.chase.obstructed and not captures.has("near-wall"):
			capture_image.call_deferred("near-wall")
		elif active_age > 2 and not captures.has("driving"):
			capture_image.call_deferred("driving")
	if demo.eligible():
		active_age += delta
		var next := mini(int(active_age / 2), 4)
		if stage != next:
			stage = next
			for code in [KEY_W, KEY_S, KEY_A, KEY_D]: key(code, false)
			match stage:
				0: key(KEY_ENTER, true); key(KEY_ENTER, false); key(KEY_S, true)
				1: key(KEY_S, true); key(KEY_D if demo.map_id == "ion-speedway" else KEY_A, true)
				2: key(KEY_W, true); key(KEY_A, true)
				3: key(KEY_W, true)
				4: key(KEY_ESCAPE, true); key(KEY_ESCAPE, false)
	if active_age > 8.5 and not capture_busy:
		if not captures.has("released"): capture_image.call_deferred("released")
		else:
			print("POLISH_LIVE_ENDED ", JSON.stringify({"map":demo.map_id, "captures":captures, "last_seq":demo.net.last_snapshot_seq}))
			quit()
	return false

func capture_image(label: String) -> void:
	if capture_busy: return
	capture_busy = true
	await RenderingServer.frame_post_draw
	check_ui(demo.hud)
	var v: Dictionary = demo.vehicle
	var node = demo.fleet.vehicle_node(v.id)
	var p := Vector3(v.x, v.y, v.z)
	assert(node.position.is_equal_approx(p), "render uses accepted vehicle")
	var path := directory.path_join(label + ".png")
	var result := root.get_texture().get_image().save_png(path)
	assert(result == OK)
	captures[label] = true
	print("POLISH_LIVE_CAPTURE ", JSON.stringify({"label":label,"seq":demo.net.last_snapshot_seq,"ack":demo.net.last_ack,"vehicle":v,"camera":[demo.chase.eye.x,demo.chase.eye.y,demo.chase.eye.z],"obstructed":demo.chase.obstructed,"candidates":demo.chase.last_candidates,"hud":demo.hud.text,"path":path}))
	capture_busy = false

func check_ui(node: Node) -> void:
	if node is Control:
		assert(node.mouse_filter == Control.MOUSE_FILTER_IGNORE and node.focus_mode == Control.FOCUS_NONE, "HUD stays passive")
		if node is Label:
			assert(root.get_visible_rect().encloses(node.get_global_rect()), "HUD label fits viewport")
	for child: Node in node.get_children(): check_ui(child)
