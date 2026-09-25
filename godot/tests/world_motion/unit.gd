extends SceneTree

const Motion = preload("res://world/local_motion.gd")
var checks: int = 0
var failed: bool = false

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		failed = true

func near(a: Vector3, b: Vector3, tolerance: float = 0.0001) -> bool:
	return a.distance_to(b) <= tolerance

func _initialize() -> void:
	var motion := Motion.new()
	check(not motion.ready() and motion.sample(0.0) == Vector3.ZERO, "empty motion is not ready")
	motion.ingest(Vector3.ZERO, true, 0.0)
	check(motion.ready(), "first valid snapshot is ready")
	var previous: Vector3 = motion.sample(0.0)
	var progressed: int = 0
	var largest_step: float = 0.0
	for frame: int in range(1, 121):
		var now: float = float(frame) / 120.0
		if frame % 2 == 0:
			var before_packet: Vector3 = motion.sample(now)
			motion.ingest(Vector3(10.0 * now, 0.0, 0.0), true, now)
			check(near(before_packet, motion.sample(now)), "regular packet must preserve visual continuity")
		else:
			if motion.sample(now).x > previous.x + 0.001:
				progressed += 1
		var rendered: Vector3 = motion.sample(now)
		largest_step = maxf(largest_step, rendered.distance_to(previous))
		previous = rendered
	check(progressed >= 55, "render subframes move between 60Hz snapshots")
	check(largest_step < 0.14, "packet cadence must not cause visible jumps or rubber-band")
	check(absf(motion.sample(1.0).x - 10.0) < 0.02, "steady motion tracks the source")
	# A 60 Hz authority can deliver two snapshots in one rendered frame. Arrival
	# timestamps are almost equal, but the source positions remain 16.7 ms apart.
	# The local-only Horde clock must not turn that burst into a 40 m/s camera kick.
	var burst := Motion.new()
	burst.ingest(Vector3.ZERO, true, 0.0, 0.0)
	burst.ingest(Vector3(0.12, 0.0, 0.0), true, 0.016, 1.0 / 60.0)
	burst.ingest(Vector3(0.24, 0.0, 0.0), true, 0.050, 2.0 / 60.0)
	burst.ingest(Vector3(0.36, 0.0, 0.0), true, 0.0501, 3.0 / 60.0)
	check(burst.sample(0.0501).is_finite(), "burst preserves a finite pose")
	check(burst.sample(0.0581).x - burst.sample(0.0501).x < 0.12,
		"source-paced Horde burst does not surge at receive-clock velocity")
	burst.ingest(Vector3(0.37, 0.0, 0.0), true, 0.0502, 3.0 / 60.0)
	check(burst.sample(0.0582).x - burst.sample(0.0502).x < 0.12,
		"duplicate source tick never falls back to a tiny receive interval")
	burst.ingest(Vector3(0.37, 0.0, 0.0), true, 0.0667, 4.0 / 60.0)
	check(burst.sample(0.4).distance_to(Vector3(0.37, 0.0, 0.0)) < 0.01,
		"Horde burst settles on the source eye without a lasting offset")
	var gap := Motion.new()
	gap.ingest(Vector3.ZERO, true, 0.0)
	gap.ingest(Vector3(0.16, 0.0, 0.0), true, 0.016)
	check(gap.sample(0.066).x > gap.sample(0.025).x, "short packet gap extrapolates")
	check(near(gap.sample(0.5), gap.sample(0.6), 0.001), "prediction is capped at 50ms and correction settles")
	var before_stop: Vector3 = motion.sample(1.0 + 1.0 / 60.0)
	motion.ingest(Vector3(10.0, 0.0, 0.0), true, 1.0 + 1.0 / 60.0)
	check(near(motion.sample(1.0 + 1.0 / 60.0), before_stop), "stationary correction begins at prior visual path")
	for i: int in range(2, 20):
		var now: float = 1.0 + float(i) / 60.0
		motion.ingest(Vector3(10.0, 0.0, 0.0), true, now)
		check(motion.sample(now).is_finite(), "stationary track remains finite")
	check(motion.sample(1.4).distance_to(Vector3(10.0, 0.0, 0.0)) < 0.01, "stationary visual converges to authoritative eye")
	check(near(motion.sample(1.5), motion.sample(2.0), 0.001), "extrapolation remains bounded after packets stop")

	motion.ingest(Vector3(100.0, 2.0, 0.0), true, 2.1)
	check(near(motion.sample(2.1), Vector3(100.0, 2.0, 0.0)), "teleport snaps without old correction")
	check(near(motion.sample(2.2), Vector3(100.0, 2.0, 0.0)), "teleport clears old velocity")
	motion.ingest(Vector3(101.0, 2.0, 0.0), true, 2.2)
	motion.ingest(Vector3(101.0, 2.0, 0.0), false, 2.21)
	check(near(motion.sample(2.25), Vector3(101.0, 2.0, 0.0)), "death clears extrapolation and correction")
	motion.ingest(Vector3(7.0, 0.0, 1.0), true, 2.3)
	check(near(motion.sample(2.35), Vector3(7.0, 0.0, 1.0)), "respawn has no ghost motion")
	motion.reset()
	check(not motion.ready() and motion.sample(3.0) == Vector3.ZERO, "reset discards the visual track")
	motion.ingest(Vector3(2.0, 3.0, 4.0), true, 3.0)
	motion.ingest(Vector3(NAN, 0.0, 0.0), true, 3.1)
	motion.ingest(Vector3(999.0, 0.0, 0.0), true, NAN)
	motion.ingest(Vector3(999.0, 0.0, 0.0), false, 2.0)
	check(near(motion.sample(3.1), Vector3(2.0, 3.0, 4.0)), "invalid and stale snapshots are ignored")
	check(motion.sample(NAN).is_finite() and near(motion.sample(NAN), Vector3(2.0, 3.0, 4.0)), "invalid render time cannot poison output")
	if failed:
		quit(1)
	else:
		print("WORLD_MOTION_UNIT_OK checks=", checks)
		quit()
