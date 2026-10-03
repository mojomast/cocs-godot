extends SceneTree
const Motion = preload("res://first_person/kick_motion.gd")
const Leg = preload("res://first_person/kick_rig.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func event(id: int, time: float, hit: Variant = 8) -> Dictionary:
	return {"type":"melee", "id":id, "time":time, "actor":7, "hit":hit}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var motion := Motion.new()
	check(motion.accept(event(1, 1.0)) and motion.step == 0, "first accepted press starts lead")
	check(not motion.accept(event(1, 1.0)) and motion.accepted == 1, "duplicate cannot restart pose")
	motion.advance(0.3)
	check(not motion.sample().visible, "recovered before legal next press")
	check(motion.accept(event(2, 1.31)) and motion.step == 1, "second accepted press cross")
	check(motion.accept(event(3, 1.62)) and motion.step == 2, "third accepted press heel")
	check(motion.accept(event(4, 2.6)) and motion.step == 0, "timeout resets sequence")
	check(motion.accept(event(5, 2.91, null)) and motion.step == 1, "miss animates current accepted strike")
	check(motion.accept(event(6, 3.22)) and motion.step == 0, "miss breaks next continuation")
	for reason: String in ["reload", "swap", "sprint", "death", "respawn", "home", "focus"]:
		motion.interrupt()
		check(not motion.sample().visible and not motion.continuing, reason + " drains pose and chain")
		check(not motion.accept(event(6, 3.22)), reason + " retains replay watermark")
	motion.advance(NAN)
	motion.advance(-1.0)
	check(motion.age == Motion.DURATION, "bad delta cannot revive pose")
	for rate: int in [30, 60, 144]:
		motion.reset()
		motion.accept(event(1, 0.0))
		for frame: int in rate: motion.advance(1.0 / rate)
		check(motion.age == Motion.DURATION and not motion.sample().visible, "exact settle at any timestep")
	var poses: Array[Vector3] = []
	for strike: int in 3:
		var contact := Motion.pose(strike, Motion.CONTACT)
		poses.append(contact.hip)
		check(contact.weight > 0.99 and contact.knee.x > -0.2, "contact extends knee")
		check(Motion.pose(strike, 0.065).knee.x < -1.0, "chamber compresses knee")
		check(Motion.pose(strike, Motion.DURATION).weapon_position == Vector3.ZERO, "weapon returns exactly")
		check(Motion.pose(strike, Motion.CONTACT, true, true).weapon_position.length() < contact.weapon_position.length(), "reduced motion bounds weight shift")
	check(poses[0] != poses[1] and poses[1] != poses[2], "three distinct contact poses")
	var leg := Leg.new()
	root.add_child(leg)
	leg.build()
	for character: String in Leg.PROFILES:
		leg.apply_identity({"character":character})
		check(leg.identity_key == character and leg.hip.scale.is_finite(), "nine palette/proportion profiles")
		for strike: int in 3:
			leg.apply_pose(Motion.pose(strike, Motion.CONTACT))
			check(leg.toe.global_position.is_finite() and leg.toe.global_position.z < -0.55, "toe projects forward with finite anatomy")
	check(leg.knee.get_parent() == leg.hip and leg.ankle.get_parent() == leg.knee and leg.toe.get_parent() == leg.ankle, "articulation hierarchy")
	for mesh: MeshInstance3D in leg.find_children("*", "MeshInstance3D", true, false): mesh.mesh = null
	leg.free()
	print("KICK_CHAINS_OK checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
