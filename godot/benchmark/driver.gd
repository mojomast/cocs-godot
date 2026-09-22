extends Node
## Bounded, scripted in-match benchmark driver.
##
## Trigger (any of these, documented in port/native-benchmark/README.md):
##   * COCS_BENCHMARK=1 in the environment, before Play.cmd / the launcher
##   * --benchmark in the session user args (after the `--` separator)
##   * combat_quality.request_benchmark(), also bound to the F7 key in-match
##
## The driver binds to a live authoritative session, waits for the round to become
## controllable, then replays a fixed wall-clock plan (run_plan.gd) through the
## session's own shared input path: the same `observe_combat_input` and weapon
## selection entry points a human press reaches. It never writes actor state,
## never predicts combat and never opens a socket: the session's owned loopback
## authority is the only server involved.
##
## While measuring, real render intervals are sampled from
## RenderingServer.frame_post_draw, vsync is disabled and restored, and result
## JSON/PNGs are written next to the build (or into COCS_BENCHMARK_OUT).
signal finished(result: Dictionary)
signal refused(reason: String)

const Plan = preload("res://benchmark/run_plan.gd")
const FrameStats = preload("res://benchmark/frame_stats.gd")
const Report = preload("res://benchmark/report.gd")
const Presentation = preload("res://benchmark/presentation.gd")
const WeaponSelection = preload("res://world/weapon_selection.gd")

const ENGINE_SAMPLE_SECONDS := 0.25
const START_WAIT_SECONDS := 30.0
const FOCUS_GRACE_SECONDS := 5.0
const OFF_ROUND_LIMIT_SECONDS := 1.0
const END_HOLD_SECONDS := 2.5
const CAPTURE_AT := 0.75
const ENV_OUTPUT := "COCS_BENCHMARK_OUT"
const LEVELS := ["Low", "High", "Extreme"]

var session: Node
var quality_controls: Node
var auto_quit = false
var autostart = false
var started := false
var done := false
var completed := false
var refusal := ""
var stats := FrameStats.new()
var presentation: CanvasLayer

var _stamp := ""
var _wait := 0.0
var _focus_wait := 0.0
var _raised := false
var _diagnostic_at := 0.0
var _autostart_done := false
var _end_hold := 0.0
var _start_usec := 0
var _last_look := Vector2.ZERO
var _down := {}
var _fire_down := false
var _off_round := 0.0
var _controls_seconds := 0.0
var _current_phase := -1
var _quality_seen := {}
var _phase_quality := []
var _capture_queue := []
var _captures := []
var _last_engine_sample := 0
var _engine := {}
var _vsync_before := DisplayServer.VSYNC_ENABLED
var _vsync_after := DisplayServer.VSYNC_ENABLED
var _vsync_restored := DisplayServer.VSYNC_ENABLED
var _vsync_changed := false

func _init() -> void:
	process_priority = -60

func _ready() -> void:
	_stamp = str(Time.get_datetime_string_from_system(true)).replace(":", "-")
	presentation = Presentation.new()
	add_child(presentation)
	set_process(true)
	if session == null:
		call_deferred("autobind")

## Bind an explicit session (used by combat_quality) or discover the running one.
func autobind() -> bool:
	if session != null: return true
	var tree := get_tree()
	if tree == null: return false
	var candidate := tree.current_scene
	if candidate != null and (candidate == self or not _surface_ok(candidate)): candidate = null
	if candidate == null:
		for node: Node in tree.get_nodes_in_group("session"):
			if _surface_ok(node):
				candidate = node
				break
	return bind_session(candidate)

func bind_session(target: Node, controls: Node = null) -> bool:
	if target == null or not _surface_ok(target): return false
	session = target
	quality_controls = controls
	if quality_controls == null and "combat" in session and is_instance_valid(session.combat) and "quality_controls" in session.combat:
		quality_controls = session.combat.quality_controls
	return true

static func _surface_ok(node: Node) -> bool:
	if node == null: return false
	return ("phase" in node) and ("client" in node) and ("presentation" in node) and node.has_method("observe_combat_input")

