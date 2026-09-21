extends SceneTree
const Session = preload("res://world/session.gd")
const Network = preload("res://net/client.gd")
class Probe extends Network:
	var result: Error = ERR_BUSY
	var sent: Array = []
	func send_frame(frame: Dictionary) -> Error:
		sent.append(frame.duplicate(true))
		return result
class FocusSession extends Session:
	var releases := 0
	func release_pointer() -> void:
		releases += 1
var checks := 0
func check(ok: bool) -> void:
	checks += 1
	if not ok:
		push_error("Session recovery assertion " + str(checks))
		quit(1)
		assert(ok)
func make_session() -> Session:
	var s := FocusSession.new()
	s.client.free()
	s.client = Probe.new()
	for node: Node in [s.camera,s.label,s.selector,s.client,s.presentation,s.pickups,s.combat,s.combat_label]: s.add_child(node)
	return s
func _initialize() -> void:
	var s := make_session()
	var p: Probe = s.client
	s.phase = 4
	s.request_restart()
	check(s.phase == 4 and "retry" in s.label.text)
	check(p.sent == [{"type":"start"}])
	p.result = OK
	s.request_restart()
	check(s.phase == 20 and "Waiting" in s.label.text)
	s.request_restart()
	check(p.sent.size() == 2)
	for phase: int in [-1,0,1,2,3,20]:
		s.phase = phase
		s.request_restart()
		check(p.sent.size() == 2)
	s.phase = 4
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	key.echo = true
	s._unhandled_input(key)
	check(p.sent.size() == 2 and s.phase == 4)
	key.echo = false
	s._unhandled_input(key)
	check(p.sent.size() == 3 and s.phase == 20)
	s._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(s.releases == 1)
	s._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(s.releases == 1)
	key.keycode = KEY_ESCAPE
	s._unhandled_input(key)
	check(s.releases == 2)
	s.free()
	for phase: int in [0,1,2,20]:
		s = make_session()
		s.phase = phase
		check(s.advance_handshake(14.0))
		check(s.phase == phase)
		check(not s.advance_handshake(1.0))
		check(s.phase == -1 and "timed out" in s.label.text)
		check(s.presentation.actors.is_empty() and s.client.actor_id == -1)
		s.free()
	s = make_session()
	s.phase = 1
	check(s.advance_handshake(14.0))
	s.phase = 2
	check(s.advance_handshake(14.0))
	check(s.phase == 2)
	for phase: int in [3,4,-1]:
		s.phase = phase
		check(s.advance_handshake(100.0) and s.phase == phase)
	s.free()
	for succeeds: bool in [false,true]:
		s = make_session()
		p = s.client
		p.result = OK if succeeds else ERR_BUSY
		s.current_id = "meridian-exchange"
		p.requested_map = s.current_id
		p.allowlist = {"meridian-exchange":{"modes":["deathmatch"]}}
		s.phase = 1
		s.on_lobby({})
		check(s.phase == (2 if succeeds else -1))
		check(p.sent.size() == 1 and p.sent[0].type == "host")
		if succeeds:
			s.on_lobby({})
			check(s.phase == 2 and p.sent.size() == 1)
		s.free()
		s = make_session()
		p = s.client
		p.result = OK if succeeds else ERR_BUSY
		s.phase = 2
		s.on_lobby({"config":{}})
		check(s.phase == (20 if succeeds else -1))
		check(p.sent == [{"type":"start"}])
		s.on_lobby({"config":{}})
		check(p.sent.size() == 1)
		s.free()
	print("PORT_SESSION_RECOVERY_OK checks=",checks," synthetic_transport_clock_focus=true")
	quit(0)
