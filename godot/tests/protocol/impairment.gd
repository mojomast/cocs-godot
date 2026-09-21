extends SceneTree
const Motion = preload("res://world/remote_motion.gd")
var checks := 0
func check(ok: bool) -> void:
	checks += 1
	if not ok:
		push_error("Impairment assertion " + str(checks))
		quit(1)
		assert(ok)
func _initialize() -> void:
	var motion := Motion.new()
	# Deterministic synthetic delivery schedule: dropped snapshots, bursts,
	# stale delivery, and a long outage. Not a real network benchmark.
	var clock := 0.0
	var latest := Vector3.ZERO
	for i: int in range(600):
		clock += 0.016
		if i % 11 != 0 and not (i > 200 and i < 320):
			latest = Vector3(clock * 0.5, 0, 0)
			motion.ingest(1, latest, clock, true, clock)
			motion.ingest(1, Vector3(999, 0, 0), 0, true, clock - 0.1)
			motion.ingest(1, Vector3(999, 0, 0), 0, true, clock)
		var pose: Dictionary = motion.sample(1, clock)
		if pose.is_empty(): continue
		check(pose.position.is_finite() and is_finite(pose.yaw))
		check(pose.position.x <= latest.x + 0.00001 and pose.position.x >= 0)
		check(motion.tracks[1].size() <= Motion.MAX_SAMPLES)
	var saved: Array = motion.tracks[1].duplicate(true)
	motion.ingest(1, Vector3(NAN, 0, 0), 0, true, clock + 1)
	motion.ingest(1, Vector3.ZERO, INF, true, clock + 1)
	motion.ingest(1, Vector3.ZERO, 0, true, NAN)
	check(motion.tracks[1] == saved)
	motion.ingest(2, Vector3(INF, 0, 0), 0, true, 0)
	check(not motion.tracks.has(2))
	check(motion.sample(1, clock + 100).position == latest)
	motion.clear()
	check(motion.tracks.is_empty())
	print("PORT_IMPAIRMENT_OK checks=", checks, " synthetic_delivery=true no_network_benchmark=true")
	quit(0)
