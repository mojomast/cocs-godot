extends "res://world/session.gd"
const HordeModel = preload("res://horde/model.gd")
const HordeClient = preload("res://horde/client.gd")
const HordeControls = preload("res://horde/controls.gd")
const BloodWire = preload("res://blood_fx/wire.gd")
const ActorVisual = preload("res://source_operators/operator_visual.gd")
const LOOK_GAIN := 0.002 # default source mouse sensitivity, app/page.tsx
const MAPS := ["meridian-exchange", "verdant-reliquary", "ember-crucible"]
## Source HORDE_UPGRADES offers exactly three rows; the number keys are the
## desktop default here because the pointer is captured during a wave.
const OFFER_HOTKEYS := {KEY_1:1, KEY_2:2, KEY_3:3, KEY_4:4, KEY_5:5, KEY_6:6, KEY_7:7, KEY_8:8, KEY_9:9}
var horde := HordeModel.new()
var horde_label := Label.new()
var waves := 10
var evidence := false
var evidence_rows := 0
var latest: Dictionary = {}
var controls := HordeControls.new()
var trace_ended := false
var horde_client: Node
## Visible choice controls. Built on first use so a detached composition (tests)
## gets them without _ready; the shared session's HUD layers stay untouched.
var choice_layer: CanvasLayer
var choice_panel: VBoxContainer
var choice_status: Label
var choice_buttons: Array[Button] = []
var last_choice_signature := ""
var last_rejected := ""
var last_confirmed := 0
var last_applied := 0
var last_selected := ""
## Horde alone owns these presentation-only remnants. The shared presentation
## intentionally discards missing/dead actors immediately; an authoritative
## death event keeps its NPC visible long enough to play a real fall.
const CORPSE_SECONDS := 3.5
const MAX_CORPSES := 24
var npc_actors: Dictionary = {}
var npc_seen: Dictionary = {}
var corpses: Array[Dictionary] = []
var corpse_events: Dictionary = {}
var terminal_blood: Node3D
var terminal_blood_age := 0.0

func _init() -> void:
	# The inherited field creates a detached Node. Free it before specializing;
	# never override the script of an already-instantiated product scene.
	client.free()
	client = HordeClient.new()
	horde_client = client

func _ready() -> void:
	build_view_layers()
	ensure_choice_controls()
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
	# The source owns NPC positions; render their received poses between packets
	# like native Deathmatch. This is visual interpolation, never NPC simulation.
	presentation.interpolate_remote = true
	if not open_catalog():
		on_error(catalog.error)
		return
	ids = map_ids()
	for id: String in ids: selector.add_item(catalog.entries[id].name)
	var selected := default_map_id()
	var operator_id := Loadout.DEFAULT_CHARACTER
	var harness_id := Loadout.DEFAULT_HARNESS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="): selected = arg.trim_prefix("--map=")
		if arg.begins_with("--operator="): operator_id = arg.trim_prefix("--operator=")
		if arg.begins_with("--harness="): harness_id = arg.trim_prefix("--harness=")
		if arg.begins_with("--endpoint="): endpoint = arg.trim_prefix("--endpoint=")
		if arg.begins_with("--waves="):
			var value := arg.trim_prefix("--waves=")
			if not value.is_valid_int():
				on_error("waves must be an integer 1..30")
				return
			waves = value.to_int()
		if arg == "--horde-evidence": evidence = true
	trace_enabled = "--native-trace" in OS.get_cmdline_user_args()
	if waves < 1 or waves > 30 or not map_supports_horde(selected):
		on_error("Horde requires a supported map and waves 1..30")
		return
	if not Loadout.valid(operator_id, harness_id):
		on_error("Horde requires a valid operator/harness pair")
		return
	selected_character = operator_id
	selected_harness = harness_id
	selected_mode = "horde"
	if not load_selected_map(selected):
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
		if phase == 3:
			combat.apply_events(items, client.actor_id)
			apply_npc_deaths(items))
	connect_selected_match()
	# Horde's source-default desktop bindings, localized to this composition.
	call_deferred("show_controls")

func show_controls() -> void:
	var hud: Node = get_node_or_null("GameHUD")
	if hud != null:
		hud.controls.text = "WASD move · Space jump · Shift sprint · Ctrl/C crouch · X mobility · Q power · E use\nLMB fire · RMB ADS · Z/MMB alt · R reload · F kick (hold to repeat) · G grenade · 1–9/0/wheel weapons · Tab scores · Esc release"

