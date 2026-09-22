extends SceneTree
const Choice = preload("res://ui/lobby_choice.gd")
var checks := 0
var failures := 0
var selected_events: Array = []
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("LOBBY_POPUP_FREE " + message)
func _initialize() -> void: call_deferred("run")
func settle() -> void: await create_timer(0.08).timeout
func key(code: int, shift := false) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.shift_pressed = shift
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()
func click(control: Control) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()
func popup_count(node: Node) -> int:
	var count := 1 if node is PopupMenu or node is OptionButton else 0
	for child: Node in node.get_children(true): count += popup_count(child)
	return count
func run() -> void:
	var probe := Choice.new()
	probe.item_selected.connect(func(index: int) -> void: selected_events.append(index))
	probe.add_item("One"); probe.add_item("Two")
	probe.set_item_metadata(1,"two")
	probe.select(1)
	check(probe.item_count==2 and probe.selected==1 and probe.text=="Two" and probe.get_selected_metadata()=="two","compatible item/metadata API")
	check(selected_events.is_empty(),"programmatic selection silent")
	probe.clear()
	check(probe.selected==-1 and probe.item_count==0 and probe.get_selected_metadata()==null,"empty choice safe")
	probe.free()
	var session: Node = load("res://world/session.tscn").instantiate()
	root.add_child(session)
	await settle()
	session.client.set_process(false)
	var menu: Node = session.lobby_menu
	check(popup_count(menu)==0,"no OptionButton or PopupMenu anywhere in lobby including internal children")
	var baseline := root.get_signal_connection_list("tree_exited").size()
	menu.role.item_selected.connect(func(index: int) -> void: selected_events.append(index))
	for size: Vector2i in [Vector2i(960,640),Vector2i(1280,800)]:
		root.size = size
		await settle()
		for choice: Control in [menu.role,menu.maps,menu.modes]:
			check(choice.get_global_rect().encloses(choice.current_label.get_global_rect()),"label contained "+str(size))
			check(not choice.previous.get_global_rect().intersects(choice.next.get_global_rect()),"buttons separate "+str(size))
			check(Rect2(Vector2.ZERO,Vector2(size)).encloses(choice.get_global_rect()),"choice in viewport "+str(size))
		await click(menu.role.next)
		check(menu.role.selected==1 and menu.modes.disabled and menu.room.editable,"guest selection disables mode and enables room")
		check(menu.role.next.has_focus(),"native button focus after click")
		await key(KEY_LEFT)
		check(menu.role.selected==0 and not menu.modes.disabled,"left arrow on focused button changes role")
		await click(menu.role.current_label)
		check(menu.role.has_focus(),"label area focuses row with drawn focus outline")
		await key(KEY_RIGHT)
		check(menu.role.selected==1,"right arrow on row changes role")
		await key(KEY_ESCAPE)
		check(menu.role.selected==1 and session.phase==-3,"Escape does not change choice or connect")
		await key(KEY_TAB)
		check(menu.role.previous.has_focus(),"Tab enters previous button")
		await key(KEY_TAB)
		check(menu.role.next.has_focus(),"Tab enters next button")
		await key(KEY_TAB,true)
		check(menu.role.previous.has_focus(),"Shift Tab returns to previous button")
		await key(KEY_ENTER)
		check(menu.role.selected==0,"Enter activates focused Previous")
		var old_map: String = menu.maps.get_selected_metadata()
		await click(menu.maps.next)
		check(menu.maps.get_selected_metadata()!=old_map,"next map selected")
		check(menu.modes.item_count==session.catalog.entries[menu.maps.get_selected_metadata()].modes.size(),"map change rebuilds mode choices")
		await click(menu.maps.previous)
		check(menu.maps.get_selected_metadata()==old_map,"previous map restored")
		var mode := int(menu.modes.selected)
		await click(menu.modes.next)
		check(menu.modes.selected!=mode,"mode next cycles")
		await click(menu.modes.previous)
		check(menu.modes.selected==mode,"mode previous restores")
		for i: int in 4:
			await click(menu.role.previous)
		check(menu.role.selected==0,"repeated wraparound selection")
		session.phase = 11 # Explicit synthetic connected fixture, no authority writes.
		await settle()
		for choice: Control in [menu.role,menu.maps,menu.modes]:
			var before: int = choice.selected
			await click(choice.next)
			await key(KEY_RIGHT)
			check(choice.disabled and choice.next.disabled and choice.previous.disabled and choice.selected==before,"connected choice inert")
		session.phase = -3
		await settle()
	check(root.get_signal_connection_list("tree_exited").size()==baseline,"no popup parent callbacks accumulated")
	check(popup_count(menu)==0,"no hidden popup introduced by cycling")
	check(selected_events.size()==16,"exactly one role signal per real selection across both sizes")
	session.free()
	print("LOBBY_POPUP_FREE checks=",checks," failures=",failures," actual_scene=true engine_events=true synthetic_connected_phase=true")
	quit(1 if failures else 0)
