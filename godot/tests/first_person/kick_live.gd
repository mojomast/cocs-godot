extends SceneTree
## Real session + ordinary input. No apply_events, model stepping or actor writes.
const Settings = preload("res://ui/settings_access.gd")
var session: Node
var output := ""
var scenario := "chain"
var revision := ""
var state: Dictionary = {}
var events: Array[Dictionary] = []
var checks: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var frames: Array[Dictionary] = []
var inputs: Array[Dictionary] = []
var pending: Dictionary = {}
var started_ms := 0
var finishing := false
var capture_busy := false

func _initialize() -> void:
	started_ms = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence="): output = arg.trim_prefix("--evidence=")
		if arg.begins_with("--scenario="): scenario = arg.trim_prefix("--scenario=")
		if arg.begins_with("--revision="): revision = arg.trim_prefix("--revision=")
	call_deferred("run")

func check(ok: bool, label: String) -> bool:
	checks.append({"passed":ok,"name":label})
	print("KICK_LIVE_CHECK ", JSON.stringify(checks.back()))
	if not ok: finish("Failed: " + label)
	return ok

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	inputs.append({"ms":Time.get_ticks_msec(),"key":code,"pressed":pressed})
	Input.parse_input_event(event)

func tap(code: int) -> void:
	key(code,true)
	key(code,false)

