extends "res://world/session.gd"
## Standalone initialization, reusing the shared session callbacks and controls.
const Objectives = preload("res://objectives/renderer.gd")
var objectives := Objectives.new()
var objective_label := Label.new()
const PAIRS := {"tidal-citadel":"ctf", "sunscar-convoy":"payload"}
var evidence_enabled := false
var evidence_count := 0

func _ready() -> void:
	add_child(camera)
	add_child(sun)
	add_child(environment)
	camera.far = 2000
	camera.rotation_order = EULER_ORDER_YXZ
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(16, 12)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	panel.add_child(label)
	panel.add_child(selector)
	panel.add_child(objective_label)
	selector.hide()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_label.add_theme_font_size_override("font_size", 17)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.custom_minimum_size.x = 880
	label.add_theme_font_size_override("font_size", 16)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 880
	add_child(pickups)
	add_child(presentation)
	add_child(combat)
	add_child(client)
	add_child(objectives)
	panel.add_child(combat_label)
	combat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	presentation.interpolate_remote = true
	if not catalog.open():
		on_error(catalog.error)
		return
	ids = catalog.entries.keys()
	for id: String in ids: selector.add_item(catalog.entries[id].name)
	var selected := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="): selected = arg.trim_prefix("--map=")
		if arg.begins_with("--endpoint="): endpoint = arg.trim_prefix("--endpoint=")
		if arg == "--objective-evidence": evidence_enabled = true
	if not PAIRS.has(selected) or not catalog.entries.has(selected) or PAIRS[selected] not in catalog.entries[selected].modes:
		on_error("Choose --map=tidal-citadel or --map=sunscar-convoy via the owned launcher.")
		return
	selected_mode = PAIRS[selected]
	if not load_map(selected):
		on_error(catalog.error)
		return
	world.get_node("StaticPickupMarkers").hide()
	client.connection_error.connect(on_error)
	client.lobby.connect(on_lobby)
	client.started.connect(on_started)
	client.snapshot.connect(on_snapshot)
	client.events.connect(func(items: Array) -> void:
		if phase == 3: combat.apply_events(items, client.actor_id))
	client.results.connect(func(frame: Dictionary) -> void:
		phase = 4
		presentation.apply_state(frame.state, client.actor_id)
		pickups.apply_state(frame.state)
		objectives.apply_state(frame.state, client.actor_id)
		combat.clear_round()
		release_pointer()
		refresh_hud())
	connect_selected_match()

func on_lobby(frame: Dictionary) -> void:
	if phase == 1:
		if client.configure_match(selected_mode, 0) != OK: on_error("Configuration failed; relaunch.")
		else: phase = 2
		return
	super.on_lobby(frame)

func on_started(frame: Dictionary) -> void:
	objectives.clear_round()
	super.on_started(frame)
	objectives.configure_map(catalog.resolve_map(current_id), selected_mode)
	refresh_hud()

func on_error(message: String) -> void:
	objectives.clear_round()
	super.on_error(message)
	objective_label.text = "Objective state cleared. Relaunch after resolving the error."

func on_snapshot(frame: Dictionary) -> void:
	if phase != 3: return
	super.on_snapshot(frame)
	objectives.apply_state(frame.state, client.actor_id)
	refresh_hud()
	if evidence_enabled and evidence_count < 5400:
		print("OBJECTIVE_NATIVE ", JSON.stringify({"schema":1,"snapshot_seq":frame.seq,"actor_id":client.actor_id,"ack":client.last_ack,"actor":presentation.local_actor,"rendered":objectives.rendered,"hud":objective_label.text,"controls_captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED}))
		evidence_count += 1

func controls_released() -> bool:
	for key: int in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_SPACE,KEY_E,KEY_R,KEY_F,KEY_SHIFT,KEY_CTRL]:
		if Input.is_physical_key_pressed(key): return false
	return not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

func _unhandled_input(event: InputEvent) -> void:
	# Fresh capture requires movement/interaction keys to have been released.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not controls_released(): return
	super._unhandled_input(event)

func refresh_hud() -> void:
	label.text = "%s / %s | %s | ACK %d\nClick: engage / Esc: release / WASD: move / mouse: aim / E: interact\nRelease movement/action keys before clicking to resume." % [current_id, selected_mode, presentation.lifecycle.status, client.last_ack]
	objective_label.text = objectives.hud_text
	if phase == 4: label.text += "\nResults: Enter to request another round."

func _process(delta: float) -> void:
	super._process(delta)
	if phase == 3 and snapshot_watch.stale(): objective_label.text = "Snapshot stalled: controls released. Waiting for authority."
	var width := maxf(240, get_viewport().get_visible_rect().size.x - 32)
	objective_label.custom_minimum_size.x = width
	label.custom_minimum_size.x = width
