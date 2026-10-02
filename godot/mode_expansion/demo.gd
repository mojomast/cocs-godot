extends "res://world/session.gd"
## Existing source Room/Match own combat, objectives, joins and round outcomes.
const ModeState = preload("res://mode_expansion/state.gd")
const Markers = preload("res://mode_expansion/markers.gd")
const PAIRS := {"meridian-exchange":["arsenal","juggernaut"], "verdant-reliquary":["arsenal","juggernaut"], "ember-crucible":["arsenal","juggernaut"], "tidal-citadel":["team-elimination"], "sunscar-convoy":["vip-escort"]}
var projection := ModeState.new()
var mode_markers := Markers.new()
var objective_label := Label.new()
var connection_label := Label.new()
var restart_button := Button.new()
var retry_button := Button.new()
var mode_panel := VBoxContainer.new()
var mode_card := PanelContainer.new()
var round_seconds := 180
var round_target := -1
var wait_players := 1
var evidence := false
var fixture_input_elapsed := 0.0
var fixture_capture := ""
var fixture_captured := false
var fixture_dropped := false
var fixture_left := false
var source_revision := -1
var fixture_spectator_checked := false

func _ready() -> void:
	for node: Node in [camera, sun, environment]: add_child(node)
	camera.far = 2000
	camera.rotation_order = EULER_ORDER_YXZ
	camera.make_current()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 1.2
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("56697b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = 0.7
	environment.environment = env
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(mode_card)
	mode_card.add_child(mode_panel)
	mode_card.position = Vector2(16, 158)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.025, 0.045, 0.065, 0.94)
	for edge: String in ["left", "right", "top", "bottom"]: card_style.set("content_margin_" + edge, 10.0)
	mode_card.add_theme_stylebox_override("panel", card_style)
	mode_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item: Label in [objective_label, connection_label, label, combat_label]:
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_theme_font_size_override("font_size", 14)
		mode_panel.add_child(item)
	# Common HUD owns vitals/controls; these inherited diagnostics remain bound.
	label.hide()
	combat_label.hide()
	var actions := HBoxContainer.new()
	mode_panel.add_child(actions)
	restart_button.text = "Restart round"
	restart_button.pressed.connect(request_restart)
	actions.add_child(restart_button)
	retry_button.text = "Reconnect seat"
	retry_button.pressed.connect(retry_seat)
	actions.add_child(retry_button)
	var leave := Button.new()
	leave.text = "Leave / Home"
	leave.pressed.connect(leave_home)
	actions.add_child(leave)
	get_viewport().size_changed.connect(resize_mode_panel)
	resize_mode_panel()
	for node: Node in [pickups, presentation, combat, client, mode_markers]: add_child(node)
	presentation.interpolate_remote = true
	if not catalog.open():
		on_error(catalog.error)
		return
	ids = catalog.entries.keys()
	for id: String in ids: selector.add_item(catalog.entries[id].name)
	var chosen := "meridian-exchange"
	selected_mode = "arsenal"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="): chosen = arg.trim_prefix("--map=")
		if arg.begins_with("--mode="): selected_mode = arg.trim_prefix("--mode=")
		if arg.begins_with("--endpoint="): endpoint = arg.trim_prefix("--endpoint=")
		if arg.begins_with("--join-room="): join_room_id = arg.trim_prefix("--join-room=")
		if arg.begins_with("--bots="): selected_bot_count = arg.trim_prefix("--bots=").to_int()
		if arg.begins_with("--time-limit="): round_seconds = arg.trim_prefix("--time-limit=").to_int()
		if arg.begins_with("--round-target="): round_target = arg.trim_prefix("--round-target=").to_int()
		if arg.begins_with("--wait-for-players="): wait_players = arg.trim_prefix("--wait-for-players=").to_int()
		if arg == "--mode-evidence": evidence = true
		if arg.begins_with("--mode-capture="): fixture_capture = arg.trim_prefix("--mode-capture=")
	if selected_mode not in PAIRS.get(chosen, []) or not catalog.entries.has(chosen) or selected_mode not in catalog.entries[chosen].modes:
		on_error("Unsupported competitive map/mode")
		return
	if not load_map(chosen):
		on_error(catalog.error)
		return
	world.get_node("StaticPickupMarkers").hide()
	client.connection_error.connect(on_error)
	client.transport_dropped.connect(on_transport_dropped)
	client.reconnect_outcome.connect(on_reconnect_outcome)
	client.lobby.connect(on_lobby)
	client.started.connect(on_started)
	client.snapshot.connect(on_snapshot)
	client.results.connect(on_results)
	client.events.connect(func(items: Array) -> void:
		if phase == 3:
			combat.apply_events(items, client.actor_id)
			av_events(items))
	connect_selected_match()

