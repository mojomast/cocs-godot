extends SceneTree
# Independent passive observations plus ordinary engine input events. Never calls
# session/UI handlers, changes widgets, or writes authority/session state.
var session: Node
var inbox := ""
var out := ""
var elapsed := 0.0
var sampled := 0.0
var last_command := -1
var pending: Array = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--lobby-inbox="): inbox = arg.trim_prefix("--lobby-inbox=")
		if arg.begins_with("--lobby-out="): out = arg.trim_prefix("--lobby-out=")
	call_deferred("begin")

func begin() -> void:
	session = load("res://world/session.tscn").instantiate()
	root.add_child(session)
	session.client.snapshot.connect(func(frame: Dictionary) -> void:
		print("LOBBY_APPLIED ", JSON.stringify({"seq":frame.seq,"round":session.round_starts,"actor":session.client.actor_id,"ack":session.client.last_ack,"local":session.presentation.local_actor,"camera":[session.camera.position.x,session.camera.position.y,session.camera.position.z]})))

func key(code: int, pressed: bool, unicode_value: int = 0, ctrl := false) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.unicode = unicode_value
	e.ctrl_pressed = ctrl
	e.pressed = pressed
	Input.parse_input_event(e)

func mouse(x: float, y: float, button: int, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = Vector2(x,y)
	e.global_position = e.position
	e.button_index = button
	e.pressed = pressed
	Input.parse_input_event(e)

func command(c: Dictionary) -> void:
	match c.op:
		"focus": root.grab_focus()
		"mouse": mouse(c.x,c.y,c.get("button",1),c.pressed)
		"key": key(c.code,c.pressed,0,c.get("ctrl",false))
		"text":
			for character: String in str(c.text):
				pending.append({"op":"character","unicode":character.unicode_at(0)})
		"character":
			key(0,true,c.unicode)
			key(0,false,c.unicode)
		"capture": capture.call_deferred(str(c.name))
		"quit": quit()

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 175: quit(9)
	if not is_instance_valid(session) or not is_instance_valid(session.lobby_menu): return false
	if not pending.is_empty(): command(pending.pop_front())
	if FileAccess.file_exists(inbox):
		var c: Variant = JSON.parse_string(FileAccess.get_file_as_string(inbox))
		if c is Dictionary and c.id > last_command:
			last_command = c.id
			command(c)
	sampled += delta
	if sampled < 0.15: return false
	sampled = 0
	var ui: Dictionary = {}
	for name: String in ["endpoint","player_name","room","role","maps","modes","connect_button","start_button","back_button","leave_button","restart_button"]:
		var control: Control = session.lobby_menu.get(name)
		var rect := control.get_global_rect()
		ui[name] = {"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"visible":control.is_visible_in_tree(),"text":control.get("text")}
	print("LOBBY_SAMPLE ",JSON.stringify({"seconds":elapsed,"command":last_command,"phase":session.phase,"map":session.current_id,"mode":session.selected_mode,"room":session.client.room_id,"peer":session.client.peer_id,"actor":session.client.actor_id,"ack":session.client.last_ack,"starts":session.round_starts,"results":session.round_results,"pose":session.received_pose,"captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"eligible":session.can_capture_pointer(),"focused":root.has_focus(),"actors":session.presentation.actors.size(),"pickups":session.pickups.markers.size(),"roster":session.lobby_menu.roster.text,"status":session.lobby_menu.status.text,"ui":ui}))
	return false
