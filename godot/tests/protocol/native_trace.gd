extends SceneTree
const Session = preload("res://world/session.gd")
var checks := 0
var failures := 0
func check(ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("Native trace assertion " + str(checks))
func _initialize() -> void:
	var s := Session.new()
	for node: Node in [s.camera,s.label,s.selector,s.client,s.presentation,s.pickups,s.combat,s.combat_label]: s.add_child(node)
	s.emit_snapshot_trace(false)
	check(s.trace_count == 0)
	s.phase = 3
	s.received_pose = true
	s.client.actor_id = 7
	s.presentation.local_actor = {"health":80,"dead":0,"private":"must not leak"}
	s.presentation.lifecycle.status = "alive"
	s.snapshot_watch.observe()
	var record := s.trace_snapshot(true)
	check(record.actor_id == 7 and record.health == 80 and record.dead == 0)
	check(record.camera_reseeded and record.control_eligible)
	check(not JSON.stringify(record).contains("private"))
	check(JSON.parse_string(JSON.stringify(record)) is Dictionary)
	s.application_focused = false
	check(not s.trace_snapshot(false).control_eligible)
	s.presentation.lifecycle.status = "dead"
	check(not s.trace_snapshot(false).control_eligible)
	s.presentation.local_actor = {}
	s.received_pose = false
	check(s.trace_snapshot(false).health == null and not s.trace_snapshot(false).pose_present)
	s.trace_enabled = true
	s.on_snapshot({"state":{"actors":[],"pickups":[],"t":0}})
	check(s.trace_count == 1 and not s.received_pose)
	s.phase = 4
	s.on_snapshot({"state":{"actors":[],"pickups":[],"t":0}})
	check(s.trace_count == 1)
	s.trace_count = s.TRACE_LIMIT - 1
	s.emit_snapshot_trace(false)
	check(s.trace_count == s.TRACE_LIMIT)
	s.emit_snapshot_trace(false)
	check(s.trace_count == s.TRACE_LIMIT)
	s.free()
	print("PORT_NATIVE_TRACE_TEST checks=",checks," failures=",failures)
	quit(1 if failures else 0)
