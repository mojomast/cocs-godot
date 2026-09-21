extends SceneTree
const Math = preload("res://world/control_math.gd")
const Session = preload("res://world/session.gd")
const Network = preload("res://net/client.gd")
class SessionProbe extends Session:
	var releases: int = 0
	func release_pointer() -> void:
		releases += 1
		super.release_pointer()
class InputProbe extends Network:
	var packets: Array[Dictionary] = []
	var input_result: Error = OK
	func send_input(value: Dictionary) -> Error:
		packets.append(value.duplicate(true))
		return input_result
var checks := 0
var failures := 0
func check(ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("Control safety assertion " + str(checks))
func _initialize() -> void:
	# 1: diagonal/cardinal normalization, cancellation and rotational invariance.
	for angle: float in [0.0, PI/2, -PI, 1.25]:
		for forward: float in [-1.0,0.0,1.0]:
			for right: float in [-1.0,0.0,1.0]:
				var direction := Math.movement(angle,forward,right)
				check(direction.length() <= 1.000001)
				check(is_equal_approx(direction.length(), 0.0 if forward == 0 and right == 0 else 1.0))
	check(Math.movement(0,1,0).is_equal_approx(Vector2(0,-1)))
	check(Math.movement(PI/2,1,0).is_equal_approx(Vector2(-1,0)))
	# 2: nonfinite values cannot poison outgoing movement/look.
	for bad: float in [NAN,INF,-INF]:
		check(Math.movement(bad,1,0) == Vector2.ZERO)
		check(Math.movement(0,bad,0) == Vector2.ZERO)
		check(Math.movement(0,0,bad) == Vector2.ZERO)
		check(Math.look(bad,bad) == Vector2.ZERO)
	# 3: bounded yaw and pitch, including prolonged rotation.
	for angle: float in [-1000000.0,-PI,0.0,PI,1000000.0]:
		var pose := Math.look(angle,angle)
		check(pose.x >= -PI - 0.000001 and pose.x <= PI + 0.000001 and absf(pose.y) <= 1.450001)
		check(absf(sin(pose.x)-sin(angle)) < 0.05)
	var s := Session.new()
	for node: Node in [s.camera,s.label,s.selector,s.client,s.presentation,s.pickups,s.combat,s.combat_label]: s.add_child(node)
	s.phase = 3
	s.received_pose = true
	s.presentation.lifecycle.status = "alive"
	s.snapshot_watch.observe()
	check(s.can_capture_pointer())
	# 4: each capture precondition independently fails closed.
	for phase: int in [-1,0,1,2,4,20]:
		s.phase = phase
		check(not s.can_capture_pointer())
	s.phase = 3
	s.received_pose = false
	check(not s.can_capture_pointer())
	s.received_pose = true
	for status: String in ["waiting","dead","results"]:
		s.presentation.lifecycle.status = status
		check(not s.can_capture_pointer())
	s.presentation.lifecycle.status = "alive"
	# 5: stale mouse motion is ignored and fresh motion resumes.
	s.yaw = 0.5
	s.snapshot_watch.advance(1.0)
	check(not s.can_capture_pointer())
	s.update_look(Vector2(100,100))
	check(s.yaw == 0.5 and s.pitch == 0)
	s.snapshot_watch.observe()
	s.update_look(Vector2(100,100))
	check(is_equal_approx(s.yaw,0.2) and is_equal_approx(s.pitch,-0.3))
	var before := Vector2(s.yaw,s.pitch)
	s.update_look(Vector2(NAN,0))
	check(Vector2(s.yaw,s.pitch) == before)
	# 6: invalid clocks do not change process timers or handshake state.
	for bad: float in [NAN,INF,-INF,-1.0]:
		s.phase = 1
		s.phase_elapsed = 2
		s.watched_phase = 1
		check(not s.advance_handshake(bad))
		s._process(bad)
		check(s.phase_elapsed == 2 and s.elapsed == 0 and s.phase == 1)
	# 7: missing local actors invalidate the pose latch and send accumulator.
	s.phase = 3
	s.received_pose = true
	s.send_elapsed = 0.01
	s.on_snapshot({"state":{"actors":[],"pickups":[],"t":0}})
	check(not s.received_pose and s.send_elapsed == 0)
	check(not s.can_capture_pointer())
	# 8: repeated mixed safety transitions remain bounded and deterministic.
	for i in range(1000):
		s.phase = 3
		s.received_pose = true
		s.presentation.lifecycle.status = "alive"
		s.snapshot_watch.observe()
		s.update_look(Vector2(10000,-10000))
		check(is_finite(s.yaw) and absf(s.yaw) <= PI and absf(s.pitch) <= 1.450001)
		s.snapshot_watch.advance(2)
		before = Vector2(s.yaw,s.pitch)
		s.update_look(Vector2(100,100))
		check(Vector2(s.yaw,s.pitch) == before)
	s.free()
	# Missing poses must keep neutral packets flowing, never retain held controls.
	var pending := SessionProbe.new()
	pending.client.free()
	var probe := InputProbe.new()
	pending.client = probe
	for node: Node in [pending.camera,pending.label,pending.selector,probe,pending.presentation,pending.pickups,pending.combat,pending.combat_label]: pending.add_child(node)
	pending.phase = 3
	pending.smoke = true
	pending.presentation.lifecycle.status = "alive"
	pending.snapshot_watch.observe()
	pending.received_pose = true
	pending._process(1.0 / 60.0)
	check(probe.packets.size() == 1 and probe.packets[0].fire)
	pending.received_pose = false
	for i in range(3): pending._process(1.0 / 60.0)
	check(probe.packets.size() == 4)
	for packet: Dictionary in probe.packets.slice(1):
		check(packet.x == 0 and packet.z == 0)
		for action: String in ["fire","jump","reload","sprint","crouch","interact","mobility"]:
			check(not packet[action])
	pending.received_pose = true
	pending._process(1.0 / 60.0)
	check(probe.packets.size() == 5 and probe.packets.back().fire)
	pending.phase = 4
	pending._process(1.0 / 60.0)
	check(probe.packets.size() == 5)
	# Repeated absent-actor snapshots cannot starve neutral sends at high FPS.
	pending.phase = 3
	pending.smoke = false
	pending.received_pose = false
	for fps: int in [30,60,120,240]:
		probe.packets.clear()
		pending.send_elapsed = 0
		for tick in range(fps):
			pending.on_snapshot({"state":{"actors":[],"pickups":[],"t":tick}})
			pending._process(1.0 / fps)
		check(probe.packets.size() >= mini(fps,60) - 1)
		check(probe.packets.size() <= mini(fps,60))
		for packet: Dictionary in probe.packets:
			check(packet.x == 0 and packet.z == 0 and not packet.fire)
	# Long frames emit one current packet rather than replaying a backlog.
	probe.packets.clear()
	pending._process(5.0)
	check(probe.packets.size() == 1)
	check(pending.send_elapsed < 1.0 / 60.0)
	# Lobby identity changes must invalidate the previous actor's control pose.
	pending.smoke = true
	for actor_id: int in [7, 0, -1, 12]:
		pending.pose_actor_id = 99
		pending.received_pose = true
		pending.presentation.lifecycle.status = "alive"
		pending.snapshot_watch.observe()
		pending.client.actor_id = actor_id
		pending.send_elapsed = 0.01
		pending.on_lobby({})
		check(not pending.received_pose)
		check(not pending.can_capture_pointer())
		check(pending.send_elapsed == 0.0)
		probe.packets.clear()
		pending._process(1.0 / 60.0)
		check(probe.packets.size() == 1)
		check(not probe.packets.back().fire and probe.packets.back().x == 0 and probe.packets.back().z == 0)
		pending.send_elapsed = 0.01
		pending.on_lobby({})
		check(pending.send_elapsed == 0.01) # Repeated rosters cannot starve neutral sends.
	# A fresh pose binds to the new identity and reseeds look; unchanged rosters preserve it.
	pending.smoke = false
	pending.on_snapshot({"state":{"actors":[{"id":12,"x":0,"y":0,"z":0,"yaw":0.7,"pitch":0.2,"dead":0}],"pickups":[],"t":500}})
	check(pending.received_pose and pending.pose_actor_id == 12)
	check(is_equal_approx(pending.yaw,0.7) and is_equal_approx(pending.pitch,0.2))
	pending.send_elapsed = 0.01
	pending.on_lobby({})
	check(pending.received_pose and pending.send_elapsed == 0.01)
	check(pending.can_capture_pointer())
	# Death releases capture; repeated dead snapshots preserve neutral cadence.
	pending.releases = 0
	probe.packets.clear()
	for tick in range(3):
		pending.on_snapshot({"state":{"actors":[{"id":12,"x":0,"y":0,"z":0,"yaw":0.7,"pitch":0.2,"dead":3-tick}],"pickups":[],"t":501+tick}})
		check(pending.releases == tick + 1)
		check(not pending.can_capture_pointer())
		pending._process(1.0 / 60.0)
		check(probe.packets.size() == tick + 1)
		var packet: Dictionary = probe.packets.back()
		check(packet.x == 0 and packet.z == 0)
		for action: String in ["fire","jump","reload","sprint","crouch","interact","mobility"]:
			check(not packet[action])
	pending.on_snapshot({"state":{"actors":[{"id":12,"x":5,"y":0,"z":7,"yaw":-0.8,"pitch":-0.1,"dead":0}],"pickups":[],"t":504}})
	check(pending.can_capture_pointer())
	check(pending.releases == 3)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	check(is_equal_approx(pending.yaw,-0.8) and is_equal_approx(pending.pitch,-0.1))
	pending._process(1.0 / 60.0)
	check(not probe.packets.back().fire and probe.packets.back().x == 0 and probe.packets.back().z == 0)
	# A detected snapshot stall releases once; recovery must not recapture.
	pending.releases = 0
	pending.snapshot_watch.observe()
	pending._process(0.01)
	check(pending.releases == 0)
	pending._process(1.0)
	check(pending.snapshot_watch.stale())
	check(pending.releases == 1)
	check(not pending.can_capture_pointer())
	for tick in range(3):
		pending._process(1.0 / 60.0)
		check(pending.releases == 1)
		check(not probe.packets.back().fire and probe.packets.back().x == 0 and probe.packets.back().z == 0)
	pending.on_snapshot({"state":{"actors":[{"id":12,"x":5,"y":0,"z":7,"yaw":-0.8,"pitch":-0.1,"dead":0}],"pickups":[],"t":505}})
	check(pending.can_capture_pointer())
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	pending._process(1.0 / 60.0)
	check(pending.releases == 1)
	check(not probe.packets.back().fire and probe.packets.back().x == 0 and probe.packets.back().z == 0)
	pending._process(1.0)
	check(pending.releases == 2)
	# Authoritative starts may arrive without a preceding local results screen.
	# Every start must release capture and invalidate the old control pose.
	for prior_phase: int in [3,4,20]:
		pending.phase = prior_phase
		pending.received_pose = true
		pending.send_elapsed = 0.01
		pending.moved = true
		pending.fired = true
		var releases_before := pending.releases
		var starts_before := pending.round_starts
		pending.on_started({})
		check(pending.releases == releases_before + 1)
		check(pending.round_starts == starts_before + 1 and pending.phase == 3)
		check(not pending.received_pose and not pending.can_capture_pointer())
		check(pending.send_elapsed == 0 and not pending.moved and not pending.fired)
		check(pending.presentation.lifecycle.status == "waiting")
		pending._process(1.0 / 60.0)
		check(not probe.packets.back().fire and probe.packets.back().x == 0 and probe.packets.back().z == 0)
		pending.on_snapshot({"state":{"actors":[{"id":12,"x":1,"y":0,"z":2,"yaw":0.4,"pitch":0.1,"dead":0}],"pickups":[],"t":1}})
		check(pending.can_capture_pointer())
		check(is_equal_approx(pending.yaw,0.4) and is_equal_approx(pending.pitch,0.1))
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
		pending._process(1.0 / 60.0)
		check(not probe.packets.back().fire and probe.packets.back().x == 0 and probe.packets.back().z == 0)
	pending._process(1.0)
	# Queue failures must end the session, including neutral sends during stalls.
	probe.input_result = ERR_CONNECTION_ERROR
	pending._process(1.0 / 60.0)
	check(pending.phase == -1)
	check(not pending.received_pose)
	check(not pending.can_capture_pointer())
	check("Input could not be queued" in pending.label.text)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	var failed_packet_count := probe.packets.size()
	pending._process(1.0)
	check(probe.packets.size() == failed_packet_count)
	pending.free()
	if failures > 0:
		quit(1)
		return
	print("PORT_CONTROL_SAFETY_OK checks=",checks," synthetic=true parts=8")
	quit(0)