func _process(delta: float) -> void:
	if done:
		_end_hold += delta
		if auto_quit and _end_hold > END_HOLD_SECONDS and is_instance_valid(get_tree()):
			get_tree().quit(0 if completed else 1)
		return
	if not started:
		_wait += delta
		if session == null or not is_instance_valid(session):
			abort("no live session was bound to the benchmark driver")
			return
		if not _runnable():
			abort("the session is a headless or smoke fixture: this benchmark measures real render cadence only")
			return
		if _autostart_step():
			return
		var live: bool = session.phase == 3 and session.received_pose and session.presentation.lifecycle.can_control()
		if live and session.can_capture_pointer():
			_begin()
			return
		if live:
			_focus_wait += delta
			if not _raised:
				# Ask the window manager to raise us once. This cannot steal focus
				# on a locked-down desktop, so it is a hint, never a requirement.
				_raised = true
				DisplayServer.window_move_to_foreground()
				print("BENCHMARK_WAITING ", _wait_reason())
			if _focus_wait > FOCUS_GRACE_SECONDS:
				abort("the round is live but the window never became focused: %s" % _wait_reason())
		elif _wait > START_WAIT_SECONDS:
			abort("the authoritative round did not become controllable within %d seconds (%s)" % [int(START_WAIT_SECONDS), _wait_reason()])
		if _wait >= _diagnostic_at:
			_diagnostic_at = _wait + 5.0
			print("BENCHMARK_WAITING ", _wait_reason())
		return
	if not is_instance_valid(session):
		await finish(false, "the session ended before the scripted sequence finished")
		return
	var elapsed := _elapsed()
	if session.phase != 3:
		_off_round += delta
		if _off_round > OFF_ROUND_LIMIT_SECONDS:
			await finish(false, "the round ended before the scripted sequence finished (use the default round length)")
			return
	else:
		_off_round = 0.0
	if session.can_capture_pointer():
		_controls_seconds += delta
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var intent: Dictionary = Plan.intent(elapsed)
	if int(intent.index) != _current_phase:
		stats.begin_phase(int(intent.index))
		_current_phase = int(intent.index)
		_phase_quality.append(_quality_name())
	_quality_seen[_quality_name()] = true
	_apply(intent)
	_sample_engine()
	_capture_due(elapsed)
	if is_instance_valid(presentation):
		presentation.progress(int(intent.index), Plan.phase_count(), str(intent.phase),
			Plan.total_seconds() - elapsed, _quality_name())
	if elapsed >= Plan.total_seconds():
		await finish(true, "")

func _runnable() -> bool:
	if DisplayServer.get_name() == "headless": return false
	if "smoke" in session and bool(session.smoke): return false
	return true

## Why the driver is still waiting. Reported in the console and inside a refusal,
## so an owner can fix the actual cause instead of guessing.
func _wait_reason() -> String:
	if session == null or not is_instance_valid(session): return "no live session is bound"
	if "smoke" in session and bool(session.smoke): return "the session is a smoke fixture"
	if session.phase == -2 or session.phase < 0: return "the match has not been started yet (native setup phase %d)" % session.phase
	if session.phase != 3: return "phase %d: waiting for the authoritative round to go live" % session.phase
	if not session.received_pose: return "no public actor pose has arrived yet"
	if not session.presentation.lifecycle.can_control(): return "the local actor cannot be controlled yet (%s)" % session.presentation.lifecycle.status
	if not session.can_capture_pointer(): return "the window is not focused, so the scripted input cannot be captured"
	return ""

## Automatic runs start the session's own match the same way its autostart option
## does. Only the session's documented launch API is used; the authority still
## owns every gameplay decision. Interactive runs (F7) never do this.
func _autostart_step() -> bool:
	if _autostart_done or not autostart: return false
	if not ("launch_match" in session) or session.phase != -2: return false
	if "auto_start" in session and bool(session.auto_start):
		_autostart_done = true
		return false
	var map := str(session.selected_native_map) if "selected_native_map" in session else ""
	_autostart_done = true
	session.launch_match(map, "Operator", int(session.bot_count), int(session.round_seconds))
	print("BENCHMARK_AUTOSTART map=%s bots=%d seconds=%d" % [map, int(session.bot_count), int(session.round_seconds)])
	return true

func _elapsed() -> float:
	return float(Time.get_ticks_usec() - _start_usec) / 1000000.0

func _quality_name() -> String:
	if quality_controls == null or not is_instance_valid(quality_controls): return "unknown"
	return str(LEVELS[clampi(int(quality_controls.quality), 0, LEVELS.size() - 1)])

func _bot_count() -> int:
	if session != null and is_instance_valid(session) and "bot_count" in session: return int(session.bot_count)
	return -1

