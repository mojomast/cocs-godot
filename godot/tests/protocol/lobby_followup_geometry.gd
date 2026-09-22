extends SceneTree
# Actual instantiated widgets with explicitly synthetic phases/stored frames.
# This is a geometry/visibility regression, not live or physical acceptance.
var checks := 0
var failures := 0
var session: Node
var hud: Node
var menu: Node
var board: Node
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("LOBBY_GEOMETRY " + message)
func _initialize() -> void:
	call_deferred("run")
func settle() -> void:
	await create_timer(0.12).timeout
func nonoverlap() -> void:
	var bounds := Rect2(Vector2.ZERO,Vector2(root.size))
	for button: Control in [menu.leave_button,menu.restart_button]:
		if not button.is_visible_in_tree(): continue
		var rect := button.get_global_rect()
		check(bounds.encloses(rect),button.text+" fully in viewport")
		for content: Control in [hud.top,hud.score_label,hud.status_panel,board.panel]:
			if content.is_visible_in_tree(): check(not rect.intersects(content.get_global_rect()),button.text+" does not collide with "+str(content.get_path()))
	if menu.leave_button.visible and menu.restart_button.visible:
		check(not menu.leave_button.get_global_rect().intersects(menu.restart_button.get_global_rect()),"results actions do not collide")
func run() -> void:
	session = load("res://world/session.tscn").instantiate()
	root.add_child(session)
	await settle()
	session.set_process(false)
	session.client.set_process(false)
	hud = session.get_node("GameHUD")
	menu = session.lobby_menu
	board = session.get_node("Scoreboard")
	check(root.size in [Vector2i(960,640),Vector2i(1280,800)],"requested actual graphical size")
	check(session.lobby_enabled and session.phase == -3,"opt-in starts disconnected")
	for phase: int in [-3,-1,0,1,2,10,11,12]:
		session.phase = phase
		await settle()
		check(menu.panel.is_visible_in_tree(),"menu visible phase "+str(phase))
		check(not hud.root.is_visible_in_tree(),"compact HUD hidden phase "+str(phase))
		check(not menu.leave_button.visible and not menu.restart_button.visible,"gameplay buttons hidden phase "+str(phase))
		check(not board.panel.visible,"scoreboard hidden phase "+str(phase))
	session.client.peer_id = 7
	session.client.actor_id = 0
	session.lobby_roster = {"hostId":7,"players":[{"peerId":7,"connected":true,"spectate":false}]}
	session.phase = 20
	await settle()
	check(hud.root.visible and not menu.panel.visible,"starting round owns compact HUD")
	check(menu.leave_button.visible and not menu.restart_button.visible,"starting actions")
	nonoverlap()
	var capture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/protocol/captured.json"))
	var snapshot: Dictionary = {}
	var results: Dictionary = {}
	for record: Dictionary in capture.frames:
		if record.direction != "server" or record.client != 1: continue
		if record.frame.type == "snapshot" and snapshot.is_empty(): snapshot = record.frame
		if record.frame.type == "results": results = record.frame
	session.client.started.emit({"mapId":"meridian-exchange"})
	session.client.snapshot.emit(snapshot)
	await settle()
	check(session.phase == 3 and hud.root.visible and not menu.panel.visible,"playing visibility")
	check(hud.vitals.is_visible_in_tree() and menu.leave_button.visible,"playing paused HUD and leave")
	nonoverlap()
	var event := InputEventKey.new()
	event.keycode = KEY_TAB
	event.pressed = true
	Input.parse_input_event(event)
	await settle()
	check(board.panel.is_visible_in_tree(),"actual scoreboard shown by engine Tab")
	nonoverlap()
	event = InputEventKey.new()
	event.keycode = KEY_TAB
	Input.parse_input_event(event)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await settle()
	check(not menu.leave_button.visible,"leave hidden while captured")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	session.client.results.emit(results)
	await settle()
	check(session.phase == 4 and board.panel.is_visible_in_tree(),"results scoreboard visible")
	check(menu.restart_button.visible and menu.leave_button.visible,"host results actions visible")
	nonoverlap()
	print("LOBBY_RESULTS_GEOMETRY ",JSON.stringify({"size":[root.size.x,root.size.y],"leave":str(menu.leave_button.get_global_rect()),"restart":str(menu.restart_button.get_global_rect()),"top":str(hud.top.get_global_rect()),"status":str(hud.status_panel.get_global_rect()),"scoreboard":str(board.panel.get_global_rect())}))
	session.join_room_id = "synthetic-guest"
	await settle()
	check(not menu.restart_button.visible and menu.leave_button.visible,"guest cannot see host restart")
	nonoverlap()
	session.lobby_enabled = false
	session.phase = 0
	await settle()
	check(hud.root.visible,"non-lobby connecting HUD unchanged")
	session.phase = -2
	await settle()
	check(not hud.root.visible,"existing setup HUD remains hidden")
	session.phase = 3
	hud.debug_hud = true
	await settle()
	check(not hud.root.visible,"debug HUD override still wins")
	session.free()
	print("LOBBY_FOLLOWUP_GEOMETRY checks=",checks," failures=",failures," synthetic_phases=true actual_widgets=true")
	quit(1 if failures else 0)
