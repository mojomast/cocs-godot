extends "res://horde/demo.gd"
## Test-only steering via ordinary input events. Never included in product scene.
var scenario := "startup"
var shot_path := ""
var held := {}
var firing := false
var completed := false
var wait := 0.0
var dead_seen := false
var respawn_seen := false
var blocked_seen := false
var life_before := 3
var captured_shots := {}
var pause_stage := 0
var probe_elapsed := 0.0

func _ready() -> void:
	super._ready()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="): scenario = arg.trim_prefix("--scenario=")
		if arg.begins_with("--screenshot="): shot_path = arg.trim_prefix("--screenshot=")

func key(code: int, down: bool) -> void:
	if held.get(code, false) == down: return
	held[code] = down
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func mouse(down: bool) -> void:
	firing = down
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	Input.parse_input_event(event)

func click() -> void:
	mouse(true)
	mouse(false)

func neutral() -> void:
	for code: int in held.keys(): key(code, false)
	if firing: mouse(false)

func picture(tag: String) -> void:
	if captured_shots.has(tag) or shot_path.is_empty(): return
	captured_shots[tag] = true
	await RenderingServer.frame_post_draw
	var hud: Node = get_node("GameHUD")
	print("HORDE_LAYOUT ", JSON.stringify({"tag":tag,"viewport":[get_window().size.x,get_window().size.y],"horde":[horde_label.position.x,horde_label.position.y,horde_label.size.x,horde_label.size.y],"status":[hud.status_panel.position.x,hud.status_panel.position.y,hud.status_panel.size.x,hud.status_panel.size.y],"status_visible":hud.status_panel.visible,"intersects":horde_label.get_rect().intersects(hud.status_panel.get_rect()),"passive":horde_label.mouse_filter == Control.MOUSE_FILTER_IGNORE}))
	print("HORDE_PICTURE ", tag, " ", get_viewport().get_texture().get_image().save_png(shot_path.replace(".png", "-"+tag+".png")))

func finish(ok: bool, message: String) -> void:
	if completed: return
	completed = true
	neutral()
	print("HORDE_DONE ", JSON.stringify({"ok":ok,"message":message,"scenario":scenario,"dead_seen":dead_seen,"respawn_seen":respawn_seen,"blocked_seen":blocked_seen}))
	await picture("final")
	if scenario == "death":
		get_window().size = Vector2i(1280, 800) if get_window().size.x < 1000 else Vector2i(960, 640)
		await get_tree().process_frame
		await get_tree().process_frame
		await picture("alternate")
	await get_tree().create_timer(0.3).timeout
	get_tree().quit(0 if ok else 1)

func _process(delta: float) -> void:
	super._process(delta)
	if completed: return
	if phase == -1:
		finish(false, label.text)
		return
	if elapsed > 170:
		finish(false, "bounded attempt expired")
		return
	if phase == 4:
		neutral()
		picture("results")
		wait += delta
		if wait > 1.0: key(KEY_ENTER, true)
		return
	if phase != 3 or not received_pose or latest.is_empty(): return
	if round_starts > 1:
		neutral()
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			finish(false,"automatic capture after restart")
			return
		picture("restart")
		finish(round_results == 1, "results and clean restart observed")
		return
	var a: Dictionary = presentation.local_actor
	if int(horde.state.get("wave", 0)) > 0: picture("wave")
	if scenario == "startup":
		if int(horde.state.get("enemiesAlive", 0)) > 0:
			finish(true,"received actual wave and enemies")
		return
	if scenario == "death":
		if pause_stage < 5:
			probe_elapsed += delta
			if pause_stage == 0:
				click()
				pause_stage = 1
				probe_elapsed = 0
			elif pause_stage == 1 and probe_elapsed > 0.5:
				key(KEY_E, true)
				key(KEY_ESCAPE, true)
				pause_stage = 2
				probe_elapsed = 0
			elif pause_stage == 2 and probe_elapsed > 0.5:
				if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
					finish(false, "Escape did not release")
					return
				print("HORDE_GATE ", JSON.stringify({"stage":"pause","seq":client.last_snapshot_seq,"captured":false}))
				neutral()
				pause_stage = 3
				probe_elapsed = 0
			elif pause_stage == 3 and probe_elapsed > 0.2:
				click()
				pause_stage = 4
				probe_elapsed = 0
			elif pause_stage == 4 and probe_elapsed > 0.2:
				if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
					finish(false, "fresh resume failed")
					return
				key(KEY_E, true) # actual held action BEFORE death, retained through respawn
				print("HORDE_GATE ", JSON.stringify({"stage":"resumed_holding_interact","seq":client.last_snapshot_seq,"captured":true}))
				pause_stage = 5
			return
		if float(a.get("health", 0)) <= 0:
			dead_seen = true
			key(KEY_W, true)
			picture("death")
			return
		if dead_seen:
			respawn_seen = int(horde.state.get("lives", 3)) < life_before
			wait += delta
			if wait < 0.5: click()
			elif wait < 1.0:
				blocked_seen = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
			else:
				neutral()
				if wait > 1.2: click()
				if wait > 1.5: finish(respawn_seen and blocked_seen and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"natural life loss and fresh respawn capture")
			return
		# Let ordinary source AI engage a stationary local player.
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: click()
		return
	if not presentation.lifecycle.can_control():
		neutral()
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		neutral()
		click()
		return
	var target: Dictionary = {}
	var distance := INF
	for npc: Dictionary in latest.get("actors", []):
		if npc.get("isNpc") != true or float(npc.get("health", 0)) <= 0: continue
		var d := Vector2(float(npc.x)-float(a.x),float(npc.z)-float(a.z)).length()
		if d < distance:
			distance = d
			target = npc
	if target.is_empty():
		neutral()
		return
	var offset := Vector3(float(target.x)-float(a.x), float(target.y)+0.9-camera.position.y, float(target.z)-float(a.z))
	var aim_yaw := atan2(-offset.x, -offset.z)
	var aim_pitch := atan2(offset.y, Vector2(offset.x,offset.z).length())
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(-wrapf(aim_yaw-yaw,-PI,PI)/0.003,-(aim_pitch-pitch)/0.003)
	Input.parse_input_event(motion)
	if not firing: mouse(true)
	key(KEY_W, distance > 18)
	key(KEY_SPACE, distance > 18 and fmod(elapsed, 3) < 0.2)
	key(KEY_R, int(a.get("ammo", [1])[int(a.get("weapon",0))]) == 0)
