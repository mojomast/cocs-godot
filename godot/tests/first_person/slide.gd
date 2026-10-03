extends SceneTree
const Rig = preload("res://first_person/rig.gd")
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	var rig := Rig.new()
	root.add_child(rig)
	rig.attach_to(camera)
	rig.set_process(false)
	var actor := {"id":7,"weapon":0,"health":100,"grounded":true,"sliding":true,"vx":8,"vz":0}
	var camera_pose := camera.transform
	var fov := camera.fov
	rig.apply_actor(actor, true)
	for frame: int in 60: rig.advance(1.0 / 60.0)
	check(rig.slide_weight > 0.99 and rig.slide_weight <= 1.0, "slide cue converges within its bound")
	check(camera.transform == camera_pose and camera.fov == fov, "slide never writes camera pose or FOV")
	rig.apply_aim(true)
	for frame: int in 120: rig.advance(1.0 / 60.0)
	check(rig.aim_weight == 1.0, "ADS settles completely")
	var aimed: Transform3D = rig.pivot.transform
	rig.slide_weight = 0.0
	rig.advance(0.0)
	check(rig.pivot.transform.is_equal_approx(aimed), "settled ADS removes slide position and cant")
	rig.reduced_motion = true
	rig.advance(0.1)
	check(rig.slide_weight == 0.0, "reduced motion clears slide immediately")
	rig.reduced_motion = false
	for field: String in ["health", "dead", "spectating", "vehicleId"]:
		rig.apply_actor(actor, true)
		rig.advance(0.1)
		var hidden := actor.duplicate()
		hidden[field] = 0 if field == "health" else 1 if field == "vehicleId" else true
		rig.apply_actor(hidden, true)
		check(rig.slide_weight == 0.0 and rig.slide_target == 0.0, "clears slide on " + field)
	rig.apply_actor(actor, true)
	rig.advance(0.1)
	rig.apply_actor(actor, false)
	check(rig.slide_weight == 0.0, "hidden weapon clears slide")
	rig.free()
	camera.free()
	print("FIRST_PERSON_SLIDE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
