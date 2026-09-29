extends "res://world/session.gd"
## Standalone native route. Match/Room remain the sole gameplay authority.
const AssaultState = preload("res://assault/state.gd")
const AssaultRenderer = preload("res://assault/renderer.gd")
const Fleet = preload("res://combined_arms/fleet.gd")
const VehicleLease = preload("res://combined_arms/lease.gd")
const VehicleControls = preload("res://combined_arms/controls.gd")
const Chase = preload("res://combined_arms/camera.gd")
const MAPS := ["tidal-citadel", "sunscar-convoy"]
var assault := AssaultState.new()
var sectors := AssaultRenderer.new()
var fleet := Fleet.new()
var scoreboard := preload("res://ui/scoreboard.gd").new()
var vehicle_controls := VehicleControls.new()
var chase := Chase.new()
var vehicle: Dictionary = {}
var vehicle_identity := ""
var round_seconds := 60
var sector_count := 3
var objective_label := Label.new()
var notice := ""
var notice_age := 0.0
var source_remaining := 0.0

func _ready() -> void:
	for node: Node in [camera, sun, environment]: add_child(node)
	camera.far = 2000
	camera.rotation_order = EULER_ORDER_YXZ
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(20, 20)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	for widget: Control in [objective_label, label, selector, combat_label]:
		panel.add_child(widget)
		widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selector.hide()
	for node: Node in [pickups, presentation, combat, client, sectors, fleet, scoreboard]: add_child(node)
	presentation.interpolate_remote = true
	selected_mode = "assault"
	var selected := MAPS[0]
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="): selected = arg.trim_prefix("--map=")
		if arg.begins_with("--endpoint="): endpoint = arg.trim_prefix("--endpoint=")
		if arg.begins_with("--mode=") and arg != "--mode=assault":
			on_error("This scene requires mode assault")
			return
		for setting: Dictionary in [{"flag":"--bots=", "min":0, "max":8}, {"flag":"--round-seconds=", "min":60, "max":900}, {"flag":"--score-limit=", "min":1, "max":9}]:
			if not arg.begins_with(setting.flag): continue
			var value := arg.trim_prefix(setting.flag)
			if not value.is_valid_int() or int(value) < setting.min or int(value) > setting.max:
				on_error("%s requires an integer from %d to %d" % [setting.flag, setting.min, setting.max])
				return
			match setting.flag:
				"--bots=": selected_bot_count = int(value)
				"--round-seconds=": round_seconds = int(value)
				"--score-limit=": sector_count = int(value)
	if not catalog.open():
		on_error(catalog.error)
		return
	ids = catalog.entries.keys()
	for id: String in ids: selector.add_item(catalog.entries[id].name)
	if selected not in MAPS or not catalog.entries.has(selected) or "assault" not in catalog.entries[selected].modes:
		on_error("Assault requires Tidal Citadel or Sunscar Convoy")
		return
	if not load_map(selected) or not chase.configure_map(selected, catalog.resolve_map(selected)):
		on_error("Could not load Assault map/camera geometry")
		return
	world.get_node("StaticPickupMarkers").hide()
	client.connection_error.connect(on_error)
	client.transport_dropped.connect(on_transport_dropped)
	client.reconnect_outcome.connect(on_reconnect_outcome)
	client.lobby.connect(on_lobby)
	client.started.connect(on_started)
	client.snapshot.connect(on_snapshot)
	client.events.connect(on_events)
	client.results.connect(on_results)
	connect_selected_match()

func on_lobby(frame: Dictionary) -> void:
	if phase == 1:
		if client.send_frame({"type":"host", "mapId":current_id, "config":{"mode":"assault", "botCount":selected_bot_count, "timeLimit":round_seconds, "fragLimit":sector_count}}) != OK:
			on_error("Assault configuration could not be queued")
		else: phase = 2
		return
	if phase == 2:
		var config: Variant = frame.get("config")
		if not config is Dictionary or config.get("mode") != "assault" or config.get("botCount") != selected_bot_count or config.get("timeLimit") != round_seconds or config.get("fragLimit") != sector_count:
			on_error("Authority returned a different Assault configuration")
			return
	super.on_lobby(frame)

func clear_assault() -> void:
	assault.clear_round()
	sectors.clear_round()
	fleet.clear_round()
	vehicle.clear()
	vehicle_identity = ""
	vehicle_controls.release()
	chase.reset()
	notice = ""
	notice_age = 0
	source_remaining = 0
	objective_label.text = ""

func on_started(frame: Dictionary) -> void:
	clear_assault()
	super.on_started(frame)

func on_error(message: String) -> void:
	clear_assault()
	super.on_error(message)

func on_transport_dropped(message: String) -> void:
	clear_assault()
	super.on_transport_dropped(message)

func on_reconnect_outcome(resumed: bool, message: String) -> void:
	clear_assault()
	super.on_reconnect_outcome(resumed, message)

