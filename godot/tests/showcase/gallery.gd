extends SceneTree
## Fixed native viewpoints, plus real spawn camera. No shared scene/session is loaded.
const DEMO = preload("res://showcase/demo.tscn")
var output := ""
var size := Vector2i(1280, 800)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.get_slice("=", 1)
		if arg.begins_with("--size="):
			var parts := arg.get_slice("=", 1).split("x")
			size = Vector2i(int(parts[0]), int(parts[1]))
	root.size = size
	root.content_scale_size = size
	call_deferred("capture")

func capture() -> void:
	if output.is_empty():
		push_error("--output is required")
		quit(1)
		return
	var scene := DEMO.instantiate()
	root.add_child(scene)
	for frame in 16: await process_frame
	var results: Array[Dictionary] = []
	for index in [-1, 0, 1, 2, 3, 4]:
		scene.set_viewpoint(index)
		var name: String = ["spawn", "atrium", "turbine", "garden", "vista", "overview"][index + 1]
		var elapsed_ms := 0.0
		for frame in 12:
			var start := Time.get_ticks_usec()
			await process_frame
			elapsed_ms += (Time.get_ticks_usec() - start) / 1000.0
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var path := output.path_join("%s-%dx%d.png" % [name, size.x, size.y])
		if image.get_size() != size or image.save_png(path) != OK:
			push_error("Screenshot dimensions/write failure: " + path)
			quit(1)
			return
		results.append({"name": name, "size": [size.x, size.y], "frame_wall_ms_mean": elapsed_ms / 12, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
		print("PRISM_SCREENSHOT ", path)
	var file := FileAccess.open(output.path_join("gallery-%dx%d.json" % [size.x, size.y]), FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer": RenderingServer.get_video_adapter_name(), "features": scene.feature_summary(), "views": results}, "\t") + "\n")
	scene.queue_free()
	for frame in 3: await process_frame
	print("PRISM_GALLERY_OK sizes_asserted=true views=6")
	quit()
