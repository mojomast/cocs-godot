extends SceneTree
const Math = preload("res://world/control_math.gd")
const Session = preload("res://world/session.gd")
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
	if failures > 0:
		quit(1)
		return
	print("PORT_CONTROL_SAFETY_OK checks=",checks," synthetic=true parts=8")
	quit(0)
