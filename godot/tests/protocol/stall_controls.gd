extends SceneTree
const Session = preload("res://world/session.gd")
const Network = preload("res://net/client.gd")
class InputProbe extends Network:
	var controls: Dictionary = {}
	func send_input(value: Dictionary) -> Error:
		controls = value.duplicate(true)
		return OK
var checks := 0
func check(ok: bool) -> void:
	checks += 1
	if not ok:
		push_error("Stall integration assertion " + str(checks))
		quit(1)
		assert(ok)
func _initialize() -> void:
	# Drive the actual session process without opening a server or invoking _ready.
	var session := Session.new()
	session.client.free()
	var probe := InputProbe.new()
	session.client = probe
	for node: Node in [session.camera,session.label,session.selector,session.client,session.presentation,session.pickups,session.combat,session.combat_label]: session.add_child(node)
	session.phase = 3
	session.smoke = true
	session.received_pose = true
	session.presentation.apply_state({"actors":[{"id":0,"x":0,"y":0,"z":0,"dead":0}]}, 0)
	session.snapshot_watch.observe()
	session._process(0.02)
	check(probe.controls.fire and probe.controls.z == -1.0)
	session._process(1.1)
	check(not probe.controls.fire and probe.controls.x == 0 and probe.controls.z == 0)
	for action: String in ["jump","reload","sprint","crouch","interact","mobility"]:
		check(not probe.controls[action])
	check("stalled" in session.combat_label.text)
	session.snapshot_watch.observe()
	session._process(0.02)
	check(probe.controls.fire and probe.controls.z == -1.0)
	check(session.combat_label.text.is_empty())
	session.smoke = false
	session.on_error("Synthetic disconnect")
	check(session.snapshot_watch.stale() and session.phase == -1)
	session.free()
	print("PORT_STALL_CONTROLS_OK checks=", checks, " actual_session_process=true synthetic_clock_and_transport=true")
	quit(0)
