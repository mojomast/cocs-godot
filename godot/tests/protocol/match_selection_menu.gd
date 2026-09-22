extends SceneTree
const Session = preload("res://world/session.gd")
var session: Node
func require(value: bool, message: String) -> bool:
	if not value:
		push_error(message)
		quit(1)
	return value
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	await process_frame
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	session = Session.new()
	root.add_child(session)
	await create_timer(0.5).timeout
	if not require(session.phase == -2 and session.client.peer.get_ready_state() == WebSocketPeer.STATE_CLOSED, "Setup connected before Start"): return
	var menu: Control = session.setup_menu
	menu.map_choice.grab_focus()
	await key(KEY_SPACE)
	await key(KEY_DOWN)
	await key(KEY_ENTER)
	if not require(menu.selected_map() == "verdant-reliquary", "Map dropdown keyboard selection failed"): return
	menu.mode_choice.grab_focus()
	await key(KEY_SPACE)
	await key(KEY_DOWN)
	await key(KEY_DOWN)
	await key(KEY_ENTER)
	if not require(menu.selected_mode() == "instagib" and not menu.start.disabled, "Mode dropdown keyboard selection failed"): return
	await process_frame
	await RenderingServer.frame_post_draw
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--selection-evidence="):
			if not require(root.get_texture().get_image().save_png(arg.trim_prefix("--selection-evidence=")) == OK, "Screenshot failed"): return
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = menu.start.get_global_rect().get_center()
	click.pressed = true
	Input.parse_input_event(click)
	await process_frame
	click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = menu.start.get_global_rect().get_center()
	Input.parse_input_event(click)
	for frame in range(900):
		await process_frame
		if session.phase == -1:
			require(false, session.label.text)
			return
		if session.phase == 3 and session.received_pose and session.client.last_ack > 10:
			if not require(not menu.visible and session.label.mouse_filter == Control.MOUSE_FILTER_IGNORE and session.selector.mouse_filter == Control.MOUSE_FILTER_IGNORE and session.label.get_parent().mouse_filter == Control.MOUSE_FILTER_IGNORE, "Gameplay UI intercepted pointer"): return
			print("PORT_MATCH_MENU_OK keyboard_dropdowns=true mouse_start=true deferred_connection=true map=", session.current_id, " mode=", session.selected_mode, " ack=", session.client.last_ack)
			quit(0)
			return
	require(false, "Menu native connection timed out")
