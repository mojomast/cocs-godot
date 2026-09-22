extends "res://objectives/demo.gd"
## Native primary player: only physical-key/mouse events, never handler calls.
var held: Dictionary = {}
var stage := "approach"
var route: Array[Vector2] = []
var index := 0
var state: Dictionary = {}
var capture_path := ""
var captured: Dictionary = {}
var carried := false
var dropped := false
var returned := false
var scored := false
var contested := false
var resumed := false
var idle := false
var checkpoint := false
var contest_distance := 0.0
var stage_started := 0.0
var results_wait := 0.0
var restart_wait := 0.0
var fresh_capture := false
var finishing := false

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

func neutral() -> void:
	for code: int in held.keys(): key(code, false)

func click() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)

func screenshot(tag: String) -> void:
	if captured.has(tag) or capture_path.is_empty(): return
	captured[tag] = true
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(capture_path.replace(".png", "-" + tag + ".png"))
	print("PROGRESSION_SCREENSHOT ", tag, " result=", error)

func on_started(frame: Dictionary) -> void:
	super.on_started(frame)
	print("PROGRESSION_BOUNDARY ", JSON.stringify({"event":"start","round":round_starts,"dynamic":objectives.rendered.keys().filter(func(k: String) -> bool: return not k.begins_with("guide_")),"hud":objective_label.text,"captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"pose":received_pose}))
	state.clear()

func on_results(frame: Dictionary) -> void:
	super.on_results(frame)
	neutral()
	print("PROGRESSION_BOUNDARY ", JSON.stringify({"event":"results","round":round_starts,"over":frame.state.over,"time":frame.state.time,"captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"control_eligible":can_capture_pointer(),"hud":objective_label.text}))
	screenshot("results")

func on_snapshot(frame: Dictionary) -> void:
	super.on_snapshot(frame)
	state = frame.state
	if round_starts != 1: return
	if selected_mode == "ctf":
		for flag: Dictionary in state.get("flags", []):
			if flag.team == presentation.local_actor.get("team"): continue
			if flag.state == "carried" and flag.carrier == client.actor_id: carried = true
			if carried and flag.state == "dropped": dropped = true
			if dropped and flag.state == "at-base": returned = true
		scored = float(state.get("teamScores", {}).get("0", 0)) > 0
	else:
		var p: Dictionary = state.get("objectives", {}).get("payload", {})
		if p.get("contested") == true:
			contested = true
			contest_distance = p.distance
			screenshot("contest")
		if contested and p.get("pushing") == 0 and p.distance > contest_distance + 1: resumed = true
		checkpoint = p.get("checkpointsReached", 0) > 0
		if resumed and p.get("pushing") == null and not p.get("contested", true): idle = true

func aim_at_point(target: Vector2) -> void:
	var a: Dictionary = presentation.local_actor
	var offset := target - Vector2(a.x, a.z)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(-wrapf(atan2(-offset.x, -offset.y)-yaw, -PI, PI)/0.003, pitch/0.003)
	Input.parse_input_event(motion)

func follow(target: Vector2, stop: float = 0.6) -> bool:
	var a: Dictionary = presentation.local_actor
	var offset := target - Vector2(a.x, a.z)
	if offset.length() < stop:
		key(KEY_W, false)
		return true
	aim_at_point(target)
	key(KEY_W, true)
	return false

func _process(delta: float) -> void:
	super._process(delta)
	if finishing: return
	if phase == -1:
		print("PROGRESSION_ERROR ", label.text)
		get_tree().quit(1)
		return
	if phase == 4:
		results_wait += delta
		if results_wait > 1.5: key(KEY_ENTER, true)
		return
	if phase != 3 or not received_pose or state.is_empty(): return
	if round_starts == 2:
		neutral()
		restart_wait += delta
		if restart_wait < 1:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				push_error("New round retained capture")
				get_tree().quit(1)
			return
		if not fresh_capture:
			click()
			fresh_capture = true
			return
		if restart_wait > 2:
			finishing = true
			screenshot("restart")
			var ok := returned if selected_mode == "ctf" else contested and resumed and idle
			print("PROGRESSION_DONE ", JSON.stringify({"ok":ok,"returned":returned,"capture":scored,"contest":contested,"resumed":resumed,"idle":idle,"checkpoint":checkpoint,"starts":round_starts,"results":round_results,"fresh_capture":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED}))
			await get_tree().create_timer(0.2).timeout
			get_tree().quit(0 if ok else 1)
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		neutral()
		click()
		return
	var a: Dictionary = presentation.local_actor
	var position := Vector2(a.x, a.z)
	if selected_mode == "ctf":
		if route.is_empty(): route.assign([Vector2(-72,0),Vector2(-54,0),Vector2(-26,0),Vector2(0,8),Vector2(26,0),Vector2(54,0),Vector2(72,0)])
		if stage == "approach" and carried:
			stage = "drop"
			stage_started = state.time
			key(KEY_E, true)
		if stage == "drop":
			follow(Vector2(62,0))
			if state.time > stage_started + 0.3: key(KEY_E, false)
			if returned:
				screenshot("return")
				stage = "recapture"
			return
		if stage == "recapture":
			follow(Vector2(72,0))
			if a.get("carryingFlag", false):
				stage = "home"
				route.reverse()
				index = 0
			return
		if scored:
			if follow(Vector2(-68,3)):
				neutral()
				aim_at_point(Vector2(-72,0))
				screenshot("capture")
			return
		if follow(route[index]) and index < route.size()-1: index += 1
	else:
		var p: Dictionary = state.get("objectives", {}).get("payload", {})
		if not p.has("position"): return
		if stage == "approach":
			# Weighbridge arch posts are at x=-78,z=-1/-19. Approach along
			# the clear west side from every ordinary attacker spawn.
			if route.is_empty(): route.assign([Vector2(-82, position.y),Vector2(-82,-10),Vector2(-78,-10)])
			if follow(route[index]):
				if index < route.size()-1: index += 1
				else: stage = "escort"
			return
		if checkpoint and stage != "leave":
			screenshot("checkpoint")
			stage = "leave"
			route.assign([position + Vector2(0, 12)])
		if stage == "leave":
			if follow(route[0]) and idle:
				aim_at_point(Vector2(p.position.x, p.position.z))
				screenshot("idle")
		else: follow(Vector2(p.position.x, p.position.z), 3.2)