func mouse(button: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = root.get_visible_rect().size * Vector2(0.5,0.65)
	event.global_position = event.position
	event.pressed = pressed
	inputs.append({"ms":Time.get_ticks_msec(),"button":button,"pressed":pressed})
	Input.parse_input_event(event)

func look(yaw: float) -> void:
	var event := InputEventMouseMotion.new()
	var gain := 0.003 * Settings.sensitivity() * (0.85 if session.aim_requested() else 1.0)
	event.relative = Vector2(wrapf(session.yaw-yaw,-PI,PI)/gain,session.pitch/gain)
	inputs.append({"ms":Time.get_ticks_msec(),"relative":[event.relative.x,event.relative.y]})
	Input.parse_input_event(event)

func wait_for(predicate: Callable, seconds: float, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds*1000)
	while not finishing and not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	if finishing: return false
	return check(predicate.call(),label)

func pause(seconds: float) -> void:
	await create_timer(seconds).timeout

func local_target() -> Dictionary:
	for actor: Dictionary in state.get("actors",[]):
		if actor.id != session.client.actor_id: return actor
	return {}

func distance() -> float:
	var target := local_target()
	var local: Dictionary = session.presentation.local_actor
	return Vector2(float(local.get("x",0))-float(target.get("x",100)),float(local.get("z",0))-float(target.get("z",100))).length()

func close_range() -> bool:
	key(KEY_W,true)
	var ok := await wait_for(func() -> bool: return distance() < 1.45,0.6,"ordinary W follows authoritative knockback")
	key(KEY_W,false)
	return ok

func observe(items: Array) -> void:
	for event: Dictionary in items:
		if event.get("type") != "melee" or event.get("actor") != session.client.actor_id: continue
		var record := {"event":event.duplicate(true),"received_ms":Time.get_ticks_msec()}
		events.append(record)
		pending = record
		print("KICK_LIVE_ACCEPTED ",JSON.stringify(record))

func capture_contact(record: Dictionary) -> void:
	capture_busy = true
	await RenderingServer.frame_post_draw
	if finishing: return
	var rendered_ms := Time.get_ticks_msec()
	var pose: Dictionary = session.first_person.rig.get_kick_state()
	var label := "%s-%03d-step%d" % [scenario,int(record.event.id),int(pose.step)]
	var path := output.path_join(label+".png")
	var error := root.get_texture().get_image().save_png(path)
	var entry := {"path":path,"event_id":record.event.id,"pose":pose,"received_ms":record.received_ms,
		"rendered_ms":rendered_ms,"receipt_to_render_ms":rendered_ms-int(record.received_ms),"saved":error == OK}
	captures.append(entry)
	print("KICK_LIVE_CAPTURE ",JSON.stringify(entry))
	capture_busy = false

func _process(_delta: float) -> bool:
	if finishing: return false
	if Time.get_ticks_msec()-started_ms > 40000:
		finish("40-second native deadline")
		return false
	if not is_instance_valid(session) or not is_instance_valid(session.first_person): return false
	var pose: Dictionary = session.first_person.rig.get_kick_state()
	if pose.active and frames.size() < 2000:
		frames.append({"ms":Time.get_ticks_msec(),"event_id":events.back().event.id if not events.is_empty() else -1,"pose":pose})
	if not pending.is_empty() and pose.active and float(pose.age) >= 0.095 and not capture_busy:
		var record := pending
		pending = {}
		capture_contact(record)
	return false

func run() -> void:
	if output.is_empty():
		finish("--evidence required")
		return
	session = load("res://world/session.tscn").instantiate()
	root.add_child(session)
	current_scene = session
	session.client.snapshot.connect(func(frame: Dictionary) -> void: state = frame.get("state",{}))
	session.client.events.connect(observe)
	session.client.connection_error.connect(func(message: String) -> void: finish(message))
	if not await wait_for(func() -> bool: return session.phase == 3 and session.received_pose and absf(float(session.presentation.local_actor.get("x",0))+44) < 0.1,12,"controlled match ready"): return
	root.grab_focus()
	await pause(0.15)
	mouse(MOUSE_BUTTON_LEFT,true)
	mouse(MOUSE_BUTTON_LEFT,false)
	await pause(0.2) # Capture click fires away from target, as logged by source.
	look(0.0)
	await pause(0.15)
	if not check(session.first_person.rig.showing and local_target().get("health") == 100,"captured FPS and untouched 100-health target"): return
	mouse(MOUSE_BUTTON_RIGHT,true)
	await pause(0.35)
	if not check(session.first_person.rig.get_aim_state().active,"ordinary right mouse enters ADS"): return
	tap(KEY_F)
	if not await wait_for(func() -> bool: return events.size() == 1,1,"first F accepted once"): return
	await pause(0.04)
	key(KEY_F,true) # Deliberately too early; keep held past cooldown.
	await pause(0.36)
	key(KEY_F,false)
	if not check(events.size() == 1,"early press held beyond cooldown produces no second action"): return
	if scenario == "chain":
		if not check(events[0].event.get("outcome") == "hit","first actual hit"): return
		if not await close_range(): return
		mouse(MOUSE_BUTTON_RIGHT,false)
		for expected: int in [2,3]:
			tap(KEY_F)
			if not await wait_for(func() -> bool: return events.size() == expected,1,"accepted legal F %d" % expected): return
			await pause(0.32)
			if expected == 2 and not await close_range(): return
		if not check(events[2].event.get("outcome") == "hit","third action hits through authority"): return
		if not await wait_for(func() -> bool: return float(local_target().get("health",100)) <= 0,1,"third ordinary 45-damage hit kills target"): return
	else:
		mouse(MOUSE_BUTTON_RIGHT,false)
		if not check(events[0].event.get("outcome") == "blocked" and events[0].event.get("hit") == null,"protected setup receives blocked result"): return
		tap(KEY_F)
		if not await wait_for(func() -> bool: return events.size() == 2,1,"second protected F accepted"): return
		await pause(0.32)
		if not check(session.first_person.rig.get_kick_state().step == 1,"blocked contact breaks continuation"): return
	look(PI)
	await pause(0.2)
	var before := events.size()
	tap(KEY_F)
	if not await wait_for(func() -> bool: return events.size() == before+1,1,"look-away F accepted"): return
	await pause(0.33)
	if not check(events.back().event.get("outcome") == "miss","ordinary look-away creates genuine miss"): return
	tap(KEY_F)
	if not await wait_for(func() -> bool: return events.size() == before+2,1,"post-miss F accepted"): return
	if not check(session.first_person.rig.get_kick_state().step == 1,"miss resets next sequence"): return
	tap(KEY_2)
	if not await wait_for(func() -> bool: return int(session.presentation.local_actor.get("weapon",-1)) == 1,1,"ordinary number key swaps weapon"): return
	if not check(not session.first_person.rig.get_kick_state().active,"swap interrupts kick"): return
	await pause(0.4)
	tap(KEY_F)
	if not await wait_for(func() -> bool: return events.size() == before+3,1,"post-swap fresh F accepted"): return
	tap(KEY_ESCAPE)
	await pause(0.15)
	if not check(not session.first_person.rig.showing and not session.first_person.rig.get_kick_state().active,"ordinary Escape releases pointer and clears pose"): return
	if not check(session.first_person.rig.kick_count == events.size(),"one rendered acceptance per received source ID"): return
	finish("")

func finish(error: String) -> void:
	if finishing: return
	finishing = true
	for code: int in [KEY_F,KEY_W,KEY_SHIFT]: key(code,false)
	for button: int in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]: mouse(button,false)
	var report := {"revision":revision,"scenario":scenario,"passed":error.is_empty(),"error":error,
		"checks":checks,"events":events,"captures":captures,"frames":frames,"inputs":inputs,
		"visual_contact_seconds":0.095,"damage_timing":"authority acceptance; visual contact follows receipt"}
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("native-report.json"),FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report,"\t"))
	print("KICK_LIVE_DONE ",JSON.stringify({"passed":error.is_empty(),"error":error,"events":events.size()}))
	if is_instance_valid(session): session.queue_free()
	await process_frame
	quit(0 if error.is_empty() else 1)
