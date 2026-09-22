extends SceneTree
const Demo = preload("res://shader_lab/demo.tscn")
const Factory = preload("res://shader_lab/factory.gd")
var output := ""
var size := Vector2i(960, 640)
var results := {}
var failure := false
var gallery: Node3D

func _initialize() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		push_error("SHADER_LAB_GRAPHICS watchdog timeout")
		quit(1))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--size="):
			var values := arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(values[0]), int(values[1]))
	call_deferred("capture")

func check(condition: bool, message: String) -> void:
	if not condition:
		failure = true
		push_error("SHADER_LAB_GRAPHICS: " + message)

func frame(name: String = "") -> Image:
	for index in range(5): await process_frame
	if gallery != null:
		gallery._update_hud()
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_size() == size, "actual screenshot dimensions")
	if not name.is_empty():
		check(image.save_png(output.path_join(name + ".png")) == OK, "save " + name)
	return image

func difference(a: Image, b: Image, area: Rect2i) -> Dictionary:
	var changed := 0
	var total := 0.0
	var maximum := 0.0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var delta := maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b)))
			if delta > 0.025: changed += 1
			total += delta
			maximum = maxf(maximum, delta)
	return {"changed_pixels": changed, "mean_max_channel_delta": total / float(area.size.x * area.size.y), "max_delta": maximum, "rect": [area.position.x, area.position.y, area.size.x, area.size.y]}

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame

func capture() -> void:
	check(not output.is_empty(), "output required")
	if failure: quit(1); return
	root.size = size
	gallery = Demo.instantiate()
	root.add_child(gallery)
	await process_frame
	await key(KEY_2)
	check(gallery.selected == 1, "keyboard selection routes through real input")
	await key(KEY_SPACE)
	check(gallery.paused, "space pauses")
	gallery.set_time(2.0)
	var paused_clock: float = gallery.seconds
	for index in range(8): await process_frame
	check(gallery.seconds == paused_clock, "pause holds caller clock across frames")
	await key(KEY_EQUAL)
	check(is_equal_approx(gallery.intensity, 1.1), "keyboard intensity")
	await key(KEY_R)
	check(gallery.seconds < 0.1 and not gallery.paused and gallery.intensity == 1.0, "keyboard reset")
	await key(KEY_3)
	await key(KEY_BRACKETRIGHT)
	check(is_equal_approx(gallery.phase_amount, 0.48), "phase step control")
	var original_yaw: float = gallery.yaw
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(200, 200)
	Input.parse_input_event(click)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(30, 5)
	motion.position = Vector2(230, 205)
	Input.parse_input_event(motion)
	await process_frame
	check(gallery.yaw != original_yaw, "mouse orbit control")
	click.pressed = false
	Input.parse_input_event(click)
	gallery.reset_gallery()
	gallery.paused = true
	gallery.capture_mode = true
	gallery.set_process(false)
	# Exclude the HUD/sidebar/footer entirely, including renderer statistic text.
	var roi := Rect2i(30, 112, size.x - (374 if size.x >= 1100 else 344), size.y - 240)
	for index in range(3):
		gallery.select_effect(index)
		gallery.set_time(1.25)
		gallery._update_hud()
		var name: String = gallery.KEYS[index]
		var material: ShaderMaterial = gallery.materials[index]
		var baseline := await frame(name + "-t1")
		var repeated := await frame()
		var freeze := difference(baseline, repeated, roi)
		check(freeze.max_delta == 0.0, name + " has exact rendered pause")
		gallery.set_time(3.75)
		gallery._update_hud()
		var moved := await frame(name + "-t2")
		var time_delta := difference(baseline, moved, roi)
		check(time_delta.changed_pixels > 80, name + " caller time visibly contributes")
		gallery.set_time(1.25)
		gallery.factory.configure(material, {"effect_enabled": false})
		gallery._update_hud()
		var disabled := await frame(name + "-disabled")
		var effect_delta := difference(baseline, disabled, roi)
		check(effect_delta.changed_pixels > 300, name + " enabled effect visibly contributes")
		gallery.factory.configure(material, {"effect_enabled": true})
		results[name] = {"pause": freeze, "time": time_delta, "effect": effect_delta}
		if size.x == 1280:
			for option: String in ["normal_strength", "field_strength", "lut_strength"]:
				var initial: float = gallery.factory.material_state(material).options[option]
				gallery.factory.configure(material, {option: 0.0})
				var without := await frame(name + "-without-" + option)
				var delta := difference(baseline, without, roi)
				results[name][option] = delta
				# Sparse original LUT masks can legitimately affect very few pixels.
				check(delta.changed_pixels > (0 if option == "lut_strength" else 20), name + " Moth " + option + " contribution")
				gallery.factory.configure(material, {option: initial})
		if index == 2:
			gallery.phase_amount = 0.0
			gallery.factory.configure(material, {"dissolve": 0.0})
			var full := await frame("phase-full")
			check(difference(full, disabled, roi).max_delta == 0.0, "phase zero is exactly intact opaque source")
			gallery.phase_amount = 1.0
			gallery.factory.configure(material, {"dissolve": 1.0})
			var empty := await frame("phase-empty")
			check(difference(full, empty, roi).changed_pixels > 1000, "phase one removes static prop")
			gallery.phase_amount = 0.43
			gallery.factory.configure(material, {"dissolve": 0.43})
	results.proxy = await performance_proxy()
	var factory_ref: WeakRef = weakref(gallery.factory)
	var material_refs: Array[WeakRef] = []
	for material: ShaderMaterial in gallery.materials: material_refs.append(weakref(material))
	gallery.queue_free()
	gallery = null
	for index in range(3): await process_frame
	check(factory_ref.get_ref() == null, "gallery factory freed on scene exit")
	for reference: WeakRef in material_refs: check(reference.get_ref() == null, "gallery material freed on scene exit")
	await alpha_occlusion()
	results.renderer = {"method": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "api": RenderingServer.get_video_adapter_api_version(), "size": [size.x, size.y]}
	results.passed = not failure
	var file := FileAccess.open(output.path_join("measurements.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t") + "\n")
	print("SHADER_LAB_GRAPHICS_%s size=%s" % ["OK" if not failure else "FAIL", size])
	quit(1 if failure else 0)

