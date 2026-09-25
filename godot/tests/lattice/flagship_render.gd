extends SceneTree
## Native pixels from the real Board/World scenes; explicit synthetic layout fixture.
## Not ordinary gameplay or source-result evidence.

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var output := ""
	var view := "setup"
	var width := 1280
	var height := 720
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): output = arg.trim_prefix("--capture=")
		elif arg.begins_with("--view="): view = arg.trim_prefix("--view=")
		elif arg.begins_with("--width="): width = int(arg.trim_prefix("--width="))
		elif arg.begins_with("--height="): height = int(arg.trim_prefix("--height="))
	if output.is_empty() or view not in ["setup", "commands", "results", "board"] or width < 640 or height < 480:
		quit(2)
		return
	root.size = Vector2i(width, height)
	var scene: PackedScene = load("res://lattice/board.tscn" if view == "board" else "res://lattice/world_demo.tscn")
	var instance := scene.instantiate()
	root.add_child(instance)
	var annotation := CanvasLayer.new()
	root.add_child(annotation)
	var legend := Label.new()
	legend.text = "SYNTHETIC LAYOUT FIXTURE · NO LIVE SOURCE RESULT"
	legend.position = Vector2(12, height - 32)
	annotation.add_child(legend)
	if view == "commands":
		instance.session_panel.hide()
		instance.world_commands.show()
		instance.world_commands.world_refresh()
	elif view == "results":
		instance.session_panel.show_result({"mode":"cocs", "revision":1, "source_time":45,
			"outcome":{"winner":0,"reason":"time"},"scores":{"0":10,"1":8},
			"dominance":{"counts":{"0":3,"1":2},"team":0,"progress":12,"target":90,"remaining":78,"count":3,"fastCount":4,"breakCount":1}},
			{"mode":"cocs","map": "asterion-relay", "time_limit":900}, true)
	for _frame in range(3): await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	quit(image.save_png(output))
