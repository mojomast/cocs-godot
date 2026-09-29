extends "res://world/viewer.gd"

const Client = preload("res://net/client.gd")
const SettingsAccess = preload("res://ui/settings_access.gd")
const MouseMotion = preload("res://ui/mouse_motion.gd")
const ControlMath = preload("res://world/control_math.gd")
const WeaponSelection = preload("res://world/weapon_selection.gd")
const CombatActions = preload("res://world/combat_actions.gd")
const VehicleBridge = preload("res://vehicles/session_bridge.gd")
const VehicleFleet = preload("res://combined_arms/fleet.gd")
const Audiovisual = preload("res://audio/av_service.gd")
const VehicleShots = preload("res://vehicles/session_shots.gd")
var vehicle_bridge := VehicleBridge.new()
var vehicle_fleet: Node3D
var vehicle_shots: Node3D
var audiovisual
var audiovisual_round := ""

func av_ensure() -> void:
	if is_instance_valid(audiovisual): return
	# Detached protocol fixtures can receive a start callback before entering the
	# tree. Child _ready (and its audio players) cannot run in that state.
	if not is_inside_tree(): return
	audiovisual = Audiovisual.new()
	audiovisual.name = "NativeAudiovisual"
	add_child(audiovisual)
	var local_settings := SettingsAccess.service()
	if local_settings != null:
		local_settings.audio_preferences_changed.connect(audiovisual.apply_settings)
		audiovisual.apply_settings(local_settings.values)
	else: audiovisual.apply_settings({"mute":"--mute" in OS.get_cmdline_user_args() or "--mute-capture" in OS.get_cmdline_user_args()})

func av_start(frame: Dictionary) -> void:
	av_ensure()
	if not is_instance_valid(audiovisual): return
	var revision: Variant = frame.get("roundRevision", client.resumed_revision)
	if not (revision is int or revision is float): revision = round_starts
	var key := "%s|%s|%s" % [endpoint, client.room_id, str(revision)]
	var arena: Dictionary = catalog.resolve_map(current_id)
	if audiovisual_round != key:
		audiovisual_round = key
		audiovisual.bind_session(self, camera, arena, selected_mode, key, int(revision))
		audiovisual.start_round(key)
	else: audiovisual.start_round(key) # same revision reconnect does not reset IDs
	if not application_focused: audiovisual.set_focus(false)

func av_snapshot(state: Dictionary) -> void:
	if not is_instance_valid(audiovisual): return
	audiovisual.apply_snapshot(state, client.actor_id, not snapshot_watch.stale())
	if SettingsAccess.overlay_open(): audiovisual.suspend("settings_overlay")

func av_events(items: Array) -> void:
	if is_instance_valid(audiovisual):
		if SettingsAccess.overlay_open(): audiovisual.suspend("settings_overlay")
		audiovisual.apply_events(items)

func av_finish(state: Dictionary) -> void:
	if is_instance_valid(audiovisual): audiovisual.finish_state(state, client.actor_id, selected_mode)

func av_tick(delta: float) -> void:
	if is_instance_valid(audiovisual): audiovisual.tick(delta)

func bind_vehicle_shots() -> void:
	if not is_inside_tree(): return
	if not is_instance_valid(vehicle_shots):
		vehicle_shots = VehicleShots.new()
		add_child(vehicle_shots)
	vehicle_shots.bind(client, vehicle_shots_allowed)

func set_vehicle_shots_active(value: bool) -> void:
	if is_instance_valid(vehicle_shots): vehicle_shots.set_active(value)

func vehicle_shots_allowed() -> bool:
	return phase == 3 and application_focused and not snapshot_watch.stale() and not SettingsAccess.overlay_open()

func clear_vehicles() -> void:
	vehicle_bridge.reset()
	if is_instance_valid(vehicle_fleet): vehicle_fleet.clear_round()
	if is_instance_valid(vehicle_shots): vehicle_shots.clear_round()

func observe_vehicles(value: Dictionary) -> void:
	bind_vehicle_shots()
	set_vehicle_shots_active(vehicle_shots_allowed())
	var changed := vehicle_bridge.observe(value, client.actor_id)
	if changed:
		release_pointer()
		local_motion.reset()
	if not value.get("vehicles", []).is_empty() and not is_instance_valid(vehicle_fleet) and is_inside_tree():
		vehicle_fleet = VehicleFleet.new()
		add_child(vehicle_fleet)
	if is_instance_valid(vehicle_fleet):
		if not vehicle_fleet.apply_state(value, client.actor_id):
			on_error("Invalid vehicle snapshot")
			return
	vehicle_bridge.crew_visibility(presentation)

