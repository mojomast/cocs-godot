extends SceneTree
## Native nine-world review, three matched views per map. Offline visual evidence
## only; production wire journeys must be recorded separately.
const Look = preload("res://ambience/weather_look.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() > 0, "Pass an existing absolute output directory")
	var viewer = load("res://world/viewer.gd").new()
	root.add_child(viewer)
	if viewer.ids.size() != 9:
		push_error("Expected all nine source worlds; verify generated semantic content before capture")
		viewer.free()
		quit(1)
		return
	viewer.set_process(false)
	var look := Look.new()
	var report: Array = []
	for id: String in viewer.ids:
		assert(viewer.load_map(id))
		viewer.camera.position = Vector3(43, 24, 49)
		viewer.camera.look_at(Vector3(-4, 3, -7))
		viewer.camera.fov = 72
		var baseline: Environment = viewer.environment.environment
		var key: float = viewer.sun.light_energy
		var key_color: Color = viewer.sun.light_color
		var started := Time.get_ticks_usec()
		look.bind(viewer.world, viewer.environment, viewer.sun)
		var bind_us := Time.get_ticks_usec() - started
		for phase: String in ["before", "wet-only", "weather"]:
			look.apply("clear" if phase == "before" else "storm", 0.0, true)
			if phase == "wet-only":
				# Same illumination isolates the material response from exposure.
				var env: Environment = viewer.environment.environment
				env.fog_density = baseline.fog_density
				env.fog_light_color = baseline.fog_light_color
				env.tonemap_exposure = baseline.tonemap_exposure
				env.ambient_light_energy = baseline.ambient_light_energy
				env.ambient_light_color = baseline.ambient_light_color
				viewer.sun.light_energy = key
				viewer.sun.light_color = key_color
			viewer.label.text = "%s · %s · matched camera FOV 72" % [id, phase]
			for frame in 4:
				await process_frame
				await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(args[0].path_join(id + "-" + phase + ".png")) == OK)
			var row := look.diagnostics()
			row.merge({"map":id, "phase":phase, "bind_cpu_us":bind_us,
				"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
			report.append(row)
		look.clear()
	FileAccess.open(args[0].path_join("manifest.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	viewer.free()
	await process_frame
	print("WORLD_WEATHER_CAPTURE_OK images=", report.size())
	quit()
