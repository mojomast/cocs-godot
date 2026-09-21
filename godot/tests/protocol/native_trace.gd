extends SceneTree
const Session = preload("res://world/session.gd")
class RecordingSession extends Session:
	var records: Array[Dictionary] = []
	func emit_native_trace(record: Dictionary) -> void:
		if trace_enabled and trace_count < TRACE_LIMIT:
			records.append(record.duplicate(true))
		super.emit_native_trace(record)

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
	var controls := {"x":0.0,"z":0.0,"fire":false,"private":"must not leak"}
	var queued := s.trace_input(controls, OK)
	check(queued.event == "input_queue" and queued.queued and queued.queue_result == OK)
	check(queued.controls.x == 0.0 and not queued.controls.fire)
	check(not JSON.stringify(queued).contains("private"))
	controls.x = 1.0
	check(queued.controls.x == 0.0)
	var rejected := s.trace_input(controls, ERR_CONNECTION_ERROR)
	check(not rejected.queued and rejected.queue_result == ERR_CONNECTION_ERROR)
	check(rejected.actor_id == 7 and rejected.phase == 4)
	s.emit_native_trace(queued)
	check(s.trace_count == 2)
	s.trace_count = s.TRACE_LIMIT - 1
	s.emit_snapshot_trace(false)
	check(s.trace_count == s.TRACE_LIMIT)
	s.emit_snapshot_trace(false)
	check(s.trace_count == s.TRACE_LIMIT)
	s.free()
	var boundary := RecordingSession.new()
	for node: Node in [boundary.camera,boundary.label,boundary.selector,boundary.client,boundary.presentation,boundary.pickups,boundary.combat,boundary.combat_label]: boundary.add_child(node)
	boundary.on_started({})
	check(boundary.records.is_empty() and boundary.trace_count == 0)
	boundary.trace_enabled = true
	boundary.received_pose = true
	boundary.on_started({})
	check(boundary.records.size() == 1 and boundary.trace_count == 1)
	var started: Dictionary = boundary.records.back()
	check(started.event == "round_start" and started.round == 2 and started.phase == 3)
	check(not started.pose_present and not started.pointer_captured and not started.complete)
	boundary.on_error("secret endpoint must not appear in trace")
	check(boundary.records.size() == 2 and boundary.trace_count == 2)
	var failed: Dictionary = boundary.records.back()
	check(failed.event == "session_error" and failed.phase == -1 and not failed.complete)
	check(not failed.pose_present and not failed.pointer_captured)
	check(not JSON.stringify(failed).contains("secret"))
	boundary.trace_count = boundary.TRACE_LIMIT
	boundary.on_started({})
	boundary.on_error("another private error")
	check(boundary.records.size() == 2 and boundary.trace_count == boundary.TRACE_LIMIT)
	boundary.free()
	print("PORT_NATIVE_TRACE_TEST checks=",checks," failures=",failures)
	quit(1 if failures else 0)
