extends SceneTree
## Run with --headless --path godot --script res://tests/world_motion/ordinary_modes.gd
const Motion = preload("res://world/local_motion.gd")
const Inertia = preload("res://first_person/inertia.gd")
const SprintFov = preload("res://first_person/sprint_fov.gd")
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		push_error(label)

func _initialize() -> void:
	var motion := Motion.new()
	motion.ingest(Vector3.ZERO, true, 0.0, 0.0, Vector3(8, 0, 0))
	motion.ingest(Vector3(0.4, 0, 0), true, 0.05, 0.05, Vector3(8, 0, 0))
	var before: Vector3 = motion.sample(0.0501)
	motion.ingest(Vector3(0.8, 0, 0), true, 0.0501, 0.1, Vector3(8, 0, 0))
	check(motion.sample(0.0501).distance_to(before) < 0.001, "batch keeps continuous camera pose")
	check(motion.sample(0.0581).x - motion.sample(0.0501).x < 0.12, "batch has no receive-clock surge")
	motion.ingest(Vector3(0.9, 0, 0), true, 0.06, 0.05, Vector3(8, 0, 0))
	check(motion._eye.x == 0.8, "older simulation tick cannot rewind")
	motion.ingest(Vector3(30, 0, 0), true, 0.1, 0.15, Vector3.ZERO)
	check(motion.sample(0.1) == Vector3(30, 0, 0), "teleport reseeds immediately")
	motion.ingest(Vector3(31, 0, 0), false, 0.2, 0.2, Vector3.ZERO)
	check(motion.sample(0.3) == Vector3(31, 0, 0), "death has no predicted motion")
	motion.reset()
	check(not motion.ready(), "epoch reset drops motion history")
	var sway := Inertia.new()
	var actor := {"x":0.0, "y":0.0, "z":0.0, "vx":0.0, "vy":0.0, "vz":0.0, "grounded":true, "health":100.0}
	sway.observe(actor, Basis.IDENTITY)
	actor.vx = 8.0
	actor.x = 0.13
	sway.observe(actor, Basis.IDENTITY)
	for i: int in 30: sway.advance(1.0 / 120.0, false)
	var moving: Dictionary = sway.advance(1.0 / 120.0, false)
	check(absf(moving.rotation.z) > 0.002, "source strafe velocity adds bounded weapon lean")
	check(absf(moving.rotation.z) < 0.02, "lean stays within comfort bound")
	var quiet: Dictionary = sway.advance(1.0 / 120.0, true)
	check(quiet.position == Vector3.ZERO and quiet.rotation == Vector3.ZERO, "reduced motion immediately silences weapon sway")
	sway.reset()
	check(sway.strafe_target == 0.0 and sway.advance(0.016, false).rotation == Vector3.ZERO, "reset prevents old strafe carrying to new life")
	var fov := SprintFov.new()
	fov.advance(0.5, true, true, false)
	check(fov.compose(75.0, 0.0) > 77.0 and fov.compose(75.0, 0.0) <= 78.0, "sprint optical cue bounded")
	check(fov.compose(30.0, 1.0) == 30.0, "ADS optics exactly preserve aim FOV")
	fov.advance(0.016, true, true, true)
	check(fov.compose(75.0, 0.0) == 75.0, "reduced motion removes sprint FOV")
	print("ORDINARY_MOTION_OK checks=13 failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
