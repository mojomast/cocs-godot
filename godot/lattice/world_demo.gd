extends "res://world/session.gd"
## Optional scene: source infantry control with the nine-map native geometry.
const WorldTransport = preload("res://lattice/world_transport.gd")
const WorldHUD = preload("res://lattice/world_hud.gd")
const WorldCommands = preload("res://lattice/world_commands.gd")
const WorldGuidance = preload("res://lattice/world_guidance.gd")
const WorldOutcomes = preload("res://lattice/world_outcomes.gd")
const WorldSessionPanel = preload("res://lattice/world_session_panel.gd")
const WorldTelemetry = preload("res://lattice/world_telemetry.gd")
const SessionOptions = preload("res://lattice/session_options.gd")
const SessionFlow = preload("res://lattice/session_flow.gd")
const WORLD_MAPS := ["asterion-relay", "monsoon-foundry"]
var lattice_hud := WorldHUD.new()
var world_label := Label.new()
var world_commands: Control
var world_wait_release := false
var world_panel: PanelContainer
var world_error := ""
var world_options: Dictionary = {}
var session_flow := SessionFlow.new()
var session_panel := WorldSessionPanel.new()
var world_telemetry := WorldTelemetry.new()
var last_lattice_lobby: Dictionary = {}

func _init() -> void:
	# Replace before attachment: the transport's _init signal observers run before
	# our snapshot callback. The inherited session never creates another socket.
	client.free()
	client = WorldTransport.new()

func _ready() -> void:
	add_child(camera)
	add_child(sun)
	add_child(environment)
	camera.far = 2000
	camera.rotation_order = EULER_ORDER_YXZ
	var layer := CanvasLayer.new()
	add_child(layer)
	world_panel = PanelContainer.new()
	world_panel.position = Vector2(18, 14)
	world_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.025, 0.045, 0.07, 0.9)
	backing.set_content_margin_all(10)
	world_panel.add_theme_stylebox_override("panel", backing)
	layer.add_child(world_panel)
	var panel := VBoxContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_panel.add_child(panel)
	for item: Label in [label, world_label, combat_label]:
		panel.add_child(item)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.add_theme_font_size_override("font_size", 16)
		item.add_theme_color_override("font_shadow_color", Color.BLACK)
		item.add_theme_constant_override("shadow_offset_x", 2)
		item.add_theme_constant_override("shadow_offset_y", 2)
	panel.add_child(selector)
	selector.hide()
	world_commands = WorldCommands.new()
	layer.add_child(world_commands)
	world_commands.world_bind(self)
	world_commands.telemetry = world_telemetry
	world_commands.close_requested.connect(world_close_commands)
	layer.add_child(session_panel)
	session_panel.start_requested.connect(world_start_requested)
	session_panel.restart_requested.connect(world_restart_requested)
	session_panel.close_requested.connect(func() -> void:
		session_panel.hide()
		world_neutral())
	session_flow.state_changed.connect(func(_state: Dictionary) -> void:
		if phase != 3 and phase != 4: refresh_session_setup())
	add_child(pickups)
	add_child(presentation)
	add_child(combat)
	add_child(lattice_hud)
	add_child(client)
	# Exact received coordinates (no extrapolation) simplify recipient auditing.
	presentation.interpolate_remote = false
	if not catalog.open():
		on_error(catalog.error)
		return
	ids = catalog.entries.keys()
	for id: String in ids: selector.add_item(catalog.entries[id].name)
	world_options = SessionOptions.parse(OS.get_cmdline_user_args())
	var selected: String = world_options.map
	selected_mode = world_options.mode
	endpoint = world_options.endpoint
	selected_bot_count = world_options.bots
	selected_character = world_options.operator
	selected_harness = world_options.harness
	join_room_id = world_options.room
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--native-trace": trace_enabled = true
		if arg in ["--session-smoke", "--lifecycle-smoke", "--setup"]:
			on_error("Synthetic session controls are unavailable on the LATTICE flagship route")
			return
	if not world_options.error.is_empty() or selected not in WORLD_MAPS or selected_mode not in ["cocs", "cocs-coop"] or selected_mode not in catalog.entries.get(selected, {}).get("modes", []):
		on_error(world_options.error if not world_options.error.is_empty() else "Require Asterion/Monsoon and cocs/cocs-coop")
		return
	client.mode = selected_mode
	if not load_map(selected):
		on_error(catalog.error)
		return
	if not lattice_hud.bind_authored_map(current_id, catalog.resolve_map(current_id)):
		world_error = "Authored objective links unavailable; guidance is uncertain"
	world_commands.bind_authored_map(current_id, catalog.resolve_map(current_id))
	world.get_node("StaticPickupMarkers").hide()
	client.connection_error.connect(on_error)
	client.changed.connect(func() -> void:
		if client.projection.is_empty(): clear_world_pose()
		else: world_telemetry.observe_projection(client.projection))
	client.lobby.connect(on_lobby)
	client.below_minimum.connect(func(message: String) -> void:
		world_error = message
		phase = 12
		session_flow.publish(SessionFlow.State.HOST_WAITING, message)
		world_label.text = message + " · waiting for roster; Enter to retry explicitly")
	client.started.connect(on_started)
	client.snapshot.connect(on_snapshot)
	client.results.connect(on_results)
	client.events.connect(func(items: Array) -> void:
		if phase == 3:
			combat.apply_events(items, client.actor_id)
			world_telemetry.events(items, client.projection))
	refresh_session_setup()
	connect_selected_match()

