extends RefCounted
## Pure result assembly for the in-match benchmark. No engine state is read here,
## so the same input dictionary produces the same JSON in a test, in the editor
## and in a packaged build. Honesty fields are derived, never asserted by hand:
##   * renderer_class marks software rasterizers, whose numbers are not hardware.
##   * verdict drops to partial/unusable when the run could not control the actor,
##     when vsync capped the cadence, when the quality level moved mid-run or when
##     samples were dropped.
const SCHEMA := 1
const TOOL := "cocs-native-benchmark"
const VERSION := "1.0.0"
const LEVELS := ["Low", "High", "Extreme"]

# Software rasterizer markers. Matching any of these means the numbers describe a
# CPU rasterizer (llvmpipe and friends), never the owner's GPU.
const SOFTWARE_MARKERS := ["llvmpipe", "softpipe", "swrast", "software rasterizer",
	"swiftshader", "lavapipe", "zink (llvmpipe", "virgl", "microsoft basic render"]

static func renderer_class(adapter: String) -> String:
	var lowered := adapter.to_lower()
	for marker: String in SOFTWARE_MARKERS:
		if lowered.contains(marker): return "software"
	return "hardware" if not adapter.strip_edges().is_empty() else "unknown"

## Classify the run for a reader who only sees the pasted line. A run can lose
## input control for part of its window (death, respawn, very low frame rate) and
## still be exactly the measurement that was wanted: that is `partial`, not
## `unusable`. `unusable` is reserved for the sequence not finishing or for a
## window with neither input control nor any combat activity, which is the only
## case that describes an idle scene.
static func verdict(data: Dictionary) -> Array:
	var reasons: Array = []
	var measured := float(data.get("measured_seconds", 0.0))
	var controlled := float(data.get("controls_seconds", 0.0))
	var combat: Dictionary = data.get("combat", {})
	var activity := int(combat.get("shots", 0)) + int(combat.get("explosions", 0)) + int(combat.get("launches", 0))
	var vsync_mode := int(data.get("vsync_during", 0))
	var quality_stable := bool(data.get("quality_stable", true))
	if not bool(data.get("complete", false)):
		reasons.append("the scripted sequence did not finish")
	var idle := measured > 0.0 and controlled < measured * 0.25 and activity <= 0
	if idle: reasons.append("the measured window had neither input control nor combat activity")
	if measured > 0.0 and controlled < measured * 0.95 and not idle:
		reasons.append("the actor was under benchmark control for %.0f%% of the measured window" % (100.0 * controlled / measured))
	if vsync_mode != DisplayServer.VSYNC_DISABLED:
		reasons.append("vsync was active: frame times are capped by the display refresh rate")
	if not quality_stable:
		reasons.append("the quality level changed during the run")
	var verdict := "usable"
	if reasons.size() > 0:
		verdict = "unusable" if (not bool(data.get("complete", false)) or idle) else "partial"
	return [verdict, reasons]

static func honesty_notes(data: Dictionary) -> Array:
	var notes: Array = []
	var adapter := str(data.get("environment", {}).get("adapter", ""))
	var kind := renderer_class(adapter)
	if kind == "software":
		notes.append("SOFTWARE RENDERER (%s): these are CPU rasterizer numbers, not hardware GPU figures, and must not be quoted as the owner's performance." % adapter)
	notes.append("Frame times are wall-clock intervals between real RenderingServer frame_post_draws, with display buffering included. They are not GPU timestamps.")
	notes.append("Engine draw calls and primitive counts are best-effort engine counters; the GL compatibility renderer can report zero.")
	notes.append("Particle allocated/submitted slots are submitted capacity, not a live GPU count and not a count of visible particles.")
	var measured := float(data.get("measured_seconds", 0.0))
	if float(data.get("controls_seconds", 0.0)) < measured * 0.95 and measured > 0.0:
		notes.append("Part of the measured window ran without benchmark input control (death, respawn or lost focus); effect load is lower than a fully controlled run.")
	if float(data.get("dropped_samples", 0.0)) > 0.0:
		notes.append("Frame intervals above the per-phase capacity were dropped; the run was longer or slower than the buffer supports.")
	return notes

static func timestamp_utc() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"

static func command_line() -> String:
	var parts := PackedStringArray()
	parts.append(OS.get_executable_path())
	for arg: String in OS.get_cmdline_args(): parts.append(arg)
	if OS.get_cmdline_user_args().size() > 0: parts.append("--")
	for arg: String in OS.get_cmdline_user_args(): parts.append(arg)
	return " ".join(parts)

## `data` keys (all optional except the measured statistics):
## environment, window, scene, phases, aggregate, engine, particles, combat,
## recommendation, artifacts, complete, measured_seconds, controls_seconds,
## startup_seconds, quality_stable, dropped_samples.
static func build(data: Dictionary) -> Dictionary:
	var classification := verdict(data)
	var result := {
		"schema": SCHEMA,
		"tool": TOOL,
		"version": VERSION,
		"generated": str(data.get("generated", timestamp_utc())),
		"command": str(data.get("command", command_line())),
		"complete": bool(data.get("complete", false)),
		"verdict": classification[0],
		"verdict_reasons": classification[1],
		"measured_seconds": float(data.get("measured_seconds", 0.0)),
		"controls_seconds": float(data.get("controls_seconds", 0.0)),
		"startup_seconds": float(data.get("startup_seconds", 0.0)),
		"environment": data.get("environment", {}),
		"window": data.get("window", {}),
		"launch": data.get("launch", {}),
		"scene": data.get("scene", {}),
		"quality": data.get("quality", {}),
		"phases": data.get("phases", []),
		"aggregate": data.get("aggregate", {}),
		"engine": data.get("engine", {}),
		"particles": data.get("particles", {}),
		"combat": data.get("combat", {}),
		"recommendation": data.get("recommendation", {}),
		"artifacts": data.get("artifacts", {}),
	}
	result["honesty"] = {
		"renderer_class": renderer_class(str(result.environment.get("adapter", ""))),
		"software_renderer": renderer_class(str(result.environment.get("adapter", ""))) == "software",
		"notes": honesty_notes(data),
	}
	return result

static func json(result: Dictionary) -> String:
	return JSON.stringify(result, "  ") + "\n"

static func result_line(result: Dictionary) -> String:
	return "BENCHMARK_RESULT " + JSON.stringify(result)
