extends SceneTree

const Demo = preload("res://cinder_array/demo.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0]
	var demo := Demo.new()
	root.add_child(demo)
	if demo.walker != null: demo.walker.set_physics_process(false)
	demo.set_physics_process(false)
	var camera := demo.camera
	if camera.get_parent() != demo:
		camera.reparent(demo)
	var views := [
		{"name": "arrival-eye", "eye": Vector3(-24, 8.6, 28), "target": Vector3(16, 10.5, -7)},
		{"name": "span-eye", "eye": demo.map.connection_point(demo.map.connections[0], 0.5) + Vector3.UP * 1.6, "target": Vector3(22, 15, -7)},
		{"name": "rim-eye", "eye": Vector3(-25, 17.6, -20.8), "target": Vector3(20, 9, 1)},
		{"name": "bore-eye", "eye": Vector3(14, 13.6, -31), "target": Vector3(-22, 15, -28)},
		{"name": "overview", "eye": Vector3(-49, 66, 57), "target": Vector3(0, 7, -6)},
	]
	var manifest: Array[Dictionary] = []
	for view: Dictionary in views:
		camera.position = view.eye
		camera.look_at(view.target)
		camera.fov = 76 if view.name != "overview" else 65
		demo.hud.update_location(demo.map.get_location(view.eye - Vector3.UP * 1.6), view.eye.y - 1.6)
		if view.name == "overview":
			demo.hud.update_location({"name": "CALDERA OVERVIEW", "code": "CA"}, 66)
		for i in range(12):
			await process_frame
			await RenderingServer.frame_post_draw
		var timings: Array[float] = []
		for i in range(24):
			var start := Time.get_ticks_usec()
			await process_frame
			await RenderingServer.frame_post_draw
			timings.append(float(Time.get_ticks_usec() - start) / 1000.0)
		timings.sort()
		var image := root.get_texture().get_image()
		var result := image.save_png(output.path_join(view.name + ".png"))
		if result != OK:
			push_error("Cannot save capture " + view.name)
			quit(1)
			return
		manifest.append({
			"view": view.name, "eye": [view.eye.x, view.eye.y, view.eye.z], "target": [view.target.x, view.target.y, view.target.z],
			"width": image.get_width(), "height": image.get_height(), "fov": camera.fov,
			"frame_median_ms": timings[timings.size() / 2], "frame_p95_ms": timings[ceili(timings.size() * 0.95) - 1],
			"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			"rendered_primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			"rendered_objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		})
		print("CINDER_CAPTURE ", JSON.stringify(manifest[-1]))
	# Hold a real rim-deck eye position fixed while only simulation time advances.
	# This checks visible molten motion independently of shader source inspection.
	camera.position = Vector3(-25, 17.6, -20.8)
	camera.look_at(Vector3(3, 0.45, 5))
	camera.fov = 76
	demo.hud.update_location({"name": "RIM / MOLTEN FLOW", "code": "05"}, 16)
	for i in range(5):
		await process_frame
		await RenderingServer.frame_post_draw
	var motion_a := root.get_texture().get_image()
	motion_a.save_png(output.path_join("lava-motion-a.png"))
	await create_timer(2.2).timeout
	await RenderingServer.frame_post_draw
	var motion_b := root.get_texture().get_image()
	motion_b.save_png(output.path_join("lava-motion-b.png"))
	var sampled := 0
	var changed := 0
	for y in range(int(motion_a.get_height() * 0.45), int(motion_a.get_height() * 0.87), 3):
		for x in range(int(motion_a.get_width() * 0.15), int(motion_a.get_width() * 0.85), 3):
			var a := motion_a.get_pixel(x, y)
			var b := motion_b.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.12: changed += 1
			sampled += 1
	var motion := {"seconds_apart_minimum": 2.2, "samples": sampled, "changed": changed, "changed_fraction": float(changed) / sampled, "camera_fixed": true, "eye_height": 1.6}
	print("CINDER_MOLTEN_MOTION ", JSON.stringify(motion))
	var file := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"views": manifest, "motion": motion, "geometry": demo.map.get_diagnostics(), "adapter": RenderingServer.get_video_adapter_name(), "godot": Engine.get_version_info().string}, "\t") + "\n")
	if motion.changed_fraction < 0.04:
		push_error("Molten surface did not visibly animate in the fixed-camera GL capture")
		quit(1)
		return
	print("CINDER_CAPTURE_COMPLETE")
	quit(0)
