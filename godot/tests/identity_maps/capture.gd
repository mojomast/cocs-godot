extends SceneTree
const MapBuilder = preload("res://identity_maps/map.gd")
var stage: Node3D
var camera: Camera3D
var output := ""
var width := 1280
var height := 800
var graybox := false
var glow := false
var ids: Array = MapBuilder.IDS
var report: Dictionary = {"scope":"Static inspection renders; no actors/gameplay/particles", "maps":[]}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--map="): ids = [arg.trim_prefix("--map=")]
		if arg.begins_with("--size="):
			var s := arg.trim_prefix("--size=").split("x")
			width = s[0].to_int()
			height = s[1].to_int()
		if arg == "--graybox": graybox = true
		if arg == "--glow": glow = true
	if output.is_empty():
		push_error("--output is required")
		quit(2)
		return
	root.size = Vector2i(width,height)
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")

func run() -> void:
	# Engine startup reapplies project window size after _initialize.
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(width,height)
	await process_frame
	report.engine = Engine.get_version_info().string
	report.adapter = RenderingServer.get_video_adapter_name()
	report.renderer = RenderingServer.get_current_rendering_method()
	report.resolution = [width,height]
	report.glow = glow
	for id: String in ids:
		stage = Node3D.new()
		root.add_child(stage)
		var map := MapBuilder.new()
		stage.add_child(map)
		if not map.build(id,graybox):
			quit(2)
			return
		var world := WorldEnvironment.new()
		world.environment = Environment.new()
		world.environment.background_mode = Environment.BG_COLOR
		world.environment.background_color = Color("142b4a") if id == "nacre-engine" else Color("a3bbc7")
		world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.environment.ambient_light_color = Color("c6d3e2")
		world.environment.ambient_light_energy = 0.6
		world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		world.environment.glow_enabled = glow
		stage.add_child(world)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-48,-28,0)
		light.light_color = Color("fff0d3")
		light.light_energy = 1.2
		light.shadow_enabled = true
		stage.add_child(light)
		camera = Camera3D.new()
		camera.far = 180
		camera.fov = 72
		stage.add_child(camera)
		camera.current = true
		var entry: Dictionary = {"id":id,"geometry":map.metrics,"cameras":[]}
		for view: Dictionary in map.recipe.cameras:
			camera.position = Vector3(view.at[0],view.at[1],view.at[2])
			camera.look_at(Vector3(view.target[0],view.target[1],view.target[2]))
			for i in range(12): await process_frame
			var samples: Array[float] = []
			var previous := Time.get_ticks_usec()
			for i in range(40):
				await process_frame
				var now := Time.get_ticks_usec()
				samples.append(float(now-previous)/1000.0)
				previous = now
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			if image.get_width() != width or image.get_height() != height:
				push_error("Actual image dimensions differ from request: %s" % image.get_size())
				quit(4)
				return
			var filename := "%s-%s-%dx%d%s.png" % [id,view.id,width,height,"-graybox" if graybox else ""]
			var error := image.save_png(output.path_join(filename))
			if error != OK: push_error("Failed image save"); quit(3); return
			samples.sort()
			entry.cameras.append({"id":view.id,"file":filename,"median_ms":samples[20],"p95_ms":samples[37],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})
		report.maps.append(entry)
		stage.queue_free()
		for i in range(3): await process_frame
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("IDENTITY_CAPTURE ",JSON.stringify(report))
	quit(0)