## ---------------------------------------------------------------------------
## Horde run upgrades: visible choice buttons plus 1..9 hotkeys. The authority
## snapshot offers the rows (singleplayer.upgrades) and only it confirms an
## application (upgradeSelected/upgradeCount); every local send is single-flight.
## ---------------------------------------------------------------------------
func ensure_choice_controls() -> void:
	if choice_panel != null: return
	choice_layer = CanvasLayer.new()
	choice_layer.layer = 5
	choice_layer.offset = Vector2(20, 300) # below the Horde strip until positioned
	add_child(choice_layer)
	choice_panel = VBoxContainer.new()
	choice_panel.name = "HordeUpgradeChoices"
	choice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice_layer.add_child(choice_panel)
	choice_status = Label.new()
	choice_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice_status.add_theme_font_size_override("font_size", 18)
	choice_status.add_theme_color_override("font_shadow_color", Color.BLACK)
	choice_status.add_theme_constant_override("shadow_offset_x", 2)
	choice_status.add_theme_constant_override("shadow_offset_y", 2)
	choice_status.visible = false
	choice_panel.add_child(choice_status)
	choice_panel.visible = false

func drop_choice_button(button: Button) -> void:
	if not is_instance_valid(button): return
	var parent: Node = button.get_parent()
	if parent != null: parent.remove_child(button)
	button.free()

func rebuild_choice_buttons() -> void:
	for button: Button in choice_buttons: drop_choice_button(button)
	choice_buttons.clear()

## The visible control set for the live offer rows: identity, label and tooltip.
## An unchanged plan is never rebuilt: a rebuild between pointer down and up
## would swallow a click the operator is already making, and would drop keyboard
## focus on every snapshot. Only a real offer change re-creates the buttons.
func choice_plan() -> Array:
	var plan: Array = []
	for index in horde.offers.size():
		var row: Dictionary = horde.offers[index]
		var name: String = str(row.get("name", ""))
		plan.append({
			"index":index + 1,
			"label":"%d · %s" % [index + 1, name if not name.is_empty() else str(row.get("id", ""))],
			"tooltip":str(row.get("description", "")),
		})
	return plan

## Authority answers stay visible: a refusal is shown with its reason and a
## confirmation is shown once, so the operator never has to infer either from
## the strip. Local "queued" feedback is replaced, never silently kept.
func update_choice_feedback() -> void:
	var rejected: String = horde_client.rejected_reason
	if not rejected.is_empty() and rejected != last_rejected:
		last_rejected = rejected
		choice_status.text = "CHOICE REFUSED · %s" % rejected.to_upper()
	if horde_client.confirmed_count > last_confirmed:
		last_confirmed = horde_client.confirmed_count
		last_rejected = rejected
		var id: String = horde_client.confirmed_choice
		if id.is_empty():
			choice_status.text = "CHOICE ACCEPTED · RUN %d" % horde_client.confirmed_count
		else:
			choice_status.text = "CHOICE ACCEPTED · %s · RUN %d" % [id.to_upper(), horde_client.confirmed_count]
	if not horde.offers.is_empty(): return
	if horde.applied_count > last_applied or (not horde.selected_id.is_empty() and horde.selected_id != last_selected):
		if horde.selected_id.is_empty():
			choice_status.text = "APPLIED · RUN %d" % horde.applied_count
		else:
			choice_status.text = "APPLIED %s · RUN %d" % [horde.selected_id.to_upper(), horde.applied_count]

func sync_choice_controls() -> void:
	ensure_choice_controls()
	var plan := choice_plan()
	var signature := JSON.stringify(plan)
	if signature != last_choice_signature:
		last_choice_signature = signature
		rebuild_choice_buttons()
		for row: Dictionary in plan:
			var button := Button.new()
			button.name = "HordeUpgradeChoice%d" % int(row.index)
			button.mouse_filter = Control.MOUSE_FILTER_STOP
			button.text = str(row.label)
			var tooltip := str(row.tooltip)
			if not tooltip.is_empty(): button.tooltip_text = tooltip
			button.pressed.connect(choose_offer.bind(int(row.index)))
			choice_panel.add_child(button)
			choice_buttons.append(button)
		choice_status.text = ""
	update_choice_feedback()
	choice_status.visible = not horde.offers.is_empty() or not choice_status.text.is_empty()
	# The status label is a child of the panel: a promoted result must keep the
	# panel open even though the offer itself is gone.
	choice_panel.visible = not horde.offers.is_empty() or choice_status.visible
	last_applied = maxi(last_applied, horde.applied_count)
	last_selected = horde.selected_id

