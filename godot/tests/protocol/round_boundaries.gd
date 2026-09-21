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
	for node: Node in [session.camera,session.label,session.selector,session.client,session.presentation,session.pickups,session.combat,session.combat_label]: session.add_child(node)
	session.presentation.apply_state({"actors":[{"id":0,"x":0,"y":0,"z":0,"dead":0}]},0)
	session.combat.apply_events([{"type":"damage","actor":0,"amount":2}],0)
	session.phase = 3
	session.received_pose = true
	session.on_error("Synthetic disconnect")
	check(session.phase == -1 and not session.received_pose, "session stops processing")
	check(session.presentation.actors.is_empty() and not session.presentation.lifecycle.can_control(), "stale actors and controls cleared")
	check(session.combat.text().is_empty() and session.pickups.markers.is_empty(), "transient state cleared")
	check(session.label.text == "Synthetic disconnect", "error stays visible")
	session.free()
	print("PORT_ROUND_BOUNDARIES_OK synthetic_checks=", checks)
	quit(0)
