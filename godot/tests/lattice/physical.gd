extends SceneTree
## External observer main loop: the command-line board.tscn remains the real scene.
## Interaction is exclusively Input.parse_input_event; reads never alter gameplay state.
var board: Control
var checks := 0
var failures := 0
var output := ""
var started := 0

func _initialize() -> void:
	started = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--physical-output="): output = arg.trim_prefix("--physical-output=")
	call_deferred("run")

func record(event: String, detail: Dictionary = {}) -> void:
	detail["event"] = event
	detail["ms"] = Time.get_ticks_msec() - started
	print("PHYSICAL " + JSON.stringify(detail))

func check(value: bool, message: String) -> bool:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
	record("check", {"ok":value, "message":message})
	return value

func wait_for(condition: Callable, message: String, seconds: float = 15.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return check(condition.call(), message)

func click_at(point: Vector2, description: String) -> void:
	record("mouse", {"control":description, "x":point.x, "y":point.y})
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func click(control: Control) -> void:
	await click_at(control.get_global_rect().get_center(), str(control.get("text")))

func key(code: Key) -> void:
	record("key", {"code":code})
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "saved " + name)

func observed(event: String) -> void:
	var p: Dictionary = board.client.projection
	record(event, {"map":board.client.requested_map, "mode":board.client.mode,
		"peer":board.client.peer_id, "actor":board.client.actor_id, "round":board.client.revision,
		"team":p.get("team"), "spent":p.get("spent"), "flux":p.get("flux"),
		"spawned":p.get("roles", {}).get("spawned"), "actions":board.client.actions.duplicate(true),
		"selected":board.selected, "history":board.history.text})

func run() -> void:
	await process_frame
	board = current_scene
	if not check(board != null and board.scene_file_path == "res://lattice/board.tscn", "actual board.tscn loaded by engine"):
		quit(1); return
	check(not board.smoke, "built-in signal smoke is off")
	await process_frame
	check(board.hold_button.disabled and board.spend_button.disabled, "initial controls disabled")
	await click(board.connect_button)
	if not await wait_for(func() -> bool: return board.phase == "active" and board.client.gate().is_empty(), "physical Connect reaches live recipient state"):
		quit(1); return
	observed("connected")
	var target: String = "front-%d" % int(board.client.projection.team)
	var index: int = board.node_ids.find(target)
	if not check(index >= 0, "recipient contains own-front objective"):
		quit(1); return
	var item: Rect2 = board.nodes.get_item_rect(index)
	await click_at(board.nodes.global_position + item.get_center(), "ItemList " + target)
	check(board.selected == target and board.nodes.is_selected(index), "real ItemList mouse selection selects own front")
	# Exercise native keyboard selection too, returning to the same source-authored target.
	await key(KEY_UP)
	check(board.selected == board.node_ids[index - 1], "ItemList Up keyboard changes selection")
	await key(KEY_DOWN)
	if not check(board.selected == target and board.nodes.is_selected(index), "ItemList Down keyboard returns to own front"):
		quit(1); return
	if not await wait_for(func() -> bool: return not board.hold_button.disabled, "HOLD enabled for selected target"):
		quit(1); return
	await click(board.hold_button)
	await click(board.hold_button)
	check(board.client.actions.size() == 1, "rapid repeated HOLD click submits one action")
	if not await wait_for(func() -> bool: return board.client.actions.size() == 1 and board.client.actions[0].status == "pending (server accepted)", "HOLD authoritative running acceptance"):
		quit(1); return
	observed("hold-accepted")
	if board.client.mode == "cocs":
		if not await wait_for(func() -> bool: return not board.confirm_spend.disabled, "Fighter authorization available"):
			quit(1); return
		var before: float = float(board.client.projection.spent)
		var spawned: int = int(board.client.projection.roles.spawned)
		observed("before-purchase")
		check(board.spend_button.disabled, "purchase requires fresh explicit checkbox")
		await click(board.confirm_spend)
		check(board.confirm_spend.button_pressed and not board.spend_button.disabled, "physical checkbox authorizes one purchase")
		await key(KEY_TAB)
		if not check(root.gui_get_focus_owner() == board.spend_button, "Tab from authorization focuses Recruit Fighter"):
			quit(1); return
		await key(KEY_ENTER)
		await click(board.spend_button)
		await click(board.spend_button)
		check(board.client.actions.size() == 2, "Enter plus repeated Recruit clicks submit one spend")
		if not await wait_for(func() -> bool: return board.client.actions.size() == 2 and board.client.actions[1].status == "confirmed", "Fighter confirmed by authoritative done card"):
			quit(1); return
		check(is_equal_approx(float(board.client.projection.spent) - before, 12.0), "exact cumulative fluxSpent increase 12")
		check(int(board.client.projection.roles.spawned) == spawned + 1, "exactly one Fighter spawned")
		check(not board.confirm_spend.button_pressed and board.spend_button.disabled, "purchase authorization consumed")
		observed("purchase-confirmed")
	else:
		check(board.confirm_spend.disabled and board.spend_button.disabled, "co-op recruitment disabled during initial deployment")
	await create_timer(0.8).timeout
	check(root.get_visible_rect().encloses(board.history.get_global_rect()), "action receipts fully inside initial viewport without scroll")
	check(root.get_visible_rect().encloses(board.resources.get_global_rect()), "resources inside viewport")
	check(root.get_visible_rect().encloses(board.spend_button.get_global_rect()), "action controls inside viewport")
	observed("visible-receipts")
	await capture("receipts")
	var disconnect: Button
	for button: Node in board.find_children("*", "Button", true, false):
		if button.text == "Disconnect": disconnect = button
	await click(disconnect)
	check(board.phase == "idle" and board.client.projection.is_empty() and board.client.actions.is_empty() and board.selected.is_empty(), "physical Disconnect clears recipient state, selection and receipts")
	check(board.hold_button.disabled and board.spend_button.disabled and board.confirm_spend.disabled, "real disconnected controls disabled")
	await click(board.hold_button)
	await click(board.spend_button)
	check(board.client.actions.is_empty(), "disabled disconnected clicks submit nothing")
	await capture("disconnected")
	record("result", {"checks":checks, "failures":failures, "input":"Input.parse_input_event mouse and physical-key events; not OS input"})
	quit(1 if failures else 0)
