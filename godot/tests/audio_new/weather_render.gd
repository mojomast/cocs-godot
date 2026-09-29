extends SceneTree
## Same-authority-state visual A/B probe. Requires a real renderer, not a
## --headless Dummy renderer. No gameplay state/input/collision is touched.
const Weather = preload("res://ambience/weather_service.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(384, 256)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_3d = World3D.new()
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 12)
	camera.fov = 90
	camera.far = 50
	viewport.add_child(camera)
	camera.look_at(Vector3(0, 7, 0))
	camera.make_current()
	var weather := Weather.new()
	viewport.add_child(weather)
	weather.bind({"id":"frost-gate","biome":"snow","sky":"day"}, camera, "playing", 73)
	var state := {"time":9.5,"singleplayer":{"weather":"rain","timeOfDay":"day"}}
	weather.apply_snapshot(state)
	weather.apply_settings({"weather_enabled":true,"weather_quality":100,"reduced_motion":false,"lightning_flashes":true,"ambience_enabled":false})
	weather.set_native_weather_suppressed(true)
	weather.tick(0.05)
	assert(weather.diagnostics().particles > 0)
	for i in 3: await RenderingServer.frame_post_draw
	var wet: Image = viewport.get_texture().get_image()
	weather.apply_settings({"weather_enabled":false,"weather_quality":100,"reduced_motion":false,"ambience_enabled":false})
	weather.apply_snapshot(state)
	weather.tick(0.05)
	assert(weather.diagnostics().particles == 0)
	for i in 3: await RenderingServer.frame_post_draw
	var dry: Image = viewport.get_texture().get_image()
	assert(wet != null and dry != null and wet.get_size() == dry.get_size())
	var difference := 0
	for y in wet.get_height():
		for x in wet.get_width():
			var a := wet.get_pixel(x, y)
			var b := dry.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.08: difference += 1
	if difference <= 15:
		push_error("WEATHER_RENDER_MISSING same-authority rain-on/off image differences=%d" % difference)
		quit(1)
		return
	var output := OS.get_environment("COCS_WEATHER_CAPTURE_DIR")
	if output.is_absolute_path():
		DirAccess.make_dir_recursive_absolute(output)
		wet.save_png(output.path_join("rain-on.png"))
		dry.save_png(output.path_join("rain-off.png"))
	print("WEATHER_RENDER_OK differing_pixels=",difference," state_time=",state.time)
	quit(0)
