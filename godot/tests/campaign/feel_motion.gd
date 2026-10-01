extends SceneTree
const Motion = preload("res://world/local_motion.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	var measurements: Array[Dictionary] = []
	for irregular: bool in [false, true]:
		var legacy := Motion.new()
		var campaign := Motion.new()
		var packets: Array[Dictionary] = []
		for i: int in range(61):
			var source := i * 0.05
			var delay := 0.0
			if irregular and i % 8 == 4: delay = 0.085
			if irregular and i % 8 == 5: delay = 0.035
			packets.append({"source":source, "arrival":source + delay})
		var cursor := 0
		var last_new := 0.0
		var last_old := 0.0
		var peak_new := 0.0
		var peak_old := 0.0
		for frame: int in range(361):
			var now := frame / 120.0
			while cursor < packets.size() and float(packets[cursor].arrival) <= now:
				var source: float = packets[cursor].source
				var eye := Vector3(source * 8.6, 1.6, 0)
				# Distinct receive microseconds reproduce draining a WS frame batch.
				var receive := now + cursor * 0.000001
				legacy.ingest(eye, true, receive)
				campaign.ingest(eye, true, receive, source, Vector3(8.6, 0, 0))
				cursor += 1
			var new_x: float = campaign.sample(now).x
			var old_x: float = legacy.sample(now).x
			if frame > 30:
				peak_new = maxf(peak_new, absf(new_x - last_new) * 120.0)
				peak_old = maxf(peak_old, absf(old_x - last_old) * 120.0)
			last_new = new_x; last_old = old_x
		check(peak_new < 15.0, "bounded campaign speed under jitter")
		if irregular: check(peak_new < peak_old, "simulation velocity removes receive-batch surge")
		measurements.append({"irregular":irregular, "legacy_peak_mps":peak_old, "campaign_peak_mps":peak_new})
	var m := Motion.new()
	m.ingest(Vector3.ZERO, true, 0, 0, Vector3(8, 0, 0))
	m.ingest(Vector3(0.4, 0, 0), true, .05, .05, Vector3(8, 0, 0))
	m.ingest(Vector3(0.8, 0, 0), true, .05, .1, Vector3(8, 0, 0))
	check(is_equal_approx(m._eye.x, 0.8), "same-arrival advancing snapshot is retained")
	m.ingest(Vector3(100, 0, 0), true, .06, .05, Vector3(8, 0, 0))
	check(is_equal_approx(m._eye.x, 0.8), "old simulation snapshot cannot teleport camera")
	m.ingest(Vector3(0.9, .2, 0), true, .1, .15, Vector3.ZERO)
	check(is_equal_approx(m.sample(.15).x, .9), "collision stops horizontal extrapolation immediately")
	check(m.sample(.15).y <= .2, "step height settles without overshoot")
	m.ingest(Vector3(20, 3, 0), true, .2, .2, Vector3.ZERO)
	check(m.sample(.2) == Vector3(20, 3, 0), "legitimate large correction resets")
	m.ingest(Vector3(20, 3, 0), false, .3, .3, Vector3.ZERO)
	check(m.sample(.4) == Vector3(20, 3, 0), "death anchors pose")
	m.reset();check(not m.ready(), "epoch reset discards history")
	print("CAMPAIGN_FEEL_MOTION ", JSON.stringify(measurements))
	quit(0 if failures.is_empty() else 1)
