extends SceneTree
## Real production scene + GUI and Input.parse_input_event + normal authority.
## Synthetic InputEvents, NOT OS/human input evidence. No actor/simulation writes.
const Model = preload("res://input_bindings/model.gd")
var session: Node
var settings: Node
var store: Node
var out := ""
var control := ""
var compact := false
var failures: Array[String] = []
var started := 0
var done := false

func _initialize() -> void:
	started = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--bindings-out="): out = arg.trim_prefix("--bindings-out=")
		if arg.begins_with("--bindings-control="): control = arg.trim_prefix("--bindings-control=")
		if arg == "--bindings-compact": compact = true
	call_deferred("run")

func _process(_delta: float) -> bool:
	if not done and Time.get_ticks_msec() - started > 65000:
		check(false, "65 second native watchdog")
		finish()
	return false

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("BINDINGS_JOURNEY " + message)

func wait_for(predicate: Callable, message: String, seconds: float = 15) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		if predicate.call(): return true
		await process_frame
	check(false, "timeout " + message)
	return false

func raw_key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func tap(code: int) -> void:
	raw_key(code, true)
	raw_key(code, false)

func input(code: String, pressed: bool) -> void:
	var event := Model.virtual_event(code, pressed)
	if event is InputEventKey:
		event.location = KEY_LOCATION_RIGHT if code in ["ControlRight", "ShiftRight", "AltRight"] else KEY_LOCATION_LEFT
	if event is InputEventMouseButton:
		event.position = root.get_visible_rect().size * Vector2(0.5, 0.65)
		event.global_position = event.position
	Input.parse_input_event(event)

func capture_pointer() -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_visible_rect().size * Vector2(0.5, 0.65)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await process_frame
	input("MouseLeft", true)
	input("MouseLeft", false)
	await process_frame
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "ordinary capture click")

func mark(stage: String) -> void:
	var request := HTTPRequest.new()
	root.add_child(request)
	request.timeout = 5
	check(request.request(control + "/" + stage, [], HTTPClient.METHOD_POST) == OK, "stage request " + stage)
	var response: Array = await request.request_completed
	check(int(response[1]) == 200, "source wire stage " + stage + ": " + response[3].get_string_from_utf8())
	request.queue_free()

func choose(action: String, code: String) -> void:
	var panel: Node = settings.panel.find_child("KeyboardMouseBindings", true, false)
	check(panel != null, "discoverable binding panel")
	var choice: OptionButton = panel.choices[action]
	var index := -1
	for item in choice.item_count:
		if choice.get_item_metadata(item) == code: index = item
	check(index >= 0, "supported option " + code)
	choice.grab_focus()
	await process_frame
	tap(KEY_SPACE)
	await process_frame
	check(choice.get_popup().visible, "keyboard opens options " + action)
	tap(KEY_HOME)
	await process_frame
	for item in choice.item_count + 1:
		var focused := choice.get_popup().get_focused_item()
		if focused == index: break
		tap(KEY_DOWN if focused < index else KEY_UP)
		await process_frame
	tap(KEY_ENTER)
	await process_frame
	check(store.values[action] == code, "GUI applied " + action + "=" + code)

func screenshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out.path_join(name + ".png")) == OK, "capture " + name)

func run() -> void:
	settings = root.get_node("LocalSettings")
	store = root.get_node("InputBindings")
	root.size = Vector2i(760, 520) if compact else Vector2i(1280, 800)
	settings.set_value("ui_scale", 150 if compact else 100, false)
	root.grab_focus()
	check(change_scene_to_file("res://world/session.tscn") == OK, "production scene")
	await scene_changed
	session = current_scene
	if not await wait_for(func() -> bool: return session.phase == 3 and session.received_pose, "living source snapshot"): finish(); return
	tap(KEY_F12)
	await process_frame
	check(settings.overlay_open(), "F12 discovers settings")
	for pair: Array in [["forward", "ArrowUp"], ["melee", "MouseX1"], ["mobility", "MouseX2"], ["fire", "KeyI"], ["power", "KeyY"], ["crouch", "ControlRight"]]:
		await choose(pair[0], pair[1])
	await screenshot("settings-scrolled")
	var previous: Dictionary = store.values.duplicate(true)
	store.load_at(store.path)
	check(store.values == previous, "reload persisted GUI bindings")
	tap(KEY_ESCAPE)
	await process_frame
	check(not settings.overlay_open() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Esc closes without recapture")
	await capture_pointer()
	await mark("old-start")
	for code: String in ["KeyW", "KeyQ", "KeyF", "KeyX", "ControlLeft", "MouseLeft"]: input(code, true)
	await create_timer(0.3).timeout
	for code: String in ["KeyW", "KeyQ", "KeyF", "KeyX", "ControlLeft", "MouseLeft"]: input(code, false)
	await mark("old-end")
	await mark("new-start")
	for code: String in ["ArrowUp", "KeyY", "MouseX1", "MouseX2", "KeyI", "ControlRight"]: input(code, true)
	await create_timer(0.4).timeout
	await mark("new-end")
	# Genuine Settings boundary while all mapped actions are held; releases are
	# delivered through the scene even though its GUI owns input.
	tap(KEY_F12)
	await create_timer(0.2).timeout
	await mark("neutral-start")
	for code: String in ["ArrowUp", "KeyY", "MouseX1", "MouseX2", "KeyI", "ControlRight"]: input(code, false)
	input("KeyI", true) # Suppressed typing must not replay after recapture.
	tap(KEY_ESCAPE)
	await process_frame
	await capture_pointer()
	await create_timer(0.25).timeout
	await mark("neutral-end")
	input("KeyI", false)
	input("KeyI", true)
	await create_timer(0.1).timeout
	input("KeyI", false)
	# Real transport snapshot/event silence, not an actor-state rewrite.
	input("ArrowUp", true)
	await mark("silence")
	await create_timer(1.3).timeout
	check(session.snapshot_watch.stale() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "stale releases held movement")
	await mark("resume")
	await create_timer(0.4).timeout
	await mark("neutral-start")
	await capture_pointer()
	await create_timer(0.25).timeout
	await mark("neutral-end")
	input("ArrowUp", false)
	var info: Node = settings.player_info
	await create_timer(0.1).timeout
	check(info.ability.text.contains("Y ·") and not info.ability.text.begins_with("Q ·"), "actual remapped ability hint")
	check(info.ability.text.contains("Mouse X2"), "actual remapped grapple hint")
	await screenshot("remapped-ability")
	# Synthetic recipient boundary is explicitly labeled; no live seat mutation
	# request or simulation action is sent by this check.
	session.client.spectating = true
	var seq: int = session.client.input_seq
	settings.open_panel()
	store.set_binding("fire", "Semicolon")
	await create_timer(0.25).timeout
	check(session.client.input_seq == seq, "spectator rebind queues no neutral packets")
	finish()

func finish() -> void:
	if done: return
	done = true
	var report := {"failures":failures,"compact":compact,"synthetic_input_events":true,"ordinary_source_authority":true,"os_input_acceptance":false,"synthetic_spectator_boundary":true}
	var file := FileAccess.open(out.path_join("native.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "  "))
	print("BINDINGS_JOURNEY_RESULT ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
