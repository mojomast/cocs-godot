extends SceneTree
const Demo = preload("res://particle_lab/demo.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var amount := int(args[1])
	var preset := args[2]
	var backend := args[3]
	var scale := float(args[4])
	var energy := float(args[5]) if args.size() > 5 else 0.85
	var scene = Demo.instantiate()
	root.add_child(scene)
	scene._orbit = false
	scene._yaw = 0.55
	scene._pitch = 0.48 if preset == "galaxy" else 0.26
	scene._place_orbit()
	scene._scale_index = 2 if scale == 0.5 else (1 if scale == 0.75 else 0)
	scene._resize()
	scene._preset_index = scene.Field.PRESETS.find(preset)
	scene._count_index = scene.Field.COUNTS.find(amount)
	check(scene.field.configure(amount, preset, backend).ok, "Requested capture configuration")
	# Explicit authored test setting, not density adaptation. Keep the SAME
	# 0.34m quads, 0.85 energy and 100% render scale across the count sweep.
	scene.field.set_appearance(0.34, energy)
	var started := Time.get_ticks_msec()
	for _frame in 8: await RenderingServer.frame_post_draw
	var warmup_ms := Time.get_ticks_msec() - started
	scene.metrics.reset()
	var measurement_start := Time.get_ticks_msec()
	for _frame in 120:
		await RenderingServer.frame_post_draw
		if Time.get_ticks_msec() - measurement_start > 15000 and scene.metrics.total_frames >= 24:
			break
	var state: Dictionary = scene.statistics()
	state["warmup_render_frames"] = 8
	state["warmup_wall_ms"] = warmup_ms
	state["measurement_wall_ms"] = Time.get_ticks_msec() - measurement_start
	state["measurement"] = "wall-clock intervals between actual RenderingServer.frame_post_draw signals; not GPU timestamp timings"
	state["software_rendering"] = "llvmpipe" in str(state.adapter).to_lower()
	state["particle_quad_size_m"] = 0.34
	state["particle_energy"] = energy
	state["raw_intervals_ms"] = Array(scene.metrics._samples.slice(0, scene.metrics._size))
	check(state.draw_slots == amount, "Actual draw-slot count matches request")
	check(state.timing.samples >= 23 and state.timing.median_ms > 0, "Sufficient real render intervals")
	check(state.primitives >= amount * 2, "Native primitive counter includes all particle quads")
	if backend == "gpu": check(state.emitter_amount == amount and state.amount_ratio == 1.0, "Actual GPU emitter count")
	else: check(state.instance_count == amount and state.visible_instance_count == amount, "Actual MultiMesh visible count")
	scene._refresh_ui()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.save_png(out + "/capture.png") == OK, "Screenshot written")
	# Exercise actual scene input dispatch and visually stable pause with both
	# simulation and camera frozen; no forced draw()/fake rendering frames.
	scene.field.set_paused(true)
	for _frame in 3: await RenderingServer.frame_post_draw
	var paused_clock: float = scene.field.clock
	var pixels_before: PackedByteArray = scene.viewport.get_texture().get_image().get_data()
	for _frame in 3: await RenderingServer.frame_post_draw
	var pixels_after: PackedByteArray = scene.viewport.get_texture().get_image().get_data()
	check(scene.field.clock == paused_clock, "Paused field clock is constant")
	check(pixels_before == pixels_after, "Paused rendered particle target is byte-identical")
	scene.toggle_camera()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape releases capture through scene input dispatch")
	state["paused_image_identical"] = pixels_before == pixels_after
	state["escape_released"] = Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
	state["failures"] = failures
	state["ok"] = failures.is_empty()
	var file := FileAccess.open(out + "/metrics.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(state, "\t") + "\n")
	file.close()
	print("PARTICLE_LAB_CAPTURE " + JSON.stringify(state))
	scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