func observe_choices() -> void:
	horde_client.observe_offer(horde.offer_view())
	sync_choice_controls()

## 1-based offer index for a number key, or -1 when that key is not a live
## choice. Interception happens before the shared control recorder, so a choice
## hotkey can never leak into held movement, a pulse or a weapon switch.
func intercept_offer_key(code: int) -> int:
	if not horde.offer_pending: return -1
	var index: int = OFFER_HOTKEYS.get(code, -1)
	if index < 1 or index > horde.offers.size(): return -1
	return index

static func key_code(event: InputEventKey) -> int:
	return event.physical_keycode if event.physical_keycode != 0 else event.keycode

func choose_offer(index: int) -> void:
	var id := horde.offer_id(index)
	if id.is_empty(): return
	ensure_choice_controls()
	var result: Dictionary = horde_client.send_upgrade_intent(id, horde.offer_wave)
	if result.ok:
		# A fresh attempt supersedes the previous refusal, so the same reason can
		# be shown again if this one is refused too.
		last_rejected = ""
		choice_status.text = "CHOICE %d QUEUED · %s" % [index, id.to_upper()]
	elif str(result.reason) == "transport":
		choice_status.text = "Choice not queued — connection closed"
	else:
		choice_status.text = "Choice refused · %s" % str(result.reason)
	choice_status.visible = true
	choice_panel.visible = true

func clear_choices() -> void:
	if choice_panel != null: choice_panel.visible = false
	rebuild_choice_buttons()
	last_choice_signature = ""
	last_rejected = ""
	last_confirmed = 0
	if choice_status != null:
		choice_status.text = ""
		choice_status.visible = false
	horde_client.reset_upgrade_state()
	last_applied = 0
	last_selected = ""

## Map-family seams. The base scene composes the three source Horde maps. The
## identity composition (res://native_arenas/identity_horde_demo.gd) overrides
## these and the view layers only, so presentation, first person/ADS, pickups,
## combat, effects and HUD remain the shared session's code.
func build_view_layers() -> void:
	add_child(camera)
	add_child(sun)
	add_child(environment)
	camera.far = 2000
	camera.rotation_order = EULER_ORDER_YXZ

func open_catalog() -> bool:
	return catalog.open()

func map_ids() -> Array:
	return catalog.entries.keys()

func default_map_id() -> String:
	return MAPS[0]

func map_supports_horde(id: String) -> bool:
	return id in MAPS and catalog.entries.has(id) and "horde" in catalog.entries[id].modes

func load_selected_map(id: String) -> bool:
	return load_map(id)

func update_look(relative: Vector2) -> void:
	if not can_capture_pointer() or not relative.is_finite(): return
	var angles := controls.look(yaw, pitch, relative)
	yaw = angles.x
	pitch = angles.y

func local_motion_source_time(state: Dictionary) -> float:
	var value: Variant = state.get("time")
	return float(value) if (value is int or value is float) and is_finite(float(value)) else NAN

# A burst of source ticks can be drained between two rendered frames. Leave the
# camera at its last drawn position while they are applied, then advance only
# at the render clock. The clamp bounds catch-up after a software/render stall;
# the authority eye and shot ray remain untouched.
const HORDE_VISUAL_MAX_SPEED := 14.0
var _horde_render_time := NAN

static func horde_visual_step(from: Vector3, target: Vector3, seconds: float) -> Vector3:
	return from.move_toward(target, HORDE_VISUAL_MAX_SPEED * maxf(seconds, 0.0))

func apply_local_snapshot_pose(eye: Vector3, _now: float, reseeded: bool) -> void:
	if reseeded or not presentation.lifecycle.can_control():
		_horde_render_time = NAN
		camera.position = eye

