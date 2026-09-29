extends SceneTree
## Seven real subviewport frames at one weapon pose, one lighting setup.
const Rig = preload("res://first_person/rig.gd")
const Catalog = preload("res://first_person/generated/finishes.gd")
var directory := ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-out="): directory = arg.trim_prefix("--evidence-out=")
	call_deferred("run")

func run() -> void:
	if directory.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(directory)
	root.size = Vector2i(640, 400)
	var camera := Camera3D.new()
	root.add_child(camera)
	var rig := Rig.new()
	root.add_child(rig)
	rig.attach_to(camera)
	rig.set_process(false)
	rig.reduced_motion = true
	var sheet := Image.create_empty(640 * 7, 400, false, Image.FORMAT_RGBA8)
	var baseline: Image
	var metrics: Array[Dictionary] = []
	var names: Array[String] = ["stock"]
	for key: String in Catalog.PALETTES: names.append(key)
	for index: int in names.size():
		var key := names[index]
		rig.apply_actor({"id":7,"weapon":0,"health":100,"finish":key if key != "stock" else null}, true)
		# Fixed hip pose, zero time-based sway and no ADS/reload/recoil/muzzle FX.
		rig.switch_remaining = 0.0
		rig.age = 0.0
		rig.advance(0.0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image := rig.viewport.get_texture().get_image()
		if image.get_size() != Vector2i(640,400):
			push_error("Invalid viewport image size: " + str(image.get_size()))
			quit(1)
			return
		image.convert(Image.FORMAT_RGBA8)
		image.save_png(directory.path_join("%s.png" % key))
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(index * 640, 0))
		if baseline == null: baseline = image
		var changed := 0
		var occupied := 0
		for y: int in range(80, 390, 2):
			for x: int in range(100, 600, 2):
				var color := image.get_pixel(x,y)
				if color.a > 0.5:
					occupied += 1
					var stock_color := baseline.get_pixel(x,y)
					if maxf(absf(color.r-stock_color.r), maxf(absf(color.g-stock_color.g),absf(color.b-stock_color.b))) > 0.12: changed += 1
		metrics.append({"finish":key,"opaque_samples":occupied,"changed_from_stock":changed})
		if occupied < 1000 or (index > 0 and changed < 100):
			push_error("Finish not visibly distinct: " + str(metrics.back()))
			quit(1)
			return
	sheet.save_png(directory.path_join("contact-sheet.png"))
	var file := FileAccess.open(directory.path_join("metrics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics, "\t") + "\n")
	file.close()
	print("FIRST_PERSON_FINISHES_CAPTURE ", JSON.stringify(metrics))
	rig.free()
	camera.free()
	quit(0)
