extends SceneTree
## Session-policy fixture, separate from the real normal-rate input run.
const Binding = preload("res://first_person/session_binding.gd")
class Peer extends RefCounted:
	var state := WebSocketPeer.STATE_OPEN
	func get_ready_state() -> int: return state
class Client extends Node:
	signal events(items: Array)
	signal started(frame: Dictionary)
	signal results(frame: Dictionary)
	signal connection_error(message: String)
	var actor_id := 7
	var spectating := false
	var peer := Peer.new()
class Lifecycle extends RefCounted:
	var alive := true
	func can_control() -> bool: return alive
class Presentation extends RefCounted:
	var local_actor := {"id":7,"health":100,"weapon":0}
	var lifecycle := Lifecycle.new()
class Watch extends RefCounted:
	var old := false
	func stale() -> bool: return old
class Session extends Node3D:
	var camera := Camera3D.new()
	var client := Client.new()
	var presentation := Presentation.new()
	var snapshot_watch := Watch.new()
	var phase := 3
	var received_pose := true
	var application_focused := true
	var captured := true
	func weapon_controls_active() -> bool: return captured
	func _ready() -> void:
		add_child(camera)
		add_child(client)
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var session := Session.new()
	root.add_child(session)
	var binding := Binding.new()
	session.add_child(binding)
	binding.bind_session(session)
	check(binding.rig.showing,"bound to active source policy")
	var event := {"type":"shot","id":1,"time":1.0,"actor":7,"weapon":0}
	session.client.events.emit([event])
	check(binding.rig.recoil_count == 1,"source event signal hooked")
	for field: String in ["application_focused","received_pose","captured"]:
		session.set(field,false)
		binding.refresh()
		check(not binding.rig.showing,"gated by "+field)
		session.set(field,true)
		binding.refresh()
	session.snapshot_watch.old = true
	binding.refresh()
	check(not binding.rig.showing,"stale snapshot hidden")
	event.id = 2
	event.time = 2.0
	session.client.events.emit([event])
	session.snapshot_watch.old = false
	binding.refresh()
	session.client.events.emit([event])
	check(binding.rig.recoil_count == 1,"stale source events consumed once")
	session.client.spectating = true
	binding.refresh()
	check(not binding.rig.showing,"spectator hidden even with stale local pose")
	session.client.spectating = false
	session.presentation.lifecycle.alive = false
	binding.refresh()
	check(not binding.rig.showing,"source lifecycle hides dead actor")
	session.presentation.lifecycle.alive = true
	session.phase = 4
	binding.refresh()
	check(not binding.rig.showing,"results hidden")
	session.phase = 3
	binding.refresh()
	session.client.peer.state = WebSocketPeer.STATE_CLOSED
	binding.refresh()
	check(not binding.rig.showing,"closed transport hidden without waiting for stale timeout")
	session.client.peer.state = WebSocketPeer.STATE_OPEN
	session.client.actor_id = -1
	binding.refresh()
	check(not binding.rig.showing,"unassigned identity cannot reuse old pose")
	session.client.actor_id = 8
	binding.refresh()
	check(not binding.rig.showing,"foreign identity cannot reuse old pose")
	session.client.actor_id = 7
	binding.refresh()
	check(binding.rig.showing,"matching source identity restored")
	session.client.results.emit({})
	check(not binding.rig.showing and binding.rig.seen.is_empty(),"results signal resets immediately")
	session.free()
	print("FIRST_PERSON_BINDING ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
