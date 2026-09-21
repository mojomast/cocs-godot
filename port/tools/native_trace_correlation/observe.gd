extends SceneTree
# Adapted from guest_session_integration/observe.gd at 389561510ac7c2223a22897c963f3440304ec928.
# Passive signals run after the shipped session handler; no runtime overrides or input injection.
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
	session.client.started.connect(func(frame: Dictionary):
		print("CORRELATION_OBSERVE " + JSON.stringify({"event":"start", "mapId":frame.mapId,"roundRevision":frame.get("roundRevision"),"actor":session.client.actor_id})))
	session.client.snapshot.connect(func(frame: Dictionary):
		var actor: Dictionary = {}
		for item: Dictionary in frame.state.actors:
			if int(item.id) == session.client.actor_id: actor = item
		print("CORRELATION_OBSERVE " + JSON.stringify({"event":"snapshot","seq":frame.seq,"actor":session.client.actor_id,"ack":session.client.last_ack,"health":actor.get("health"),"dead":actor.get("dead")})))
func _process(delta: float) -> bool:
	elapsed += delta
	sample_elapsed += delta
	if is_instance_valid(session) and sample_elapsed >= 0.5:
		sample_elapsed = 0.0
		print("GUEST_SAMPLE " + JSON.stringify({"seconds":elapsed,"phase":session.phase,"phase_seconds":session.phase_elapsed,"snapshots":session.presentation.applied,"ack":session.client.last_ack,"actor":session.client.actor_id,"pose":session.received_pose,"starts":session.round_starts,"error":session.label.text if session.phase == -1 else ""}))
	if elapsed > 12.0:
		quit(0)
	return false
