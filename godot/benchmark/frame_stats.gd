extends RefCounted
## Bounded wall-clock intervals between real RenderingServer frame_post_draw
## events. Same percentile definition as the particle lab's frame metrics
## (median of the ordered samples, p95 = ordered[ceil(n * 0.95) - 1]) extended
## with per-phase buckets and a hard capacity so a long or very slow run cannot
## grow memory without limit.
##
## These are end-to-end render cadence numbers with the display's buffering
## included: they are not GPU timestamps and not a compute-only profile.
const CAPACITY_PER_PHASE := 6000

var phases: Array = []
var dropped := 0
var total_frames := 0
var _current := 0
var _last_usec := 0
var _recording := false

func configure(names: PackedStringArray, measured: Array) -> void:
	phases.clear()
	for i in range(names.size()):
		phases.append({"name": str(names[i]), "measured": bool(measured[i]) if i < measured.size() else true,
			"samples": [], "size": 0, "cursor": 0, "frames": 0})
	_current = 0
	_last_usec = 0
	_recording = false
	dropped = 0
	total_frames = 0

func reset() -> void:
	for phase: Dictionary in phases:
		phase.samples = []
		phase.size = 0
		phase.cursor = 0
		phase.frames = 0
	_current = 0
	_last_usec = 0
	_recording = false
	dropped = 0
	total_frames = 0

func start() -> void:
	_recording = true
	_last_usec = 0

func stop() -> void:
	_recording = false

func is_recording() -> bool:
	return _recording

func begin_phase(index: int) -> void:
	if phases.is_empty(): return
	_current = clampi(index, 0, phases.size() - 1)
	# The first interval of a new phase is measured from the boundary frame, so a
	# phase change does not charge the new phase for the previous phase's frame.
	_last_usec = Time.get_ticks_usec()

func current_phase() -> int:
	return _current

func record() -> void:
	if not _recording or phases.is_empty(): return
	total_frames += 1
	var phase: Dictionary = phases[_current]
	phase.frames = int(phase.frames) + 1
	var now := Time.get_ticks_usec()
	if _last_usec <= 0:
		_last_usec = now
		return
	var samples: Array = phase.samples
	var size := int(phase.size)
	if size >= CAPACITY_PER_PHASE:
		dropped += 1
		_last_usec = now
		return
	samples.append(float(now - _last_usec) / 1000.0)
	phase.size = size + 1
	_last_usec = now

func frame_count() -> int:
	return total_frames

func sample_count(measured_only: bool = false) -> int:
	var total := 0
	for phase: Dictionary in phases:
		if measured_only and not bool(phase.measured): continue
		total += int(phase.size)
	return total

static func summarize(samples: Array) -> Dictionary:
	var count := samples.size()
	if count == 0:
		return {"samples": 0, "median_ms": 0.0, "p95_ms": 0.0, "max_ms": 0.0, "mean_ms": 0.0, "fps_from_median": 0.0}
	var ordered := samples.duplicate()
	ordered.sort()
	var median: float = float(ordered[count / 2])
	if count % 2 == 0:
		median = (float(ordered[count / 2 - 1]) + median) * 0.5
	var total := 0.0
	for value: float in ordered:
		total += value
	return {"samples": count, "median_ms": median,
		"p95_ms": float(ordered[ceili(count * 0.95) - 1]), "max_ms": float(ordered[count - 1]),
		"mean_ms": total / float(count), "fps_from_median": 1000.0 / maxf(median, 0.001)}

## Aggregate over the measured phases only. Warm-up stays visible per phase but
## never reaches the reported aggregate.
func aggregate() -> Dictionary:
	var gathered: Array = []
	for phase: Dictionary in phases:
		if bool(phase.measured): gathered.append_array(phase.samples)
	return summarize(gathered)

func phase_report() -> Array:
	var report: Array = []
	for phase: Dictionary in phases:
		var stats := summarize(phase.samples)
		stats["name"] = str(phase.name)
		stats["measured"] = bool(phase.measured)
		stats["frames"] = int(phase.frames)
		report.append(stats)
	return report