func render_local_translation(now: float) -> void:
	if phase != 3 or client.spectating or not received_pose or presentation.local_actor.is_empty(): return
	if snapshot_watch.stale() or not application_focused:
		local_motion.reset()
		_horde_render_time = NAN
		camera.position = presentation.eye_position()
		return
	if not presentation.lifecycle.can_control():
		_horde_render_time = NAN
		camera.position = presentation.eye_position()
		return
	if local_motion.ready():
		var target: Vector3 = local_motion.sample(now)
		camera.position = target if not is_finite(_horde_render_time) else horde_visual_step(camera.position, target, now - _horde_render_time)
		_horde_render_time = now

func aim_requested() -> bool:
	return can_capture_pointer() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and controls.mouse.has(MOUSE_BUTTON_RIGHT)

func release_pointer() -> void:
	controls.focus(false)
	if phase == 3 and horde_client.input_epoch > 0 and client.peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		horde_client.send_controls({}, true) # immediate FIFO cancellation, not a fire release
	super.release_pointer()

func on_lobby(frame: Dictionary) -> void:
	var echoed: Dictionary = echoed_loadout(frame)
	if not echoed.is_empty() and (echoed.get("character") != selected_character or echoed.get("harness") != selected_harness):
		on_error("Horde authority assigned a different operator/harness")
		return
	if phase == 1:
		if client.send_frame({"type":"host", "mapId":current_id,"config":{"mode":"horde","botCount":0,"difficulty":"easy","fragLimit":waves}}) != OK:
			on_error("Horde configuration failed")
		else: phase = 2
		return
	super.on_lobby(frame)

func on_started(frame: Dictionary) -> void:
	release_terminal_blood()
	clear_npc_deaths()
	latest.clear()
	horde.clear()
	clear_choices()
	horde_label.text = horde.text
	super.on_started(frame)

func on_snapshot(frame: Dictionary) -> void:
	if phase != 3: return
	remember_npcs(frame.state)
	super.on_snapshot(frame)
	apply_horde(frame.state)
	record_state(frame.get("seq", -1))

func apply_horde(state: Dictionary, stale: bool = false) -> void:
	latest = state
	horde.apply(state, stale)
	horde_label.text = horde.text
	observe_choices()
	if stale: return
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

func remember_npcs(state: Dictionary) -> void:
	var timestamp: Variant = state.get("time")
	for value: Variant in state.get("actors", []):
		if not value is Dictionary or value.get("isNpc") != true: continue
		var id := BloodWire.identity(value.get("id"))
		if id < 0: continue
		# Keep the last known pose after an actor leaves the public snapshot: event
		# delivery and removal may cross on the same network tick.
		npc_actors[id] = value.duplicate(true)
		if BloodWire.numeric(timestamp): npc_seen[id] = float(timestamp)
	if BloodWire.numeric(timestamp):
		for id: int in npc_seen.keys():
			if float(timestamp) - float(npc_seen[id]) > 0.75:
				npc_seen.erase(id)
				npc_actors.erase(id)
	# Bound long multi-wave runs even when snapshots carry no source clock.
	while npc_actors.size() > 512:
		var oldest: int = npc_actors.keys()[0]
		npc_actors.erase(oldest)
		npc_seen.erase(oldest)

func apply_npc_deaths(items: Array) -> void:
	for value: Variant in items:
		if not value is Dictionary or value.get("type") not in ["death", "enemy-detonate"]: continue
		var event_id := BloodWire.identity(value.get("id"))
		var id := BloodWire.identity(value.get("actor"))
		if event_id < 0 or id < 0 or corpse_events.has(event_id) or not npc_actors.has(id): continue
		var actor: Dictionary = npc_actors[id]
		# A reused seat that is now a player must not inherit an NPC corpse.
		if actor.get("isNpc") != true or id == client.actor_id: continue
		if value.type == "enemy-detonate" and actor.get("npcType") != "sapper": continue
		corpse_events[event_id] = true
		for seen_id: int in corpse_events.keys():
			if seen_id < event_id - 4096: corpse_events.erase(seen_id)
		if corpses.size() >= MAX_CORPSES: retire_corpse(0)
		var node := ActorVisual.new()
		node.name = "HordeCorpse_%d" % event_id
		node.local_id = client.actor_id
		add_child(node)
		node.apply_actor(actor)
		var point: Variant = BloodWire.point(value.get("pos"))
		# Wire death.pos is the impact/body point (usually actor.y + 1), not
		# the foot anchor used by PortPresentation. Preserve snapshot foot height.
		var origin := Vector3(float(actor.get("x", 0)), float(actor.get("y", 0)), float(actor.get("z", 0)))
		if point != null:
			origin.x = point.x
			origin.z = point.z
		node.position = origin + Vector3.UP * 0.9
		node.rotation.y = float(actor.get("bodyYaw", actor.get("yaw", 0.0)))
		node.begin_death()
		corpses.append({"node":node, "age":0.0, "actor":id, "event":event_id})

