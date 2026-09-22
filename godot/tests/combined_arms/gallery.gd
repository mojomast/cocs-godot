extends SceneTree
## Synthetic silhouette/readability fixture, separate from live authority evidence.
const Chassis = preload("res://combined_arms/chassis.gd")
const Puma = preload("res://vehicles/puma.gd")
var output := ""
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence="): output = arg.trim_prefix("--evidence=")
	run.call_deferred()
func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("202c3b")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	scene.add_child(sun)
	var kinds := ["puma", "scout", "titan", "transport", "hornet"]
	for i in range(kinds.size()):
		var n: Node3D = Puma.new() if i == 0 else Chassis.new(kinds[i])
		scene.add_child(n)
		n.position.x = (i-2)*7
		n.rotation.y = -0.3
		var label := Label3D.new()
		label.text = kinds[i].to_upper()
		label.position = Vector3((i-2)*7, 3.5, 0)
		label.font_size = 56
		label.pixel_size = 0.015
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		scene.add_child(label)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0, 9, 21)
	camera.fov = 62
	camera.look_at(Vector3(0, 0.8, 0))
	camera.current = true
	for width in [960, 1280]:
		root.size = Vector2i(width, width*5/8)
		await process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(output+"/silhouettes-%s.png" % width) != OK:
			quit(1)
			return
	print("COMBINED_SYNTHETIC_GALLERY_COMPLETE")
	quit()