func controls_released() -> bool:
	for key: int in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_R, KEY_SHIFT, KEY_CTRL, KEY_E, KEY_F, KEY_C, KEY_ESCAPE, KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]:
		if Input.is_physical_key_pressed(key): return false
	return not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

func can_capture_pointer() -> bool:
	return super.can_capture_pointer() and not world_wait_release and not session_panel.visible and not (is_instance_valid(world_commands) and world_commands.visible) and client.projection_actor == client.actor_id and not client.projection.is_empty()

func world_command_gate() -> String:
	if session_panel.visible: return "Close the session panel before issuing commands"
	if not super.can_capture_pointer(): return "World unavailable — focus, fresh state and a living actor required"
	if client.projection.is_empty() or client.projection_actor != client.actor_id: return "Waiting for recipient identity"
	return ""

func world_neutral() -> void:
	release_pointer()
	world_wait_release = true
	if phase != 3 or not client.connection_open(): return
	var controls := {"x":0.0, "z":0.0, "yaw":yaw, "pitch":pitch, "fire":false, "jump":false, "reload":false, "sprint":false, "crouch":false, "interact":false, "mobility":false, "ads":false, "power":false, "melee":false, "grenade":false, "altFire":false}
	var result: Error = client.send_input(controls)
	emit_native_trace(trace_input(controls, result))
	if result != OK: on_error("Neutral input could not be queued. Relaunch to reconnect.")

func world_close_commands() -> void:
	world_telemetry.panel(false, client.projection)
	world_commands.world_clear()
	world_commands.hide()
	world_neutral()

func world_roster() -> Dictionary:
	return {"hostId":session_flow.host_peer, "players":client.roster_metadata.get("players", [])}

func world_start_requested() -> void:
	if phase != 12: return
	var answer: Dictionary = session_flow.start(client, world_roster())
	if not answer.queued: world_error = answer.reason
	else:
		phase = 20
		session_panel.hide()
	refresh_world_hud()
	refresh_session_setup()

func world_restart_requested() -> void:
	if phase != 4 or not join_room_id.is_empty(): return
	var answer: Dictionary = session_flow.restart(client, world_roster())
	if not answer.queued: world_error = answer.reason
	else:
		phase = 20
		session_panel.hide()
	refresh_world_hud()

func session_lobby_echo() -> Dictionary:
	if not client.session_config.is_empty(): return client.session_config.duplicate(true)
	var raw: Variant = last_lattice_lobby.get("config")
	if not raw is Dictionary or last_lattice_lobby.get("mapId") != current_id or raw.get("mode") != selected_mode: return {}
	return {"map":last_lattice_lobby.get("mapId"), "mode":raw.get("mode"), "rung":raw.get("rung"),
		"bot_count":raw.get("botCount"), "human_count":last_lattice_lobby.get("cocs", {}).get("humans") if last_lattice_lobby.get("cocs") is Dictionary else null,
		"time_limit":raw.get("timeLimit"), "operator":client.assigned_character, "harness":client.assigned_harness,
		"roster":client.roster_metadata.duplicate(true)}

