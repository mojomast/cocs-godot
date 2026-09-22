extends Node
## Test-only external observer/controller of the ACTUAL product scene. No root
## script replacement: that reinitializes detached field-created Nodes and leaks.
@onready var session: Node = $Horde
var scenario := "startup"
var shot_path := ""
var held := {}
var firing := false
var completed := false
var wait := 0.0
var elapsed := 0.0
var dead_seen := false
var respawn_seen := false
var blocked_seen := false
var captured_shots := {}
var pause_stage := 0
var probe_elapsed := 0.0
var results_started := false
var results_ready := false
var fresh_click_done := false

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="): scenario = arg.trim_prefix("--scenario=")
		if arg.begins_with("--screenshot="): shot_path = arg.trim_prefix("--screenshot=")
	print("HORDE_PRODUCT ", JSON.stringify({"scene":session.scene_file_path,
		"script":session.get_script().resource_path, "scoreboard":session.has_node("Scoreboard")}))

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
	var hud: Node = session.get_node("GameHUD")
	var board: Node = session.get_node("Scoreboard")
	var strip: Label = session.horde_label
	print("HORDE_LAYOUT ", JSON.stringify({"tag":tag,"viewport":[get_window().size.x,get_window().size.y],
		"horde":[strip.position.x,strip.position.y,strip.size.x,strip.size.y],
		"status":[hud.status_panel.position.x,hud.status_panel.position.y,hud.status_panel.size.x,hud.status_panel.size.y],
		"status_visible":hud.status_panel.visible,"intersects":hud.status_panel.visible and strip.get_rect().intersects(hud.status_panel.get_rect()),
		"scoreboard_visible":board.panel.visible,"scoreboard":[board.panel.position.x,board.panel.position.y,board.panel.size.x,board.panel.size.y],
		"scoreboard_intersects":board.panel.visible and strip.get_rect().intersects(board.panel.get_rect()),
		"scoreboard_bottom":board.panel.position.y+board.panel.size.y,
		"controls_visible":hud.controls.visible,"controls_bottom":hud.controls.position.y+hud.controls.size.y,
		"controls":[hud.controls.position.x,hud.controls.position.y,hud.controls.size.x,hud.controls.size.y],
		"passive":strip.mouse_filter == Control.MOUSE_FILTER_IGNORE}))
	print("HORDE_PICTURE ", tag, " ", get_viewport().get_texture().get_image().save_png(shot_path.replace(".png", "-"+tag+".png")))

func alternate_picture(tag: String) -> void:
	var original := get_window().size
	get_window().size = Vector2i(1280, 800) if original.x < 1000 else Vector2i(960, 640)
	await get_tree().process_frame
	await get_tree().process_frame
	await picture(tag)
	get_window().size = original
	await get_tree().process_frame

func result_pictures() -> void:
	results_started = true
	await picture("results")
	await alternate_picture("results-alternate")
	results_ready = true

func finish(ok: bool, message: String) -> void:
	if completed: return
	completed = true
	neutral()
	print("HORDE_DONE ", JSON.stringify({"ok":ok,"message":message,"scenario":scenario,"dead_seen":dead_seen,"respawn_seen":respawn_seen,"blocked_seen":blocked_seen}))
	await picture("final")
	await alternate_picture("alternate")
	await get_tree().process_frame
	get_tree().quit(0 if ok else 1)

func _process(delta: float) -> void:
	if completed: return
	elapsed += delta
	if session.phase == -1:
		finish(false, session.label.text)
		return
	if elapsed > 170:
		finish(false, "bounded attempt expired")
		return
	if session.phase == 4:
		neutral()
		if not results_started: result_pictures()
		if results_ready:
			wait += delta
			if wait > 1.0: key(KEY_ENTER, true)
		return
	if session.phase != 3 or not session.received_pose or session.latest.is_empty(): return
	if session.round_starts > 1:
		neutral()
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			finish(false,"automatic capture after restart")
			return
		picture("restart")
		finish(session.round_results == 1, "results and clean restart observed")
		return
	var a: Dictionary = session.presentation.local_actor
	if int(session.horde.state.get("wave", 0)) > 0: picture("wave")
	if scenario == "startup":
		if int(session.horde.state.get("enemiesAlive", 0)) > 0:
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
				print("HORDE_GATE ", JSON.stringify({"stage":"pause","seq":session.client.last_snapshot_seq,"captured":false}))
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
				key(KEY_E, true) # source press, physically retained before death
				key(KEY_CTRL, true) # source HELD action, before death through respawn
				print("HORDE_GATE ", JSON.stringify({"stage":"resumed_holding_interact","seq":session.client.last_snapshot_seq,"captured":true,"held_crouch":true}))
				pause_stage = 5
			return
		if float(a.get("health", 0)) <= 0:
			dead_seen = true
			key(KEY_W, true)
			picture("death")
			return
		if dead_seen:
			respawn_seen = int(session.horde.state.get("lives", 3)) < 3
			wait += delta
			if wait < 0.5: click()
			elif wait < 1.0:
				blocked_seen = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
			else:
				neutral()
				if wait > 1.2 and not fresh_click_done:
					fresh_click_done = true
					click()
				if wait > 1.5: finish(respawn_seen and blocked_seen and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"natural life loss and fresh respawn capture")
			return
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: click()
		return
	if not session.presentation.lifecycle.can_control():
		neutral()
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		neutral()
		click()
		return
	var target: Dictionary = {}
	var distance := INF
	for npc: Dictionary in session.latest.get("actors", []):
		if npc.get("isNpc") != true or float(npc.get("health", 0)) <= 0: continue
		var d := Vector2(float(npc.x)-float(a.x),float(npc.z)-float(a.z)).length()
		if d < distance:
			distance = d
			target = npc
	if target.is_empty():
		neutral()
		return
	var offset := Vector3(float(target.x)-float(a.x), float(target.y)+0.9-session.camera.position.y, float(target.z)-float(a.z))
	var aim_yaw := atan2(-offset.x, -offset.z)
	var aim_pitch := atan2(offset.y, Vector2(offset.x,offset.z).length())
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(-wrapf(aim_yaw-session.yaw,-PI,PI)/session.LOOK_GAIN,-(aim_pitch-session.pitch)/session.LOOK_GAIN)
	Input.parse_input_event(motion)
	if not firing: mouse(true)
	key(KEY_W, distance > 18)
	key(KEY_SPACE, distance > 18 and fmod(elapsed, 3) < 0.2)
	key(KEY_R, int(a.get("ammo", [1])[int(a.get("weapon",0))]) == 0)
