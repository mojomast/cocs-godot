extends SceneTree
## Connected graphical journey. Inputs enter Input.parse_input_event. Source
## damage/pickup setup is explicitly requested from the owned HTTP test server.
var session: Node
var settings: Node
var info: Node
var out := ""
var control := ""
var scenario := "mode"
var compact := false
var failures: Array[String] = []
var captures: Array = []
var events_seen: Array = []
var started := 0
var done := false

func _initialize() -> void:
	started = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--experience-out="): out = arg.trim_prefix("--experience-out=")
		if arg.begins_with("--experience-control="): control = arg.trim_prefix("--experience-control=")
		if arg.begins_with("--experience-scenario="): scenario = arg.trim_prefix("--experience-scenario=")
		if arg == "--experience-compact": compact = true
	call_deferred("run")

func _process(_delta: float) -> bool:
	if not done and Time.get_ticks_msec() - started > 75000:
		check(false, "native journey watchdog")
		finish()
	return false

func check(ok: bool, note: String) -> void:
	if not ok:
		failures.append(note)
		printerr("EXPERIENCE_NATIVE_FAIL ", note)

func wait_for(predicate: Callable, note: String, seconds: float = 20) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < end:
		if predicate.call(): return true
		await process_frame
	check(false, "timeout " + note)
	return false

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func tap(code: int) -> void:
	key(code, true)
	key(code, false)

func click(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_visible_rect().size * Vector2(0.7, 0.5)
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)

func capture(name: String) -> void:
	await create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	var record := {"name":name,"viewport":str(root.get_visible_rect().size),"captions":{},"kit":{},"recap":{}}
	for pair: Array in [["captions",info.caption],["kit",info.ability],["recap",info.recap]]:
		var label: Label = pair[1]
		record[pair[0]] = {"text":label.text,"visible":label.is_visible_in_tree(),"rect":str(label.get_global_rect())}
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	captures.append(record)
	print("EXPERIENCE_CAPTURE ", JSON.stringify(record))

func stage(name: String) -> void:
	var request := HTTPRequest.new()
	root.add_child(request)
	request.timeout = 8
	check(request.request(control + "/" + name, [], HTTPClient.METHOD_POST) == OK, "fixture request " + name)
	var result: Array = await request.request_completed
	check(int(result[1]) == 200, "source fixture " + name)
	request.queue_free()