func _begin() -> void:
	if started or not _runnable():
		return
	started = true
	stats.configure(Plan.phase_names(), _measured_flags())
	stats.start()
	RenderingServer.frame_post_draw.connect(_on_frame_drawn)
	_vsync_before = DisplayServer.window_get_vsync_mode()
	_vsync_after = _vsync_before
	if _vsync_before != DisplayServer.VSYNC_DISABLED:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		# Read back instead of assuming: a driver that refuses the change must
		# appear as a vsync-capped run, not as an uncapped one.
		_vsync_after = DisplayServer.window_get_vsync_mode()
		_vsync_changed = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_last_look = Vector2.ZERO
	_last_engine_sample = 0
	_current_phase = -1
	_capture_queue = _capture_plan()
	_quality_seen[_quality_name()] = true
	_start_usec = Time.get_ticks_usec()
	print("BENCHMARK_START plan=%ss phases=%s" % [str(Plan.total_seconds()), ", ".join(Plan.phase_names())])
	if is_instance_valid(presentation):
		presentation.message("BENCHMARK armed: %d bots, effects %s\nF7 benchmark · F9 quality · F10 metrics" % [_bot_count(), _quality_name()])

static func _measured_flags() -> Array:
	var flags: Array = []
	for i in range(Plan.phase_count()): flags.append(Plan.is_measured(i))
	return flags

## One rendered capture shortly before each measured phase ends, so the PNG shows
## the phase under load rather than the idle moment after it.
static func _capture_plan() -> Array:
	var plan: Array = []
	for i in range(Plan.phase_count()):
		if not Plan.is_measured(i): continue
		plan.append({"at": Plan.phase_start(i) + float(Plan.PHASES[i].seconds) * CAPTURE_AT, "name": str(Plan.PHASES[i].name)})
	return plan

func _on_frame_drawn() -> void:
	stats.record()

## Feed one frame of scripted player intent through the session's shared input
## path. Keys are diffed against the previous frame, so the driver never leaves a
## synthetic press latched after the sequence ends.
func _apply(intent: Dictionary) -> void:
	var desired := {}
	for key: int in intent.keys: desired[key] = true
	for key: int in _down.keys():
		if not desired.has(key):
			_session_key(key, false)
			_down.erase(key)
	for key: int in desired.keys():
		if not _down.has(key):
			_session_key(key, true)
			_down[key] = true
	if bool(intent.fire) != _fire_down:
		_session_button(MOUSE_BUTTON_LEFT, bool(intent.fire))
		_fire_down = bool(intent.fire)
	var target: Vector2 = intent.look
	var relative := target - _last_look
	if not relative.is_zero_approx():
		session.update_look(relative)
	_last_look = target

func _session_key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	_session_event(event)

func _session_button(index: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	_session_event(event)

## Mirrors world/session.gd `_input` exactly, using only its public entry points.
func _session_event(event: InputEvent) -> void:
	session.observe_combat_input(event)
	if session.weapon_selection.handle_event(event, session.weapon_controls_active(), session.presentation.local_actor):
		if session.weapon_selection.pending >= 0: session.combat_actions.cancel_aim()

func _sample_engine() -> void:
	var now := Time.get_ticks_usec()
	if _last_engine_sample > 0 and float(now - _last_engine_sample) / 1000000.0 < ENGINE_SAMPLE_SECONDS: return
	_last_engine_sample = now
	var viewport := get_viewport()
	if viewport != null:
		var calls := viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		var primitives := viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
		_engine["viewport_draw_calls"] = int(_engine.get("viewport_draw_calls", 0)) + maxi(calls, 0)
		_engine["viewport_draw_calls_max"] = maxi(int(_engine.get("viewport_draw_calls_max", 0)), calls)
		_engine["viewport_primitives"] = int(_engine.get("viewport_primitives", 0)) + maxi(primitives, 0)
		_engine["viewport_primitives_max"] = maxi(int(_engine.get("viewport_primitives_max", 0)), primitives)
		_engine["samples"] = int(_engine.get("samples", 0)) + 1
	_engine["video_mem_peak_bytes"] = maxi(int(_engine.get("video_mem_peak_bytes", 0)), int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)))
	_engine["object_nodes_peak"] = maxi(int(_engine.get("object_nodes_peak", 0)), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))

func _capture_due(elapsed: float) -> void:
	while not _capture_queue.is_empty() and float(_capture_queue[0].at) <= elapsed:
		var entry: Dictionary = _capture_queue.pop_front()
		_capture_at(str(entry.name))

