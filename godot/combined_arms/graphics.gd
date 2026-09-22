extends Node3D
## Composition-local, passive adapter. Only decoded snapshots/events drive graphics.
const Rig = preload("res://first_person/rig.gd")
const Feedback = preload("res://world/combat_feedback.gd")
var session: Node
var rig := Rig.new()
var feedback := Feedback.new()
var public_active := false

func attach_to(target: Node) -> void:
	if session != null: return
	session = target
	add_child(rig)
	rig.attach_to(session.world.camera)
	add_child(feedback)

func refresh(focused: bool, captured: bool) -> void:
	if session == null: return
	var allowed: bool = session.eligible() and focused and session.controls.focused and not session.net.spectating and session.net.actor_id >= 0 and Rig.identity(session.actor.get("id")) == session.net.actor_id and not session.actor.get("spectating", false) and session.net.peer.get_ready_state() == WebSocketPeer.STATE_OPEN
	if public_active and not allowed: feedback.clear_round()
	if allowed and not public_active: feedback.apply_state(session.state)
	public_active = allowed
	rig.apply_actor(session.actor, allowed and captured and session.controls.engaged and session.vehicle.is_empty())

func apply_state() -> void:
	if public_active: feedback.apply_state(session.state)

func apply_events(items: Array) -> void:
	# The network already deduplicates public IDs. Consume hidden rig events too;
	# temporary capture/seat/freshness changes must never replay an old trigger.
	rig.apply_events(items, session.net.actor_id)
	if public_active: feedback.apply_events(items, session.net.actor_id)

func hide_infantry() -> void:
	rig.apply_actor({}, false)

func can_capture_pointer() -> bool:
	return rig.showing

func reset() -> void:
	rig.reset()
	feedback.clear_round()
	public_active = false
