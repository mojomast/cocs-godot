extends SceneTree

# Real normal-rate authority observer. Rockets deliberately bypasses the native
# setup capability gate for diagnosis only; it remains unavailable in that UI.
const Client = preload("res://net/client.gd")
const Catalog = preload("res://world/catalog.gd")
const Viewer = preload("res://world/viewer.gd")
const Presentation = preload("res://world/presentation.gd")
const Combat = preload("res://world/combat_feedback.gd")
const Pickups = preload("res://world/pickups.gd")
const Scoreboard = preload("res://ui/scoreboard.gd")
var client := Client.new()
var presentation := Presentation.new()
var combat := Combat.new()
var pickups := Pickups.new()
var board := Scoreboard.new()
var viewer := Viewer.new()
var mode := "teamdeathmatch"
var map_id := "meridian-exchange"
var phase := 0
var elapsed := 0.0
var cadence := 0.0
var samples := 0
var initial := Vector3.ZERO
var moved := 0.0
var local_shots := 0
var launch_weapon := -1
var projectiles := 0
var score_changes := 0
var previous_scores := ""
var pickup_kinds: Array[String] = []
var last_state: Dictionary = {}
var failed := false

func require(ok: bool, message: String) -> void:
	if ok: return
	failed = true
	push_error(message)
	client.disconnect_server()
	quit(1)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var endpoint := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--endpoint="): endpoint = arg.trim_prefix("--endpoint=")
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		if arg.begins_with("--map="): map_id = arg.trim_prefix("--map=")
	require(mode in ["teamdeathmatch", "rockets"], "observer only accepts its two focused modes")
	var catalog := Catalog.new()
	require(catalog.open(), "catalog unavailable")
	root.add_child(viewer)
	require(viewer.load_map(map_id), "locked map unavailable")
	viewer.world.get_node("StaticPickupMarkers").hide()
	for node: Node in [client, presentation, combat, pickups, board]: root.add_child(node)
	client.connection_error.connect(func(_message: String) -> void: require(false, "live transport failure"))
	client.lobby.connect(func(frame: Dictionary) -> void:
		if phase == 1:
			phase = 2
			require(client.send_frame({"type":"host", "mapId":map_id, "config":{"mode":mode,"botCount":2,"timeLimit":60,"fragLimit":100}}) == OK, "configure queue")
		elif phase == 2:
			require(frame.config.mode == mode and frame.mapId == map_id and frame.config.timeLimit == 60, "echoed config correspondence")
			phase = 3
			require(client.send_frame({"type":"start"}) == OK, "start queue"))
	client.started.connect(func(_frame: Dictionary) -> void: phase = 4)
	client.snapshot.connect(observe)
	client.events.connect(func(items: Array) -> void:
		combat.apply_events(items, client.actor_id)
		for item: Dictionary in items:
			if item.get("actor") != client.actor_id: continue
			if item.type in ["shot", "launch"]: local_shots += 1
			if item.type == "launch": launch_weapon = int(item.weapon))
	client.results.connect(finish_round)
	require(client.connect_server(endpoint, catalog.entries, map_id) == OK, "connect queue")

func observe(frame: Dictionary) -> void:
	var state: Dictionary = frame.state
	require(state.config.mode == mode and state.mapId == map_id, "snapshot mode/map correspondence")
	last_state = state
	presentation.apply_state(state, client.actor_id)
	pickups.apply_state(state)
	board.apply_state(state, client.actor_id)
	board.tab_held = true
	board.refresh_visibility()
	board.render()
	var a: Dictionary = presentation.local_actor
	require(not a.is_empty() and state.actors.size() == 3, "authoritative actor assignment")
	var position := presentation.eye_position()
	viewer.camera.position = position
	viewer.camera.rotation = Vector3(float(a.pitch), float(a.yaw), 0)
	if samples == 0: initial = position
	moved = maxf(moved, Vector2(position.x - initial.x, position.z - initial.z).length())
	samples += 1
	for pickup: Dictionary in state.pickups:
		if str(pickup.kind) not in pickup_kinds: pickup_kinds.append(str(pickup.kind))
	if mode == "teamdeathmatch":
		var expected := "Team totals  ·  Red %d  ·  Blue %d" % [int(state.teamScores["0"]), int(state.teamScores["1"])]
		require(board.team_score_text == expected and expected in board.summary.text, "live team score UI correspondence")
		if not previous_scores.is_empty() and previous_scores != expected: score_changes += 1
		previous_scores = expected
		for actor: Dictionary in state.actors:
			require(int(actor.team) == int(actor.id) % 2, "source alternating team seats")
		for entry: Dictionary in board.entries:
			require(entry.team in ["Red", "Blue"], "readable live team labels")
	else:
		require(board.team_score_text.is_empty(), "Rocket Arena is FFA despite teamScores envelope")
		for actor: Dictionary in state.actors:
			require(not actor.has("team") and int(actor.weapon) == 1 and actor.ammo[1] == "∞", "source rockets-only unlimited FFA loadout")
		for rocket: Dictionary in state.rockets:
			if int(rocket.owner) == client.actor_id and int(rocket.weapon) == 1: projectiles += 1
		for pickup: Dictionary in state.pickups:
			require(pickup.kind in ["health", "armor"], "source restricted supplies")

