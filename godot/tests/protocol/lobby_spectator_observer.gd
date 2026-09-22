extends "res://tests/protocol/lobby_followup_observer.gd"
# Additional passive renderer/role receipts. The inherited driver only injects
# engine input and manages its own window; no handler or authority writes.
var spectator_sampled := 0.0
func begin() -> void:
	super.begin()
	session.client.snapshot.connect(func(frame: Dictionary) -> void:
		var actors: Array = []
		for id: int in session.presentation.actors:
			var node: Node3D = session.presentation.actors[id]
			var track: Array = session.presentation.motion.tracks.get(id,[])
			if track.is_empty(): continue
			var position: Vector3 = track.back().position
			actors.append({"id":id,"ingested":[position.x,position.y,position.z],"rendered":[node.position.x,node.position.y,node.position.z],"visible":node.visible})
		print("SPECTATOR_APPLIED ",JSON.stringify({"seq":frame.seq,"peer":session.client.peer_id,"revision":revision,"spectating":session.client.spectating,"actor":session.client.actor_id,"ack":session.client.last_ack,"local_empty":session.presentation.local_actor.is_empty(),"actors":actors,"rendered_remote_poses":session.presentation.rendered_remote_poses})))
func _process(delta: float) -> bool:
	var result := super._process(delta)
	if elapsed > 115: quit(9)
	if elapsed - spectator_sampled < 0.15 or not is_instance_valid(session): return result
	spectator_sampled = elapsed
	var hud: Node = session.get_node("GameHUD")
	print("SPECTATOR_SAMPLE ",JSON.stringify({"seconds":elapsed,"command":last_command,"revision":revision,"spectating":session.client.spectating,"phase":session.phase,"peer":session.client.peer_id,"actor":session.client.actor_id,"ack":session.client.last_ack,"input_seq":session.client.input_seq,"pose":session.received_pose,"captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"eligible":session.can_capture_pointer(),"title":hud.status_title.text,"detail":hud.status_detail.text,"controls_visible":hud.controls.is_visible_in_tree(),"score":hud.score_label.text,"snapshots":session.presentation.applied,"rendered_remote_poses":session.presentation.rendered_remote_poses,"camera":[session.camera.position.x,session.camera.position.y,session.camera.position.z]}))
	return result
