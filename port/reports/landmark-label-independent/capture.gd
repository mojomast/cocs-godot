extends SceneTree
## Offline visual fixture: same authored landmark, near/far cameras, no authority.
const Viewer = preload("res://world/viewer.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var output := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--label-out="): output = arg.trim_prefix("--label-out=")
	assert(not output.is_empty())
	var viewer := Viewer.new()
	root.add_child(viewer)
	viewer.set_process(false)
	assert(viewer.load_map("tidal-citadel"))
	viewer.selector.hide()
	var landmark: Label3D
	for node: Node in viewer.find_children("*", "Label3D", true, false):
		if node.text == "WEST CITADEL": landmark = node
	assert(landmark != null)
	for distance: float in [6.0, 30.0]:
		viewer.camera.position = landmark.global_position + Vector3(distance, 0, 0)
		viewer.camera.look_at(landmark.global_position)
		viewer.label.text = "CONTROLLED OFFLINE VIEW · Tidal landmark · camera %.0f m away\nPresentation review only; no authoritative gameplay session" % distance
		await process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output + ("/near.png" if distance < 10 else "/far.png")) == OK)
		print("LANDMARK_CAPTURE ", JSON.stringify({"distance":distance, "camera":[viewer.camera.position.x,viewer.camera.position.y,viewer.camera.position.z], "label_begin":landmark.visibility_range_begin, "label_end":landmark.visibility_range_end}))
	viewer.queue_free()
	await process_frame
	quit(0)
