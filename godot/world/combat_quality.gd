extends CanvasLayer
## Popup-free in-match controls. The effect owners provide actual resource metrics.
##
## F9 cycles the effect quality, F10 toggles the measured resource metrics and F7
## runs the bounded in-match benchmark (res://benchmark/, port/native-benchmark/).
## The benchmark can also be armed before launch with COCS_BENCHMARK=1 or with
## --benchmark in the session user args, which is how the owner's Windows run sheet
## starts it. `recommended_level()`/`recommendation_for()`/`apply_recommended()`
## map a measured frame time to a preset; the F9 cycle keeps every level selectable.
signal quality_changed(level: int)
signal benchmark_finished(summary: Dictionary)
const LEVELS := ["Low", "High", "Extreme"]
const BenchmarkScene = preload("res://benchmark/benchmark.tscn")
## Measured-frame-time budgets for the recommended preset, applied to the p95
## wall-clock frame time the in-match benchmark reports:
##   extreme <= 8.3 ms (inside a 120 Hz budget), high <= 16.7 ms (the 60 Hz budget),
##   anything slower recommends Low. A fast machine therefore still reaches Extreme.
const PRESET_EXTREME_MS := 8.3
const PRESET_HIGH_MS := 16.7
const BENCHMARK_TRIGGER := "COCS_BENCHMARK"
const BENCHMARK_LEVEL := "COCS_BENCHMARK_LEVEL"
var quality := 1
var active := false
var telemetry := false
var remaining := 0.0
var metrics: Dictionary = {}
var text := Label.new()
var benchmark: Node
var benchmark_summary: Dictionary = {}

func _ready() -> void:
	layer = 5
	add_child(text)
	text.position = Vector2(20, 70)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_color_override("font_color", Color("b4e9ff"))
	text.add_theme_color_override("font_shadow_color", Color.BLACK)
	text.add_theme_constant_override("shadow_offset_x", 2)
	text.add_theme_constant_override("shadow_offset_y", 2)
	text.add_theme_font_size_override("font_size", 14)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh()
	var requested := requested_level()
	if requested >= 0: select_quality(requested)
	if requested_by_launch():
		request_benchmark(true)

func _layout() -> void:
	# Teardown emits size changes after the layer leaves the tree; a freed window
	# has no viewport and must never raise a script error during cleanup.
	var viewport := get_viewport()
	if viewport == null: return
	var rect := viewport.get_visible_rect().size
	text.size.x = maxf(200, rect.x - 40)
	# F10 telemetry can be long; clip it inside the window instead of drawing off
	# the bottom edge, and shrink the font when the line count grows.
	text.size.y = maxf(80, rect.y - text.position.y - 16)
	text.clip_text = true

func set_active(value: bool) -> void:
	if value and not active: remaining = 4.0
	active = value
	_refresh()

func set_metrics(value: Dictionary) -> void:
	metrics = value.duplicate(true)
	_refresh()

func select_quality(value: int) -> void:
	var next := clampi(value, 0, LEVELS.size()-1)
	if next != quality:
		quality = next
		quality_changed.emit(quality)
	remaining = 4.0
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_F9:
		select_quality((quality + 1) % LEVELS.size())
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F10:
		telemetry = not telemetry
		_refresh()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F7:
		if request_benchmark(false):
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	remaining = maxf(0,remaining-delta)
	if remaining == 0 and not telemetry: text.hide()

func _refresh() -> void:
	var hint := ""
	if is_instance_valid(benchmark) and not benchmark.done:
		hint = " · F7 benchmark running"
	text.visible = active and (remaining > 0 or telemetry)
	text.text = "Combat effects: %s · F9 quality · F10 metrics · F7 benchmark%s" % [LEVELS[quality], hint]
	if telemetry:
		for key: String in metrics:
			var value: Variant = metrics[key]
			if value is int or value is float or value is String:
				text.text += "\n%s: %s" % [key, str(value).left(120)]

# --- recommended presets ----------------------------------------------------

## The preset a measured p95 frame time supports. Kept static and pure so the
## benchmark, a future HUD control and tests all agree on one rule.
static func recommended_level(frame_ms: float) -> int:
	if not is_finite(frame_ms) or frame_ms <= 0.0: return 1
	if frame_ms <= PRESET_EXTREME_MS: return 2
	if frame_ms <= PRESET_HIGH_MS: return 1
	return 0

