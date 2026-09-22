extends SceneTree
## Actual native engine-event controls against an ordinary normal-rate authority.
var demo: Node
var panel: Control
var output := ""
var started := 0
var failures := 0
var checks := 0

func _initialize() -> void:
	started = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--world-output="): output = arg.trim_prefix("--world-output=")
	call_deferred("run")

func record(event: String, data: Dictionary = {}) -> void:
	data.event = event
	data.ms = Time.get_ticks_msec() - started
	if is_instance_valid(demo):
		data.inputSeq = demo.client.input_seq
		data.snapshotSeq = demo.client.last_snapshot_seq
		data.ackHighWater = demo.client.last_ack
		data.actor = demo.client.actor_id
		data.peer = demo.client.peer_id
	print("WORLD_COMMANDS ", JSON.stringify(data))

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures += 1; push_error(message)
	record("check", {"ok":ok, "message":message})
	return ok

func wait_for(condition: Callable, message: String, seconds: float = 15) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while not condition.call() and Time.get_ticks_msec() < end: await process_frame
	return check(condition.call(), message)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func click(point: Vector2) -> void:
	await mouse(point, true)
	await mouse(point, false)

func button(control: Control) -> void:
	await click(control.get_global_rect().get_center())

func toggle() -> void:
	await key(KEY_C, true)
	await key(KEY_C, false)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "saved " + name)

func run() -> void:
	await process_frame
	demo = current_scene
	panel = demo.world_commands
	if not await wait_for(func() -> bool: return demo.can_capture_pointer(), "ordinary world host ready"): quit(1); return
	check(panel.client == demo.client, "overlay shares the actor movement transport")
	await click(Vector2(900, 600))
	await key(KEY_W, true)
	await mouse(Vector2(900, 600), true)
	await create_timer(0.15).timeout
	await toggle()
	record("opened")
	check(panel.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not demo.can_capture_pointer(), "C releases pointer and blocks capture with controls held")
	check(demo.client.actions.is_empty(), "opening sends no command")
	await create_timer(0.35).timeout
	var position: Vector3 = demo.camera.position
	await create_timer(0.4).timeout
	check(demo.camera.position.distance_to(position) < 0.1, "open overlay stops authoritative movement despite held W/fire")
	await key(KEY_W, false)
	await mouse(Vector2(900, 600), false)
	var index: int = panel.node_ids.find("front-%d" % int(demo.client.projection.team))
	if not check(index >= 0, "public own-front objective listed"): quit(1); return
	panel.nodes.ensure_current_is_visible()
	await click(panel.nodes.global_position + panel.nodes.get_item_rect(index).get_center())
	check(panel.selected == panel.node_ids[index] and demo.client.actions.is_empty(), "objective selection has no command side effect")
	await button(panel.hold_button)
	await button(panel.hold_button)
	check(demo.client.actions.size() == 1 and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "double HOLD click queues one action without world recapture")
	if not await wait_for(func() -> bool: return demo.client.actions.size() == 1 and demo.client.actions[0].status != "queued", "HOLD receives authoritative card status"): quit(1); return
	check(demo.client.actions[0].status != "rejected", "source accepts HOLD")
	record("hold-receipt", {"actions":demo.client.actions.duplicate(true)})
	await create_timer(0.8).timeout
	if demo.client.mode == "cocs":
		if not await wait_for(func() -> bool: return not panel.confirm_spend.disabled, "recipient permits PvP Fighter"): quit(1); return
		var spent: float = demo.client.projection.spent
		var spawned: int = demo.client.projection.roles.spawned
		record("before-purchase", {"spent":spent,"spawned":spawned})
		await button(panel.spend_button)
		check(demo.client.actions.size() == 1, "purchase without fresh checkbox queues nothing")
		await button(panel.confirm_spend)
		check(panel.confirm_spend.button_pressed, "explicit engine click authorizes one purchase")
		await button(panel.spend_button)
		await button(panel.spend_button)
		check(demo.client.actions.size() == 2 and not panel.confirm_spend.button_pressed, "double purchase click consumes one consent")
		if not await wait_for(func() -> bool: return demo.client.actions.size() == 2 and demo.client.actions[1].status == "confirmed", "Fighter confirmed by source card"): quit(1); return
		check(is_equal_approx(float(demo.client.projection.spent) - spent, demo.client.PVP_FIGHTER_FLUX) and int(demo.client.projection.roles.spawned) == spawned + 1, "recipient reconciles 12 FLUX spent and one source unit")
		record("purchase-receipt", {"spent":demo.client.projection.spent,"spawned":demo.client.projection.roles.spawned,"actions":demo.client.actions.duplicate(true)})
	else:
		check(panel.confirm_spend.disabled and panel.spend_button.disabled and panel.economy_help.text == demo.client.action_gate("reinforce"), "co-op recruitment uses current transport window permission")
		record("coop-window", {"gate":panel.economy_help.text,"recruitment":demo.client.projection.recruitment})
	await capture("commands")
	check(panel.panel.get_global_rect().end.x <= root.size.x and panel.panel.get_global_rect().end.y <= root.size.y, "command panel fits native viewport")
	# Close with W held; neither its closing key nor a held button can recapture.
	await key(KEY_W, true)
	await toggle()
	await mouse(Vector2(900, 600), true)
	check(not panel.visible and panel.selected.is_empty() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "closing clears selection and held movement blocks recapture")
	await key(KEY_W, false)
	await process_frame
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not demo.can_capture_pointer(), "key release with mouse still held cannot recapture")
	await mouse(Vector2(900, 600), false)
	await process_frame
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "releasing all controls alone does not resume")
	record("resume-click")
	await click(Vector2(900, 600))
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "fresh click after release resumes world")
	record("resumed")
	var previous: Vector3 = demo.camera.position
	await key(KEY_D, true)
	await create_timer(0.4).timeout
	await key(KEY_D, false)
	check(demo.camera.position.distance_to(previous) > 0.5, "same actor moves after explicit recapture")
	await toggle()
	await capture("reopened")
	record("before-disconnect", {"actions":demo.client.actions.duplicate(true)})
	demo.client.disconnect_server()
	await process_frame
	check(panel.selected.is_empty() and not panel.confirm_spend.button_pressed and panel.hold_button.disabled and panel.spend_button.disabled and demo.client.actions.is_empty() and not demo.can_capture_pointer(), "disconnect clears recipient actions, selection, consent and controls")
	record("result", {"checks":checks,"failures":failures})
	quit(0 if failures == 0 else 1)
