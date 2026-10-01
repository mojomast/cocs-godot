extends SceneTree
## Real-lit matched player-eye evidence. --render=/absolute/existing/directory
const Terrain = preload("res://campaign/terrain.gd")
const VIEWS := [
	{"id":"rootfall-verge", "name":"relay", "eye":Vector3(-53.28,7.89,-70.72), "target":Vector3(-41.21,8.9,-89.17), "fov":50.0},
	{"id":"rootfall-verge", "name":"wreck-close", "eye":Vector3(-48,7.9,-78), "target":Vector3(-43,8.8,-89.2), "fov":60.0},
	{"id":"crown-array", "name":"receiver", "eye":Vector3(-15.54,73.56,-52.49), "target":Vector3(-25.83,93.4,-27.59), "fov":65.0},
	{"id":"crown-array", "name":"receiver-side", "eye":Vector3(-39,74.5,-45), "target":Vector3(-25.83,93.4,-27.59), "fov":72.0},
]

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var output := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--render="): output = arg.trim_prefix("--render=")
	if output.is_empty() or not DirAccess.dir_exists_absolute(output):
		push_error("--render must name an existing absolute directory")
		quit(1)
		return
	root.size = Vector2i(1280,720)
	var scene := Node3D.new()
	root.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	camera.far = 1200
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("9bb8bb")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("cfddd8")
	env.environment.ambient_light_energy = 0.35
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-28,0)
	sun.light_color = Color("fff0d7")
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	scene.add_child(sun)
	var label := Label.new()
	label.position = Vector2(24,18)
	label.add_theme_font_size_override("font_size",25)
	label.add_theme_color_override("font_outline_color",Color.BLACK)
	label.add_theme_constant_override("outline_size",5)
	root.add_child(label)
	for view: Dictionary in VIEWS:
		var terrain := Terrain.new()
		scene.add_child(terrain)
		assert(terrain.build(view.id))
		camera.position = view.eye
		camera.fov = view.fov
		camera.look_at(view.target)
		label.text = "%s / %s" % [terrain.recipe.name,view.name]
		for frame: int in 3: await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join(view.id+"-"+view.name+".png")) == OK)
		terrain.queue_free()
		await process_frame
	print("LANDMARK_CAPTURE views=",VIEWS.size())
	quit()
