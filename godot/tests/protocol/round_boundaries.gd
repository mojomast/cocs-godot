extends SceneTree
const Client = preload("res://net/client.gd")
const Session = preload("res://world/session.gd")
var checks: int = 0
var snapshots: int = 0
var results: int = 0
var events: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		quit(1)
		assert(ok, message)
func _initialize() -> void:
	# Explicit synthetic protocol ordering and cleanup, not live packets.
	var client := Client.new()
	client.allowlist = {"meridian-exchange":{}}
	client.requested_map = "meridian-exchange"
	client.actor_id = 0
	client.snapshot.connect(func(_f: Dictionary) -> void: snapshots += 1)
	client.results.connect(func(_f: Dictionary) -> void: results += 1)
	client.events.connect(func(items: Array) -> void: events += items.size())
	var state: Dictionary = {"mapId":"meridian-exchange","over":false}
	var snapshot: Dictionary = {"type":"snapshot","seq":1,"state":state,"acks":{"0":4}}
	check(client.decode_text(JSON.stringify(snapshot)) and snapshots == 1, "first snapshot")
	state.over = true
	var result: Dictionary = {"type":"results","state":state}
	check(client.decode_text(JSON.stringify(result)) and results == 1 and client.round_finished, "results latch")
	client.decode_text(JSON.stringify(result))
	check(results == 1, "duplicate results suppressed")
	snapshot.seq = 2
	client.decode_text(JSON.stringify(snapshot))
	check(snapshots == 1 and client.last_snapshot_seq == 1, "late snapshot cannot replace results")
	client.decode_text(JSON.stringify({"type":"events","items":[{"id":1,"type":"shot"}]}))
	check(events == 0, "late events suppressed")
	client.decode_text(JSON.stringify({"type":"start","mapId":"meridian-exchange"}))
	check(not client.round_finished and client.last_ack == 0 and client.snapshots.is_empty(), "start resets transport round")
	snapshot.seq = 1
	state.over = false
	client.decode_text(JSON.stringify(snapshot))
	check(snapshots == 2 and client.last_ack == 4, "new round restarts sequences")
	client.room_id = "synthetic-room"
	client.peer_id = 9
	client.disconnect_server()
	check(client.room_id.is_empty() and client.peer_id == -1 and client.actor_id == -1 and client.snapshots.is_empty(), "disconnect clears identities and queues")
	client.free()
	# Exercise actual session error cleanup without starting its _ready/network.
	var session := Session.new()
	# _ready normally adopts these constructor-created nodes. This detached
	# fixture skips _ready/network, so it must provide the same ownership.
	for node: Node in [session.camera,session.label,session.selector,session.environment,session.sun,session.client,session.presentation,session.pickups,session.combat,session.combat_label]: session.add_child(node)
	var environment_ref : WeakRef = weakref(session.environment)
	var sun_ref : WeakRef = weakref(session.sun)
	session.presentation.apply_state({"actors":[{"id":0,"x":0,"y":0,"z":0,"dead":0}]},0)
	session.combat.apply_events([{"type":"damage","actor":0,"amount":2}],0)
	session.phase = 3
	session.received_pose = true
	session.on_error("Synthetic disconnect")
	check(session.phase == -1 and not session.received_pose, "session stops processing")
	check(session.presentation.actors.is_empty() and not session.presentation.lifecycle.can_control(), "stale actors and controls cleared")
	check(session.combat.text().is_empty() and session.pickups.markers.is_empty(), "transient state cleared")
	check(session.label.text == "Synthetic disconnect", "error stays visible")
	# Repeated authoritative round starts, snapshots and errors must free actual
	# visuals, not merely empty dictionaries. WeakRefs do not retain the nodes.
	for cycle: int in range(3):
		session.on_started({})
		check(not session.received_pose and not session.presentation.lifecycle.can_control(), "restart waits for fresh authority")
		session.client.actor_id = 0
		session.on_snapshot({"state":{"actors":[
			{"id":0,"x":0,"y":0,"z":0,"yaw":0,"pitch":0,"dead":0,"health":100},
			{"id":1,"x":2,"y":0,"z":0,"dead":0,"health":100}],
			"pickups":[{"id":7,"kind":"health","x":1,"z":1,"wait":0}]}})
		check(session.received_pose and session.presentation.lifecycle.can_control() and session.presentation.actors.size() == 2 and session.pickups.markers.size() == 1, "fresh state repopulates round")
		check(session.presentation.actors[1].visible and not session.presentation.actors[0].visible, "healthy remote visible and local body hidden")
		var actor_ref : WeakRef = weakref(session.presentation.actors[1])
		var pickup_ref : WeakRef = weakref(session.pickups.markers[7])
		var mesh_ref : WeakRef = weakref(session.presentation.actors[1].get_child(0))
		var label_ref : WeakRef = weakref(session.pickups.markers[7].get_node("CloseLabel"))
		if cycle % 2 == 0: session.on_started({})
		else: session.on_error("Repeated synthetic disconnect")
		check(session.presentation.actors.is_empty() and session.pickups.markers.is_empty() and session.presentation.get_child_count() == 0 and session.pickups.get_child_count() == 0, "boundary clears visual collections and children")
		check(actor_ref.get_ref() == null and pickup_ref.get_ref() == null and mesh_ref.get_ref() == null and label_ref.get_ref() == null, "boundary frees visuals and descendants synchronously")
		check(not session.received_pose and not session.can_capture_pointer() and not session.presentation.lifecycle.can_control(), "boundary disables stale controls")
		session.on_error("Repeated synthetic disconnect")
		check(session.presentation.actors.is_empty() and session.pickups.markers.is_empty(), "repeated cleanup is idempotent")
	session.free()
	check(environment_ref.get_ref() == null and sun_ref.get_ref() == null, "detached fixture frees environment and light")
	print("PORT_ROUND_BOUNDARIES_OK synthetic_checks=", checks)
	quit(0)
