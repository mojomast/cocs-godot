extends SceneTree
## Real shipped session/menu; only scripted pointer clicks and setup fields.
var session: Node
var inbox := ""
var screenshot := ""
var command_id := -1
var revision := -1
var sampled := 0.0
var elapsed := 0.0
var profile_digest := ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--reconnect-inbox="): inbox = arg.trim_prefix("--reconnect-inbox=")
		if arg.begins_with("--reconnect-shot="): screenshot = arg.trim_prefix("--reconnect-shot=")
	call_deferred("begin")

func begin() -> void:
	session = load("res://world/session.tscn").instantiate()
	root.add_child(session)
	current_scene = session
	session.client.started.connect(func(frame: Dictionary) -> void: revision = int(frame.get("roundRevision", -1)))

func action(command: Dictionary) -> void:
	var menu: Node = session.lobby_menu
	match command.get("op"):
		"setup_guest":
			menu.role.select(1)
			menu.room.text = str(command.get("room", ""))
		"scale": root.content_scale_factor = float(command.get("value", 1.0))
		"resize": root.size = Vector2i(int(command.width), int(command.height))
		"click":
			var control: Control = menu.get(str(command.get("name", "")))
			if control == null or not control.is_visible_in_tree(): return
			root.grab_focus()
			control.grab_focus()
			await process_frame
			await process_frame
			var rect := control.get_global_rect()
			var event := InputEventMouseButton.new()
			event.position = rect.get_center() * root.content_scale_factor
			event.global_position = event.position
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = true
			Input.parse_input_event(event)
			await process_frame
			var released := event.duplicate() as InputEventMouseButton
			released.pressed = false
			Input.parse_input_event(released)
		"capture":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(screenshot)

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 100: quit(9)
	if not is_instance_valid(session) or not is_instance_valid(session.lobby_menu): return false
	if FileAccess.file_exists(inbox):
		var command: Variant = JSON.parse_string(FileAccess.get_file_as_string(inbox))
		if command is Dictionary and int(command.get("id", -1)) > command_id:
			command_id = int(command.id)
			action(command)
	sampled += delta
	if sampled < 0.12: return false
	sampled = 0.0
	var menu: Node = session.lobby_menu
	var controls := {}
	for name: String in ["reconnect_button", "back_button", "connect_button"]:
		var control: Control = menu.get(name)
		var rect := control.get_global_rect()
		controls[name] = {"visible":control.is_visible_in_tree(), "disabled":control.disabled, "rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]}
	var career: Node = root.get_node_or_null("Career")
	var profile_id := str(career.profile.get("id", "")) if career != null else ""
	# Internal equality witness only; neither ID nor digest is serialized.
	if profile_digest.is_empty() and not profile_id.is_empty(): profile_digest = profile_id.sha256_text()
	var view := {"phase":session.phase,"command":command_id,"actor":session.client.actor_id,
		"revision":revision,"seq":session.client.input_seq,"ack":session.client.last_ack,
		"pose":session.received_pose,"pointer":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"room_seated":not session.client.room_id.is_empty(),"profile_present":not profile_id.is_empty(),
		"profile_stable":not profile_id.is_empty() and profile_id.sha256_text() == profile_digest,
		"chat_count":menu.chat_panel.log_box.get_child_count(),"chat_draft":menu.chat_panel.input.text.length(),
		"ticket":not session.client.reconnect_ticket.token.is_empty(),"controls":controls,
		"viewport":[root.get_visible_rect().size.x,root.get_visible_rect().size.y]}
	print("RECONNECT_SAMPLE ", JSON.stringify(view))
	return false
