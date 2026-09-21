extends SceneTree
const Session = preload("res://world/session.gd")
const Network = preload("res://net/client.gd")
class Probe extends Network:
	var frames: Array[Dictionary] = []
	var result: Error = OK
	func send_frame(frame: Dictionary) -> Error:
		frames.append(frame)
		return result
var checks := 0
var failures := 0
func check(value: bool) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("Guest assertion " + str(checks))
func _initialize() -> void:
	var s := Session.new()
	s.client.free()
	var p := Probe.new()
	s.client = p
	for node: Node in [s.camera,s.label,s.selector,s.client,s.presentation,s.pickups,s.combat,s.combat_label]: s.add_child(node)
	s.begin_room()
	check(s.phase == 1 and p.frames[-1].type == "create")
	s.join_room_id = "approved-room"
	s.begin_room()
	check(s.phase == 10 and p.frames[-1].type == "join" and p.frames[-1].roomId == "approved-room")
	var count := p.frames.size()
	s.on_lobby({})
	check(s.phase == 11 and p.frames.size() == count)
	s.on_lobby({"config":{}})
	check(s.phase == 11 and p.frames.size() == count)
	check(s.advance_handshake(119.0))
	check(not s.advance_handshake(1.0) and s.phase == -1)
	s.phase = 10
	check(not s.advance_handshake(15.0) and s.phase == -1)
	s.phase = 11
	s.on_started({})
	check(s.phase == 3 and s.round_starts == 1 and not s.received_pose)
	s.phase = 4
	s.request_restart()
	check(s.phase == 4 and p.frames.size() == count)
	p.result = ERR_CONNECTION_ERROR
	s.begin_room()
	check(s.phase == -1)
	s.free()
	print("PORT_GUEST_SESSION checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
