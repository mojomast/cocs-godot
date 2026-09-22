extends SceneTree
const Field = preload("res://particle_lab/field.gd")
const Library = preload("res://moth/library.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func settle() -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw

func _run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 20, 100)
	camera.look_at(Vector3.ZERO)
	var field := Field.new()
	root.add_child(field)
	check(field.count == 0 and field.get_child_count() == 0, "No allocation before configure")
	check(field.configure(32768, "vortex", "gpu").ok, "Default true GPU simulation")
	check(field.gpu.amount == 32768 and field.gpu.amount_ratio == 1.0, "Actual GPU amount / ratio")
	check(field.gpu.fixed_fps == 0 and field.gpu.draw_order == GPUParticles3D.DRAW_ORDER_INDEX, "No fixed-step catch-up or CPU sorting")
	await settle()
	var ids := field.resource_ids()
	var before := field.snapshot()
	for malformed in [0, -4, 1048577, 1.5, NAN, INF, "1000000", null, {}, []]:
		check(not field.configure(malformed).ok, "Reject malformed count: %s" % str(malformed))
		check(field.count == before.requested_count and field.resource_ids() == ids, "Invalid count is transactional")
	for malformed in ["unknown", 3, null, []]:
		check(not field.configure(10, malformed).ok, "Reject malformed preset")
	for malformed in ["cpu", "", 5, null]:
		check(not field.configure(10, "vortex", malformed).ok, "Reject malformed backend")
	field.budget = 8192
	check(not field.configure(8193).ok, "Configurable map-instance budget enforced")
	field.budget = Field.HARD_LIMIT * 2
	check(not field.configure(Field.HARD_LIMIT + 1).ok, "Hard 1M ceiling enforced even with excessive budget")
	field.budget = Field.HARD_LIMIT
	for backend in ["gpu", "analytic"]:
		for preset in Field.PRESETS:
			for amount in [64, 8192, 1024]:
				check(field.configure(amount, preset, backend).ok, "Configure valid combination")
				check(field.resource_ids() == ids, "Node/material/MultiMesh identities are stable")
				check(field.clock == 0.0, "Count or preset change resets clock")
				var state := field.snapshot()
				check(state.draw_slots == amount and state.capacity == amount, "Exact capacity, no hidden preallocation")
				if backend == "analytic":
					check(field.multimesh.instance_count == amount and field.multimesh.visible_instance_count == amount, "Actual analytic instance counts")
					check(field.gpu.amount == 1 and not field.gpu.emitting, "Inactive GPU allocation released")
				else:
					check(field.gpu.amount == amount and field.multimesh.instance_count == 0, "Inactive MultiMesh allocation released")
				await settle()
		field.set_paused(true)
		var clock_before := field.clock
		await settle()
		check(field.clock == clock_before and field.gpu.speed_scale == 0.0, "Pause freezes clock and GPU step")
		field.reset()
		await settle()
		check(field.clock == 0.0 and field.paused, "Reset remains paused")
		field.set_paused(false)
		await settle()
		check(field.clock > 0.0 and field.gpu.speed_scale == 1.0, "Resume advances normal engine clock")
	var alpha_min := 1.0
	var alpha_max := 0.0
	var pixels := 0
	for texture in Library.effect("arc-burst").frames:
		var image: Image = texture.get_image()
		if image.is_compressed(): image.decompress()
		for y in image.get_height():
			for x in image.get_width():
				var alpha := image.get_pixel(x, y).a
				alpha_min = minf(alpha_min, alpha)
				alpha_max = maxf(alpha_max, alpha)
				pixels += 1
	check(alpha_min == 1.0 and alpha_max == 1.0, "Source alpha is opaque; shader must derive coverage")
	check(field.snapshot().effect_frames > 1, "Multiple authentic Moth effect frames")
	check(Library.texture("flow-field") != null and not Library.material_lut("entanglement").is_empty(), "Authentic Moth flow field and material LUT")
	var refs := [weakref(field.mesh), weakref(field.multimesh), weakref(field.draw_material), weakref(field.simulation_material)]
	field.dispose()
	field.dispose()
	check(field.get_child_count() == 0 and field.snapshot().draw_slots == 0, "Idempotent teardown releases child nodes and draw slots")
	check(not field.configure(8192).ok, "Disposed field cannot allocate")
	for ref in refs: check(ref.get_ref() == null, "Owned resources released")
	field.queue_free()
	await settle()
	# Cache is warm before measuring. Repeated creation + teardown exercises
	# lifetime behavior rather than comparing ordinary driver high-water marks.
	var memory_samples: Array[Dictionary] = []
	# Allocate the observer itself first, so its retained dictionaries do not
	# masquerade as monotonically growing effect memory.
	for cycle in 8:
		memory_samples.append({"cycle": cycle, "objects": 0, "resources": 0, "static_bytes": 0, "render_buffer_bytes": 0})
	for cycle in 8:
		var temporary := Field.new()
		root.add_child(temporary)
		temporary.configure(2048, Field.PRESETS[cycle % 4], "gpu" if cycle % 2 == 0 else "analytic")
		await settle()
		temporary.dispose()
		temporary.queue_free()
		await settle()
		memory_samples[cycle].objects = int(Performance.get_monitor(Performance.OBJECT_COUNT))
		memory_samples[cycle].resources = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
		memory_samples[cycle].static_bytes = int(Performance.get_monitor(Performance.MEMORY_STATIC))
		memory_samples[cycle].render_buffer_bytes = int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED))
	var initial: Dictionary = memory_samples[2]
	var final: Dictionary = memory_samples[-1]
	check(final.resources <= initial.resources + 2 and final.objects <= initial.objects + 4, "No accumulating resources/nodes after warmed teardown cycles")
	check(final.static_bytes <= initial.static_bytes + 2097152, "No >2MiB retained static-memory growth across warmed teardown cycles")
	print("PARTICLE_LAB_VERIFY " + JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures, "source_alpha_min": alpha_min, "source_alpha_max": alpha_max, "source_pixels_checked": pixels, "renderer": RenderingServer.get_current_rendering_method(), "display": DisplayServer.get_name(), "memory_cycles": memory_samples}))
	quit(0 if failures.is_empty() else 1)