## Stop measuring, gather the honest numbers and publish the artifacts.
func finish(complete: bool, reason: String) -> void:
	if done: return
	if started:
		stats.stop()
		if RenderingServer.frame_post_draw.is_connected(_on_frame_drawn):
			RenderingServer.frame_post_draw.disconnect(_on_frame_drawn)
		if _vsync_changed:
			DisplayServer.window_set_vsync_mode(_vsync_before)
		_vsync_restored = DisplayServer.window_get_vsync_mode()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if is_instance_valid(session):
			for key: int in _down.keys(): _session_key(key, false)
			if _fire_down: _session_button(MOUSE_BUTTON_LEFT, false)
		_down.clear()
		_fire_down = false
	completed = complete
	done = true
	if not complete and not reason.is_empty(): refusal = reason
	await _publish(_collect(complete, reason))

func abort(reason: String) -> void:
	if done: return
	if started:
		await finish(false, reason)
		return
	refusal = reason
	completed = false
	done = true
	print("BENCHMARK_REFUSED ", reason)
	refused.emit(reason)
	await _publish(_collect(false, reason))

## --- honest result data ----------------------------------------------------

func _collect(complete: bool, reason: String) -> Dictionary:
	var phases := stats.phase_report()
	var aggregate := stats.aggregate()
	var level := -1
	if quality_controls != null and is_instance_valid(quality_controls): level = int(quality_controls.quality)
	var scene := {"map": "unknown", "mode": "unknown", "bots": _bot_count(), "authority": "owned-loopback",
		"autostart": autostart, "interactive": not auto_quit}
	if session != null and is_instance_valid(session):
		scene["map"] = str(session.current_id)
		scene["mode"] = str(session.selected_mode)
		scene["round_seconds"] = int(session.round_seconds)
		scene["actor_count"] = session.presentation.actors.size()
		scene["round_starts"] = int(session.round_starts)
		scene["snapshots"] = int(session.presentation.applied)
		scene["acks"] = int(session.client.last_ack)
	var levels_seen: Array = _quality_seen.keys()
	levels_seen.sort()
	return {
		"complete": complete,
		"refused": reason,
		"measured_seconds": Plan.measured_seconds(),
		"controls_seconds": _controls_seconds,
		"startup_seconds": _wait,
		"quality_stable": levels_seen.size() <= 1,
		"dropped_samples": stats.dropped,
		"vsync_during": _vsync_during(),
		"environment": _environment(),
		"window": _window_info(),
		"launch": _launch_info(),
		"scene": scene,
		"quality": {"level": level, "name": _quality_name(), "levels": LEVELS,
			"stable": levels_seen.size() <= 1, "levels_seen": levels_seen, "per_phase": _phase_quality},
		"phases": phases,
		"aggregate": aggregate,
		"engine": _engine_report(),
		"particles": _particle_report(),
		"combat": _combat_report(),
		"recommendation": _recommendation(float(aggregate.get("p95_ms", 0.0)), level),
	}

func _vsync_during() -> int:
	return _vsync_after

## How this run was armed, so a pasted result explains its own command line.
func _launch_info() -> Dictionary:
	var armed := OS.get_environment("COCS_BENCHMARK").strip_edges()
	var level_env := OS.get_environment("COCS_BENCHMARK_LEVEL").strip_edges()
	var trigger := "interactive (F7 or the quality API)"
	if auto_quit and not armed.is_empty(): trigger = "environment"
	elif auto_quit: trigger = "user args (--benchmark)"
	var level := level_env if not level_env.is_empty() else _quality_name()
	return {
		"trigger": trigger,
		"automatic": auto_quit,
		"env": {
			"COCS_BENCHMARK": armed,
			"COCS_BENCHMARK_LEVEL": level_env,
			"COCS_BENCHMARK_OUT": OS.get_environment("COCS_BENCHMARK_OUT").strip_edges(),
		},
		"windows_run": "set COCS_BENCHMARK=1 && set COCS_BENCHMARK_LEVEL=%s && Play.cmd --experience=native-dm --map=%s --bots=%d --round-seconds=%d" % [
			level.to_lower(), _scene_map(), _bot_count(), int(session.round_seconds) if session != null and is_instance_valid(session) and "round_seconds" in session else 180],
	}

func _scene_map() -> String:
	if session != null and is_instance_valid(session) and "current_id" in session: return str(session.current_id)
	return "unknown"

