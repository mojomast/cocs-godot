extends "res://world/session.gd"
const HordeModel = preload("res://horde/model.gd")
const HordeClient = preload("res://horde/client.gd")
const HordeControls = preload("res://horde/controls.gd")
const LOOK_GAIN := 0.002 # default source mouse sensitivity, app/page.tsx
const MAPS := ["meridian-exchange", "verdant-reliquary", "ember-crucible"]
var horde := HordeModel.new()
var horde_label := Label.new()
var waves := 10
var evidence := false
var evidence_rows := 0
var latest: Dictionary = {}
var controls := HordeControls.new()
var trace_ended := false
var horde_client: Node

func _init() -> void:
	# The inherited field creates a detached Node. Free it before specializing;
	# never override the script of an already-instantiated product scene.
	client.free()
	client = HordeClient.new()
	horde_client = client

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
	panel.add_child(label)
	panel.add_child(selector)
	panel.add_child(combat_label)
	selector.hide()
	label.hide()
	combat_label.hide()
	var strip := CanvasLayer.new()
	strip.layer = 4
	add_child(strip)
	strip.add_child(horde_label)
	horde_label.position = Vector2(20, 190) # below shared status panel (starts at y=78)
	horde_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	horde_label.add_theme_font_size_override("font_size", 17)
	horde_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	horde_label.add_theme_constant_override("shadow_offset_x", 2)
	horde_label.add_theme_constant_override("shadow_offset_y", 2)
	horde_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(pickups)
	add_child(presentation)
	add_child(combat)
	add_child(client)
	presentation.interpolate_remote = false # exact received positions, no prediction
	if not catalog.open():
		on_error(catalog.error)
		return
	ids = catalog.entries.keys()
	for id: String in ids: selector.add_item(catalog.entries[id].name)
	var selected := MAPS[0]
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="): selected = arg.trim_prefix("--map=")
		if arg.begins_with("--endpoint="): endpoint = arg.trim_prefix("--endpoint=")
		if arg.begins_with("--waves="):
			var value := arg.trim_prefix("--waves=")
			if not value.is_valid_int():
				on_error("waves must be an integer 1..30")
				return
			waves = value.to_int()
		if arg == "--horde-evidence": evidence = true
	trace_enabled = "--native-trace" in OS.get_cmdline_user_args()
	if selected not in MAPS or waves < 1 or waves > 30 or not catalog.entries.has(selected) or "horde" not in catalog.entries[selected].modes:
		on_error("Horde requires a supported map and waves 1..30")
		return
	selected_mode = "horde"
	if not load_map(selected):
		on_error(catalog.error)
		return
	world.get_node("StaticPickupMarkers").hide()
	client.connection_error.connect(on_error)
	horde_client.input_reset.connect(func(_reason: String) -> void: release_pointer())
	client.lobby.connect(on_lobby)
	client.started.connect(on_started)
	client.snapshot.connect(on_snapshot)
	client.results.connect(on_results)
	client.events.connect(func(items: Array) -> void:
		if phase == 3: combat.apply_events(items, client.actor_id))
	connect_selected_match()
	# Horde's source-default desktop bindings, localized to this composition.
	call_deferred("show_controls")

func show_controls() -> void:
	var hud: Node = get_node_or_null("GameHUD")
	if hud != null:
		hud.controls.text = "WASD move · Space jump · Shift sprint · Ctrl/C crouch · X mobility · Q power · E use\nLMB fire · RMB ADS · Z/MMB alt · R reload · F melee · G grenade · 1–9/0/wheel weapons · Tab scores · Esc release"

func update_look(relative: Vector2) -> void:
	if not can_capture_pointer() or not relative.is_finite(): return
	var angles := controls.look(yaw, pitch, relative)
	yaw = angles.x
	pitch = angles.y

func aim_requested() -> bool:
	return can_capture_pointer() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and controls.mouse.has(MOUSE_BUTTON_RIGHT)

func release_pointer() -> void:
	controls.clear()
	if phase == 3 and horde_client.input_epoch > 0 and client.peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		horde_client.send_controls({}, true) # immediate FIFO cancellation, not a fire release
	super.release_pointer()

func on_lobby(frame: Dictionary) -> void:
	if phase == 1:
		if client.send_frame({"type":"host", "mapId":current_id,"config":{"mode":"horde","botCount":0,"difficulty":"easy","fragLimit":waves}}) != OK:
			on_error("Horde configuration failed")
		else: phase = 2
		return
	super.on_lobby(frame)

func on_started(frame: Dictionary) -> void:
	latest.clear()
	horde.clear()
	horde_label.text = horde.text
	super.on_started(frame)

