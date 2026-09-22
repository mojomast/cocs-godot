extends "res://objectives/demo.gd"
## Live acceptance driver: emits native InputEventKey/Mouse events only.
## Does not assign actor, objective, camera pose or server state.
var active_time := 0.0
var target_index := 0
var held: Dictionary = {}
var route: Array[Vector2] = []
var stage := "approach"
var stage_time := 0.0
var capture_path := ""
var captured: Dictionary = {}
var witnessed_carry := false
var witnessed_drop := false
var initial_distance := -1.0
var progressed := false
var idle_samples := 0
var idle_distance := -1.0

func _ready() -> void:
	super._ready()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="): capture_path = arg.trim_prefix("--screenshot=")

func key(code: int, pressed: bool) -> void:
	if held.get(code, false) == pressed: return
	held[code] = pressed
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func click() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)

func on_snapshot(frame: Dictionary) -> void:
	super.on_snapshot(frame)
	if selected_mode == "ctf":
		for flag: Dictionary in frame.state.get("flags", []):
			if flag.get("carrier") == client.actor_id and flag.get("state") == "carried": witnessed_carry = true
			if witnessed_carry and flag.get("state") == "dropped": witnessed_drop = true
	else:
		var payload: Dictionary = frame.state.get("objectives", {}).get("payload", {})
		if payload.has("distance"):
			if initial_distance < 0: initial_distance = float(payload.distance)
			progressed = progressed or float(payload.distance) > initial_distance + 1.0
			if stage == "leave" and payload.get("pushing") == null and payload.get("contested") == false:
				if idle_distance == float(payload.distance): idle_samples += 1
				else: idle_samples = 0
				idle_distance = float(payload.distance)
			if stage == "approach" and point_in_range(payload):
				stage = "escort"
				stage_time = 0

func point_in_range(payload: Dictionary) -> bool:
	if not payload.has("position") or presentation.local_actor.is_empty(): return false
	var a: Dictionary = presentation.local_actor
	var p: Dictionary = payload.position
	return Vector2(a.x, a.z).distance_to(Vector2(p.x, p.z)) < 2

func screenshot(tag: String = "gameplay") -> void:
	if captured.has(tag) or capture_path.is_empty(): return
	captured[tag] = true
	await RenderingServer.frame_post_draw
	var path := capture_path if tag == "gameplay" else capture_path.replace(".png", "-" + tag + ".png")
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("OBJECTIVE_SCREENSHOT result=", error)

func _process(delta: float) -> void:
	super._process(delta)
	if phase == -1:
		print("OBJECTIVE_ATTEMPT_ERROR ", label.text)
		get_tree().quit(1)
		return
	if phase != 3 or not received_pose: return
	active_time += delta
	stage_time += delta
	if active_time > 100:
		print("OBJECTIVE_ATTEMPT_TIMEOUT stage=", stage, " carry=", witnessed_carry, " drop=", witnessed_drop, " progressed=", progressed)
		get_tree().quit(1)
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		for code: int in held.keys(): key(code, false)
		click()
		return
	var a: Dictionary = presentation.local_actor
	var position := Vector2(a.x, a.z)
	if route.is_empty():
		if selected_mode == "ctf":
			var sign_x := 1.0 if int(a.team) == 0 else -1.0
			route.assign([Vector2(-72*sign_x,0),Vector2(-54*sign_x,0),Vector2(-26*sign_x,0),Vector2(0,8),Vector2(26*sign_x,0),Vector2(54*sign_x,0),Vector2(72*sign_x,0)])
		else: route.assign([Vector2(-78,-10)])
	if selected_mode == "ctf" and witnessed_carry and stage == "approach":
		stage = "drop"
		stage_time = 0
		key(KEY_W, false)
		key(KEY_E, true)
		screenshot()
	if stage == "drop":
		if stage_time > 0.3: key(KEY_E, false)
		if witnessed_drop and stage_time > 0.5:
			print("OBJECTIVE_ATTEMPT_OK carry=true drop=true return=false")
			get_tree().quit(0)
		return
	if stage == "escort":
		key(KEY_W, false)
		if progressed:
			screenshot()
			stage = "leave"
			stage_time = 0
			route.assign([Vector2(position.x, position.y - 12)])
			target_index = 0
		return
	if stage == "leave" and idle_samples >= 15:
		key(KEY_W, false)
		print("OBJECTIVE_ATTEMPT_OK push=true idle=true contest=false")
		get_tree().quit(0)
		return
	var target: Vector2 = route[target_index]
	if selected_mode == "ctf" and target_index == route.size()-1 and position.distance_to(target) < 4 and position.distance_to(target) > 1.3: screenshot("approach")
	if position.distance_to(target) < (0.55 if target_index == route.size()-1 else 1.0):
		if target_index < route.size()-1: target_index += 1
		else:
			key(KEY_W, false)
			return
	var offset := target - position
	var desired := atan2(-offset.x, -offset.y)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(-wrapf(desired-yaw, -PI, PI)/0.003, pitch/0.003)
	Input.parse_input_event(motion)
	key(KEY_W, true)