func _environment() -> Dictionary:
	var info := Engine.get_version_info()
	return {
		"godot": str(info.get("string", "")),
		"renderer_method": RenderingServer.get_current_rendering_method(),
		"renderer_driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"adapter_api": RenderingServer.get_video_adapter_api_version(),
		"driver_info": OS.get_video_adapter_driver_info(),
		"display_server": DisplayServer.get_name(),
		"os": OS.get_name(),
		"os_version": OS.get_version(),
		"cpu": OS.get_processor_name(),
		"cpu_count": OS.get_processor_count(),
		"screen_refresh_hz": _finite(DisplayServer.screen_get_refresh_rate(), -1.0),
		"max_fps": Engine.max_fps,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"vsync_before": int(_vsync_before),
		"vsync_during": int(_vsync_after),
		"vsync_restored": int(_vsync_restored),
		"vsync_changed_by_benchmark": _vsync_changed,
		"headless": DisplayServer.get_name() == "headless",
	}

func _window_info() -> Dictionary:
	var size := DisplayServer.window_get_size()
	var viewport := get_viewport()
	var viewport_size := Vector2i.ZERO
	var scaling := 1.0
	if viewport != null:
		viewport_size = Vector2i(viewport.get_visible_rect().size)
		scaling = viewport.scaling_3d_scale
	var mode := "unknown"
	var mode_id := DisplayServer.window_get_mode()
	if mode_id == DisplayServer.WINDOW_MODE_FULLSCREEN: mode = "fullscreen"
	elif mode_id == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN: mode = "exclusive-fullscreen"
	elif mode_id == DisplayServer.WINDOW_MODE_MAXIMIZED: mode = "maximized"
	elif mode_id == DisplayServer.WINDOW_MODE_WINDOWED: mode = "windowed"
	return {"size": [size.x, size.y], "viewport_size": [viewport_size.x, viewport_size.y],
		"mode": mode, "scaling_3d": scaling}

func _engine_report() -> Dictionary:
	var samples := maxi(int(_engine.get("samples", 0)), 1)
	return {
		"sample_seconds": ENGINE_SAMPLE_SECONDS,
		"draw_calls_mean": float(int(_engine.get("viewport_draw_calls", 0))) / float(samples),
		"draw_calls_max": int(_engine.get("viewport_draw_calls_max", 0)),
		"primitives_mean": float(int(_engine.get("viewport_primitives", 0))) / float(samples),
		"primitives_max": int(_engine.get("viewport_primitives_max", 0)),
		"video_mem_peak_bytes": int(_engine.get("video_mem_peak_bytes", 0)),
		"object_nodes_peak": int(_engine.get("object_nodes_peak", 0)),
		"render_frames": stats.frame_count(),
		"source": "Viewport.get_render_info(RENDER_INFO_TYPE_VISIBLE) and Performance monitors; 0 means the GL compatibility renderer did not report it",
	}

func _particle_report() -> Dictionary:
	var report := {"source": "F10 combat metrics and the world particle pool snapshot",
		"allocated_slots": -1, "draw_slots": -1, "budget": -1, "backend": "", "quality": ""}
	if quality_controls != null and is_instance_valid(quality_controls):
		report["metrics"] = quality_controls.metrics
	if session == null or not is_instance_valid(session): return report
	if not ("combat" in session) or not is_instance_valid(session.combat): return report
	if not ("world_particles" in session.combat) or not is_instance_valid(session.combat.world_particles): return report
	var snapshot: Dictionary = session.combat.world_particles.snapshot()
	for key: String in ["allocated_slots", "draw_slots", "budget", "backend", "quality", "active_emitters", "pool_nodes", "buffer_payload_estimate_bytes"]:
		if snapshot.has(key): report[key] = snapshot[key]
	return report

func _combat_report() -> Dictionary:
	var report := {"shots": 0, "explosions": 0, "launches": 0, "local_launches": 0, "hits": 0, "hurts": 0,
		"local_deaths": 0, "local_weapon": -1, "local_weapon_name": "", "local_ammo": ""}
	if session == null or not is_instance_valid(session): return report
	if "combat" in session and is_instance_valid(session.combat):
		for key: String in ["shots", "explosions", "launches", "local_launches", "hits", "hurts"]:
			report[key] = int(session.combat.get(key))
	report["local_deaths"] = int(session.presentation.lifecycle.death_transitions)
	var actor: Dictionary = session.presentation.local_actor
	var weapon := int(actor.get("weapon", -1))
	report["local_weapon"] = weapon
	report["local_weapon_name"] = WeaponSelection.weapon_name(weapon)
	var ammo: Variant = actor.get("ammo")
	if ammo is Array:
		var parts := PackedStringArray()
		for value: Variant in ammo: parts.append(str(value))
		report["local_ammo"] = ",".join(parts)
	return report

