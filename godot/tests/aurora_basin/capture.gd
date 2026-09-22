extends SceneTree
const Demo = preload("res://aurora_basin/demo.gd")
var output := "/tmp/opencode/aurora-landing.png"
var view := "landing"
var size := Vector2i(1280, 800)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--view="): view = arg.trim_prefix("--view=")
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(parts[0]), int(parts[1]))
	root.size = size
	root.content_scale_size = size
	call_deferred("run")

func run() -> void:
	var demo := Demo.new()
	root.add_child(demo)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	demo.set_process(false)
	demo.walker.set_physics_process(false)
	var pose: Dictionary = demo.map.camera_views()[view]
	demo.walker.position = pose.eye - Vector3.UP * 1.6
	demo.walker.look_at(Vector3(pose.target.x, demo.walker.position.y, pose.target.z))
	demo.walker.camera.look_at(pose.target)
	if view == "overview":
		demo.walker.camera.fov = 59.0
		demo.hud.visible = false
	var timings: Array[float] = []
	var previous := Time.get_ticks_usec()
	var node_count := 0
	var resource_count := 0
	for i in 84:
		await process_frame
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		if i >= 24: timings.append((now - previous) / 1000.0)
		previous = now
		if i == 23:
			node_count = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			resource_count = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	if node_count != int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) or resource_count != int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)):
		push_error("AURORA_CAPTURE node/resource count changed after warmup")
		quit(1)
		return
	var image := root.get_texture().get_image()
	if image.get_size() != size:
		push_error("AURORA_CAPTURE incorrect dimensions: " + str(image.get_size()))
		quit(1)
		return
	var error := image.save_png(output)
	if error != OK:
		push_error("AURORA_CAPTURE save failed: " + str(error))
		quit(1)
		return
	timings.sort()
	var total := 0.0
	for frame in timings: total += frame
	var report := {
		"view": view, "image": output, "width": size.x, "height": size.y, "eye_level": pose.eye_level,
		"eye": [pose.eye.x, pose.eye.y, pose.eye.z], "target": [pose.target.x, pose.target.y, pose.target.z],
		"renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(),
		"frames_measured": timings.size(), "warmup_frames": 24,
		"frame_ms_mean": total / timings.size(), "frame_ms_median": timings[timings.size() / 2], "frame_ms_p95": timings[int(timings.size() * 0.95)],
		"draw_calls_last_frame": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"rendered_primitives_last_frame": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"video_memory_bytes_reported": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"nodes_after_warmup": node_count, "nodes_at_end": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"resources_after_warmup": resource_count, "resources_at_end": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"map": demo.map.resource_report(), "engine": Engine.get_version_info()
	}
	var file := FileAccess.open(output + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print("AURORA_CAPTURE ", JSON.stringify(report))
	quit()