func observe_assault(frame: Dictionary) -> bool:
	if not frame.get("state") is Dictionary:
		on_error("Malformed Assault snapshot; presentation cleared")
		return false
	var state: Dictionary = frame.state
	var config: Variant = state.get("config")
	if state.get("mapId") != current_id or not config is Dictionary or config.get("mode") != "assault" or config.get("botCount") != selected_bot_count or config.get("fragLimit") != sector_count or config.get("timeLimit") != round_seconds or not state.get("over") is bool or not state.has("winner") or not AssaultState.team(state.winner) or not AssaultState.number(state.get("time")) or not state.get("actors") is Array or not state.get("vehicles") is Array or not assault.apply_state(state):
		on_error("Malformed Assault snapshot; presentation cleared")
		return false
	if not fleet.apply_state(frame.state, client.actor_id):
		on_error("Malformed Assault vehicle snapshot; presentation cleared")
		return false
	source_remaining = maxf(0, round_seconds-float(state.time))
	sectors.apply_sector(assault.active_sector())
	return true

func on_snapshot(frame: Dictionary) -> void:
	if phase != 3 or not observe_assault(frame): return
	super.on_snapshot(frame)
	for actor: Dictionary in frame.state.get("actors", []):
		if actor.get("vehicleId") != null and presentation.actors.has(int(actor.id)): presentation.actors[int(actor.id)].hide()
	vehicle = VehicleLease.vehicle_for(frame.state, presentation.local_actor)
	var next := "%s/%s/%s" % [client.actor_id, presentation.local_actor.get("vehicleId"), presentation.local_actor.get("vehicleSeat")]
	if next != vehicle_identity:
		release_pointer()
		chase.reset()
		local_motion.reset()
		vehicle_identity = next
	refresh_objective_hud()

func refresh_objective_hud() -> void:
	objective_label.text = assault.text(presentation.local_actor.get("team"), phase == 4)
	if phase == 3: objective_label.text += "\nSource clock: %.1fs remaining" % source_remaining
	if not notice.is_empty(): objective_label.text += "\n" + notice
	if mounted(): objective_label.text += "\nVEHICLE · Click to capture · WASD drive · Fire · Space/Shift/Ctrl · E exit"
	elif phase == 3: objective_label.text += "\nE: enter nearby source vehicle"
	if phase == 4: objective_label.text += "\nEnter: request source rematch"

func on_events(items: Array) -> void:
	if phase != 3 or snapshot_watch.stale(): return
	combat.apply_events(items, client.actor_id)
	for item: Variant in items:
		if not item is Dictionary: continue
		match item.get("type"):
			"assault-sector-captured": notice = "Source notice: sector captured"
			"assault-sector-lost": notice = "Source notice: sector lost"
			"assault-breach": notice = "Source notice: breach"
			"assault-hold": notice = "Source notice: defenders held"
			_: continue
		notice_age = 4.0
	refresh_objective_hud()

func on_results(frame: Dictionary) -> void:
	if phase != 3 or not observe_assault(frame): return
	if frame.state.get("over") != true:
		on_error("Invalid Assault results")
		return
	av_snapshot(frame.state)
	av_finish(frame.state)
	round_results += 1
	phase = 4
	presentation.apply_state(frame.state, client.actor_id)
	pickups.apply_state(frame.state)
	combat.clear_round()
	sectors.clear_round()
	vehicle.clear()
	release_pointer()
	label.text = "Source round complete"
	refresh_objective_hud()

func mounted() -> bool:
	return presentation.local_actor.get("vehicleId") != null

func weapon_controls_active() -> bool:
	return not mounted() and super.weapon_controls_active()

func combat_controls_active() -> bool:
	return not mounted() and super.combat_controls_active()

func _request_restart() -> bool:
	if not super._request_restart(): return false
	clear_assault()
	return true

func can_capture_pointer() -> bool:
	return super.can_capture_pointer() and (not mounted() or not vehicle.is_empty())

func release_pointer() -> void:
	vehicle_controls.release()
	super.release_pointer()

func _input(event: InputEvent) -> void:
	if not mounted():
		super._input(event)
		return
	vehicle_controls.accept(event, can_capture_pointer(), false)

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if mounted() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and can_capture_pointer(): vehicle_controls.engaged = true

func render_local_translation(now: float) -> void:
	if not mounted(): super.render_local_translation(now)

func _process(delta: float) -> void:
	if not mounted() or phase != 3:
		super._process(delta)
	else:
		# One input owner per frame. Source seat identity selects vehicle commands.
		snapshot_watch.advance(delta)
		if not can_capture_pointer(): release_pointer()
		send_elapsed += delta
		if not client.spectating and send_elapsed >= 1.0 / 60.0:
			send_elapsed = 0
			var packet := vehicle_controls.command(yaw, pitch, can_capture_pointer(), presentation.local_actor.get("vehicleSeat") == "driver")
			if client.send_input(packet) != OK: on_error("Vehicle input could not be queued")
		if not vehicle.is_empty() and not snapshot_watch.stale():
			var pose := chase.follow(vehicle, delta)
			camera.position = pose.eye
			camera.look_at(pose.target)
	if phase == 3 and snapshot_watch.stale():
		clear_assault()
		objective_label.text = "ASSAULT · " + snapshot_watch.message()
		if snapshot_watch.age > 10: on_error("Authoritative Assault snapshots timed out")
	elif phase == 3:
		notice_age = maxf(0, notice_age-delta)
		if notice_age == 0: notice = ""
		refresh_objective_hud()