func performance_proxy() -> Dictionary:
	var report := {}
	for index in range(3):
		gallery.select_effect(index)
		for warm in range(10): await process_frame
		var times: Array[float] = []
		var previous := Time.get_ticks_usec()
		for sample in range(60):
			gallery.set_time(1.0 + float(sample) / 60.0)
			await process_frame
			var now := Time.get_ticks_usec()
			times.append(float(now - previous) / 1000.0)
			previous = now
		times.sort()
		await RenderingServer.frame_post_draw
		report[gallery.KEYS[index]] = {"median_frame_ms": times[30], "p95_frame_ms": times[56], "draw_calls": root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME), "primitives": root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME), "samples": times.size(), "note": "Software llvmpipe wall-clock proxy with HUD; not hardware acceptance or GPU timestamp. Viewport visible-pass counters, not delayed Performance monitors."}
	return report

func alpha_occlusion() -> void:
	var rig := Node3D.new()
	root.add_child(rig)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.0
	camera.position = Vector3(0, 0, 6)
	camera.current = true
	rig.add_child(camera)
	var factory := Factory.new()
	var material := factory.create_material("shield")
	factory.update_time(1.25)
	var sphere := SphereMesh.new()
	sphere.radius = 1.4
	sphere.height = 2.8
	var shell := MeshInstance3D.new()
	shell.mesh = sphere
	shell.material_override = material
	rig.add_child(shell)
	for spec: Array in [[Vector3(2, 1.25, 0.1), Vector3(0, 0, -0.3), Color("e9a34b")], [Vector3(0.24, 3.25, 0.1), Vector3(0.55, 0, 2), Color("dae6f0")]]:
		var block := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = spec[0]
		block.mesh = mesh
		block.position = spec[1]
		var plain := StandardMaterial3D.new()
		plain.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		plain.albedo_color = spec[2]
		block.material_override = plain
		rig.add_child(block)
	var on := await frame("alpha-depth-on")
	factory.configure(material, {"effect_enabled": false})
	var off := await frame("alpha-depth-off")
	var protected := camera.unproject_position(Vector3(0.55, 0, 2))
	var occluder := difference(on, off, Rect2i(Vector2i(protected) - Vector2i(8, 160), Vector2i(16, 320)))
	check(occluder.max_delta == 0.0, "opaque foreground occludes transparent shader exactly")
	var corners: Array[Dictionary] = []
	for x: float in [-1.27, 1.27]:
		for y: float in [-1.27, 1.27]:
			var pixel := camera.unproject_position(Vector3(x, y, 0))
			var delta := difference(on, off, Rect2i(Vector2i(pixel) - Vector2i(5, 5), Vector2i(10, 10)))
			corners.append(delta)
			check(delta.max_delta == 0.0, "no solid rectangle at bounding-square corners")
	var center := Vector2i(camera.unproject_position(Vector3.ZERO))
	var see_through := on.get_pixelv(center)
	check(see_through.r > 0.4 and see_through.g > 0.25, "warm opaque rear plate remains visible through shell")
	results.alpha_depth = {"foreground_occluder": occluder, "corners": corners, "center_rgb": [see_through.r, see_through.g, see_through.b]}
	rig.queue_free()
	await process_frame