## Reporting the preset is the driver's job; applying it is the quality manager's
## documented API. The printed numbers are always measured before it is applied.
func _recommendation(p95_ms: float, level: int) -> Dictionary:
	if level < 0 or quality_controls == null or not is_instance_valid(quality_controls):
		return {"level": -1, "name": "", "basis": "unavailable: no quality manager was bound"}
	if p95_ms <= 0.0:
		return {"level": -1, "name": "", "basis": "unavailable: the run produced no frame samples"}
	var recommendation: Dictionary = quality_controls.recommendation_for(p95_ms, level)
	var applied := int(quality_controls.apply_recommended(p95_ms))
	recommendation["applied_level"] = applied
	recommendation["applied_name"] = str(LEVELS[clampi(applied, 0, LEVELS.size() - 1)])
	recommendation["applied_note"] = "the reported frame times were measured before this preset was applied"
	return recommendation

static func _finite(value: float, fallback: float) -> float:
	return value if is_finite(value) else fallback

## --- artifacts -------------------------------------------------------------

func _output_dir() -> String:
	var configured := OS.get_environment(ENV_OUTPUT).strip_edges()
	if not configured.is_empty(): return configured
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("user://benchmark-results")
	return OS.get_executable_path().get_base_dir().path_join("benchmark-results")

func _capture_at(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var directory := _output_dir()
	if not _ensure_directory(directory).is_empty(): return
	var path := directory.path_join("benchmark-%s-%s.png" % [_stamp, name])
	await RenderingServer.frame_post_draw
	if not is_inside_tree(): return
	var viewport := get_viewport()
	if viewport == null: return
	var image := viewport.get_texture().get_image()
	if image == null: return
	if image.save_png(path) != OK: return
	_captures.append({"file": path, "phase": name, "width": image.get_width(), "height": image.get_height()})

func _publish(data: Dictionary) -> void:
	await _flush_captures()
	var directory := _output_dir()
	var json_path := directory.path_join("benchmark-%s.json" % _stamp)
	var write_error := _ensure_directory(directory)
	var captures: Array = _captures
	data["artifacts"] = {"directory": directory, "json": json_path, "captures": captures, "write_error": write_error}
	var result := Report.build(data)
	if not write_error.is_empty():
		result.honesty.notes.append("Artifacts were not written: " + write_error)
	var written := _write_json(json_path, result) if write_error.is_empty() else false
	result.artifacts["json_written"] = written
	if not written and write_error.is_empty():
		result.honesty.notes.append("Artifacts could not be written to " + json_path)
	print(Report.result_line(result))
	print("BENCHMARK_ARTIFACTS ", JSON.stringify({"json": json_path, "written": written, "captures": _capture_names(captures)}))
	_summary(result)
	finished.emit(result)

func _flush_captures() -> void:
	while not _capture_queue.is_empty():
		var entry: Dictionary = _capture_queue.pop_front()
		await _capture_at(str(entry.name))

func _capture_names(captures: Array) -> Array:
	var names: Array = []
	for entry: Dictionary in captures:
		names.append(str(entry.get("file", "")))
	return names

func _write_json(path: String, result: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(Report.json(result))
	file.close()
	return FileAccess.file_exists(path)

func _ensure_directory(directory: String) -> String:
	if directory.is_empty(): return "no artifact directory was resolved"
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK and not DirAccess.dir_exists_absolute(directory):
		return "artifact directory could not be created: " + directory
	var probe := FileAccess.open(directory.path_join(".benchmark-write-probe"), FileAccess.WRITE)
	if probe == null: return "artifact directory is not writable: " + directory
	probe.close()
	DirAccess.remove_absolute(directory.path_join(".benchmark-write-probe"))
	return ""

func _summary(result: Dictionary) -> void:
	var aggregate: Dictionary = result.aggregate
	if not is_instance_valid(presentation): return
	var text := "BENCHMARK %s · median %.1f ms · p95 %.1f ms · max %.1f ms · %d frames" % [
		"complete" if result.complete else "incomplete",
		float(aggregate.get("median_ms", 0.0)), float(aggregate.get("p95_ms", 0.0)),
		float(aggregate.get("max_ms", 0.0)), int(aggregate.get("samples", 0))]
	var level := str(result.recommendation.get("applied_name", ""))
	if not level.is_empty(): text += "\nrecommended effects preset: " + level + " (applied; press F9 to change)"
	text += "\nsaved " + str(result.artifacts.get("json", ""))
	presentation.result({"text": text})
