extends SceneTree
# Actual scene/input/UI; stored frames and synthetic queue transport, not live.
const Context = preload("res://tests/protocol/lobby_spectator_context.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("LOBBY_SPECTATOR_SESSION " + message)
func _initialize() -> void:
	call_deferred("run")
func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame
func run() -> void:
	var session: Node = load("res://world/session.tscn").instantiate()
	session.client.free()
	var client := Context.Probe.new()
	session.client = client
	root.add_child(session)
	await create_timer(0.2).timeout
	client.set_process(false)
	client.allowlist = session.catalog.entries
	client.requested_map = session.current_id
	session.join_room_id = "ROOM"
	session.phase = 10
	check(client.join_room("ROOM") == OK,"ordinary join queued")
	var welcome := {"type":"welcome","v":3,"roomId":"ROOM","peerId":7,"host":false,"spectate":true}
	var roster := {"type":"lobby","roomId":"ROOM","hostId":1,"started":true,"roundRevision":1,"lifecycle":{"phase":"live"},"mapId":"meridian-exchange","config":{"mode":"teamdeathmatch"},"players":[{"peerId":1,"name":"Host","connected":true,"spectate":false,"actorId":0},{"peerId":7,"name":"Observer","connected":true,"spectate":true,"actorId":null}]}
	for frame: Dictionary in [welcome,roster,{"type":"error","message":Context.NOTICE},{"type":"start","mapId":"meridian-exchange"}]:
		check(client.decode_text(JSON.stringify(frame)),"production decoder accepts spectator handshake frame "+str(frame.type))
	var recording: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/protocol/captured.json"))
	var snap := {}
	var result := {}
	for record: Dictionary in recording.frames:
		if record.direction != "server" or record.client != 1: continue
		if record.frame.type == "snapshot" and snap.is_empty(): snap = record.frame.duplicate(true)
		if record.frame.type == "results": result = record.frame.duplicate(true)
	snap.acks = {"-1":999,"0":25}
	var camera: Vector3 = session.camera.position
	check(client.decode_text(JSON.stringify(snap)),"snapshot accepted")
	await create_timer(0.2).timeout
	var hud: Node = session.get_node("GameHUD")
	var board: Node = session.get_node("Scoreboard")
	check(client.spectating and client.actor_id == -1 and client.last_ack == 0,"read-only identity and ACK sentinel")
	check(session.phase == 3 and not session.received_pose and session.presentation.local_actor.is_empty(),"no phantom local pose")
	check(not session.presentation.actors.is_empty() and session.presentation.applied > 0,"received actors rendered")
	check(session.camera.position == camera,"fixed camera policy")
	check(hud.status_title.text == "SPECTATING · READ ONLY" and hud.score_label.text == "SPECTATOR","explicit spectator UI")
	check("Local actor absent" not in hud.status_detail.text and "No player controls" in hud.status_detail.text,"not missing-player UI")
	check(not hud.controls.visible and not hud.vitals.visible and not hud.weapon_panel.visible,"no player controls/equipment advertised")
	client.sent.clear()
	await key(KEY_W,true)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = Vector2(800,500)
	mouse.pressed = true
	Input.parse_input_event(mouse)
	await create_timer(0.15).timeout
	check(not session.can_capture_pointer() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED,"click cannot capture spectator")
	check(client.sent.is_empty() and client.input_seq == 0,"held movement/fire queues no input, including neutral")
	mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(mouse)
	await key(KEY_W,false)
	await key(KEY_TAB,true)
	check(board.panel.visible,"read-only scoreboard available")
	await key(KEY_TAB,false)
	session.snapshot_watch.advance(1.1)
	await create_timer(0.1).timeout
	check("Snapshots stalled" in hud.status_detail.text and client.sent.is_empty(),"watchdog remains visible without inputs")
	check(client.decode_text(JSON.stringify(result)),"spectator results")
	await create_timer(0.1).timeout
	check(session.phase == 4 and board.panel.visible,"results render")
	check("SPECTATOR" in hud.status_title.text and not session.lobby_menu.restart_button.visible,"results explicitly read-only")
	await key(KEY_ENTER,true)
	await key(KEY_ENTER,false)
	check(client.sent.is_empty() and session.phase == 4,"guest Enter does not start")
	roster.roundRevision = 2
	check(client.decode_text(JSON.stringify(roster)) and client.decode_text(JSON.stringify({"type":"start","mapId":"meridian-exchange"})),"host restart accepted")
	check(client.decode_text(JSON.stringify(snap)),"new round snapshots accepted")
	await create_timer(0.1).timeout
	check(client.spectating and client.actor_id == -1 and not session.can_capture_pointer() and client.input_seq == 0,"restart preserves spectator authority")
	check("SPECTATING" in hud.status_title.text and not board.finished,"restart UI updated")
	var leave: Control = session.lobby_menu.leave_button
	mouse = InputEventMouseButton.new()
	mouse.position = leave.get_global_rect().get_center()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	Input.parse_input_event(mouse)
	await process_frame
	mouse = InputEventMouseButton.new()
	mouse.position = leave.get_global_rect().get_center()
	mouse.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(mouse)
	await create_timer(0.1).timeout
	check(session.phase == -3 and not client.spectating and client.room_id.is_empty(),"explicit UI Leave resets spectator connection")
	check(not hud.root.visible and session.presentation.actors.is_empty(),"leave clears view and HUD")
	session.free()
	print("LOBBY_SPECTATOR_SESSION checks=",checks," failures=",failures," actual_scene=true synthetic_transport=true")
	quit(1 if failures else 0)
