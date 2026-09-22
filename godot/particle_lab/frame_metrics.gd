extends RefCounted
## Bounded wall-clock intervals between real RenderingServer frame_post_draws.
## These are end-to-end render cadence, not GPU timestamp/query timings.
const CAPACITY := 240
var _samples := PackedFloat64Array()
var _cursor := 0
var _size := 0
var _last_usec := 0
var total_frames := 0

func _init() -> void:
	_samples.resize(CAPACITY)

func reset() -> void:
	_cursor = 0
	_size = 0
	_last_usec = 0
	total_frames = 0

func record_render_frame() -> void:
	var now := Time.get_ticks_usec()
	if _last_usec > 0:
		_samples[_cursor] = float(now - _last_usec) / 1000.0
		_cursor = (_cursor + 1) % CAPACITY
		_size = mini(_size + 1, CAPACITY)
	_last_usec = now
	total_frames += 1

func snapshot() -> Dictionary:
	if _size == 0:
		return {"samples": 0, "render_frames": total_frames, "median_ms": 0.0, "p95_ms": 0.0, "max_ms": 0.0, "fps_from_median": 0.0}
	var ordered := _samples.slice(0, _size)
	ordered.sort()
	var median: float = ordered[_size / 2]
	if _size % 2 == 0:
		median = (ordered[_size / 2 - 1] + median) * 0.5
	return {"samples": _size, "render_frames": total_frames,
		"median_ms": median, "p95_ms": ordered[ceili(_size * 0.95) - 1],
		"max_ms": ordered[_size - 1], "fps_from_median": 1000.0 / maxf(median, 0.001)}
