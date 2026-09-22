extends SceneTree
const Client = preload("res://net/client.gd")
const Catalog = preload("res://world/catalog.gd")
const Manager = preload("res://combat_particles/manager.gd")
var client := Client.new()
var manager := Manager.new()
var camera := Camera3D.new()
var state := {}
var phase := 0
var elapsed := 0.0
var live_seconds := 0.0
var cadence := 0.0
var snapshots := 0
var public_explosions := 0
var matched_explosions := 0
var local_launches := 0
var local_trail_samples := 0
var samples: Array[Dictionary] = []
var failed := false
func _initialize() -> void: call_deferred("run")
func fail(message: String) -> void:
	failed = true
	push_error(message)
	finish()
func run() -> void:
	root.add_child(camera)
	root.add_child(manager)
	root.add_child(client)
	if not manager.configure(camera, "meridian-exchange").ok: fail("map setup"); return
	manager.set_quality("Low")
	var catalog := Catalog.new()
	if not catalog.open(): fail("catalog"); return
	client.connection_error.connect(func(message: String) -> void: fail(message))
	client.lobby.connect(func(_frame: Dictionary) -> void:
		if phase == 1:
			phase = 2
			client.send_frame({"type": "host", "mapId": "meridian-exchange", "config": {"mode": "rockets", "botCount": 2, "timeLimit": 120, "fragLimit": 100}})
		elif phase == 2:
			phase = 3
			client.send_frame({"type": "start"}))
	client.started.connect(func(_frame: Dictionary) -> void: phase = 4; manager.reset())
	client.snapshot.connect(observe)
	client.events.connect(events)
	client.results.connect(func(_frame: Dictionary) -> void: finish())
	client.connect_server("ws://127.0.0.1:4187", catalog.entries, "meridian-exchange")

func observe(frame: Dictionary) -> void:
	state = frame.state
	snapshots += 1
	manager.apply_state(state, client.actor_id)
	for actor: Dictionary in state.actors:
		if actor.id == client.actor_id:
			camera.position = Vector3(actor.x, actor.y + 1.6, actor.z)
			camera.rotation = Vector3(actor.pitch, actor.yaw, 0)
	for r: Dictionary in state.rockets:
		if r.owner == client.actor_id and not manager._find_trail(int(r.id)).is_empty(): local_trail_samples += 1

func events(items: Array) -> void:
	for item: Dictionary in items:
		if item.get("type") == "launch" and item.get("actor") == client.actor_id: local_launches += 1
		if item.get("type") != "explosion": continue
		public_explosions += 1
		manager.consume([item], client.actor_id)
		if manager.last_event_id == int(item.id):
			var p := Vector3(item.pos.x, item.pos.y, item.pos.z)
			if manager.last_event_position == p:
				matched_explosions += 1
				if samples.size() < 12: samples.append({"public_id": item.id, "public_pos": item.pos, "manager_pos": manager.snapshot().last_event_position, "weapon": item.get("weapon")})

func _process(delta: float) -> bool:
	if phase == 5: return false
	elapsed += delta
	if elapsed > 65: fail("normal server observer timeout"); return false
	if phase == 0 and client.peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		phase = 1
		client.create_room("Particle correlation observer")
	if phase != 4 or state.is_empty(): return false
	live_seconds += delta
	if live_seconds > 22:
		finish()
		return false
	cadence += delta
	if cadence < 1.0 / 30.0: return false
	cadence = 0
	var local := {}
	for actor: Dictionary in state.actors:
		if actor.id == client.actor_id: local = actor
	if local.is_empty(): return false
	var yaw := float(local.yaw)
	var pitch := 0.0
	var nearest := INF
	for actor: Dictionary in state.actors:
		if actor.id == local.id or actor.health <= 0: continue
		var offset := Vector3(actor.x - local.x, actor.y - local.y, actor.z - local.z)
		if offset.length() < nearest:
			nearest = offset.length()
			yaw = atan2(-offset.x, -offset.z)
			pitch = atan2(offset.y, Vector2(offset.x, offset.z).length())
	client.send_input({"x": sin(live_seconds * 0.6), "z": cos(live_seconds * 0.6), "yaw": yaw, "pitch": pitch, "fire": local.health > 0})
	return false

func finish() -> void:
	if phase == 5: return
	phase = 5
	var record := {"normal_server": true, "headless_correlation_only": true, "wall_seconds": elapsed, "public_time": state.get("time"),
		"snapshots": snapshots, "acks": client.last_ack, "local_launches": local_launches, "local_trail_samples": local_trail_samples,
		"public_explosions": public_explosions, "exact_position_matches": matched_explosions, "samples": samples, "manager": manager.snapshot()}
	var ok := not failed and snapshots > 100 and local_launches > 0 and local_trail_samples > 0 and matched_explosions > 0 and client.last_ack > 100
	print("COMBAT_PARTICLES_LIVE ", "PASS " if ok else "FAIL ", JSON.stringify(record))
	client.disconnect_server()
	manager.reset()
	quit(0 if ok else 1)