static func recommended_reason(frame_ms: float) -> String:
	if not is_finite(frame_ms) or frame_ms <= 0.0:
		return "no usable measurement: keeping the project default (High)"
	if frame_ms <= PRESET_EXTREME_MS:
		return "p95 %.1f ms still fits the Extreme particle budget (<= %.1f ms)" % [frame_ms, PRESET_EXTREME_MS]
	if frame_ms <= PRESET_HIGH_MS:
		return "p95 %.1f ms holds a 60 Hz budget at High (<= %.1f ms)" % [frame_ms, PRESET_HIGH_MS]
	return "p95 %.1f ms misses the 60 Hz budget at the measured level; Low is the supported load" % frame_ms

## Full recommendation for a benchmark result, including the level it was
## measured at and the honest caveat that the preset is an extrapolation.
func recommendation_for(frame_ms: float, measured_level: int) -> Dictionary:
	var level := recommended_level(frame_ms)
	var measured := str(LEVELS[clampi(measured_level, 0, LEVELS.size()-1)]) if measured_level >= 0 else "unknown"
	return {
		"level": level, "name": LEVELS[level],
		"p95_ms": frame_ms if is_finite(frame_ms) else -1.0,
		"measured_level": measured_level, "measured_name": measured,
		"basis": "p95 wall-clock frame time measured by the in-match benchmark",
		"reason": recommended_reason(frame_ms),
		"confirm": "re-run the benchmark at the recommended level to confirm; F9 still cycles every level",
		"thresholds_ms": {"extreme": PRESET_EXTREME_MS, "high": PRESET_HIGH_MS},
	}

## Apply the preset a measured frame time supports and return the level index.
func apply_recommended(frame_ms: float) -> int:
	var level := recommended_level(frame_ms)
	select_quality(level)
	return level

## True when the launcher environment or user args asked for a benchmark run.
static func requested_by_launch() -> bool:
	var value := OS.get_environment(BENCHMARK_TRIGGER).strip_edges().to_lower()
	if value in ["1", "true", "yes", "on"]: return true
	return "--benchmark" in OS.get_cmdline_user_args()

## Level requested with COCS_BENCHMARK_LEVEL=low|high|extreme, or -1 when unset.
static func level_index(name: String) -> int:
	var wanted := name.strip_edges().to_lower()
	for i in range(LEVELS.size()):
		if str(LEVELS[i]).to_lower() == wanted: return i
	return -1

static func requested_level() -> int:
	return level_index(OS.get_environment(BENCHMARK_LEVEL))

## Start one bounded benchmark against the live session. `automatic` runs are the
## scripted owner/CI path and quit the process when the result is saved.
func request_benchmark(automatic: bool = false) -> bool:
	if is_instance_valid(benchmark) and not benchmark.done: return false
	var session := find_session()
	if session == null: return false
	var driver: Node = BenchmarkScene.instantiate()
	driver.name = "BenchmarkDriver"
	if not driver.bind_session(session, self):
		driver.free()
		return false
	driver.auto_quit = automatic
	driver.autostart = automatic
	driver.finished.connect(_on_benchmark_finished)
	add_child(driver)
	benchmark = driver
	_refresh()
	return true

func benchmark_active() -> bool:
	return is_instance_valid(benchmark) and not benchmark.done

## Nearest ancestor that exposes the authoritative session surface. Detached
## diagnostics and non-session owners simply find nothing.
func find_session() -> Node:
	var node := get_parent()
	while node != null:
		if ("phase" in node) and ("client" in node) and ("presentation" in node) and node.has_method("observe_combat_input"):
			return node
		node = node.get_parent()
	return null

func _on_benchmark_finished(result: Dictionary) -> void:
	var aggregate: Dictionary = result.get("aggregate", {})
	benchmark_summary = {
		"p95_ms": float(aggregate.get("p95_ms", 0.0)),
		"median_ms": float(aggregate.get("median_ms", 0.0)),
		"max_ms": float(aggregate.get("max_ms", 0.0)),
		"samples": int(aggregate.get("samples", 0)),
		"measured_level": str(result.get("quality", {}).get("name", "unknown")),
		"recommended": str(result.get("recommendation", {}).get("name", "")),
		"complete": bool(result.get("complete", false)),
		"verdict": str(result.get("verdict", "")),
	}
	benchmark_finished.emit(benchmark_summary)
	_refresh()