func refresh_session_setup() -> void:
	if phase in [3, 4] or not session_panel.is_inside_tree(): return
	session_panel.show_setup(world_options, session_lobby_echo(), session_flow.snapshot(), client.peer_id >= 0 and client.peer_id == session_flow.host_peer and join_room_id.is_empty())
	world_neutral()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and is_instance_valid(world_commands):
		if event.keycode == KEY_ENTER and phase == 12:
			world_start_requested()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ENTER and phase == 4 and join_room_id.is_empty():
			world_restart_requested()
			get_viewport().set_input_as_handled()
			return
		if session_panel.visible: return
		if event.keycode == KEY_C or (event.keycode == KEY_ESCAPE and world_commands.visible):
			if world_commands.visible: world_close_commands()
			else:
				world_neutral()
				world_commands.world_clear()
				world_commands.show()
				world_telemetry.panel(true, client.projection)
				world_commands.world_refresh()
			get_viewport().set_input_as_handled()
			return
	super._input(event)

func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_instance_valid(world_commands): world_commands.world_clear()
		world_neutral()

func _unhandled_input(event: InputEvent) -> void:
	if session_panel.visible or is_instance_valid(world_commands) and world_commands.visible: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not controls_released(): return
	super._unhandled_input(event)

func clear_world_pose() -> void:
	if is_instance_valid(world_commands): world_commands.world_clear()
	if received_pose: send_elapsed = 0.0
	received_pose = false
	pose_actor_id = -1
	presentation.clear_round()
	lattice_hud.clear_round()
	release_pointer()

func on_lobby(frame: Dictionary) -> void:
	last_lattice_lobby = frame.duplicate(true)
	if pose_actor_id != client.actor_id: clear_world_pose()
	session_flow.observe_roster(frame, client)
	if not join_room_id.is_empty():
		if phase == 10:
			var config: Variant = frame.get("config")
			if config is Dictionary:
				if frame.get("mapId") != current_id or config.get("mode") != world_options.mode:
					world_error = "Joined room does not match requested map/mode; leave and select a matching room"
					world_label.text = world_error
					phase = 11
					session_flow.publish(SessionFlow.State.GUEST_WAITING, world_error)
					return
				session_flow.echoed = config.duplicate(true)
			phase = 11
			session_flow.publish(SessionFlow.State.GUEST_WAITING, "Joined; waiting for host start")
			world_label.text = "Guest · waiting for host Start"
		refresh_session_setup()
		return
	if phase == 1:
		var answer := session_flow.request_configuration(world_options, client)
		if not answer.queued: on_error(answer.reason); return
		phase = 2
		refresh_session_setup()
		return
	if phase == 2 and frame.get("config") is Dictionary:
		var cfg: Dictionary = frame.config
		if cfg.get("mode") != selected_mode or cfg.get("timeLimit") != world_options.time_limit:
			on_error("Authority echoed different mode/limit; start cancelled")
			return
		session_flow.echoed = cfg.duplicate(true)
		session_flow.minimum_humans = int(client.roster_metadata.get("minimum_humans", 0))
		session_flow.publish(SessionFlow.State.HOST_WAITING, "Configuration echoed")
		world_label.text = "Host lobby · Enter to start"
		phase = 12
	refresh_session_setup()

func on_started(frame: Dictionary) -> void:
	if client.revision < 1 or client.actor_id < 0: return
	if not session_flow.observe_start(frame, current_id, selected_mode):
		on_error(session_flow.reason)
		return
	if lattice_hud.authored_map_id != current_id:
		lattice_hud.bind_authored_map(current_id, catalog.resolve_map(current_id))
	if world_commands.authored_map_id != current_id:
		world_commands.bind_authored_map(current_id, catalog.resolve_map(current_id))
	if is_instance_valid(world_commands): world_commands.world_clear()
	world_telemetry.begin_round()
	session_panel.hide()
	lattice_hud.clear_round()
	super.on_started(frame)

