extends SceneTree
const Stub = preload("res://tests/combined_arms/session_stub.gd")
var failures := 0

func check(value: bool, detail: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL shared session vehicle-shot: ", detail)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var session = Stub.new()
	root.add_child(session)
	session.phase = 3
	session.application_focused = true
	session.bind_vehicle_shots()
	check(session.vehicle_shots.bound_client == session.client and session.client.events.is_connected(session.vehicle_shots._on_events),
		"binds before source events, even before a snapshot")
	session.bind_vehicle_shots()
	check(session.client.events.get_connections().size() == 1, "repeated binding does not add another event handler")
	var shot := {"type":"vehicle-shot","id":17,"vehicle":"p","actor":1,"barrel":0,
		"from":{"x":1.0,"y":3.0,"z":4.0},"to":{"x":8.0,"y":3.0,"z":4.0}}
	session.client.events.emit([shot])
	check(session.vehicle_shots.shot_fx.traces.is_empty(), "pre-snapshot events cannot draw")
	session.snapshot_watch.observe()
	var state := {"actors":[],"vehicles":[{"id":"p", "kind":"puma", "x":1.0,"y":2.0,"z":3.0,
		"yaw":0.0,"roll":0.0,"pitchBody":0.0,"turretYaw":0.0,"vx":0.0,"vz":0.0,
		"health":300,"maxHealth":300,"respawnTimer":0.0}]}
	session.observe_vehicles(state)
	check(session.vehicle_shots.active and session.vehicle_shots.bound_client == session.client, "shared session binds source events on snapshot")
	session.client.events.emit([{"type":"shot", "id":16, "from":shot["from"], "to":shot["to"]}])
	check(session.vehicle_shots.shot_fx.traces.is_empty(), "ordinary shots cannot draw mounted tracers")
	session.client.events.emit([shot,shot])
	check(session.vehicle_shots.shot_fx.traces.size() == 1, "source signal routes once to mounted tracer")
	session.client.events.emit([shot])
	check(session.vehicle_shots.shot_fx.traces.size() == 1, "repeated source event ID does not duplicate tracer")
	session.snapshot_watch.advance(2.0)
	session.vehicle_shots._process(0.0)
	check(session.vehicle_shots.shot_fx.traces.is_empty() and not session.vehicle_shots.active,
		"stale snapshot clears traces without needing another event")
	session.client.events.emit([{"type":"vehicle-shot", "id":18, "from":shot["from"], "to":shot["to"]}])
	check(session.vehicle_shots.shot_fx.traces.is_empty(), "stale event cannot draw")
	session.snapshot_watch.observe()
	session.observe_vehicles(state)
	shot.id = 19
	session.client.events.emit([shot])
	check(session.vehicle_shots.shot_fx.traces.size() == 1, "fresh snapshot resumes source-only shots")
	session._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(session.vehicle_shots.shot_fx.traces.is_empty(), "focus loss clears tracer")
	session.client.events.emit([shot])
	check(session.vehicle_shots.shot_fx.traces.is_empty(), "unfocused event never replays")
	session._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	session.snapshot_watch.observe()
	session.observe_vehicles(state)
	shot.id = 20
	session.client.events.emit([shot])
	check(session.vehicle_shots.shot_fx.traces.size() == 1, "fresh source snapshot re-enables visual shots")
	session.phase = 4
	session.client.events.emit([{"type":"vehicle-shot", "id":21, "from":shot["from"], "to":shot["to"]}])
	check(session.vehicle_shots.shot_fx.traces.is_empty(), "results phase blocks events and clears live visual")
	session.phase = 3
	session.snapshot_watch.observe()
	session.observe_vehicles(state)
	shot.id = 22
	session.client.events.emit([shot])
	check(session.vehicle_shots.shot_fx.traces.size() == 1, "new round can draw fresh event")
	session.clear_vehicles()
	check(session.vehicle_shots.shot_fx.traces.is_empty() and not session.vehicle_shots.active
		and session.vehicle_shots.shot_fx.seen.is_empty(), "round teardown clears visual owner and dedup history")
	session.client.events.emit([shot])
	check(session.vehicle_shots.shot_fx.traces.is_empty(), "events after teardown stay suppressed")
	session.snapshot_watch.observe()
	session.observe_vehicles(state)
	session.client.events.emit([shot])
	check(session.vehicle_shots.shot_fx.traces.size() == 1, "new round accepts a previously used source ID")
	# This stripped session overrides _ready and never parents its normal UI/
	# world components. Explicitly free those fixture-only unattached nodes.
	var detached: Array[Node] = [session.camera,session.sun,session.environment,
		session.label,session.selector,session.client,session.presentation,
		session.pickups,session.combat,session.combat_label]
	root.remove_child(session)
	check(not session.client.events.is_connected(session.vehicle_shots._on_events), "unmount disconnects source signal")
	session.free()
	for node: Node in detached:
		if is_instance_valid(node) and node.get_parent() == null: node.free()
	await process_frame
	await process_frame
	print("SHARED_VEHICLE_SHOTS failures=", failures)
	quit(1 if failures else 0)
