extends "res://world/session.gd"
## Standalone native route. Match/Room remain the sole gameplay authority.
const AssaultState = preload("res://assault/state.gd")
const AssaultRenderer = preload("res://assault/renderer.gd")
const Chase = preload("res://combined_arms/camera.gd")
const MAPS := ["tidal-citadel", "sunscar-convoy"]
var assault := AssaultState.new()
var sectors := AssaultRenderer.new()
var scoreboard := preload("res://ui/scoreboard.gd").new()
var game_hud := preload("res://assault/hud.gd").new()
var chase := Chase.new()
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
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 20
	panel.offset_top = 20
	panel.offset_right = -20
	panel.offset_bottom = -20
	for widget: Control in [objective_label, label, selector, combat_label]:
		panel.add_child(widget)
		widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if widget is Label:
			widget.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selector.hide()
	for node: Node in [pickups, presentation, combat, client, sectors, scoreboard, game_hud]: add_child(node)
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
	clear_vehicles()
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
	if state.get("mapId") != current_id or not config is Dictionary or config.get("mode") != "assault" or config.get("botCount") != selected_bot_count or config.get("fragLimit") != sector_count or config.get("timeLimit") != round_seconds or not state.get("over") is bool or not state.has("winner") or not AssaultState.team(state.winner) or not AssaultState.number(state.get("time")) or not state.get("actors") is Array or not state.get("vehicles") is Array:
		on_error("Malformed Assault snapshot; presentation cleared")
		return false
	if not assault.apply_state(state):
		var explanation := assault.error
		on_error("Malformed Assault snapshot: " + explanation)
		return false
	source_remaining = maxf(0, round_seconds-float(state.time))
	sectors.apply_sector(assault.active_sector())
	return true

func on_snapshot(frame: Dictionary) -> void:
	if phase != 3 or not observe_assault(frame): return
	super.on_snapshot(frame)
	if phase != 3: return
	refresh_objective_hud()

func refresh_objective_hud() -> void:
	objective_label.text = game_hud.objective_text() if is_instance_valid(game_hud.session) else assault.text(presentation.local_actor.get("team"), phase == 4)
	if not notice.is_empty(): objective_label.text += "\n" + notice
	if mounted(): objective_label.text += "\nVEHICLE · Click to capture · WASD drive · Fire · Space/Shift/Ctrl · E exit"
	elif phase == 3: objective_label.text += "\nE: enter nearby source vehicle"
	if phase == 4: objective_label.text += "\nEnter: request source rematch"

func on_events(items: Array) -> void:
	if phase != 3: return
	if snapshot_watch.stale():
		# Preserve wire identities while context is absent; never play a stale
		# sector announcement or infer an old local team/seat.
		if is_instance_valid(audiovisual): audiovisual.suspend("stale_snapshot")
		av_events(items)
		return
	combat.apply_events(items, client.actor_id)
	av_events(items)
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
	release_pointer()
	label.text = "Source round complete"
	refresh_objective_hud()

func mounted() -> bool:
	return vehicle_bridge.mounted()

func _request_restart() -> bool:
	if not super._request_restart(): return false
	clear_assault()
	return true

func render_local_translation(now: float) -> void:
	if not mounted(): super.render_local_translation(now)

func _process(delta: float) -> void:
	super._process(delta)
	if phase == 3 and not vehicle_bridge.vehicle.is_empty() and not snapshot_watch.stale():
		var pose := chase.mounted(vehicle_bridge.vehicle, vehicle_bridge.actor, yaw, pitch, delta)
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