func on_error(message: String) -> void:
	world_error = message
	session_panel.hide()
	if is_instance_valid(world_commands): world_commands.world_clear()
	lattice_hud.clear_round()
	super.on_error(message)
	world_label.text = "LATTICE world session stopped. Relaunch to reconnect."

func advance_handshake(delta: float) -> bool:
	if not is_finite(delta) or delta < 0.0: return false
	# LATTICE guests wait for the host indefinitely; connect/config/start attempts
	# retain the inherited bounded timeout.
	if phase == 11 and not join_room_id.is_empty():
		phase_elapsed = 0.0
		watched_phase = phase
		return true
	return super.advance_handshake(delta)

func on_snapshot(frame: Dictionary) -> void:
	if phase != 3: return
	if client.projection.is_empty() or client.projection_actor != client.actor_id:
		snapshot_watch.observe()
		clear_world_pose()
		pickups.clear_round()
		combat.clear_round()
		refresh_world_hud()
		return
	super.on_snapshot(frame)
	if is_instance_valid(world_commands): world_commands.world_refresh()
	# PvP wire nodes omit y/r. Height is static authored geometry, not inferred
	# gameplay state. Never draw a guessed capture radius.
	for node: Dictionary in client.projection.nodes:
		if not lattice_hud.heights.has(node.id):
			lattice_hud.heights[node.id] = support_height(catalog.resolve_map(current_id), node.x, node.z)
	lattice_hud.apply_projection(client.projection, presentation.local_actor)
	refresh_world_hud()

func on_results(frame: Dictionary) -> void:
	session_flow.observe_result(client.result_projection)
	world_telemetry.finish_round()
	if is_instance_valid(world_commands): world_commands.world_clear()
	round_results += 1
	presentation.apply_state(frame.state, client.actor_id)
	pickups.apply_state(frame.state)
	phase = 4
	world_label.text = WorldOutcomes.final_result(client.result_projection, client.peer_id == session_flow.host_peer and join_room_id.is_empty())
	session_panel.show_result(client.result_projection, client.session_config, client.peer_id == session_flow.host_peer and join_room_id.is_empty())
	combat.clear_round()
	lattice_hud.clear_round()
	release_pointer()
	refresh_world_hud()

func refresh_world_hud() -> void:
	var status := WorldGuidance.control_state(self)
	label.text = "LATTICE / WORLD · %s · HP %s\n%s\n%s" % ["Co-op Operations" if selected_mode == "cocs-coop" else "PvP", presentation.local_actor.get("health", "unknown"), status.title, status.hint]
	if status.id in ["engaged", "released", "commands"]:
		world_label.text = lattice_hud.text(client.projection, presentation.local_actor, yaw) + "\n" + WorldOutcomes.live(client.projection)
	elif phase == 12:
		world_label.text = world_error if not world_error.is_empty() else "Host lobby · floor %s · Enter to start" % str(session_flow.minimum_humans)
	elif phase == 11:
		world_label.text = session_flow.reason if not session_flow.reason.is_empty() else "Guest · waiting for host Start"
	elif phase == 4:
		world_label.text = WorldOutcomes.final_result(client.result_projection, client.peer_id == session_flow.host_peer and join_room_id.is_empty())
	elif phase == 1 or phase == 2:
		world_label.text = "Host lobby · waiting for configuration echo"
	elif phase == 20:
		world_label.text = "Waiting for authoritative start"
	else:
		world_label.text = world_error if not world_error.is_empty() else ""
	combat_label.visible = not combat_label.text.is_empty()
	if is_instance_valid(world_panel):
		world_panel.visible = not session_panel.visible and not (is_instance_valid(world_commands) and world_commands.visible)
		world_panel.size = Vector2(minf(590, get_viewport().get_visible_rect().size.x - 36), 0)

func _process(delta: float) -> void:
	if session_panel.visible or is_instance_valid(world_commands) and world_commands.visible: release_pointer()
	if world_wait_release and controls_released() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): world_wait_release = false
	super._process(delta)
	if phase == 3 and snapshot_watch.stale():
		if is_instance_valid(world_commands): world_commands.world_clear()
		lattice_hud.clear_round()
	refresh_world_hud()
