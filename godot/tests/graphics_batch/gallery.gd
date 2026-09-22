extends SceneTree
## Matched static camera evidence, never a live gameplay claim.
const Viewer = preload("res://world/viewer.gd")
var output := ""
var label_prefix := ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--gallery-output="): output = arg.trim_prefix("--gallery-output=")
		if arg.begins_with("--gallery-label="): label_prefix = arg.trim_prefix("--gallery-label=")
	call_deferred("capture")

func capture() -> void:
	if output.is_empty():
		push_error("Gallery requires --gallery-output")
		quit(1)
		return
	var viewer := Viewer.new()
	root.add_child(viewer)
	await process_frame
	viewer.selector.hide()
	for size: Vector2i in [Vector2i(960,640), Vector2i(1280,800)]:
		root.size = size
		for id: String in viewer.ids:
			if not viewer.load_map(id):
				quit(1)
				return
			var map: Dictionary = viewer.catalog.resolve_map(id)
			var bounds: Dictionary = map.bounds
			var center := Vector3((float(bounds.minX)+float(bounds.maxX))*.5, 2, (float(bounds.minZ)+float(bounds.maxZ))*.5)
			var radius := maxf(float(bounds.maxX)-float(bounds.minX),float(bounds.maxZ)-float(bounds.minZ))
			for view: String in ["overview", "spawn"]:
				if view == "overview":
					viewer.camera.position = center + Vector3(radius*.48,radius*.38,radius*.52)
				else:
					var spawn: Array = map.spawns[0]
					viewer.camera.position = Vector3(spawn[0],viewer.support_height(map,spawn[0],spawn[1])+1.45,spawn[1])
				viewer.camera.look_at(center)
				viewer.label.text = "%s · %s · %s\nSTATIC MATCHED CAMERA · %dx%d" % [label_prefix,id,view,size.x,size.y]
				for frame in range(5): await process_frame
				await RenderingServer.frame_post_draw
				var path := output.path_join("%s-%s-%dx%d.png" % [id,view,size.x,size.y])
				if root.get_texture().get_image().save_png(path) != OK:
					push_error("Gallery image write failed")
					quit(1)
					return
	viewer.queue_free()
	await process_frame
	print("GRAPHICS_GALLERY_OK maps=9 views=2 sizes=2 static=true")
	quit(0)
