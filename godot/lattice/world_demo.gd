extends "res://world/session.gd"
## Optional scene: source infantry control with the nine-map native geometry.
const WorldTransport = preload("res://lattice/world_transport.gd")
const WorldHUD = preload("res://lattice/world_hud.gd")
const WorldCommands = preload("res://lattice/world_commands.gd")
const WorldGuidance = preload("res://lattice/world_guidance.gd")
const WORLD_MAPS := ["asterion-relay", "monsoon-foundry"]
var lattice_hud := WorldHUD.new()
var world_label := Label.new()
var world_commands: Control
var world_wait_release := false
var world_panel: PanelContainer
var world_error := ""

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
	world_commands.close_requested.connect(world_close_commands)
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
	var selected := "asterion-relay"
	selected_mode = "cocs"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="): selected = arg.trim_prefix("--map=")
		if arg.begins_with("--mode="): selected_mode = arg.trim_prefix("--mode=")
		if arg.begins_with("--endpoint="): endpoint = arg.trim_prefix("--endpoint=")
		if arg == "--native-trace": trace_enabled = true
		if arg in ["--session-smoke", "--lifecycle-smoke", "--setup"] or arg.begins_with("--join"):
			on_error("World slice requires an ordinary standalone host; unsupported option: " + arg)
			return
	if selected not in WORLD_MAPS or selected_mode not in ["cocs", "cocs-coop"] or selected_mode not in catalog.entries.get(selected, {}).get("modes", []):
		on_error("Require Asterion/Monsoon and cocs/cocs-coop")
		return
	client.mode = selected_mode
	if not load_map(selected):
		on_error(catalog.error)
		return
	world.get_node("StaticPickupMarkers").hide()
	client.connection_error.connect(on_error)
	client.changed.connect(func() -> void:
		if client.projection.is_empty(): clear_world_pose())
	client.lobby.connect(on_lobby)
	client.started.connect(on_started)
	client.snapshot.connect(on_snapshot)
	client.results.connect(on_results)
	client.events.connect(func(items: Array) -> void:
		if phase == 3: combat.apply_events(items, client.actor_id))
	connect_selected_match()

func controls_released() -> bool:
	for key: int in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_R, KEY_SHIFT, KEY_CTRL, KEY_E, KEY_F, KEY_C, KEY_ESCAPE, KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]:
		if Input.is_physical_key_pressed(key): return false
	return not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

func can_capture_pointer() -> bool:
	return super.can_capture_pointer() and not world_wait_release and not (is_instance_valid(world_commands) and world_commands.visible) and client.projection_actor == client.actor_id and not client.projection.is_empty()

func world_command_gate() -> String:
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
	world_commands.world_clear()
	world_commands.hide()
	world_neutral()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and is_instance_valid(world_commands):
		if event.keycode == KEY_C or (event.keycode == KEY_ESCAPE and world_commands.visible):
			if world_commands.visible: world_close_commands()
			else:
				world_neutral()
				world_commands.world_clear()
				world_commands.show()
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
	if is_instance_valid(world_commands) and world_commands.visible: return
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
	if pose_actor_id != client.actor_id: clear_world_pose()
	super.on_lobby(frame)

func on_started(frame: Dictionary) -> void:
	if client.revision < 1 or client.actor_id < 0: return
	if is_instance_valid(world_commands): world_commands.world_clear()
	lattice_hud.clear_round()
	super.on_started(frame)

func on_error(message: String) -> void:
	world_error = message
	if is_instance_valid(world_commands): world_commands.world_clear()
	lattice_hud.clear_round()
	super.on_error(message)
	world_label.text = "LATTICE world session stopped. Relaunch to reconnect."

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
	if is_instance_valid(world_commands): world_commands.world_clear()
	round_results += 1
	presentation.apply_state(frame.state, client.actor_id)
	pickups.apply_state(frame.state)
	phase = 4
	combat.clear_round()
	lattice_hud.clear_round()
	release_pointer()
	refresh_world_hud()

func refresh_world_hud() -> void:
	var status := WorldGuidance.control_state(self)
	label.text = "LATTICE / WORLD · %s · HP %s\n%s\n%s" % ["Co-op Operations" if selected_mode == "cocs-coop" else "PvP", presentation.local_actor.get("health", "unknown"), status.title, status.hint]
	world_label.text = lattice_hud.text(client.projection, presentation.local_actor, yaw) if status.id in ["engaged", "released", "commands"] else ""
	if phase == -1: world_label.text = world_error
	combat_label.visible = not combat_label.text.is_empty()
	if is_instance_valid(world_panel):
		world_panel.visible = not (is_instance_valid(world_commands) and world_commands.visible)
		world_panel.size = Vector2(minf(590, get_viewport().get_visible_rect().size.x - 36), 0)

func _process(delta: float) -> void:
	if is_instance_valid(world_commands) and world_commands.visible: release_pointer()
	if world_wait_release and controls_released() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): world_wait_release = false
	super._process(delta)
	if phase == 3 and snapshot_watch.stale():
		if is_instance_valid(world_commands): world_commands.world_clear()
		lattice_hud.clear_round()
	refresh_world_hud()
