extends SceneTree

const Motion = preload("res://world/remote_motion.gd")
const Presentation = preload("res://world/presentation.gd")
var checks: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		push_error(message)
		quit(1)
		assert(value, message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Synthetic timing fixtures, not recorded packets or latency measurements.
	var motion := Motion.new()
	check(motion.sample(1, 0).is_empty(), "missing actor")
	motion.ingest(1, Vector3.ZERO, deg_to_rad(170), true, 1.0)
	motion.ingest(1, Vector3(2, 0, 0), deg_to_rad(-170), true, 1.1)
	check(motion.sample(1, 1.0).position == Vector3.ZERO, "startup clamps")
	var middle: Dictionary = motion.sample(1, 1.15)
	check(middle.position.is_equal_approx(Vector3(1, 0, 0)), "delayed midpoint")
	check(is_equal_approx(absf(middle.yaw), PI), "shortest yaw path")
	check(motion.sample(1, 2).position == Vector3(2, 0, 0), "stall holds; no extrapolation")
	motion.ingest(1, Vector3(7, 0, 0), 0, true, 1.05)
	motion.ingest(1, Vector3(7, 0, 0), 0, true, 1.1)
	check(motion.tracks[1].size() == 2, "stale and duplicate timestamps rejected")
	motion.ingest(1, Vector3(30, 0, 0), 0, true, 1.2)
	check(motion.sample(1, 1.2).position == Vector3(30, 0, 0), "teleport snaps")
	motion.ingest(1, Vector3(31, 0, 0), 0, false, 1.3)
	check(motion.tracks[1].size() == 1, "death flushes history")
	motion.ingest(1, Vector3(32, 0, 0), 0, true, 1.4)
	check(motion.sample(1, 1.4).position == Vector3(32, 0, 0), "respawn snaps")
	for i: int in range(100):
		motion.ingest(2, Vector3(i, 0, 0), 0, true, 2.0 + i * 0.03)
	check(motion.tracks[2].size() == Motion.MAX_SAMPLES, "bounded memory")
	motion.clear()
	check(motion.tracks.is_empty(), "reset")
	var view := Presentation.new()
	root.add_child(view)
	view.interpolate_remote = true
	var actor: Dictionary = {"id":1,"x":0.0,"y":0.0,"z":0.0,"dead":0.0}
	view.apply_state({"actors":[actor]}, 1)
	actor.x = 3.0
	view.apply_state({"actors":[actor]}, 1)
	check(view.actors[1].position.x == 3.0 and view.eye_position().x == 3.0, "local pose never delayed")
	view.apply_state({"actors":[]}, 1)
	check(view.motion.tracks.is_empty(), "despawn removes history")
	view.apply_state({"actors":[actor]}, 1)
	view.clear_round()
	check(view.motion.tracks.is_empty() and view.actors.is_empty(), "round clears history and nodes")
	view.free()
	print("PORT_REMOTE_MOTION_OK checks=", checks, " synthetic_timing=true authority=unchanged")
	quit(0)
