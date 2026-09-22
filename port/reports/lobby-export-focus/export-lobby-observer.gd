extends SceneTree
# Live helper: input events and window configuration only. Session, widgets and
# authority are read-only. All gameplay handlers remain the shipped handlers.
var session: Node
var inbox := ""
var out := ""
var elapsed := 0.0
var sampled := 0.0
var last_command := -1
var revision := -1
var pending: Array = []
var stage := "startup"
var focus_policy := "needed"
func witness(event: String) -> void:
	var popups := {}
	if is_instance_valid(session) and is_instance_valid(session.lobby_menu):
		for name: String in ["role","maps","modes"]:
			var item: OptionButton = session.lobby_menu.get(name)
			var popup := item.get_popup()
			popups[name] = {"visible":popup.visible,"focused":popup.has_focus(),"embedded":popup.is_embedded(),"index":popup.get_focused_item(),"selected":item.selected}
	var connections := {}
	for signal_name: String in ["focus_entered","tree_exited"]:
		var calls: Array = []
		for entry: Dictionary in root.get_signal_connection_list(signal_name):
			var callback: Callable = entry.callable
			calls.append({"id":callback.get_object_id(),"method":str(callback.get_method()),"valid":callback.is_valid()})
		connections[signal_name] = calls
	print("EXPORT_WITNESS ",JSON.stringify({"wall":Time.get_unix_time_from_system()*1000,"ticks":Time.get_ticks_usec(),"event":event,"stage":stage,"command":last_command,"root_focused":root.has_focus(),"popups":popups,"connections":connections}))
const KEYS := {"W":KEY_W,"A":KEY_A,"Escape":KEY_ESCAPE,"Enter":KEY_ENTER,"Down":KEY_DOWN,"Tab":KEY_TAB}
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--lobby-inbox="): inbox = arg.trim_prefix("--lobby-inbox=")
		if arg.begins_with("--lobby-out="): out = arg.trim_prefix("--lobby-out=")
	call_deferred("begin")
func begin() -> void:
	session = load("res://world/session.tscn").instantiate()
	root.add_child(session)
	root.focus_entered.connect(func() -> void: witness("root-focus-entered"))
	root.focus_exited.connect(func() -> void: witness("root-focus-exited"))
	for name: String in ["role","maps","modes"]:
		var item: OptionButton = session.lobby_menu.get(name)
		item.get_popup().about_to_popup.connect(func() -> void: witness(name+"-about-to-popup"))
		item.get_popup().popup_hide.connect(func() -> void: witness(name+"-popup-hide"))
		item.item_selected.connect(func(_index: int) -> void: witness(name+"-item-selected"))
	session.client.started.connect(func(frame: Dictionary) -> void: revision = int(frame.get("roundRevision",-1)))
	session.client.snapshot.connect(func(frame: Dictionary) -> void:
		var actor: Dictionary = session.presentation.local_actor
		var local := {}
		for key: String in ["id","x","y","z","health","dead","shots","weapon","ammo"]:
			if actor.has(key): local[key] = actor[key]
		var visuals: Array = []
		for id: int in session.presentation.actors:
			var node: Node3D = session.presentation.actors[id]
			var track: Array = session.presentation.motion.tracks.get(id,[])
			if not track.is_empty():
				var pose: Vector3 = track.back().position
				visuals.append({"id":id,"ingested":[pose.x,pose.y,pose.z],"rendered":[node.position.x,node.position.y,node.position.z],"visible":node.visible})
		print("LOBBY_APPLIED ",JSON.stringify({"seq":frame.seq,"revision":revision,"peer":session.client.peer_id,"actor":session.client.actor_id,"ack":session.client.last_ack,"local":local,"camera":[session.camera.position.x,session.camera.position.y,session.camera.position.z],"spectating":session.client.spectating,"visuals":visuals})))
func key(code: int, pressed: bool, unicode_value := 0, ctrl := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode_value
	event.ctrl_pressed = ctrl
	event.pressed = pressed
	Input.parse_input_event(event)
func command(c: Dictionary) -> void:
	stage = c.get("stage",stage)
	witness("before-"+str(c.op))
	match c.op:
		"focus":
			if c.get("policy","needed") == "always" or not root.has_focus():
				witness("grab-focus-issued")
				root.grab_focus()
			else: witness("grab-focus-skipped-already-focused")
		"resize": root.size = Vector2i(c.width,c.height)
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
		"capture": capture.call_deferred(str(c.name))
	witness("after-"+str(c.op))
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/"+name+".png")
func rect(control: Control) -> Array:
	var r := control.get_global_rect()
	return [r.position.x,r.position.y,r.size.x,r.size.y]
func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 115: quit(9)
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
	var hud: Node = session.get_node("GameHUD")
	var board: Node = session.get_node("Scoreboard")
	var ui := {}
	for name: String in ["endpoint","player_name","room","role","maps","modes","connect_button","start_button","back_button","leave_button","restart_button"]:
		var control: Control = menu.get(name)
		ui[name] = {"rect":rect(control),"visible":control.is_visible_in_tree(),"text":control.get("text"),"in_form":menu.form.is_ancestor_of(control)}
		if control is OptionButton:
			ui[name].popup_visible = control.get_popup().visible
			ui[name].popup_focused = control.get_popup().get_focused_item()
			ui[name].selected = control.selected
			ui[name].items = []
			for i: int in control.item_count: ui[name].items.append({"text":control.get_item_text(i),"metadata":control.get_item_metadata(i)})
	var layout := {}
	for entry: Array in [["hud",hud.root],["top",hud.top],["score",hud.score_label],["status",hud.status_panel],["board",board.panel],["menu",menu.panel]]:
		layout[entry[0]] = {"rect":rect(entry[1]),"visible":entry[1].is_visible_in_tree()}
	print("LOBBY_SAMPLE ",JSON.stringify({"seconds":elapsed,"wall":Time.get_unix_time_from_system()*1000,"stage":stage,"command":last_command,"phase":session.phase,"revision":revision,"map":session.current_id,"mode":session.selected_mode,"room":session.client.room_id,"peer":session.client.peer_id,"actor":session.client.actor_id,"ack":session.client.last_ack,"input_seq":session.client.input_seq,"starts":session.round_starts,"results":session.round_results,"pose":session.received_pose,"captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"eligible":session.can_capture_pointer(),"focused":root.has_focus(),"actors":session.presentation.actors.size(),"pickups":session.pickups.markers.size(),"roster":menu.roster.text,"status":menu.status.text,"error":session.label.text if session.phase == -1 else "","ui":ui,"layout":layout,"viewport":[root.size.x,root.size.y],"spectating":session.client.spectating,"hud_title":hud.status_title.text,"hud_detail":hud.status_detail.text}))
	return false
