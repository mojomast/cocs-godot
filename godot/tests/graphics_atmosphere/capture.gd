extends SceneTree

const Atmosphere = preload("res://graphics_atmosphere/atmosphere.gd")
const REVIEW_MAPS := ["meridian-exchange", "ember-crucible", "asterion-relay"]

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0]
	var phase := args[1]
	var viewer = load("res://world/viewer.gd").new()
	root.add_child(viewer)
	viewer.set_process(false)
	var controller := Atmosphere.new()
	var manifest: Array = []
	for id: String in viewer.ids:
		if args.size() > 2 and id != args[2]: continue
		if phase == "before" and not id in REVIEW_MAPS: continue
		if not viewer.load_map(id):
			quit(1)
			return
		var map: Dictionary = viewer.catalog.resolve_map(id)
		if phase == "after":
			var texture := load("res://tests/graphics_atmosphere/fixtures/" + Atmosphere.sky_name(map) + ".png") as Texture2D
			controller.configure(map, viewer.environment, viewer.sun, texture)
			controller.decorate(viewer.world)
		# No camera, source or scene differences between before and after.
		var views := ["overview", "street"] if id in REVIEW_MAPS else ["overview"]
		for view: String in views:
			viewer.camera.fov = 72
			viewer.camera.position = Vector3(43, 24, 49) if id == "meridian-exchange" else Vector3(75, 32, 73)
			var target := Vector3(-4, 3, -7)
			if view == "street":
				match id:
					"meridian-exchange":
						viewer.camera.position = Vector3(9, 2.2, 21)
						target = Vector3(-13, 4, -19)
					"ember-crucible":
						viewer.camera.position = Vector3(-38, viewer.support_height(map, -38, 27) + 2.2, 27)
						target = Vector3(4, 5, -8)
					"asterion-relay":
						viewer.camera.position = Vector3(-84, viewer.support_height(map, -84, 18) + 2.2, 18)
						target = Vector3(0, 5, -5)
			viewer.camera.look_at(target)
			viewer.label.text = "%s · %s · %s\nOffline atmosphere art review · matched camera · FOV 72" % [map.name, phase.to_upper(), view]
			for frame in range(8):
				await process_frame
				await RenderingServer.frame_post_draw
			var path := output.path_join(id + "-" + view + ".png")
			var image := root.get_texture().get_image()
			if image.save_png(path) != OK:
				quit(1)
				return
			manifest.append({"map": id, "view": view, "phase": phase, "position": [viewer.camera.position.x, viewer.camera.position.y, viewer.camera.position.z], "target": [target.x, target.y, target.z], "fov": 72, "width": image.get_width(), "height": image.get_height(), "key": viewer.sun.light_energy, "ambient": viewer.environment.environment.ambient_light_energy, "fog_density": viewer.environment.environment.fog_density})
			print("ATMOSPHERE_CAPTURE ", id, " ", phase, " ", view, " ", image.get_size())
		if phase == "after":
			# Real GL horizon probe, independent of the analytic shader formula.
			# Remove only the world from this diagnostic view, then compare pixels
			# on either side of the actual horizon over many azimuth samples.
			viewer.world.visible = false
			viewer.camera.position = Vector3.ZERO
			viewer.camera.rotation = Vector3.ZERO
			for frame in range(3):
				await process_frame
				await RenderingServer.frame_post_draw
			var horizon_image := root.get_texture().get_image()
			var center := horizon_image.get_height() / 2
			var maximum_jump := 0.0
			for x in range(32, horizon_image.get_width() - 32, 16):
				var a := horizon_image.get_pixel(x, center - 2)
				var b := horizon_image.get_pixel(x, center + 2)
				maximum_jump = maxf(maximum_jump, maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))))
			if maximum_jump > 0.025:
				push_error("Visible sky horizon discontinuity: " + id + " jump=" + str(maximum_jump))
				quit(1)
				return
			horizon_image.get_region(Rect2i(0, center - 16, horizon_image.get_width(), 32)).save_png(output.path_join(id + "-horizon-strip.png"))
			print("ATMOSPHERE_HORIZON map=", id, " max_channel_jump=", maximum_jump)
	var file := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.close()
	controller.clear(viewer.environment)
	viewer.free()
	controller = null
	await process_frame
	await process_frame
	print("ATMOSPHERE_GRAPHICAL_SMOKE phase=", phase, " captures=", manifest.size())
	quit(0)
