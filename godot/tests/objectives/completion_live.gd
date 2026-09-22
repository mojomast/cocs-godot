extends "res://objectives/demo.gd"
## Accepted native event construction, extended to the complete cart route.
var held: Dictionary = {}
var stage := "approach"
var route: Array[Vector2] = []
var index := 0
var state: Dictionary = {}
var capture_path := ""
var captured: Dictionary = {}
var results_wait := 0.0
var restart_wait := 0.0
var fresh_capture := false
var finishing := false
var bank_time := -1.0
var rollback_seen := false
var banked := false
var delivered := false
var leave_target := Vector2.ZERO
var previous_distance := -1.0
var last_progress_time := 0.0
var last_progress_position := Vector2.ZERO

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
	print("COMPLETION_SCREENSHOT ", tag, " result=", error)

func aim_at_point(target: Vector2) -> void:
	var a: Dictionary = presentation.local_actor
	var offset := target - Vector2(a.x, a.z)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(-wrapf(atan2(-offset.x, -offset.y)-yaw, -PI, PI)/0.003, pitch/0.003)
	Input.parse_input_event(motion)

func follow(target: Vector2, stop: float = 0.6) -> bool:
	var a: Dictionary = presentation.local_actor
	if target.distance_to(Vector2(a.x, a.z)) < stop:
		key(KEY_W, false)
		return true
	aim_at_point(target)
	key(KEY_W, true)
	return false

func on_started(frame: Dictionary) -> void:
	super.on_started(frame)
	print("COMPLETION_BOUNDARY ", JSON.stringify({"event":"start","round":round_starts,"dynamic":objectives.rendered.keys().filter(func(k: String) -> bool: return not k.begins_with("guide_")),"hud":objective_label.text,"captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"pose":received_pose}))
	state.clear()

func on_snapshot(frame: Dictionary) -> void:
	super.on_snapshot(frame)
	state = frame.state
	print("COMPLETION_HUD ", JSON.stringify({"round":round_starts,"seq":frame.seq,"model":objectives.hud_model}))
	if round_starts != 1 or selected_mode != "payload": return
	var p: Dictionary = state.objectives.payload
	var bank: float = state.objectives.zones[0].distance
	if p.pushing == 1 and previous_distance > p.distance + 0.001:
		rollback_seen = true
		screenshot("rollback")
	if rollback_seen and p.pushing == 1 and absf(p.distance - bank) < 0.002:
		if bank_time < 0: bank_time = state.time
		if state.time > bank_time + 1.5:
			banked = true
			screenshot("banked")
	previous_distance = p.distance
	if p.checkpointsReached == 2: screenshot("checkpoint2")

func on_results(frame: Dictionary) -> void:
	delivered = frame.state.get("objectives", {}).get("payload", {}).get("delivered", false)
	super.on_results(frame)
	neutral()
	print("COMPLETION_RESULT ", JSON.stringify({"delivered":delivered,"hud":objective_label.text,"model":objectives.hud_model,"released":controls_released(),"phase":phase,"captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"eligible":can_capture_pointer(),"rendered":objectives.rendered}))
	screenshot("results")

func _process(delta: float) -> void:
	super._process(delta)
	if finishing: return
	if phase == -1:
		print("COMPLETION_ERROR ", label.text)
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
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: get_tree().quit(1)
			return
		if not fresh_capture:
			click()
			fresh_capture = true
			return
		if restart_wait > 2:
			finishing = true
			screenshot("restart")
			var ok := completion_success()
			print("COMPLETION_DONE ", JSON.stringify({"ok":ok,"rollback":rollback_seen,"banked":banked,"delivered":delivered,"fresh_capture":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED}))
			await get_tree().create_timer(0.2).timeout
			get_tree().quit(0 if ok else 1)
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		neutral()
		click()
		return
	var a: Dictionary = presentation.local_actor
	var position := Vector2(a.x, a.z)
	drive_objective(position)

func completion_success() -> bool:
	return rollback_seen and banked and delivered

func drive_objective(position: Vector2) -> void:
	var a: Dictionary = presentation.local_actor
	var p: Dictionary = state.objectives.payload
	var cart := Vector2(p.position.x, p.position.z)
	if stage == "approach":
		if route.is_empty(): route.assign([Vector2(-82, position.y),Vector2(-82,-10),Vector2(-78,-10)])
		if follow(route[index]):
			if index < route.size()-1: index += 1
			else: stage = "escort"
	elif stage == "escort" and p.checkpointsReached == 1 and p.distance > state.objectives.zones[0].distance + 3:
		screenshot("checkpoint1")
		stage = "rollback"
		leave_target = position + Vector2(0, 12)
	elif stage == "rollback":
		if follow(leave_target): aim_at_point(cart)
		if banked and state.time > bank_time + 3: stage = "delivery"
	else:
		# Close following avoids cutting the navigation cart's tight wall corners.
		follow(cart, 1.2)
	if position.distance_to(last_progress_position) > 0.5:
		last_progress_position = position
		last_progress_time = state.time
	if stage in ["approach", "escort", "delivery"] and state.time > last_progress_time + 12:
		finishing = true
		neutral()
		print("COMPLETION_BLOCKED ", JSON.stringify({"stage":stage,"time":state.time,"actor":a,"payload":p}))
		screenshot("blocked")
		await get_tree().create_timer(0.3).timeout
		get_tree().quit(1)
