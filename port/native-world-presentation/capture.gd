extends SceneTree

# Offline art-review camera, never a gameplay pose or live-session acceptance.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var viewer = load("res://world/viewer.gd").new()
	root.add_child(viewer)
	viewer.set_process(false)
	var args := OS.get_cmdline_user_args()
	var id: String = args[0]
	if not viewer.load_map(id):
		quit(1)
		return
	viewer.selector.select(viewer.ids.find(id))
	viewer.camera.position = Vector3(43, 24, 49) if id == "meridian-exchange" else Vector3(75, 32, 73)
	viewer.camera.look_at(Vector3(-4, 3, -7))
	viewer.camera.fov = 72
	print("ART_LIGHT sun=", viewer.sun.light_energy, " ambient=", viewer.environment.environment.ambient_light_energy, " wall=", viewer.style.wall)
	if args.size() > 2 and args[2] == "street":
		viewer.camera.position = Vector3(9, 2.2, 21)
		viewer.camera.look_at(Vector3(-13, 4, -19))
	for frame in range(8):
		await process_frame
		await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(args[1])
	print("NATIVE_WORLD_CAPTURE map=", id, " file=", args[1])
	viewer.queue_free()
	await process_frame
	await process_frame
	quit(result)