func retire_corpse(index: int) -> void:
	var corpse: Dictionary = corpses[index]
	corpses.remove_at(index)
	var node: Node3D = corpse.node
	if is_instance_valid(node):
		if node.is_inside_tree(): node.queue_free()
		else: node.free()

func advance_corpses(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0: return
	for i in range(corpses.size() - 1, -1, -1):
		corpses[i].age += delta
		if corpses[i].age >= CORPSE_SECONDS: retire_corpse(i)

func clear_npc_deaths() -> void:
	while not corpses.is_empty(): retire_corpse(corpses.size() - 1)
	corpse_events.clear()
	npc_actors.clear()
	npc_seen.clear()

## Reuse (never clone) the shared configured blood controller for a terminal
## kill. The shared round clear would otherwise erase a burst in the same frame
## as the results packet, before even one render pass. Only the visual lifetime
## moves here; combat admission and damage stay wholly in CombatFeedback.
func hold_terminal_blood() -> void:
	if not is_instance_valid(combat.blood_fx) or not combat.effects_active: return
	var fx: Node3D = combat.blood_fx
	if int(fx.snapshot().get("active_emitters", 0)) <= 0: return
	# Leave the node in the scene tree: removing it triggers its exit-tree
	# notification, which correctly drains blood on real disconnects.
	combat.blood_fx = null
	terminal_blood = fx
	terminal_blood_age = 0.0
	fx.set_active(true, false) # results do not publish fresh actor snapshots

func release_terminal_blood() -> void:
	if not is_instance_valid(terminal_blood): return
	terminal_blood.reset()
	combat.blood_fx = terminal_blood
	terminal_blood = null

func on_results(frame: Dictionary) -> void:
	# The final NPC death may finish the wave before the next render tick.
	# Consume already-received authoritative events before clear_round drains
	# the shared effects pipeline; this is never a synthetic result-frame hit.
	combat.flush_effects()
	hold_terminal_blood()
	round_results += 1
	phase = 4
	presentation.apply_state(frame.state, client.actor_id)
	pickups.apply_state(frame.state)
	combat.clear_round()
	release_pointer()
	apply_horde(frame.state)
	record_state(-1)

func on_error(message: String) -> void:
	release_terminal_blood()
	clear_npc_deaths()
	latest.clear()
	horde.clear()
	clear_choices()
	horde_label.text = "Horde unavailable: " + message
	super.on_error(message)

func controls_released() -> bool:
	for key: int in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_SPACE,KEY_E,KEY_R,KEY_F,KEY_G,KEY_Q,KEY_X,KEY_Z,KEY_C,KEY_SHIFT,KEY_CTRL]:
		if Input.is_physical_key_pressed(key): return false
	return not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var index := intercept_offer_key(key_code(event))
		if index > 0:
			choose_offer(index)
			return
	controls.record(event, weapon_controls_active(), presentation.local_actor)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not controls_released(): return
	super._unhandled_input(event)

func _process(delta: float) -> void:
	advance_corpses(delta)
	if is_instance_valid(terminal_blood) and is_finite(delta) and delta > 0.0:
		terminal_blood_age += delta
		if terminal_blood_age >= CORPSE_SECONDS: release_terminal_blood()
	# Local specialization of session's handshake/watch/send loop. Shared session
	# keeps its old contract; this scene samples source press/hold controls instead.
	controls.focused = application_focused
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
	if choice_layer != null: choice_layer.offset = Vector2(20, horde_label.position.y + horde_label.size.y + 10)
	if phase == 3 and snapshot_watch.stale():
		horde.apply({}, true)
		horde_label.text = horde.text
		observe_choices()

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
