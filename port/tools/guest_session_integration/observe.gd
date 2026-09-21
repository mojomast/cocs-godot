extends SceneTree
# Harness-only sampler: instantiate the shipped scene, never override its methods.
var session: Node
var elapsed := 0.0
var sample_elapsed := 0.0
func _initialize() -> void:
	call_deferred("begin")
func begin() -> void:
	session = load("res://world/session.tscn").instantiate()
	root.add_child(session)
	if not session.catalog.entries.has("meridian-exchange") or session.current_id != "meridian-exchange":
		push_error("Harness prerequisite: semantic map not loaded")
		quit(3)
func _process(delta: float) -> bool:
	elapsed += delta
	sample_elapsed += delta
	if is_instance_valid(session) and sample_elapsed >= 0.5:
		sample_elapsed = 0.0
		print("GUEST_SAMPLE " + JSON.stringify({"seconds":elapsed,"phase":session.phase,"phase_seconds":session.phase_elapsed,"snapshots":session.presentation.applied,"ack":session.client.last_ack,"actor":session.client.actor_id,"pose":session.received_pose,"starts":session.round_starts,"error":session.label.text if session.phase == -1 else ""}))
	if elapsed > 140.0:
		quit(2)
	return false
