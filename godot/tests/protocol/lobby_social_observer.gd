extends SceneTree
# Live helper for the native social journey. Input events, window size and
# interface scale only. The session, its widgets and the authority stay
# read-only: every gameplay handler is the shipped one. Samples are printed as
# SOCIAL_SAMPLE lines for the parent Node harness to assert against.
var session: Node
var inbox := ""
var out := ""
var elapsed := 0.0
var sampled := 0.0
var last_command := -1
var revision := -1
var pending: Array = []
const KEYS := {"W":KEY_W,"A":KEY_A,"S":KEY_S,"D":KEY_D,"Escape":KEY_ESCAPE,"Enter":KEY_ENTER,"Down":KEY_DOWN,"Tab":KEY_TAB}
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--lobby-inbox="): inbox = arg.trim_prefix("--lobby-inbox=")
		if arg.begins_with("--lobby-out="): out = arg.trim_prefix("--lobby-out=")
	call_deferred("begin")
func begin() -> void:
	session = load("res://world/session.tscn").instantiate()
	root.add_child(session)
	session.client.started.connect(func(frame: Dictionary) -> void: revision = int(frame.get("roundRevision",-1)))
func key(code: int, pressed: bool, unicode_value := 0, ctrl := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode_value
	event.ctrl_pressed = ctrl
	event.pressed = pressed
	Input.parse_input_event(event)
func command(c: Dictionary) -> void:
	match c.op:
		"focus": root.grab_focus()
		"resize": root.size = Vector2i(c.width,c.height)
		"scale": root.content_scale_factor = float(c.value)
		"key": key(KEYS[c.key],c.pressed,0,c.get("ctrl",false))
		"mouse":
			var event := InputEventMouseButton.new()
			event.position = Vector2(c.x,c.y)
			event.global_position = event.position
			event.button_index = c.get("button",1)
			event.pressed = c.pressed
			Input.parse_input_event(event)
		"text":
			for character: String in str(c.text): pending.append(character.unicode_at(0))
		"focus_named":
			var control := named(str(c.name))
			if control != null: control.grab_focus()
		"capture": capture.call_deferred(str(c.name))
func named(control_name: String) -> Control:
	var menu: Node = session.lobby_menu
	if menu == null: return null
	match control_name:
		"browse": return menu.room_browser.refresh_button
		"chat_toggle": return menu.chat_panel.toggle_button
		"chat_close": return menu.chat_panel.close_button
		"chat_input": return menu.chat_panel.input
		_:
			var direct: Node = menu.get(control_name)
			return direct if direct is Control else null
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/"+name+".png")
func rect(control: Control) -> Array:
	var r := control.get_global_rect()
	return [r.position.x,r.position.y,r.size.x,r.size.y]
func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 175: quit(9)
	if not is_instance_valid(session) or not is_instance_valid(session.lobby_menu): return false
	if not pending.is_empty():
		var character: int = pending.pop_front()
		key(0,true,character)
		key(0,false,character)
	if FileAccess.file_exists(inbox):
		var c: Variant = JSON.parse_string(FileAccess.get_file_as_string(inbox))
		if c is Dictionary and c.id > last_command:
			last_command = c.id
			command(c)
	sampled += delta
	if sampled < 0.15: return false
	sampled = 0
	var menu: Node = session.lobby_menu
	var browser: Node = menu.room_browser
	var chat: Node = menu.chat_panel
	var ui := {}
	for name: String in ["endpoint","player_name","room","role","maps","modes","connect_button","start_button","back_button","leave_button","restart_button"]:
		var control: Control = menu.get(name)
		ui[name] = {"rect":rect(control),"visible":control.is_visible_in_tree(),"text":control.get("text"),"in_form":menu.form.is_ancestor_of(control)}
	for entry: Array in [["browse",browser.refresh_button],["chat_toggle",chat.toggle_button],["chat_close",chat.close_button],["chat_input",chat.input],["chat_send",chat.send_button],["chat_panel",chat.panel]]:
		var control: Control = entry[1]
		ui[entry[0]] = {"rect":rect(control),"visible":control.is_visible_in_tree(),"text":control.get("text")}
	var rooms: Array = []
	var row_index := 0
	for row: Node in browser.list_box.get_children():
		if row.get_child_count() >= 2:
			ui["room_%d" % row_index] = {"rect":rect(row.get_child(0)),"visible":row.get_child(0).is_visible_in_tree(),"text":(row.get_child(0) as Button).text}
			rooms.append({"code":(row.get_child(0) as Button).text,"detail":(row.get_child(1) as Label).text})
			row_index += 1
	var chat_log := PackedStringArray()
	for line: Node in chat.log_box.get_children():
		if line is Label: chat_log.append((line as Label).text)
	var local: Dictionary = session.presentation.local_actor
	print("SOCIAL_SAMPLE ",JSON.stringify({
		"seconds":elapsed,"command":last_command,"phase":session.phase,"revision":revision,
		"map":session.current_id,"selected_map":str(menu.maps.get_selected_metadata()),"selected_mode":str(menu.modes.get_selected_metadata()),
		"mode":session.selected_mode,"room":session.client.room_id,"endpoint":session.endpoint,
		"bound":browser.endpoint_label.text,"browser_status":browser.status.text,
		"peer":session.client.peer_id,"actor":session.client.actor_id,"ack":session.client.last_ack,"input_seq":session.client.input_seq,
		"starts":session.round_starts,"results":session.round_results,"pose":session.received_pose,
		"captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"eligible":session.can_capture_pointer(),"capturing":menu.capturing_input(),
		"focused":root.has_focus(),"actors":session.presentation.actors.size(),
		"local":{"x":local.get("x"),"z":local.get("z"),"shots":local.get("shots"),"health":local.get("health")},
		"roster":menu.roster.text,"status":menu.status.text,"chat_status":chat.status.text,"chat_log":Array(chat_log),"rooms":rooms,
		"error":session.label.text if session.phase == -1 else "","ui":ui,"viewport":[root.size.x,root.size.y] }))
	return false
