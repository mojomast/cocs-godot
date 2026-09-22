extends SceneTree
const Session = preload("res://world/session.gd")
const Network = preload("res://net/client.gd")
class Probe extends Network:
	var sent: Array = []
	func send_frame(frame: Dictionary) -> Error:
		sent.append(frame.duplicate(true))
		return OK
var checks := 0
func check(ok: bool) -> void:
	checks += 1
	if not ok:
		push_error("Lobby synthetic check %d" % checks)
		quit(1)
		assert(ok)
func make_session() -> Session:
	var s := Session.new()
	s.client.free()
	s.client = Probe.new()
	for node: Node in [s.camera,s.label,s.selector,s.environment,s.sun,s.client,s.presentation,s.pickups,s.combat,s.combat_label]: s.add_child(node)
	s.lobby_enabled = true
	s.current_id = "meridian-exchange"
	s.catalog.entries = {s.current_id:{"modes":["deathmatch","teamdeathmatch","rockets"]}}
	s.client.allowlist = s.catalog.entries
	s.client.requested_map = s.current_id
	return s
func _initialize() -> void:
	var s := make_session()
	var p: Probe = s.client
	var frame := {"hostId":7,"config":{"mode":"deathmatch"},"players":[{"peerId":7,"connected":true,"spectate":false,"actorId":null}]}
	p.peer_id = 7
	s.phase = 1
	s.on_lobby({"hostId":7,"players":frame.players})
	check(s.phase == 2 and p.sent.size() == 1 and p.sent[0].type == "host")
	s.on_lobby(frame)
	check(s.phase == 12 and p.sent.size() == 1)
	check(s.lobby_host_allowed())
	s.lobby_start()
	check(s.phase == 20 and p.sent[-1].type == "start")
	s.lobby_start()
	check(p.sent.size() == 2)
	s.on_started({})
	check(s.phase == 3 and not s.received_pose and s.round_starts == 1)
	s.phase = 4
	s.request_restart()
	check(s.phase == 20 and p.sent.size() == 3)
	s.join_room_id = "guest-room"
	s.phase = 10
	p.sent.clear()
	s.on_lobby(frame)
	check(s.phase == 11 and p.sent.is_empty() and not s.lobby_host_allowed())
	check(s.advance_handshake(1000) and s.phase == 11)
	s.lobby_start()
	s.phase = 4
	s.request_restart()
	check(p.sent.is_empty())
	for i: int in range(3):
		p.actor_id = 8
		s.pose_actor_id = 8
		s.received_pose = true
		s.weapon_selection.pending = 2
		s.lobby_leave()
		check(s.phase == -3 and p.actor_id == -1 and s.pose_actor_id == -1)
		check(not s.received_pose and s.weapon_selection.pending == -1)
		check(s.presentation.actors.is_empty() and s.pickups.markers.is_empty())
		check(p.sent[-1].type == "leave")
		s.on_started({})
		s.on_lobby(frame)
		check(s.phase == -3 and s.lobby_roster.is_empty())
		check(not s.can_capture_pointer())
	s.lobby_connect("http://bad", "Tester", "", s.current_id, "deathmatch", false)
	check(s.phase == -1 and "ws://" in s.label.text)
	s.lobby_connect("ws://127.0.0.1:1", "Tester", "", s.current_id, "deathmatch", true)
	check(s.phase == -1 and "room code" in s.label.text)
	s.lobby_connect("ws://127.0.0.1:1", "Tester", "", "unknown", "deathmatch", false)
	check(s.phase == -1 and "Unknown" in s.label.text)
	p.room_id = "joined-room"
	s.phase = 11
	s.on_error("Lobby map substitution")
	check(p.sent[-1].type == "leave" and p.room_id.is_empty() and s.phase == -1)
	check(s.label.text == "Lobby map substitution")
	s.free()
	print("PORT_LOBBY_FLOW_OK checks=",checks," synthetic=true")
	quit(0)
