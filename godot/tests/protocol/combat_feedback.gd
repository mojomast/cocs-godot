extends SceneTree
const Feedback = preload("res://world/combat_feedback.gd")
const Client = preload("res://net/client.gd")
var checks: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		quit(1)
		assert(ok, message)
func _initialize() -> void:
	var feedback := Feedback.new()
	var client := Client.new()
	client.events.connect(func(items: Array) -> void: feedback.apply_events(items, 0))
	# Explicit synthetic packets: exercise actual decoder/dedup plus native meshes.
	var shot: Dictionary = {"id":1,"type":"shot","actor":0,"from":{"x":1,"y":2,"z":3},"to":{"x":4,"y":5,"z":6}}
	var packet: String = JSON.stringify({"type":"events","items":[shot]})
	check(client.decode_text(packet), "decode shot")
	check(feedback.shots == 1 and feedback.tracers.size() == 1, "one tracer")
	check(client.decode_text(packet) and feedback.shots == 1, "duplicate event ignored")
	var mesh: Mesh = feedback.tracers[0].node.mesh
	check(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX][0] == Vector3(1,2,3), "source tracer origin")
	check(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX][1] == Vector3(4,5,6), "source tracer endpoint")
	feedback.apply_events([{"type":"damage","actor":1,"source":0,"amount":20}],0)
	check(feedback.hits == 1 and "HIT" in feedback.text(), "source confirms local hit")
	feedback.apply_events([{"type":"damage","actor":0,"source":null,"amount":10}],0)
	check(feedback.hurts == 1 and feedback.hits == 1, "environmental damage not local hit")
	feedback.apply_events([{"type":"damage","actor":0,"source":0,"amount":10}],0)
	check(feedback.hurts == 2 and feedback.hits == 1, "self damage not hit confirmation")
	feedback.apply_events([{"type":"shot","from":{"x":0},"to":null}],0)
	check(feedback.shots == 1, "malformed geometry skipped")
	for i: int in range(150): feedback.apply_events([shot],0)
	check(feedback.tracers.size() == 128 and feedback.get_child_count() == 128, "bounded tracer storage")
	feedback.advance(0.5)
	check(feedback.tracers.is_empty() and feedback.get_child_count() == 0 and feedback.text().is_empty(), "transient feedback expires")
	feedback.clear_round()
	client.reset_round()
	client.decode_text(packet)
	check(feedback.shots == 1, "round allows reused event identity")
	feedback.clear_round()
	check(feedback.shots == 0 and feedback.hits == 0 and feedback.hurts == 0 and feedback.get_child_count() == 0, "round cleanup")
	# Genuine captured server event output, separately counted from synthetic cases.
	var capture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/protocol/captured.json"))
	for record: Dictionary in capture.frames:
		if record.direction == "server" and record.client == 1 and record.frame.type == "events":
			feedback.apply_events(record.frame.items, 0)
	print("PORT_COMBAT_FEEDBACK_OK synthetic_checks=", checks, " recorded_shots=", feedback.shots, " recorded_hits=", feedback.hits)
	feedback.clear_round()
	feedback.free()
	client.free()
	quit(0)
