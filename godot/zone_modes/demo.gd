extends "res://world/session.gd"
const Adapter = preload("res://zone_modes/adapter.gd")
var zones := Adapter.new()
var zone_renderer := preload("res://zone_modes/renderer.gd").new()
var zone_hud := preload("res://zone_modes/hud.gd").new()
var scoreboard := preload("res://ui/scoreboard.gd").new()
var bot_count := 2
var round_seconds := 60
var evidence := false
var evidence_count := 0

static func validate_options(entries: Dictionary, map_id: String, mode: String) -> bool:
	return mode in ["koth", "domination"] and entries.has(map_id) and mode in entries[map_id].get("modes", [])

func _ready() -> void:
	add_child(camera)
	add_child(sun)
	add_child(environment)
	camera.far = 2000
	camera.rotation_order = EULER_ORDER_YXZ
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	for item: Control in [label, selector, combat_label]:
		panel.add_child(item)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selector.hide()
	for child: Node in [pickups, presentation, combat, client, zone_renderer, zone_hud, scoreboard]: add_child(child)
	presentation.interpolate_remote = false
	if not catalog.open():
		on_error(catalog.error)
		return
	ids = catalog.entries.keys()
	for id: String in ids: selector.add_item(catalog.entries[id].name)
	var selected := "meridian-exchange"
	selected_mode = "domination"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="): selected = arg.trim_prefix("--map=")
		if arg.begins_with("--mode="): selected_mode = arg.trim_prefix("--mode=")
		if arg.begins_with("--endpoint="): endpoint = arg.trim_prefix("--endpoint=")
		if arg == "--native-trace": trace_enabled = true
		if arg == "--zone-evidence": evidence = true
		if arg.begins_with("--bots="):
			var value := arg.trim_prefix("--bots=")
			if not value.is_valid_int() or value.to_int() < 0 or value.to_int() > 8:
				on_error("Bots must be 0..8")
				return
			bot_count = value.to_int()
		if arg.begins_with("--round-seconds="):
			var value := arg.trim_prefix("--round-seconds=")
			if not value.is_valid_int() or value.to_int() < 60 or value.to_int() > 180:
				on_error("Round seconds must be 60..180")
				return
			round_seconds = value.to_int()
		if arg in ["--session-smoke", "--lifecycle-smoke", "--setup"] or arg.begins_with("--join"):
			on_error("Zone scene requires a standalone host")
			return
	if not validate_options(catalog.entries, selected, selected_mode):
		on_error("Choose a locked destination supporting koth or domination")
		return
	if not load_map(selected):
		on_error(catalog.error)
		return
	world.get_node("StaticPickupMarkers").hide()
	client.connection_error.connect(on_error)
	client.lobby.connect(on_lobby)
	client.started.connect(on_started)
	client.snapshot.connect(on_snapshot)
	client.results.connect(on_results)
	client.events.connect(func(items: Array) -> void:
		if phase == 3: combat.apply_events(items, client.actor_id))
	connect_selected_match()

func on_lobby(frame: Dictionary) -> void:
	if phase == 1:
		if client.send_frame({"type":"host", "mapId":current_id, "config":{"mode":selected_mode, "botCount":bot_count, "timeLimit":round_seconds}}) != OK:
			on_error("Could not configure zone match")
		else: phase = 2
		return
	super.on_lobby(frame)

func on_started(frame: Dictionary) -> void:
	zones.clear()
	zone_renderer.clear_round()
	super.on_started(frame)

func on_error(message: String) -> void:
	zones.clear()
	zone_renderer.clear_round()
	super.on_error(message)

func on_snapshot(frame: Dictionary) -> void:
	if phase != 3: return
	super.on_snapshot(frame)
	apply_zones(frame)

func apply_zones(frame: Dictionary) -> void:
	zones.apply(frame.state, client.actor_id, current_id, selected_mode)
	zone_renderer.apply(zones.projection)
	if zones.projection.is_empty(): release_pointer()
	if evidence and evidence_count < 6000:
		print("ZONE_NATIVE ", JSON.stringify({"round":round_starts,"seq":frame.get("seq",-1),"actor_id":client.actor_id,"ack":client.last_ack,"rendered":zone_renderer.rendered,"projection":zones.projection,"captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED}))
		evidence_count += 1

func on_results(frame: Dictionary) -> void:
	round_results += 1
	phase = 4
	presentation.apply_state(frame.state, client.actor_id)
	pickups.apply_state(frame.state)
	apply_zones(frame)
	combat.clear_round()
	release_pointer()

func can_capture_pointer() -> bool:
	return super.can_capture_pointer() and not zones.projection.is_empty()

func controls_released() -> bool:
	for key: int in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_E, KEY_R, KEY_F, KEY_SHIFT, KEY_CTRL]:
		if Input.is_physical_key_pressed(key): return false
	return not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not controls_released(): return
	super._unhandled_input(event)

func _process(delta: float) -> void:
	super._process(delta)
	if phase == 3 and snapshot_watch.stale():
		zones.clear()
		zone_renderer.clear_round()