var combat_actions := CombatActions.new()
const FirstPersonBinding = preload("res://first_person/session_binding.gd")
var first_person: Node
var weapon_selection := WeaponSelection.new()
const MatchSetup = preload("res://ui/match_setup.gd")
const Loadout = preload("res://ui/loadout.gd")
var selected_mode: String = "deathmatch"
var selected_bot_count: int = 2
# Identity this session asks the authority to seat it as. The authority echo in
# the lobby roster is the only confirmation; the local value is never assumed.
var selected_character: String = Loadout.DEFAULT_CHARACTER
var selected_harness: String = Loadout.DEFAULT_HARNESS
var endpoint: String = ""
var setup_menu: Control
const LobbyMenu = preload("res://ui/lobby_menu.gd")
var lobby_menu: CanvasLayer
var lobby_enabled := false
var lobby_player_name := "Godot"
var lobby_roster: Dictionary = {}
var disconnected_phase := -1
# Debug facility: OFF by default, only created for a local single-human route
# whose authority echoed a debug channel. Never in the multi-human lobby/guest
# path (those are source-locked and stay fair).
const DebugPanelScene = preload("res://debug/debug_panel.tscn")
var debug_panel: CanvasLayer
var debug_authority_echo: Dictionary = {}

func debug_requested() -> bool:
	return OS.get_environment("COCS_DEBUG") == "1" or "--debug-panel" in OS.get_cmdline_user_args()

func debug_available() -> bool:
	return debug_requested() and not lobby_enabled and join_room_id.is_empty()

func ensure_debug_panel() -> void:
	if not debug_available() or is_instance_valid(debug_panel): return
	debug_panel = DebugPanelScene.instantiate()
	add_child(debug_panel)
	debug_panel.bind_session(self)
	if not debug_authority_echo.is_empty(): debug_panel.acknowledge(debug_authority_echo)

func debug_send(frame: Dictionary) -> Error:
	if not debug_available() or not is_instance_valid(debug_panel): return ERR_UNAUTHORIZED
	if debug_authority_echo.get("enabled", false) != true: return ERR_CONNECTION_ERROR
	return client.send_frame(frame)

func debug_restart() -> bool:
	return _request_restart()

func spectator_status() -> String:
	if phase == 4:
		return "Host restart keeps you a spectator.\nLeave and join between rounds to request a player seat."
	if snapshot_watch.stale():
		return snapshot_watch.message() + "\nRead-only fixed view · No player controls."
	return "Read-only fixed view · Tab: scores · No player controls.\nRestart keeps you a spectator; Leave and join between rounds to request play."

func lobby_host_allowed() -> bool:
	if client.spectating: return false
	if not lobby_enabled or not join_room_id.is_empty(): return false
	if client.peer_id < 0 or lobby_roster.get("hostId", -2) != client.peer_id: return false
	for player: Dictionary in lobby_roster.get("players", []):
		if player.peerId == client.peer_id:
			return bool(player.get("connected", false)) and not bool(player.get("spectate", false))
	return false

func lobby_clear() -> void:
	if is_instance_valid(audiovisual): audiovisual.suspend("lobby")
	audiovisual_round = ""
	clear_vehicles()
	release_pointer()
	local_motion.reset()
	browsing = false
	client.disconnect_server()
	snapshot_watch.reset()
	presentation.clear_round()
	pickups.clear_round()
	combat.clear_round()
	received_pose = false
	pose_actor_id = -1
	send_elapsed = 0
	elapsed = 0
	phase_elapsed = 0
	watched_phase = -999
	yaw = 0
	pitch = 0
	round_starts = 0
	round_results = 0
	moved = false
	fired = false
	lobby_roster.clear()
	if is_instance_valid(lobby_menu):
		lobby_menu.last_frame.clear()
		lobby_menu.roster.text = "No active room. Connect explicitly to a fresh lobby."
	for child: Node in get_children():
		if child.has_method("clear_round") and child not in [presentation, pickups, combat]: child.clear_round()

func lobby_leave() -> void:
	if not lobby_enabled: return
	client.send_frame({"type":"leave"})
	lobby_clear()
	phase = -3
	label.text = "Disconnected"

func lobby_retry_reconnect() -> void:
	if not lobby_enabled or phase != -5: return
	var room: String = client.reconnect_ticket.room_id
	if not client.reconnect_ticket.available(endpoint, current_id, room):
		label.text = "Seat grace expired. Leave and join a room explicitly."
		return
	if client.retry_reconnect(endpoint, catalog.entries, current_id, room) != OK:
		label.text = "Reconnect failed. Leave and join a room explicitly."
		return
	phase = -6
	label.text = "Reconnecting to the same room…"

func on_transport_dropped(message: String) -> void:
	if is_instance_valid(audiovisual): audiovisual.suspend("transport")
	clear_vehicles()
	if not lobby_enabled:
		on_error("Connection lost. Return to the launcher and join a room explicitly.")
		return
	local_motion.reset()
	release_pointer()
	snapshot_watch.reset()
	presentation.clear_round()
	pickups.clear_round()
	combat.clear_round()
	received_pose = false
	pose_actor_id = -1
	send_elapsed = 0.0
	disconnected_phase = phase
	phase = -5
	label.text = message
	lobby_roster.clear()
	if is_instance_valid(lobby_menu): lobby_menu.last_frame.clear()
	emit_boundary_trace("transport_drop")

func on_reconnect_outcome(resumed: bool, message: String) -> void:
	if phase not in [-5, -6]: return
	if not client.career_wire_open():
		phase = -5
		label.text = message
		return
	# Source may join a new spectator when its token has expired. Both paths
	# await authoritative roster/start/results, never restore an old pose.
	phase = 3 if disconnected_phase in [3, 4, 20] else (11 if not join_room_id.is_empty() else 12)
	label.text = message