func _process(delta: float) -> bool:
	if failed: return false
	elapsed += delta
	if elapsed > 80: require(false, "bounded live round timeout")
	if phase == 0 and client.peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		phase = 1
		require(client.create_room() == OK, "create queue")
	if phase != 4 or presentation.local_actor.is_empty(): return false
	cadence += delta
	if cadence < 1.0 / 60.0: return false
	cadence = fmod(cadence, 1.0 / 60.0)
	var a: Dictionary = presentation.local_actor
	var yaw := float(a.yaw)
	var pitch := 0.0
	var nearest := INF
	for other: Dictionary in last_state.actors:
		if other.id == a.id or other.health <= 0 or (mode == "teamdeathmatch" and other.team == a.team): continue
		var offset := Vector3(other.x - a.x, other.y - a.y, other.z - a.z)
		if offset.length() < nearest:
			nearest = offset.length()
			yaw = atan2(-offset.x, -offset.z)
			pitch = atan2(offset.y, Vector2(offset.x, offset.z).length())
	var alive := presentation.lifecycle.can_control()
	# Only ordinary gameplay inputs; no actor/state/clock writes.
	require(client.send_input({"x":sin(elapsed * 0.65) if alive else 0.0,
		"z":cos(elapsed * 0.65) if alive else 0.0, "yaw":yaw, "pitch":pitch, "fire":alive}) == OK, "input queue")
	return false

func finish_round(frame: Dictionary) -> void:
	phase = 5
	board.apply_state(frame.state, client.actor_id, true)
	board.render()
	# Default source sudden-death windows begin before the time limit (TDM 15s,
	# Rockets 12s). A tie broken in that window legitimately ends the round early.
	var minimum_time := 45.0 if mode == "teamdeathmatch" else 48.0
	require(frame.state.over and frame.state.config.mode == mode and float(frame.state.time) >= minimum_time - 0.1, "normal source round results")
	require(elapsed >= float(frame.state.time) * 0.9, "round ran at normal wall-clock rate")
	require(moved > 0.5 and local_shots > 0 and client.last_ack > 10 and samples > 100, "movement/fire acknowledged over full round")
	if mode == "rockets": require(launch_weapon == 1 and projectiles > 0, "actual rocket launch weapon and in-flight snapshots")
	if failed: return
	print("PORT_NATIVE_MODE_LIVE_OK ", JSON.stringify({"map":map_id,"mode":mode,"seconds":frame.state.time,
		"wall_seconds":snappedf(elapsed,0.01),"ending_reason":frame.state.overReason,
		"normal_rate":true,"headless_program_state":true,"snapshots":samples,"ack":client.last_ack,
		"movement_metres":snappedf(moved,0.01),"local_fire_events":local_shots,"rocket_launch_weapon":launch_weapon,
		"local_projectile_samples":projectiles,"team_score_changes":score_changes,"team_scores":frame.state.teamScores,
		"displayed_team_totals":board.team_score_text,"pickup_kinds":pickup_kinds,
		"native_combat_shot_feedback":combat.shots,"results_visible":board.panel.visible}))
	client.disconnect_server()
	for node: Node in [client, presentation, combat, pickups, board, viewer]: node.queue_free()
	await process_frame
	quit(0)