func run() -> void:
	settings = root.get_node("LocalSettings")
	info = settings.player_info
	root.size = Vector2i(760,520) if compact else Vector2i(1280,800)
	settings.set_value("ui_scale",150 if compact else 100,false)
	root.grab_focus()
	# Real Home and its F12 shortcut, with real focused CheckButton key handling.
	var home: Node = load("res://ui/main_menu.tscn").instantiate()
	root.add_child(home)
	current_scene = home
	await create_timer(0.4).timeout
	tap(KEY_F12)
	if not await wait_for(func() -> bool: return settings.overlay_open(), "Home F12"): finish(); return
	settings.rows.captions.grab_focus()
	await process_frame
	if not settings.values.captions: tap(KEY_SPACE)
	await process_frame
	check(settings.values.captions, "keyboard enables captions")
	settings.rows.mute.grab_focus()
	await process_frame
	if not settings.values.mute: tap(KEY_SPACE)
	await process_frame
	check(settings.values.mute, "keyboard mute independent of captions")
	check(settings.save(), "preferences persisted to isolated path")
	settings.load_at(settings.path)
	check(settings.values.captions and settings.values.mute, "saved preferences reloaded")
	await capture("home-settings")
	tap(KEY_ESCAPE)
	await process_frame
	check(not settings.overlay_open() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "Esc Home settings closes without capture")
	var scene := "res://campaign/demo.tscn" if scenario == "campaign" else ("res://world/session.tscn" if scenario == "mobility" else "res://mode_expansion/demo.tscn")
	if scenario in ["sports", "combined_arms"]: scene = "res://" + scenario + "/demo.tscn"
	check(change_scene_to_file(scene) == OK, "normal scene handoff")
	await scene_changed
	session = current_scene
	if scenario in ["sports", "combined_arms"]:
		await independent()
		return
	session.client.events.connect(func(items: Array) -> void: events_seen.append_array(items))
	if scenario == "campaign":
		await process_frame
		session.campaign_hud.primary.grab_focus()
		tap(KEY_SPACE)
	if not await wait_for(func() -> bool: return session.phase == 3 and session.received_pose, "authoritative seated snapshot"): finish(); return
	await create_timer(0.35).timeout
	if scenario == "campaign":
		await wait_for(func() -> bool: return session.can_capture_pointer(), "campaign ready for pointer")
	var pointer := InputEventMouseMotion.new()
	pointer.position = root.get_visible_rect().size * Vector2(0.7, 0.5)
	pointer.global_position = pointer.position
	Input.parse_input_event(pointer)
	await process_frame
	click(true)
	click(false)
	await create_timer(0.2).timeout
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "ordinary click captures")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(0, (session.pitch + 0.35) / 0.003)
	Input.parse_input_event(motion)
	tap(KEY_Q)
	tap(KEY_X)
	await create_timer(0.3).timeout
	await capture("ability")
	check(not info.gameplay_model.is_empty() and info.ability.is_visible_in_tree(), "gameplay model actually displayed")
	check(not session.get_node("PlayerGameplay").show_compact_status, "fixed fallback disabled")
	click(true)
	await create_timer(0.25).timeout
	await capture("muted-fire")
	click(false)
	check(events_seen.any(func(e: Dictionary) -> bool: return e.type == "shot" and e.get("actor") == session.client.actor_id), "ordinary native local fire reached authority")
	if scenario != "mobility":
		await stage("pickup")
		if await wait_for(func() -> bool: return info.caption.text == "Health acquired", "source pickup caption", 5):
			await capture("pickup")
			check(info.caption.is_visible_in_tree(), "pickup caption on screen")
	if scenario == "mode":
		await stage("damage")
		await create_timer(0.15).timeout
		await stage("death")
		if await wait_for(func() -> bool: return info.combat.dead, "source elimination", 5):
			await capture("death-recap")
			check(info.recap.is_visible_in_tree() and info.recap.text.contains("damage"), "death recap visible")
		await wait_for(func() -> bool: return not info.combat.dead and session.presentation.lifecycle.can_control(), "source respawn", 8)
		check(info.combat.hits.is_empty(), "respawn clears incoming ledger")
		await capture("respawn")
		if "--experience-kill" in OS.get_cmdline_user_args():
			await stage("kill")
			await wait_for(func() -> bool: return not info.kill.text.is_empty(), "local kill readout", 4)
			await capture("local-kill")
			check(info.kill.is_visible_in_tree(), "local kill badge displayed")
	if scenario == "campaign":
		await stage("story")
		await capture("story-comms")
		check(session.story_widgets.comms_docked, "story participates in shared transcript")
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: tap(KEY_ESCAPE)
		await create_timer(0.2).timeout
		session.campaign_hud.objective_scroll.grab_focus()
		await process_frame
		tap(KEY_END)
		await capture("kit-scrolled")
		check(session.campaign_hud.objective_scroll.scroll_vertical > 0, "keyboard scroll reaches campaign kit")
		tap(KEY_F3)
		await create_timer(0.2).timeout
		await capture("cheats-overlay")
		check(not info.ability.is_visible_in_tree(), "F3 suppresses kit")
		await boundary()
		tap(KEY_F3)
		await create_timer(0.2).timeout
	# Settings handoff, mute captions off/on, focus lifecycle and no catch-up.
	await stage("stale")
	await create_timer(1.5).timeout
	check(info.gameplay_model.is_empty() and info.captions.current.is_empty(), "transport stale clears status and captions")
	await capture("stale")
	await stage("resume")
	await wait_for(func() -> bool: return not info.gameplay_model.is_empty(), "fresh transport resumes model", 5)
	tap(KEY_F12)
	await process_frame
	check(settings.overlay_open(), "in-match F12")
	await boundary()
	await capture("match-settings")
	check(not info.caption.is_visible_in_tree() and not info.ability.is_visible_in_tree(), "modal clears presentation")
	settings.rows.captions.grab_focus()
	await process_frame
	tap(KEY_SPACE)
	await process_frame
	check(not settings.values.captions, "keyboard disables captions")
	settings.career_button.grab_focus()
	await process_frame
	tap(KEY_SPACE)
	await process_frame
	check(root.get_node("Career").active(), "keyboard opens Career from settings")
	await boundary()
	await capture("career")
	tap(KEY_ESCAPE)
	await process_frame
	tap(KEY_ESCAPE)
	await process_frame
	check(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "settings close never captures")
	check(info.captions.current.is_empty(), "disabled captions no replay")
	session._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	check(info.gameplay_model.is_empty(), "focus loss clears gameplay model")
	session._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await create_timer(0.2).timeout
	if scenario == "mode":
		tap(KEY_TAB)
		key(KEY_TAB,true)
		await capture("scoreboard")
		key(KEY_TAB,false)
	# Teardown of actual scene must return persistent labels before freeing it.
	check(change_scene_to_file("res://ui/main_menu.tscn") == OK, "normal Home return")
	await scene_changed
	check(is_instance_valid(info.caption) and is_instance_valid(info.ability), "persistent labels survive route teardown")
	check(info.caption.get_parent() == info and info.ability.get_parent() == info.ability_scroll, "labels returned to persistent owner")
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	finish()

