extends SceneTree
## Benchmark and preset contracts. Pure logic only: the plan's determinism and
## bounds, the frame statistics, the honesty classification and the preset API.
## The rendered live run is owned by port/native-benchmark/run_benchmark.mjs.
const Plan = preload("res://benchmark/run_plan.gd")
const FrameStats = preload("res://benchmark/frame_stats.gd")
const Report = preload("res://benchmark/report.gd")
const Driver = preload("res://benchmark/benchmark.tscn")
const Quality = preload("res://world/combat_quality.gd")
const Demo = preload("res://native_arenas/demo.gd")
const ALLOWED_KEYS := [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_R, KEY_G,
	KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
var checks := 0
var failures: Array[String] = []

class Session extends Node3D:
	## Minimal session surface the driver requires. Never stepped: this fixture
	## only proves bind and autostart decisions, not live input. The child nodes
	## stay null so the fixture owns no orphans at exit.
	var phase := 3
	var received_pose := true
	var presentation: Node
	var client: Node
	var selected_native_map := "prism-foundry"
	var bot_count := 4
	var round_seconds := 180
	var auto_start := false
	var launch_calls: Array = []
	func launch_match(map_id: String, player_name: String, bots: int, seconds: int) -> void:
		launch_calls.append([map_id, player_name, bots, seconds])
	func observe_combat_input(_event: InputEvent) -> void: pass
	func can_capture_pointer() -> bool: return true
	func update_look(_relative: Vector2) -> void: pass

class SetupOnly extends Node3D:
	## A native setup surface that has no benchmark autostart API: the driver
	## must never guess a launch call for it.
	var phase := -2
	var received_pose := false
	var presentation: Node
	var client: Node
	func observe_combat_input(_event: InputEvent) -> void: pass
	func can_capture_pointer() -> bool: return false
	func update_look(_relative: Vector2) -> void: pass

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	check_plan()
	check_stats()
	check_report()
	await check_quality()
	await check_arming()
	print("BENCHMARK_CONTRACTS_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func check_plan() -> void:
	var total := Plan.total_seconds()
	check(total >= 20.0 and total <= 60.0, "the scripted plan stays inside the 20..60 second budget")
	check(Plan.measured_seconds() > 0.0 and Plan.measured_seconds() < total, "warm-up is excluded from the measured aggregate")
	check(Plan.phase_count() >= 3, "the plan has warm-up plus at least two measured phases")
	var names := Plan.phase_names()
	var unique := {}
	for name: String in names: unique[name] = true
	check(unique.size() == names.size(), "phase names are unique")
	check(str(names[0]) == "warmup" and not Plan.is_measured(0), "phase 0 is the unmeasured warm-up")
	check(Plan.phase_start(1) == float(Plan.PHASES[0].seconds), "phase starts accumulate phase lengths")
	check(Plan.phase_index(0.0) == 0 and Plan.phase_index(total - 0.001) == Plan.phase_count() - 1, "phase lookup covers the whole plan")
	check(Plan.phase_index(total + 5.0) == Plan.phase_count() - 1, "phase lookup clamps past the end")
	check(Plan.local_seconds(Plan.phase_start(2) + 1.5) == 1.5, "phase-local time is the offset inside the phase")
	# Determinism: identical elapsed seconds must produce identical intent.
	var sample_times := [0.0, 1.234, 5.0, 6.7, 12.5, 17.999, 18.0, 25.5, 32.9]
	for elapsed: float in sample_times:
		var first := Plan.intent(elapsed)
		var second := Plan.intent(elapsed)
		check(JSON.stringify(_stable(first)) == JSON.stringify(_stable(second)), "intent is pure at %.3fs" % elapsed)
		check(str(first.phase) != "", "intent names its phase at %.3fs" % elapsed)
		check(bool(first.fire) == Plan.is_measured(int(first.index)) or not Plan.is_measured(int(first.index)), "fire intent is defined at %.3fs" % elapsed)
		var look: Vector2 = first.look
		check(is_finite(look.x) and is_finite(look.y), "look intent is finite at %.3fs" % elapsed)
		check(absf(look.x) <= 400.0 and absf(look.y) <= 400.0, "look intent stays inside the scripted sweep at %.3fs" % elapsed)
		for key: int in first.keys:
			check(key in ALLOWED_KEYS, "scripted key %d is a documented player key" % key)
	# The whole plan is sampled rather than trusting a few instants.
	var seen := {}
	var index := 0.0
	while index < total:
		for key: int in Plan.held_keys(index): seen[key] = true
		index += 0.1
	for key: int in seen.keys():
		check(key in ALLOWED_KEYS, "every key the plan holds is a documented player key (%d)" % key)
	check(seen.has(KEY_W) and seen.has(KEY_D) and seen.has(KEY_G), "the plan moves, strafes and throws grenades")
	check(Plan.weapon_key(0) == KEY_1 and Plan.weapon_key(9) == KEY_0, "weapon keys follow the source 1..9/0 order")
	check(Plan.weapon_key(-1) == 0 and Plan.weapon_key(10) == 0, "out-of-range weapon indexes request nothing")

func _stable(intent: Dictionary) -> Dictionary:
	var keys: Array = intent.keys.duplicate()
	keys.sort()
	return {"index": intent.index, "phase": intent.phase, "local": intent.local, "keys": keys,
		"fire": intent.fire, "look": [intent.look.x, intent.look.y], "measured": intent.measured}

func check_stats() -> void:
	var stats := FrameStats.summarize([4.0, 1.0, 3.0, 2.0])
	check(stats.samples == 4, "summary counts every sample")
	check(is_equal_approx(float(stats.median_ms), 2.5), "median of an even series averages the middle pair")
	check(is_equal_approx(float(stats.max_ms), 4.0), "max is the largest interval")
	check(is_equal_approx(float(stats.mean_ms), 2.5), "mean is the arithmetic average")
	check(is_equal_approx(float(stats.p95_ms), 4.0), "p95 of four samples is the largest")
	check(is_equal_approx(float(FrameStats.summarize([16.0]).median_ms), 16.0), "single-sample median")
	check(is_equal_approx(float(FrameStats.summarize([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]).p95_ms), 10.0), "p95 of a ramp is the top decile")
	var ordered := []
	for i in range(20): ordered.append(float(i) + 0.5)
	check(is_equal_approx(float(FrameStats.summarize(ordered).p95_ms), 18.5), "p95 uses the ceil(n*0.95)-1 ordered sample")
	check(int(FrameStats.summarize([]).samples) == 0 and is_equal_approx(float(FrameStats.summarize([]).median_ms), 0.0), "empty series reports zeroes, not NaN")
	var running := FrameStats.new()
	running.configure(PackedStringArray(["warmup", "combat"]), [false, true])
	running.start()
	running.begin_phase(0)
	for i in range(5): running.record()
	check(int(running.phases[0].frames) == 5 and int(running.phases[1].frames) == 0, "frames land in their phase bucket")
	running.begin_phase(1)
	for i in range(3): running.record()
	check(int(running.phases[1].frames) == 3, "a later phase keeps its own bucket")
	check(running.sample_count(true) == int(running.phases[1].size), "measured-only sample count excludes warm-up")
	check(running.aggregate().samples == running.sample_count(true), "the aggregate gathers measured phases only")
	check(running.frame_count() == 8, "every drawn frame is counted once")
	check(int(running.dropped) == 0, "short runs drop nothing")

func check_report() -> void:
	check(Report.renderer_class("llvmpipe (LLVM 20.1.8, 256 bits)") == "software", "llvmpipe is classified as a software rasterizer")
	check(Report.renderer_class("NVIDIA GeForce RTX 4070/PCIe/SSE2") == "hardware", "a discrete GPU is classified as hardware")
	check(Report.renderer_class("") == "unknown", "an unknown adapter is not claimed as hardware")
	var data := {
		"complete": true, "measured_seconds": 28.0, "controls_seconds": 28.0, "startup_seconds": 2.5,
		"quality_stable": true, "dropped_samples": 0, "vsync_during": 0,
		"environment": {"adapter": "llvmpipe (LLVM 20.1.8, 256 bits)", "renderer_method": "gl_compatibility"},
		"window": {"size": [1280, 800], "viewport_size": [1280, 800]},
		"scene": {"map": "prism-foundry", "actor_count": 5},
		"quality": {"level": 1, "name": "High", "levels": ["Low", "High", "Extreme"], "stable": true},
		"phases": [FrameStats.summarize([12.0, 13.0])],
		"aggregate": {"samples": 2, "median_ms": 12.5, "p95_ms": 13.0, "max_ms": 13.0, "mean_ms": 12.5, "fps_from_median": 80.0},
		"engine": {"draw_calls_mean": 0.0}, "particles": {"allocated_slots": 131072},
		"combat": {"explosions": 3}, "recommendation": {"level": 1, "name": "High"},
	}
	var result := Report.build(data)
	check(int(result.schema) == 1, "result carries its schema")
	check(bool(result.complete), "completeness is reported honestly")
	check(str(result.honesty.renderer_class) == "software" and bool(result.honesty.software_renderer), "software rendering is flagged in the result")
	var note_text := " ".join(result.honesty.notes)
	check(note_text.contains("not hardware"), "an llvmpipe result states that its numbers are not hardware figures")
	check(note_text.contains("frame_post_draw"), "the result states what a frame time measures")
	for key: String in ["aggregate", "phases", "quality", "particles", "combat", "window", "environment", "recommendation", "artifacts"]:
		check(result.has(key), "result carries " + key)
	check(str(result.verdict) == "usable", "a complete controlled software run is usable, if software")
	var parsed: Variant = JSON.parse_string(Report.result_line(result).trim_prefix("BENCHMARK_RESULT "))
	check(parsed is Dictionary and int(parsed.schema) == 1, "the printed line is valid JSON")
	check(Report.result_line(result).begins_with("BENCHMARK_RESULT {"), "the printed line is greppable")
	var partial := data.duplicate(true)
	partial["complete"] = false
	partial["refused"] = "the round ended"
	var partial_result := Report.build(partial)
	check(str(partial_result.verdict) == "unusable", "an unfinished sequence is not usable evidence")
	partial["complete"] = true
	partial["vsync_during"] = 1
	var capped := Report.build(partial)
	check(str(capped.verdict) == "partial", "vsync-capped runs are partial")
	var uncontrolled := data.duplicate(true)
	uncontrolled["controls_seconds"] = 1.0
	check(str(Report.build(uncontrolled).verdict) == "partial", "a heavy run that lost input control is partial, not unusable")
	var idle := data.duplicate(true)
	idle["controls_seconds"] = 0.0
	idle["combat"] = {"shots": 0, "explosions": 0, "launches": 0}
	check(str(Report.build(idle).verdict) == "unusable", "a window with no control and no combat is unusable")
	check(Report.json(result).ends_with("\n"), "the saved JSON ends with a newline")

func check_quality() -> void:
	check(Quality.recommended_level(4.0) == 2, "a fast p95 recommends Extreme")
	check(Quality.recommended_level(Quality.PRESET_EXTREME_MS) == 2, "the Extreme boundary is inclusive")
	check(Quality.recommended_level(9.0) == 1, "a 60 Hz-capable p95 recommends High")
	check(Quality.recommended_level(Quality.PRESET_HIGH_MS) == 1, "the High boundary is inclusive")
	check(Quality.recommended_level(30.0) == 0, "a slow p95 recommends Low")
	check(Quality.recommended_level(0.0) == 1 and Quality.recommended_level(-1.0) == 1, "a missing measurement keeps the default High")
	check(Quality.recommended_level(NAN) == 1 and Quality.recommended_level(INF) == 1, "non-finite measurements keep the default")
	check(Quality.recommended_level(8.0) != Quality.recommended_level(20.0), "the mapping is not constant")
	check(Quality.recommended_reason(4.0).contains("Extreme"), "the reason names the Extreme budget")
	check(Quality.recommended_reason(30.0).contains("Low"), "the slow reason names Low")
	var quality: CanvasLayer = Quality.new()
	root.add_child(quality)
	var changes: Array = []
	quality.quality_changed.connect(func(level: int) -> void: changes.append(level))
	check(quality.quality == 1 and quality.recommendation_for(20.0, 1).name == "Low", "the default level stays High and recommends Low for a slow run")
	var recommendation: Dictionary = quality.recommendation_for(20.0, 2)
	check(int(recommendation.level) == 0 and str(recommendation.measured_name) == "Extreme", "the recommendation records the measured level")
	check(str(recommendation.basis).contains("p95"), "the recommendation states its basis")
	check(str(recommendation.confirm).contains("F9"), "the recommendation tells the owner F9 still cycles levels")
	check(int(quality.apply_recommended(20.0)) == 0 and quality.quality == 0, "apply_recommended drops to Low for a slow measurement")
	check(int(quality.apply_recommended(5.0)) == 2 and quality.quality == 2, "apply_recommended selects Extreme on a fast machine")
	check(changes == [0, 2], "apply_recommended emits quality_changed for each real change")
	# F9 must still cycle every level, including back up to Extreme.
	quality.set_active(true)
	quality._unhandled_input(_key(KEY_F9))
	check(quality.quality == 0, "F9 cycles past Extreme back to Low")
	quality._unhandled_input(_key(KEY_F9))
	quality._unhandled_input(_key(KEY_F9))
	check(quality.quality == 2, "F9 still reaches Extreme by hand")
	check(changes == [0, 2, 0, 1, 2], "each F9 step is reported")
	quality._unhandled_input(_key(KEY_F10))
	check(quality.telemetry, "F10 still toggles the measured metrics")
	quality.set_metrics({"allocated_slots": 32768})
	check(quality.text.text.contains("allocated_slots: 32768"), "F10 shows the measured allocated slots")
	quality._unhandled_input(_key(KEY_F10))
	check(not quality.telemetry, "F10 toggles back off")
	check(not Quality.requested_by_launch(), "no benchmark is armed without the launch trigger")
	check(Quality.level_index("extreme") == 2 and Quality.level_index(" low ") == 0, "level names resolve case-insensitively")
	check(Quality.level_index("bogus") == -1 and Quality.level_index("") == -1, "unknown level names resolve to nothing")
	check(Quality.requested_level() == -1, "no level override is applied without the environment variable")
	check(not quality.benchmark_active(), "no benchmark is active before a request")
	check(not quality.request_benchmark(), "a quality manager with no live session refuses a benchmark")
	check(quality.find_session() == null, "a detached quality manager finds no session to benchmark")
	# Driver binding: refuses non-sessions, accepts the documented surface.
	var driver: Node = Driver.instantiate()
	var stranger := Node.new()
	check(not driver.bind_session(stranger), "the driver refuses a node that is not a session")
	stranger.free()
	var session := Session.new()
	root.add_child(session)
	check(driver.bind_session(session, quality), "the driver binds the authoritative session surface")
	check(driver.session == session and driver.quality_controls == quality, "binding records the session and the quality manager")
	check(not driver._runnable(), "a headless display is refused rather than measured")
	driver.free()
	session.free()
	quality.free()

## The two automatic-start decisions that the owner's run sheet depends on:
## the launch arming (COCS_BENCHMARK/--benchmark, COCS_BENCHMARK_LEVEL) and the
## driver's one-shot autostart for a setup-phase native session. Pinned here so
## the env-armed run cannot silently regress into a parked setup screen.
func check_arming() -> void:
	var before_trigger := OS.get_environment(Quality.BENCHMARK_TRIGGER)
	var before_level := OS.get_environment(Quality.BENCHMARK_LEVEL)
	OS.unset_environment(Quality.BENCHMARK_TRIGGER)
	check(not Quality.requested_by_launch(), "an unset trigger does not arm the benchmark")
	OS.set_environment(Quality.BENCHMARK_TRIGGER, "1")
	check(Quality.requested_by_launch(), "COCS_BENCHMARK=1 arms the benchmark")
	OS.set_environment(Quality.BENCHMARK_TRIGGER, " YES ")
	check(Quality.requested_by_launch(), "the arming value is trimmed and case-insensitive")
	OS.set_environment(Quality.BENCHMARK_TRIGGER, "off")
	check(not Quality.requested_by_launch(), "a non-arming value does not arm the benchmark")
	OS.unset_environment(Quality.BENCHMARK_LEVEL)
	check(Quality.requested_level() == -1, "no level override without the environment variable")
	OS.set_environment(Quality.BENCHMARK_LEVEL, "extreme")
	check(Quality.requested_level() == 2, "COCS_BENCHMARK_LEVEL selects the measured level")
	# The native route must start its own match for every automatic launch, the
	# env-armed run sheet included; an interactive launch keeps the setup HUD.
	check(Demo.launch_starts_match(true, false), "--autostart starts the native match without UI input")
	check(Demo.launch_starts_match(false, true), "--smoke starts the native match without UI input")
	check(not Demo.launch_starts_match(false, false), "an un-armed interactive launch keeps the setup HUD")
	OS.set_environment(Quality.BENCHMARK_TRIGGER, "1")
	check(Demo.launch_starts_match(false, false), "the documented COCS_BENCHMARK=1 run starts the native match itself")
	OS.unset_environment(Quality.BENCHMARK_TRIGGER)
	check(not Demo.launch_starts_match(false, false), "clearing the trigger restores the interactive setup HUD")
	if before_trigger.is_empty(): OS.unset_environment(Quality.BENCHMARK_TRIGGER)
	else: OS.set_environment(Quality.BENCHMARK_TRIGGER, before_trigger)
	if before_level.is_empty(): OS.unset_environment(Quality.BENCHMARK_LEVEL)
	else: OS.set_environment(Quality.BENCHMARK_LEVEL, before_level)
	# Driver autostart decision path: the fallback for any setup-phase session
	# that does not start itself. It must use the session's documented launch API,
	# exactly once, and only while the session is still in setup.
	var quality: CanvasLayer = Quality.new()
	root.add_child(quality)
	var session := Session.new()
	session.phase = -2
	root.add_child(session)
	var driver: Node = Driver.instantiate()
	check(driver.bind_session(session, quality), "the autostart fixture binds the session surface")
	check(not driver._autostart_step(), "an un-armed driver never starts the session's match")
	driver.autostart = true
	check(driver._autostart_step(), "an armed driver starts a setup-phase native session itself")
	check(session.launch_calls == [["prism-foundry", "Operator", 4, 180]], "the driver passes the session's own map, operator, bots and round seconds")
	check(not driver._autostart_step(), "the driver autostart decision is one-shot")
	driver.free()
	var waiting := Session.new()
	waiting.phase = 0
	root.add_child(waiting)
	var waiting_driver: Node = Driver.instantiate()
	waiting_driver.bind_session(waiting, quality)
	waiting_driver.autostart = true
	check(not waiting_driver._autostart_step(), "a session past setup is never re-started by the driver")
	check(waiting.launch_calls.is_empty(), "no launch call lands outside the setup phase")
	waiting_driver.free()
	var self_start := Session.new()
	self_start.phase = -2
	self_start.auto_start = true
	root.add_child(self_start)
	var self_driver: Node = Driver.instantiate()
	self_driver.bind_session(self_start, quality)
	self_driver.autostart = true
	check(not self_driver._autostart_step(), "a session that starts itself is not started twice")
	check(self_start.launch_calls.is_empty(), "no second start is sent when auto_start already owns it")
	self_driver.free()
	var setup_only := SetupOnly.new()
	root.add_child(setup_only)
	var plain_driver: Node = Driver.instantiate()
	plain_driver.bind_session(setup_only, quality)
	plain_driver.autostart = true
	check(not plain_driver._autostart_step(), "a setup surface with no launch_match is never autostarted blindly")
	plain_driver.free()
	session.free()
	waiting.free()
	self_start.free()
	setup_only.free()
	quality.free()

func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event