func resize_mode_panel() -> void:
	var width := minf(680.0, get_viewport().get_visible_rect().size.x - 52.0)
	for item: Label in [objective_label, connection_label]: item.custom_minimum_size.x = width
	mode_panel.size.x = width
	mode_panel.reset_size()
	mode_card.size.x = width + 20.0
	mode_card.reset_size()

func advance_handshake(delta: float) -> bool:
	# Waiting for invited humans is user-controlled, not a failed handshake.
	if phase in [2, 11]: return true
	return super.advance_handshake(delta)

func on_lobby(frame: Dictionary) -> void:
	connection_label.text = "Room %s · %s · %d connected" % [client.room_id, "Guest" if not join_room_id.is_empty() else "Host", frame.get("players", []).size()]
	if phase == 1:
		var config := {"mode":selected_mode, "botCount":selected_bot_count, "timeLimit":round_seconds}
		if round_target > 0: config.fragLimit = round_target
		if client.send_frame({"type":"host", "mapId":current_id, "config":config}) != OK:
			on_error("Could not configure source match")
			return
		phase = 2
		return
	if phase == 2:
		var connected := 0
		for player: Dictionary in frame.get("players", []):
			if bool(player.get("connected", false)) and not bool(player.get("spectate", false)): connected += 1
		if connected < wait_players:
			connection_label.text += " · Waiting for %d players" % wait_players
			return
	super.on_lobby(frame)

func on_started(frame: Dictionary) -> void:
	mode_markers.clear_round()
	var revision := int(frame.get("roundRevision", -1))
	var resumed_round := revision == source_revision and round_starts > 0
	super.on_started(frame)
	if resumed_round: round_starts -= 1
	source_revision = revision

func project_state(state: Dictionary) -> void:
	projection.apply(state, client.actor_id)
	mode_markers.apply(projection.markers)
	objective_label.text = projection.text
	if client.spectating: objective_label.text = "SPECTATOR · Read-only\n" + objective_label.text
	if evidence: print("MODE_NATIVE ", JSON.stringify({"mode":selected_mode,"map":current_id,"phase":phase,"round":round_starts,"peer":client.peer_id,"actor":client.actor_id,"spectating":client.spectating,"ack":client.last_ack,"objectives":state.get("objectives"),"winner":state.get("winner")}))

func on_snapshot(frame: Dictionary) -> void:
	if phase != 3: return
	super.on_snapshot(frame)
	if client.spectating:
		camera.position = Vector3(0, 18, 30)
		camera.look_at(Vector3.ZERO)
		if evidence and not fixture_spectator_checked:
			fixture_spectator_checked = true
			var denied := client.send_input({"fire":true}) == ERR_UNAUTHORIZED
			assert(denied and not can_capture_pointer())
			print("MODE_NATIVE_SPECTATOR_BOUNDARY ", JSON.stringify({"inputDenied":denied,"controls":can_capture_pointer()}))
	project_state(frame.state)
	if round_results >= 1 and not fixture_left and "--mode-fixture-leave" in OS.get_cmdline_user_args() and float(frame.state.get("time", 0)) >= 1.0:
		fixture_left = true
		call_deferred("leave_home")
	if not fixture_capture.is_empty() and not fixture_captured and float(frame.state.get("time", 0)) >= 2.0:
		fixture_captured = true
		capture_mode(fixture_capture + ".png")
	if "--mode-fixture-reconnect" in OS.get_cmdline_user_args() and not fixture_dropped and float(frame.state.get("time", 0)) >= 4.0:
		fixture_dropped = true
		client.peer.close(1000, "Acceptance transport interruption")