func boundary() -> void:
	await create_timer(0.2).timeout
	await stage("boundary-start")
	key(KEY_W, true)
	tap(KEY_Q)
	tap(KEY_X)
	await create_timer(0.3).timeout
	key(KEY_W, false)
	await stage("boundary-end")

func independent() -> void:
	session.net.events.connect(func(items: Array) -> void: events_seen.append_array(items))
	if not await wait_for(func() -> bool: return session.phase == "active" and session.age < 0.5, "independent active snapshot"): finish(); return
	await create_timer(0.4).timeout
	check(info.client == session.net, "independent net owner adopted")
	check(info.gameplay_model.is_empty(), "independent route does not invent infantry kit")
	if scenario == "sports": await create_timer(4).timeout
	tap(KEY_ENTER)
	await process_frame
	key(KEY_W, true)
	await create_timer(0.4).timeout
	key(KEY_W, false)
	await stage("respawn")
	await wait_for(func() -> bool: return info.caption.text == "Respawn", "independent received respawn", 5)
	await capture("independent-caption")
	check(info.caption.is_visible_in_tree(), "independent caption fits actual HUD")
	await stage("stale")
	await create_timer(1.5).timeout
	check(info.captions.current.is_empty(), "independent transport stale clears caption")
	await stage("resume")
	await wait_for(func() -> bool: return session.age < 0.5, "independent fresh snapshot")
	check(info.captions.current.is_empty(), "independent resume has no replay")
	tap(KEY_F12)
	await process_frame
	check(settings.overlay_open(), "independent settings modal")
	await boundary()
	await capture("independent-settings")
	tap(KEY_ESCAPE)
	await process_frame
	check(change_scene_to_file("res://ui/main_menu.tscn") == OK, "independent Home return")
	await scene_changed
	await create_timer(0.3).timeout
	check(info.client == null and info.captions.current.is_empty(), "independent teardown releases presenter")
	finish()

func finish() -> void:
	if done: return
	done = true
	var file := FileAccess.open(out.path_join("native.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"scenario":scenario,"compact":compact,"failures":failures,"captures":captures,"events":events_seen},"  "))
	file.close()
	print("EXPERIENCE_NATIVE ", "PASS" if failures.is_empty() else "FAIL", " ", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
