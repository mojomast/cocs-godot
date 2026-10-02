extends SceneTree
## AFTER explicit engine grant only. Normal-rate connected native record/save/reopen.
const Session = preload("res://tests/replay/journey_session.gd")
const Capture = preload("res://replay/capture.gd")
const Library = preload("res://replay/library.gd")
var session: Node3D
var capture: CanvasLayer
var library: Control
var checks := 0
var failures := 0
var output := ""
var saved_id := ""

func require(value: bool, text: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(text)
	print("REPLAY_CHECK ", value, " ", text)

func wait_for(predicate: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await process_frame
	return false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	output = OS.get_environment("COCS_REPLAY_EVIDENCE")
	if output.is_empty(): push_error("COCS_REPLAY_EVIDENCE required"); quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 800)
	session = Session.new()
	root.add_child(session)
	current_scene = session
	capture = session.get_node_or_null("ReplayCapture")
	if capture == null:
		capture = Capture.new()
		session.add_child(capture)
	require(await wait_for(func() -> bool: return session.phase == 3 and not capture.last_state.is_empty(), 15), "native live recipient")
	if failures: quit(1); return
	capture.begin()
	require(await wait_for(func() -> bool: return capture.recording, 10), "Record button pipeline acknowledged")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var down := InputEventKey.new()
	down.physical_keycode = KEY_W
	down.pressed = true
	Input.parse_input_event(down)
	var fire := InputEventMouseButton.new()
	fire.button_index = MOUSE_BUTTON_LEFT
	fire.pressed = true
	Input.parse_input_event(fire)
	await create_timer(1.0).timeout
	down.pressed = false
	Input.parse_input_event(down)
	fire.pressed = false
	Input.parse_input_event(fire)
	require(await wait_for(func() -> bool: return session.phase == 4, 40), "actual source round results")
	require(session.client.last_ack > 0, "source acknowledged native input")
	capture.bridge.reply.connect(func(op: String, value: Dictionary) -> void:
		if op == "save": saved_id = str(value.clip.id))
	capture.save()
	require(await wait_for(func() -> bool: return not saved_id.is_empty(), 12), "native clip saved")
	capture.begin()
	require(await wait_for(func() -> bool: return capture.has_capture, 8), "second recording started")
	capture.discard()
	require(await wait_for(func() -> bool: return not capture.has_capture, 8), "discard leaves saved clip intact")
	if failures: quit(1); return
	session.client.disconnect_server()
	session.free()
	print("REPLAY_AUTHORITY_LEFT")
	await process_frame
	library = Library.new()
	root.add_child(library)
	current_scene = library
	require(await wait_for(func() -> bool: return not library.rows.is_empty(), 12), "Home library metadata")
	var index := -1
	for i: int in library.rows.size():
		if library.rows[i].get("id") == saved_id: index = i
	require(index >= 0, "saved clip discoverable")
	if index < 0: quit(1); return
	library.open_clip(index)
	require(await wait_for(func() -> bool: return library.opened and is_instance_valid(library.stage) and not library.stage.state.is_empty(), 20), "reopened source snapshot rendering")
	require(not ("client" in library) and not ("client" in library.stage), "read-only replay has zero authority clients")
	library.seek_to(1.25)
	require(await wait_for(func() -> bool: return absf(library.seek.value - 1.25) < 0.001, 8), "exact native seek")
	library.toggle_play()
	require(await wait_for(func() -> bool: return not library.paused, 8), "play")
	await create_timer(0.5).timeout
	library.pause_for_modal()
	require(await wait_for(func() -> bool: return library.paused, 8), "pause/settings cue clear")
	var settings := root.get_node_or_null("LocalSettings")
	if settings != null:
		settings.open_panel(true)
		await process_frame
		# Real overlay stays open for captured inspection; Escape uses normal handling.
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		Input.parse_input_event(escape)
	await screenshot("wide")
	root.size = Vector2i(760, 520)
	root.content_scale_factor = 1.5
	await screenshot("compact-ui150")
	library.free()
	await process_frame
	require(not is_instance_valid(library), "back/teardown releases player and helper")
	print("REPLAY_NATIVE_DONE checks=", checks, " failures=", failures, " clip=", saved_id)
	quit(0 if failures == 0 else 1)

func screenshot(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	require(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "captured " + label)