func on_results(frame: Dictionary) -> void:
	av_snapshot(frame.state)
	av_finish(frame.state)
	round_results += 1
	phase = 4
	presentation.apply_state(frame.state, client.actor_id)
	pickups.apply_state(frame.state)
	combat.clear_round()
	release_pointer()
	project_state(frame.state)
	if evidence: print("MODE_NATIVE_BOUNDARY ", JSON.stringify({"kind":"results","controls":can_capture_pointer(),"pointerReleased":Input.mouse_mode == Input.MOUSE_MODE_VISIBLE}))
	connection_label.text = "Round complete · Enter / Restart" if join_room_id.is_empty() and not client.spectating else "Round complete · Waiting for host restart"
	if not fixture_capture.is_empty(): capture_mode(fixture_capture + "-results.png")
	if "--mode-fixture-restart" in OS.get_cmdline_user_args() and join_room_id.is_empty() and round_results == 1:
		get_tree().create_timer(2.0).timeout.connect(request_restart)

func capture_mode(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(path)
	if result == OK: print("MODE_NATIVE_CAPTURE ", path)
	else: push_error("Mode screenshot failed: " + str(result))

func on_transport_dropped(message: String) -> void:
	if evidence: print("MODE_NATIVE_DROP ", message)
	if is_instance_valid(audiovisual): audiovisual.suspend("transport")
	disconnected_phase = phase
	phase = -5
	local_motion.reset()
	release_pointer()
	snapshot_watch.reset()
	presentation.clear_round()
	combat.clear_round()
	mode_markers.clear_round()
	received_pose = false
	connection_label.text = message + " · Reconnect to resume your source seat."
	if "--mode-fixture-reconnect" in OS.get_cmdline_user_args(): get_tree().create_timer(0.5).timeout.connect(retry_seat)

func retry_seat() -> void:
	if phase != -5: return
	var result := client.retry_reconnect(endpoint, catalog.entries, current_id, client.reconnect_ticket.room_id)
	if evidence: print("MODE_NATIVE_RETRY ", result)
	if result == OK:
		phase = -6
		connection_label.text = "Reconnecting…"

func on_reconnect_outcome(resumed: bool, message: String) -> void:
	super.on_reconnect_outcome(resumed, message)
	connection_label.text = message
	if evidence: print("MODE_NATIVE_RECONNECT ", JSON.stringify({"resumed":resumed,"actor":client.actor_id,"spectating":client.spectating,"phase":phase}))

func on_error(message: String) -> void:
	if evidence: print("MODE_NATIVE_ERROR ", message)
	super.on_error(message)
	connection_label.text = message

func leave_home() -> void:
	client.send_frame({"type":"leave"})
	client.disconnect_server()
	phase = -3
	received_pose = false
	release_pointer()
	if evidence: print("MODE_NATIVE_BOUNDARY ", JSON.stringify({"kind":"leave","controls":can_capture_pointer(),"pointerReleased":Input.mouse_mode == Input.MOUSE_MODE_VISIBLE}))
	if "--mode-fixture-leave" in OS.get_cmdline_user_args(): load("res://tests/mode_expansion/home_probe.gd").observe(get_tree(), fixture_capture + "-home.png", current_id, selected_mode)
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")

func _process(delta: float) -> void:
	# Let Client observe a closing transport and preserve its reconnect ticket.
	# The base live-input loop treats send failure as a terminal session error.
	if phase == 3 and client.peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		release_pointer()
		return
	super._process(delta)
	restart_button.visible = phase == 4 and join_room_id.is_empty() and not client.spectating
	retry_button.visible = phase == -5
	# Direct-scene acceptance only; emits ordinary source input, never state writes.
	if phase == 3 and "--mode-fixture-input" in OS.get_cmdline_user_args() and not client.spectating:
		fixture_input_elapsed += delta
		if fixture_input_elapsed >= 0.05:
			fixture_input_elapsed = 0.0
			client.send_input({"x":0.0, "z":0.0, "yaw":0.0, "pitch":1.2, "fire":true})