func lobby_connect(url: String, player_name: String, room: String, map_id: String, mode: String, guest: bool, character: String = "", harness: String = "") -> void:
	if not lobby_enabled or phase not in [-3, -1, -4]: return
	lobby_clear()
	# An explicit pair from the lobby surface replaces the session pair. An empty
	# pair keeps whatever the CLI or an earlier explicit choice established, so
	# the documented defaults are never overwritten by omission.
	if not character.is_empty() or not harness.is_empty():
		var pair: Dictionary = Loadout.resolve(character, harness)
		selected_character = pair.character
		selected_harness = pair.harness
	var problem := MatchSetup.validate(catalog.entries, map_id, mode if not guest else MatchSetup.DEFAULT_MODE)
	if not problem.is_empty():
		on_error(problem)
		return
	if not (url.begins_with("ws://") or url.begins_with("wss://")) or url.contains("@") or url.contains("\n"):
		on_error("Use an explicit ws:// or wss:// endpoint without embedded credentials.")
		return
	if player_name.is_empty() or (guest and room.is_empty()):
		on_error("Enter a display name and, for guests, a room code.")
		return
	if current_id != map_id and not load_map(map_id):
		on_error(catalog.error)
		return
	world.get_node("StaticPickupMarkers").hide()
	endpoint = url
	lobby_player_name = player_name.left(32)
	join_room_id = room if guest else ""
	selected_mode = mode if not guest else MatchSetup.DEFAULT_MODE
	for child: Node in get_children():
		if "guest" in child: child.guest = guest
	connect_selected_match()

# Browse the current endpoint's advertised rooms without seating anywhere. This
# is the same selected endpoint and the same connection as a join; there is no
# scanning or discovery of any other address. Choosing a room then uses the
# normal explicit join path, so the source's active-room spectator rule holds.
func browse_rooms(url: String) -> void:
	# -4 is a live browse seat: re-browsing there must reconnect to the newly
	# entered endpoint instead of listing the previous connection.
	if not lobby_enabled or phase not in [-3, -1, -4]: return
	if not (url.begins_with("ws://") or url.begins_with("wss://")) or url.contains("@") or url.contains("\n"):
		on_error("Use an explicit ws:// or wss:// endpoint without embedded credentials.")
		return
	lobby_clear()
	endpoint = url
	browsing = true
	connect_selected_match()

# True while the lobby's chat surface has focus and is capturing typing. The
# gameplay input adapters gate on this exactly like SettingsAccess.overlay_open,
# so typing a message cannot move or fire, and key releases still reach them.
func social_capturing() -> bool:
	return is_instance_valid(lobby_menu) and lobby_menu.has_method("capturing_input") and lobby_menu.capturing_input()

func lobby_start() -> void:
	if phase != 12 or not lobby_host_allowed(): return
	if not MatchSetup.validate(catalog.entries, current_id, selected_mode).is_empty(): return
	if client.send_frame({"type":"start"}) != OK:
		on_error("Start could not be queued. Retry explicitly.")
		return
	phase = 20

func can_capture_pointer() -> bool:
	if client.spectating: return false
	if vehicle_bridge.mounted() and not vehicle_bridge.eligible(client.actor_id, 0.0, phase == 3, client.spectating): return false
	# Application focus notifications may lag the window's focus state (X11).
	# Detached logic probes have no window; attached sessions must check it.
	if is_inside_tree() and not get_window().has_focus(): return false
	return application_focused and not SettingsAccess.overlay_open() and not social_capturing() and phase == 3 and received_pose and not snapshot_watch.stale() and presentation.lifecycle.can_control()

func update_look(relative: Vector2) -> void:
	if not can_capture_pointer() or not relative.is_finite(): return
	var gain := 0.003 * SettingsAccess.sensitivity() * (0.85 if aim_requested() else 1.0)
	var angles := ControlMath.look(yaw - relative.x * gain, pitch - relative.y * gain)
	if vehicle_bridge.actor.get("vehicleSeat") != "passenger": yaw = angles.x
	pitch = angles.y

const SnapshotWatch = preload("res://net/snapshot_watch.gd")
var snapshot_watch := SnapshotWatch.new()
const Presentation = preload("res://world/presentation.gd")
const LocalMotion = preload("res://world/local_motion.gd")
const Pickups = preload("res://world/pickups.gd")
const CombatFeedback = preload("res://world/combat_feedback.gd")
var combat := CombatFeedback.new()
var combat_label := Label.new()
var pickups := Pickups.new()
var client := Client.new()
var presentation := Presentation.new()
var local_motion := LocalMotion.new()
# Guest phases: 10 waits for join acknowledgement; 11 waits for host start.
# Browse phase: -4 is a connected room-browser seat (no room joined); it shares
# the editable pre-join form and is left by choosing a room and joining.
var join_room_id: String = ""
var browsing := false
var phase: int = 0
# Opt-in program-state evidence, never a claim of graphical acceptance.
var trace_enabled: bool = false
var trace_count: int = 0
const TRACE_LIMIT: int = 10000

func native_trace_limit() -> int:
	return TRACE_LIMIT

