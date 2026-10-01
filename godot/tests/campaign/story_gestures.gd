extends SceneTree
const Gesture = preload("res://campaign/story_gesture.gd")
const Director = preload("res://campaign/story_director.gd")
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		push_error(message)
		quit(1)
		assert(value, message)

func close_pose(a: Dictionary, b: Dictionary, tolerance: float = 0.00001) -> bool:
	for joint: String in Gesture.JOINTS:
		if (a[joint] as Vector3).distance_to(b[joint]) > tolerance: return false
	return true

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for name_: String in ["wave", "point", "work", "walk"]:
		var fine := Gesture.new()
		var coarse := Gesture.new()
		fine.select(name_)
		coarse.select(name_)
		for i: int in range(120): fine.advance(1.0 / 60.0)
		for i: int in range(20): coarse.advance(0.1)
		check(close_pose(fine.sample(), coarse.sample()), "Chunk-invariant " + name_)
		check(is_equal_approx(fine.walk_weight(), coarse.walk_weight()), "Chunk-invariant walking blend")
		fine.advance(2.0)
		check(close_pose(fine.sample(), Gesture.rest()), "Finite gesture settles: " + name_)
		var time_before: float = fine.time
		for invalid: float in [NAN, INF, -1.0, 0.0]: fine.advance(invalid)
		check(fine.time == time_before, "Invalid delta must not poison clock")
	# Interruptions retain the exact current pose, then transition continuously.
	var interrupted := Gesture.new()
	interrupted.select("wave")
	interrupted.advance(0.9)
	var held := interrupted.sample()
	interrupted.select("point")
	check(close_pose(held, interrupted.sample()), "Pose change has no instantaneous joint pop")
	interrupted.advance(1.0 / 60.0)
	check(close_pose(held, interrupted.sample(), 0.015), "Interrupted gesture starts smoothly")
	var director := Director.new()
	root.add_child(director)
	director.set_process(false)
	var entity := {"id":"mara", "kind":"operator", "character":"claude", "name":"Mara", "x":0.0, "y":1.0, "z":0.0, "yaw":0.0, "pose":"wave", "active":true, "reactionSerial":0}
	var story := {"version":1, "entities":[entity], "caption":null, "prompt":null, "completed":[], "pets":0}
	director.apply(story, "rootfall-verge")
	var actor: Node3D = director.actors.mara
	var rig: RefCounted = actor.rig
	var last_hand: Vector3 = actor.nodes.handR.global_position
	var feet_origin: Vector3 = actor.position
	for i: int in range(360):
		# A high-rate authority replay must not restart the one-shot greeting.
		director.apply(story, "rootfall-verge")
		director._process(1.0 / 60.0)
		var gesture: RefCounted = director.gestures.mara
		for joint: String in Gesture.JOINTS:
			var angles: Vector3 = gesture.sample()[joint]
			check(angles.is_finite() and angles.length() < 1.5, "Bounded authored joint: " + joint)
			check(absf(actor.nodes[joint].quaternion.length() - 1.0) < 0.00001, "Normalized absolute joint rotation")
		var hand: Vector3 = actor.nodes.handR.global_position
		check(hand.distance_to(last_hand) < 0.09, "No frame-to-frame hand explosion")
		last_hand = hand
		check(actor.position == feet_origin, "Gesture never displaces authoritative feet/root")
		check(not actor.nodes.weapon.visible and actor.world_weapon == null, "Story performance stays unarmed")
		if i == 59:
			check(hand.x > actor.nodes.head.global_position.x + 0.20, "Greeting palm is outside the face, not rolled inward")
	check(director.gestures.mara.age > 5.9, "Repeated snapshots do not restart the gesture clock")
	check(close_pose(director.gestures.mara.sample(), Gesture.rest()), "Persistent wave snapshot returns to rest")
	# Reapplying absolute poses is idempotent, including parent/child joints.
	var settled: Transform3D = actor.nodes.handR.global_transform
	for i: int in range(100): director.gestures.mara.apply_to(actor)
	check(actor.nodes.handR.global_transform.is_equal_approx(settled), "No cumulative transforms")
	# The actual imported joint hierarchy is also invariant to chunking, including
	# the quiet body/feet gait; a pose does not inherit combat ADS/crouch channels.
	var planted_y: float = actor.nodes.footR.global_position.y
	for name_: String in ["wave", "point", "work", "walk"]:
		var fine := Gesture.new()
		var coarse := Gesture.new()
		fine.select(name_)
		coarse.select(name_)
		for i: int in range(90): fine.advance(1.0 / 60.0)
		for i: int in range(3): coarse.advance(0.5)
		fine.apply_to(actor)
		var expected := {}
		for joint: String in ["root", "head", "handR", "handL", "footR", "footL"]:
			expected[joint] = actor.nodes[joint].global_transform
		coarse.apply_to(actor)
		for joint: String in expected:
			check(actor.nodes[joint].global_transform.is_equal_approx(expected[joint]), "Actual rig chunk invariance: " + name_ + "/" + joint)
		if name_ != "walk":
			check(absf(actor.nodes.footR.global_position.y - planted_y) < 0.00001, "Gesture keeps the same planted sole")
		entity.pose = name_
		director.apply(story, "rootfall-verge")
		check(not actor.snapshot.ads and not actor.snapshot.crouching, "No weapon aiming/crouch leaks into story " + name_)
	# Return to a completed wave before exercising temporary visibility changes.
	entity.pose = "wave"
	director.apply(story, "rootfall-verge")
	director._process(6.0)
	var retained: RefCounted = director.gestures.mara
	entity.active = false
	director.apply(story, "rootfall-verge")
	entity.active = true
	director.apply(story, "rootfall-verge")
	check(director.gestures.mara == retained and retained.age > 5.9, "Temporary absence does not re-wave")
	director.clear_round()
	check(director.gestures.is_empty(), "Chapter cleanup clears gesture controllers")
	director.free()
	print("CAMPAIGN_STORY_GESTURES_OK checks=", checks)
	quit(0)