func on_snapshot(frame: Dictionary) -> void:
	if phase != 3: return
	super.on_snapshot(frame)
	apply_horde(frame.state)
	record_state(frame.get("seq", -1))

func apply_horde(state: Dictionary) -> void:
	latest = state
	horde.apply(state)
	horde_label.text = horde.text
	for a: Dictionary in state.get("actors", []):
		if a.get("isNpc") != true: continue
		var id := int(a.id)
		if not presentation.actors.has(id): continue
		var visual: Node3D = presentation.actors[id]
		var badge: Label3D = visual.get_node_or_null("HordeRole")
		if badge == null:
			badge = Label3D.new()
			badge.name = "HordeRole"
			badge.position.y = 1.35
			badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			badge.font_size = 28
			badge.pixel_size = 0.012
			visual.add_child(badge)
		badge.text = str(a.get("npcType", "enemy")).to_upper() + "  %d" % int(a.get("health", 0))
		badge.modulate = Color("ffcc66") if a.get("npcType") == "spitter" else Color("ff7388")

func on_results(frame: Dictionary) -> void:
	round_results += 1
	phase = 4
	presentation.apply_state(frame.state, client.actor_id)
	pickups.apply_state(frame.state)
	combat.clear_round()
	release_pointer()
	apply_horde(frame.state)
	record_state(-1)

func on_error(message: String) -> void:
	latest.clear()
	horde.clear()
	horde_label.text = "Horde unavailable: " + message
	super.on_error(message)

func controls_released() -> bool:
	for key: int in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_SPACE,KEY_E,KEY_R,KEY_F,KEY_G,KEY_Q,KEY_X,KEY_Z,KEY_C,KEY_SHIFT,KEY_CTRL]:
		if Input.is_physical_key_pressed(key): return false
	return not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)

func _input(event: InputEvent) -> void:
	controls.record(event, weapon_controls_active(), presentation.local_actor)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not controls_released(): return
	super._unhandled_input(event)

func _process(delta: float) -> void:
	# Local specialization of session's handshake/watch/send loop. Shared session
	# keeps its old contract; this scene samples source press/hold controls instead.
	if not advance_handshake(delta): return
	elapsed += delta
	if phase == 0 and client.peer.get_ready_state() == WebSocketPeer.STATE_OPEN: begin_room()
	if phase == 3:
		var was_stale := snapshot_watch.stale()
		snapshot_watch.advance(delta)
		if not was_stale and snapshot_watch.stale(): release_pointer()
		camera.rotation = Vector3(pitch, yaw, 0)
		send_elapsed += delta
		if send_elapsed >= 1.0 / 60.0:
			send_elapsed = fmod(send_elapsed, 1.0 / 60.0)
			var active := weapon_controls_active()
			if not active: controls.clear()
			var sample: Dictionary = controls.sample(yaw, pitch) if active else {}
			var result: Error = horde_client.send_controls(sample, not active)
			if result == OK: controls.queued()
			if trace_enabled: emit_native_trace(trace_input(sample, result))
			if result != OK: on_error("Input could not be queued. Relaunch to reconnect.")
	horde_label.custom_minimum_size.x = maxf(240, get_viewport().get_visible_rect().size.x - 40)
	if phase == 3 and snapshot_watch.stale():
		horde.apply({}, true)
		horde_label.text = horde.text

func trace_input(sample: Dictionary, result: Error) -> Dictionary:
	var record := super.trace_input(sample, result)
	for key: String in ["power", "melee", "grenade", "ads", "altFire"]: record.controls[key] = sample.get(key, false)
	record["input_seq"] = client.input_seq
	record["input_epoch"] = horde_client.input_epoch
	record["received_input"] = horde_client.received_input
	return record

func _exit_tree() -> void:
	if trace_enabled and not trace_ended:
		trace_ended = true
		emit_native_trace({"event":"recording_end", "complete":trace_count < TRACE_LIMIT, "phase":phase})
	super._exit_tree()

func record_state(seq: int) -> void:
	if not evidence or evidence_rows >= 5500: return
	var rendered := {}
	for id: int in presentation.actors:
		var visual: Node3D = presentation.actors[id]
		rendered[str(id)] = {"position":[visual.position.x,visual.position.y,visual.position.z],"visible":visual.visible}
	print("HORDE_NATIVE ", JSON.stringify({"round":round_starts,"seq":seq,"actor_id":client.actor_id,"ack":client.last_ack,"input_epoch":horde_client.input_epoch,"input_status":horde_client.input_status,"model":horde.state,"hud":horde_label.text,"rendered":rendered,"captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"phase":phase}))
	evidence_rows += 1
