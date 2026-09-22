extends SceneTree
# Disconnected UI check only: native event dispatch, no authority or UI handlers.
var session: Node
func _initialize() -> void:
	call_deferred("run")
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.window_id = session.lobby_menu.role.get_popup().get_window_id()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.window_id = session.lobby_menu.role.get_popup().get_window_id()
	event.keycode = code
	event.physical_keycode = code
	Input.parse_input_event(event)
	await process_frame
func run() -> void:
	session = load("res://world/session.tscn").instantiate()
	root.add_child(session)
	await create_timer(0.3).timeout
	var menu: Node = session.lobby_menu
	var event := InputEventMouseButton.new()
	event.position = menu.role.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventMouseButton.new()
	event.position = menu.role.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(event)
	await process_frame
	print("LOBBY_POPUP visible=",menu.role.get_popup().visible," window=",menu.role.get_popup().get_window_id()," focused=",menu.role.get_popup().get_focused_item())
	await key(KEY_DOWN)
	print("LOBBY_POPUP_AFTER_DOWN visible=",menu.role.get_popup().visible," focused=",menu.role.get_popup().get_focused_item())
	await key(KEY_DOWN)
	await key(KEY_ENTER)
	await process_frame
	print("LOBBY_MENU_INPUT role=",menu.role.selected," down=",KEY_DOWN," enter=",KEY_ENTER," phase=",session.phase)
	var ok: bool = menu.role.selected == 1 and menu.room.editable and menu.modes.disabled and session.phase == -3
	session.free()
	quit(0 if ok else 1)