func trace_snapshot(reseeded: bool) -> Dictionary:
	var actor: Dictionary = presentation.local_actor
	return {"schema":1, "event":"snapshot", "round":round_starts,
		"actor_id":client.actor_id, "ack":client.last_ack, "phase":phase,
		"pose_present":received_pose, "health":actor.get("health", null),
		"dead":actor.get("dead", null), "lifecycle":presentation.lifecycle.status,
		"camera_reseeded":reseeded, "yaw":yaw, "pitch":pitch,
		"camera_position":[camera.position.x,camera.position.y,camera.position.z],
		"pointer_captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"control_eligible":can_capture_pointer(), "focused":application_focused}

func trace_input(controls: Dictionary, result: Error) -> Dictionary:
	var selected: Dictionary = {}
	for key: String in ["x", "z", "yaw", "pitch", "fire", "jump", "reload", "sprint", "crouch", "interact", "mobility", "ads", "power", "melee", "grenade", "altFire"]:
		selected[key] = controls.get(key, null)
	if controls.has("weapon"): selected["weapon"] = controls.weapon
	return {"schema":1, "event":"input_queue", "round":round_starts,
		"actor_id":client.actor_id, "ack":client.last_ack, "phase":phase,
		"controls":selected, "queue_result":int(result), "queued":result == OK}

func emit_snapshot_trace(reseeded: bool) -> void:
	if not trace_enabled or trace_count >= native_trace_limit(): return
	emit_native_trace(trace_snapshot(reseeded))

func emit_native_trace(record: Dictionary) -> void:
	if not trace_enabled or trace_count >= native_trace_limit(): return
	record["sequence"] = trace_count
	record["monotonic_usec"] = Time.get_ticks_usec()
	print("PORT_NATIVE_TRACE ", JSON.stringify(record))
	trace_count += 1
	if trace_count == native_trace_limit():
		print('PORT_NATIVE_TRACE {"schema":1,"event":"limit","complete":false}')

func emit_boundary_trace(event: String) -> void:
	if not trace_enabled or trace_count >= native_trace_limit(): return
	# Never serialize error messages: transport details may contain credentials.
	emit_native_trace({"schema":1, "event":event, "round":round_starts,
		"actor_id":client.actor_id, "phase":phase, "complete":false,
		"pose_present":received_pose,
		"pointer_captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED})

func begin_room() -> void:
	var result: Error = client.create_room(lobby_player_name, selected_character, selected_harness) if join_room_id.is_empty() else client.join_room(join_room_id, lobby_player_name if lobby_enabled else "Godot guest", selected_character, selected_harness)
	if result != OK:
		on_error("Room request could not be queued. Relaunch to reconnect.")
		return
	phase = 1 if join_room_id.is_empty() else 10
var elapsed: float = 0
var send_elapsed: float = 0
var yaw: float = 0
var pitch: float = 0
var received_pose: bool = false
var pose_actor_id: int = -1
var smoke: bool = false
var initial_position := Vector3.ZERO
var moved: bool = false
var fired: bool = false
var lifecycle_smoke: bool = false
var round_starts: int = 0
var round_results: int = 0
var phase_elapsed: float = 0.0
var watched_phase: int = -999
const HANDSHAKE_TIMEOUT: float = 15.0

func request_restart() -> void:
	_request_restart()

func _request_restart() -> bool:
	if client.spectating: return false
	if phase != 4 or not join_room_id.is_empty(): return false
	if lobby_enabled and not lobby_host_allowed(): return false
	if client.send_frame({"type":"start"}) == OK:
		phase = 20
		label.text = "Waiting for authoritative round start…"
		return true
	label.text = presentation.hud_text + "\nRestart could not be queued. Enter: retry"
	return false

func release_pointer() -> void:
	weapon_selection.clear()
	combat_actions.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

var application_focused: bool = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_instance_valid(audiovisual): audiovisual.set_focus(false)
		application_focused = false
		set_vehicle_shots_active(false)
		local_motion.reset()
		release_pointer()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		application_focused = true
		if is_instance_valid(audiovisual): audiovisual.set_focus(true)

func advance_handshake(delta: float) -> bool:
	if not is_finite(delta) or delta < 0.0: return false
	if lobby_enabled and phase == 11: return true
	if phase != watched_phase:
		watched_phase = phase
		phase_elapsed = 0.0
	if phase not in [0, 1, 2, 10, 11, 20]: return true
	phase_elapsed += delta
	if phase_elapsed < (120.0 if phase == 11 else HANDSHAKE_TIMEOUT): return true
	on_error("Connection/round-start timed out. Relaunch to reconnect.")
	return false

func _ready() -> void:
	super._ready()
	if not catalog.entries.has("meridian-exchange"): return
	add_child(pickups)
	selector.disabled = true
	selector.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.get_parent().mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(client)
	add_child(presentation)
	add_child(combat)
	label.get_parent().add_child(combat_label)
	combat_label.position = Vector2(24, 170)
	combat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	client.events.connect(func(items: Array) -> void:
		if phase == 3:
			combat.apply_events(items, client.actor_id)
			av_events(items))
	presentation.interpolate_remote = true
	camera.rotation_order = EULER_ORDER_YXZ
	trace_enabled = "--native-trace" in OS.get_cmdline_user_args()
	smoke = "--session-smoke" in OS.get_cmdline_user_args()
	lifecycle_smoke = "--lifecycle-smoke" in OS.get_cmdline_user_args()
	lobby_enabled = "--lobby-menu" in OS.get_cmdline_user_args()
	var options := MatchSetup.parse_args(OS.get_cmdline_user_args(), catalog.entries)
	if not options.error.is_empty():
		on_error(options.error)
		return
	selected_mode = options.mode
	selected_bot_count = options.bots
	selected_character = options.operator
	selected_harness = options.harness
	if not load_map(options.map):
		on_error(catalog.error)
		return
	world.get_node("StaticPickupMarkers").hide()
	selector.select(ids.find(current_id))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--endpoint="): endpoint = arg.trim_prefix("--endpoint=")
		if arg.begins_with("--join-room="):
			join_room_id = arg.trim_prefix("--join-room=").strip_edges()
			if join_room_id.is_empty():
				on_error("Join room ID must not be empty")
				return
	if not join_room_id.is_empty() and (smoke or lifecycle_smoke):
		on_error("Guest mode cannot be combined with automatic smoke controls")
		return
	ensure_debug_panel()
	client.connection_error.connect(on_error)
	client.transport_dropped.connect(on_transport_dropped)
	client.reconnect_outcome.connect(on_reconnect_outcome)
	client.lobby.connect(on_lobby)
	client.started.connect(on_started)
	client.snapshot.connect(on_snapshot)
	client.results.connect(func(f: Dictionary) -> void:
		if lobby_enabled and phase != 3: return
		set_vehicle_shots_active(false)
		round_results += 1
		presentation.apply_state(f.state, client.actor_id)
		av_snapshot(f.state)
		av_finish(f.state)
		observe_vehicles(f.state)
		pickups.apply_state(f.state)
		phase = 4
		combat.clear_round()
		release_pointer()
		label.text = presentation.hud_text + ("\nEnter: restart" if join_room_id.is_empty() else "\nWaiting for host to restart")
		if client.spectating: label.text = "SPECTATOR · ROUND COMPLETE\n" + spectator_status()
		if lifecycle_smoke:
			if not bool(f.state.get("over", false)) or presentation.lifecycle.can_control():
				on_error("Results did not disable controls")
				return
			request_restart())
	if lobby_enabled:
		phase = -3
		smoke = false
		lifecycle_smoke = false
		lobby_menu = LobbyMenu.new()
		add_child(lobby_menu)
		label.hide()
		selector.hide()
		combat_label.hide()
	elif options.setup:
		phase = -2 # Waiting for local choice: no connection and no handshake timer.
		setup_menu = MatchSetup.new()
		label.get_parent().get_parent().add_child(setup_menu)
		setup_menu.configure(catalog.entries, current_id, selected_mode, selected_character, selected_harness, selected_bot_count)
		setup_menu.start_requested.connect(start_selected_match)
		label.hide()
		selector.hide()
	else:
		connect_selected_match()

func start_selected_match(map_id: String, mode: String) -> void:
	if phase != -2: return
	var problem := MatchSetup.validate(catalog.entries, map_id, mode)
	if not problem.is_empty():
		on_error(problem)
		return
	if not load_map(map_id):
		on_error(catalog.error)
		return
	world.get_node("StaticPickupMarkers").hide()
	selected_mode = mode
	# start_requested stays a 2-argument signal: the surface that owns the pair is
	# read here instead of widening the signal contract.
	if is_instance_valid(setup_menu) and setup_menu.has_method("selected_character"):
		var pair: Dictionary = Loadout.resolve(setup_menu.selected_character(), setup_menu.selected_harness())
		selected_character = pair.character
		selected_harness = pair.harness
	selector.select(ids.find(current_id))
	setup_menu.hide()
	label.show()
	selector.show()
	connect_selected_match()

func connect_selected_match() -> void:
	phase = 0
	if endpoint.is_empty() or client.connect_server(endpoint, catalog.entries, current_id) != OK:
		on_error("A local launcher endpoint is required")
		return
	label.text = "Connecting to isolated Node authority…"

func on_started(_frame: Dictionary) -> void:
	bind_vehicle_shots()
	if lobby_enabled and phase not in [11, 12, 20, 3, 4, -6]: return
	av_start(_frame)
	# A host can start a new round without this client visiting results.
	# Never carry interactive capture across an authoritative round boundary.
	release_pointer()
	clear_vehicles()
	local_motion.reset()
	if is_instance_valid(debug_panel): debug_panel.round_started()
	round_starts += 1
	snapshot_watch.reset()
	presentation.clear_round()
	pickups.clear_round()
	combat.clear_round()
	received_pose = false
	send_elapsed = 0.0
	moved = false
	fired = false
	phase = 3
	emit_boundary_trace("round_start")

func on_error(message: String) -> void:
	clear_vehicles()
	local_motion.reset()
	if is_instance_valid(setup_menu): setup_menu.hide()
	label.show()
	snapshot_watch.reset()
	phase = -1
	presentation.clear_round()
	pickups.clear_round()
	combat.clear_round()
	received_pose = false
	if lobby_enabled and not client.room_id.is_empty(): client.send_frame({"type":"leave"})
	client.disconnect_server()
	label.text = message
	if lobby_enabled:
		lobby_clear()
		phase = -1
		label.hide()
	release_pointer()
	emit_boundary_trace("session_error")
	if smoke or lifecycle_smoke:
		push_error(message)
		get_tree().quit(1)

# The authority echo is the only confirmation of the identity this connection
# was seated as. An empty dictionary means the roster carried no identity at all.
func echoed_loadout(frame: Dictionary) -> Dictionary:
	for player: Dictionary in frame.get("players", []):
		if int(player.get("peerId", -1)) == client.peer_id and player.get("character") is String and player.get("harness") is String:
			return {"character": str(player.character), "harness": str(player.harness)}
	if not client.assigned_character.is_empty() or not client.assigned_harness.is_empty():
		return {"character": client.assigned_character, "harness": client.assigned_harness}
	return {}

func on_lobby(frame: Dictionary) -> void:
	# Additive debug capability echo. It only ever arrives from a port-owned
	# local authority with the channel enabled; the panel is created here so
	# native routes (which skip session _ready) get it without scene edits.
	if frame.get("debug") is Dictionary:
		debug_authority_echo = frame.debug
		ensure_debug_panel()
		if is_instance_valid(debug_panel): debug_panel.acknowledge(debug_authority_echo)
	if lobby_enabled:
		if phase not in [1, 2, 10, 11, 12, 20, 3, 4, -6]: return
		lobby_roster = frame.duplicate(true)
		if is_instance_valid(lobby_menu): lobby_menu.show_roster(frame)
		# Narrow identity check: only a roster that actually carries this
		# connection's identity can contradict the request, so minimal legacy
		# rosters keep working unchanged.
		var echoed: Dictionary = echoed_loadout(frame)
		if not echoed.is_empty():
			var requested: Dictionary = Loadout.resolve(selected_character, selected_harness)
			if echoed.character != requested.character or echoed.harness != requested.harness:
				on_error("Authority assigned a different operator/harness; session cancelled.")
				return
		if frame.get("config") is Dictionary:
			var problem := MatchSetup.validate(catalog.entries, current_id, str(frame.config.get("mode", "")))
			if not problem.is_empty():
				on_error(problem)
				return
	# Identity has already been updated by the validated network roster.
	# Never use the previous actor's pose while waiting for the new snapshot.
	if received_pose and pose_actor_id != client.actor_id:
		received_pose = false
		local_motion.reset()
		send_elapsed = 0.0
		release_pointer()
	if not join_room_id.is_empty() and frame.get("config") is Dictionary:
		selected_mode = str(frame.config.get("mode", selected_mode))
	if phase == 10:
		phase = 11
		label.text = "Joined room. Waiting for host start (120-second limit)…"
		return
	if phase == 1:
		var queued: Error
		if lifecycle_smoke:
			queued = client.send_frame({"type":"host", "mapId":current_id, "config":{"mode":selected_mode,"botCount":2,"timeLimit":60,"fragLimit":100}})
		elif lobby_enabled:
			queued = client.send_frame({"type":"host", "mapId":current_id, "config":{"mode":selected_mode,"botCount":2,"timeLimit":60,"fragLimit":100}})
		else:
			queued = client.configure_match(selected_mode, selected_bot_count)
		if queued != OK:
			on_error("Match configuration could not be queued. Relaunch to reconnect.")
			return
		phase = 2
	elif phase == 2 and frame.get("config") != null:
		# Check an echoed mode without broadening the existing partial-envelope contract.
		if not frame.config is Dictionary or (frame.config.has("mode") and frame.config.mode != selected_mode):
			on_error("Authority returned a different match mode; start cancelled.")
			return
		if lobby_enabled:
			phase = 12
			return
		if client.send_frame({"type":"start"}) != OK:
			on_error("Initial round start could not be queued. Relaunch to reconnect.")
			return
		phase = 20

func on_snapshot(frame: Dictionary) -> void:
	if phase != 3: return
	# Native Deathmatch and Horde build their own _ready composition; all playable
	# sessions still reach this shared snapshot path. Connect once here so their
	# render clock drives local translation too.
	if not presentation.render_frame.is_connected(render_local_translation):
		presentation.render_frame.connect(render_local_translation)
	if is_instance_valid(debug_panel): debug_panel.observe_config(frame.state.get("config", {}))
	snapshot_watch.observe()
	pickups.apply_state(frame.state)
	combat.apply_state(frame.state)
	presentation.apply_state(frame.state, client.actor_id)
	av_snapshot(frame.state)
	observe_vehicles(frame.state)
	if phase != 3: return
	if is_inside_tree() and not is_instance_valid(first_person):
		first_person = FirstPersonBinding.new()
		first_person.name = "FirstPerson"
		add_child(first_person)
		first_person.bind_session(self)
	if client.spectating:
		local_motion.reset()
		received_pose = false
		pose_actor_id = -1
		release_pointer()
		label.text = "SPECTATING\n" + spectator_status()
		emit_snapshot_trace(false)
		return
	var actor: Dictionary = presentation.local_actor
	combat_actions.observe_actor(actor)
	if actor.is_empty():
		local_motion.reset()
		# Reset once on loss, not on every absent-actor snapshot: otherwise
		# frequent snapshots starve the neutral-input send cadence.
		if received_pose: send_elapsed = 0.0
		received_pose = false
		release_pointer()
		emit_snapshot_trace(false)
		return
	var reseeded: bool = not received_pose or pose_actor_id != client.actor_id or presentation.lifecycle.reseed_look
	if reseeded: local_motion.reset()
	var eye: Vector3 = presentation.eye_position()
	var now: float = Time.get_ticks_usec() / 1000000.0
	local_motion.ingest(eye, presentation.lifecycle.can_control(), now, local_motion_source_time(frame.state))
	apply_local_snapshot_pose(eye, now, reseeded)
	if reseeded:
		weapon_selection.clear()
		combat_actions.clear()
		var angles := ControlMath.look(float(actor.yaw), float(actor.pitch))
		yaw = angles.x
		pitch = angles.y
		initial_position = camera.position
		received_pose = true
	if vehicle_bridge.actor.get("vehicleSeat") == "passenger": yaw = float(actor.get("yaw", yaw))
	pose_actor_id = client.actor_id
	# A respawn must not silently reactivate controls held before death.
	# Keep the pose for authoritative camera tracking, but require recapture.
	if not presentation.lifecycle.can_control(): release_pointer()
	emit_snapshot_trace(reseeded)
	moved = moved or camera.position.distance_to(initial_position) > 0.5
	fired = fired or int(actor.get("shots", 0)) > 0
	if lifecycle_smoke and round_starts == 2 and round_results == 1 and client.last_ack > 10:
		if presentation.lifecycle.status != "alive" or presentation.actors.size() != 3:
			on_error("Restart state invalid")
			return
		print("PORT_LIFECYCLE_LIVE_OK starts=", round_starts, " results=", round_results, " restarted_actors=", presentation.actors.size(), " restarted_ack=", client.last_ack, " map=", current_id, " normal_rate=true")
		client.disconnect_server()
		get_tree().quit(0)
	label.text = "NODE-AUTHORITATIVE PROTOTYPE · %s\n" % selected_mode + presentation.hud_text + "\nClick: capture/fire · RMB: ADS · Z/MMB: alt · Esc: release · WASD: move · Space: jump\nShift: sprint · Ctrl/C: crouch · R: reload · E: interact · X: mobility · Q: power · F: melee · G: grenade · 1–9/0 or wheel: weapon | ACK %d" % client.last_ack
	var smoke_pickups_ok: bool = pickups.markers.is_empty() if selected_mode == "instagib" else not pickups.markers.is_empty()
	var smoke_fire_ok: bool = combat.local_launches > 0 if selected_mode == "rockets" else combat.shots > 0
	if smoke and smoke_fire_ok and moved and fired and client.last_ack > 10 and presentation.actors.size() == selected_bot_count + 1 and (selected_bot_count == 0 or presentation.rendered_remote_poses > 10) and smoke_pickups_ok and not world.get_node("StaticPickupMarkers").visible:
		print("PORT_OPERATOR_MODEL ", presentation.actors.values()[0].get_script().resource_path)
		print("PORT_SESSION_SMOKE_OK actors=3 camera=authoritative movement=true fired=true ack=", client.last_ack, " snapshots=", presentation.applied, " remote_poses=", presentation.rendered_remote_poses, " pickups=", pickups.markers.size(), " static_pickups_hidden=true combat_shots=", combat.shots, " combat_launches=", combat.launches, " local_launches=", combat.local_launches, " map=", current_id, " mode=", selected_mode)
		client.disconnect_server()
		get_tree().quit(0)

## Horde can use source ticks while ordinary sessions retain receive-time motion.
func local_motion_source_time(_state: Dictionary) -> float:
	return NAN

func apply_local_snapshot_pose(eye: Vector3, now: float, _reseeded: bool) -> void:
	camera.position = local_motion.sample(now) if local_motion.ready() else eye

# Runs from the presentation node's render clock, not session._process: Horde
# overrides that method. Translation alone is visual; look angles and input
# remain current, and stale/focus/spectator epochs cannot extrapolate a pose.
func render_local_translation(now: float) -> void:
	if phase != 3 or client.spectating or not received_pose or presentation.local_actor.is_empty(): return
	if snapshot_watch.stale() or not application_focused:
		local_motion.reset()
		camera.position = presentation.eye_position()
		return
	if local_motion.ready(): camera.position = local_motion.sample(now)

func weapon_controls_active() -> bool:
	if vehicle_bridge.mounted() and vehicle_bridge.actor.get("vehicleSeat") != "passenger": return false
	return can_capture_pointer() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func combat_controls_active() -> bool:
	# Arms Race disables weapon selection, not ordinary combat or ADS.
	return can_capture_pointer() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func aim_requested() -> bool:
	if vehicle_bridge.mounted() and vehicle_bridge.actor.get("vehicleSeat") != "passenger": return false
	combat_actions.observe_actor(presentation.local_actor)
	if not combat_controls_active():
		combat_actions.clear()
		return false
	return combat_actions.aiming()

func observe_combat_input(event: InputEvent) -> void:
	combat_actions.record(event, combat_controls_active(), presentation.local_actor)

func _input(event: InputEvent) -> void:
	if SettingsAccess.overlay_open() or social_capturing():
		if (event is InputEventKey or event is InputEventMouseButton) and not event.pressed:
			combat_actions.record(event, false, presentation.local_actor)
			weapon_selection.handle_event(event, false, presentation.local_actor)
		return
	# Observe releases even when a GUI control handles the event later.
	observe_combat_input(event)
	if weapon_selection.handle_event(event, weapon_controls_active(), presentation.local_actor):
		if weapon_selection.pending >= 0: combat_actions.cancel_aim()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if SettingsAccess.overlay_open() or social_capturing(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE: release_pointer()
		if event.keycode == KEY_ENTER: request_restart()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and can_capture_pointer():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		combat_actions.captured()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		update_look(MouseMotion.raw_delta(event))

func _process(delta: float) -> void:
	if phase == 4 and is_instance_valid(audiovisual) and application_focused and not SettingsAccess.overlay_open(): av_tick(delta)
	if phase == 3 and is_instance_valid(audiovisual):
		if snapshot_watch.stale() or not application_focused or SettingsAccess.overlay_open():
			if audiovisual.fresh: audiovisual.suspend("settings_overlay" if SettingsAccess.overlay_open() else "stale_or_focus")
		else: av_tick(delta)
	if phase != 3 or not application_focused or SettingsAccess.overlay_open(): set_vehicle_shots_active(false)
	if not advance_handshake(delta): return
	weapon_selection.advance(delta, weapon_controls_active(), presentation.local_actor, client.last_ack)
	combat_label.text = combat.text()
	if phase == 3:
		var was_stale := snapshot_watch.stale()
		snapshot_watch.advance(delta)
		# Do not silently resume held controls when snapshots recover.
		if not was_stale and snapshot_watch.stale(): release_pointer()
		if snapshot_watch.stale():
			set_vehicle_shots_active(false)
			combat_label.text = snapshot_watch.message()
	elapsed += delta
	if smoke and elapsed > 20:
		on_error("Session smoke timeout")
		return
	if lifecycle_smoke and elapsed > 90:
		on_error("Lifecycle smoke timeout")
		return
	if phase == 0 and client.peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if browsing:
			# Browse seat: connected but unseated. The lobby surface sends the
			# `list` request once it sees phase -4 so one request owns one reply.
			browsing = false
			phase = -4
			label.text = "Browsing server rooms…"
		else:
			begin_room()
	if phase != 3: return
	if client.spectating:
		release_pointer()
		send_elapsed = 0.0
		return # Read-only recipients do not even queue neutral player inputs.
	camera.rotation = Vector3(pitch, yaw, 0)
	send_elapsed += delta
	if send_elapsed < 1.0 / 60.0: return
	send_elapsed = fmod(send_elapsed, 1.0 / 60.0)
	var active: bool = combat_controls_active()
	combat_actions.observe_actor(presentation.local_actor)
	var controls := combat_actions.sample(yaw, pitch, active)
	# Explicit legacy smoke stimulus is isolated from ordinary event input.
	if smoke and received_pose and not snapshot_watch.stale() and presentation.lifecycle.can_control():
		var direction := ControlMath.movement(yaw, 1.0, 0.0)
		controls.x = direction.x
		controls.z = direction.y
		controls.fire = true
	if weapon_controls_active() and weapon_selection.pending >= 0:
		controls["weapon"] = weapon_selection.pending
	if vehicle_bridge.mounted():
		# Source driveVehicle projects world axes into throttle and negative right.
		if vehicle_bridge.actor.get("vehicleSeat") == "driver":
			var throttle := float(combat_actions.key(KEY_W)) - float(combat_actions.key(KEY_S))
			var steer := float(combat_actions.key(KEY_D)) - float(combat_actions.key(KEY_A))
			var axes := Vector2(-sin(yaw)*throttle-cos(yaw)*steer, -cos(yaw)*throttle+sin(yaw)*steer)
			axes /= maxf(1.0, maxf(absf(axes.x), absf(axes.y)))
			controls.x = axes.x
			controls.z = axes.y
		controls = vehicle_bridge.adapt(controls, active and vehicle_bridge.eligible(client.actor_id, 0.0, phase == 3 and not snapshot_watch.stale(), client.spectating))
	var queue_result: Error = client.send_input(controls)
	if queue_result == OK: combat_actions.queued()
	if queue_result == OK and controls.has("weapon"): weapon_selection.queued(client.input_seq)
	if trace_enabled and trace_count < native_trace_limit():
		emit_native_trace(trace_input(controls, queue_result))
	if queue_result != OK:
		# The client polls the close in its own process turn. A transport drop
		# must reach its bounded ticket path, not the fatal session-error path.
		if lobby_enabled and client.was_open and not client.reconnect_ticket.token.is_empty() and client.peer.get_ready_state() != WebSocketPeer.STATE_OPEN: return
		on_error("Input could not be queued. Relaunch to reconnect.")

func _exit_tree() -> void:
	client.disconnect_server()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
