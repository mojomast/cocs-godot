extends Node3D
const Renderer = preload("res://vehicles/renderer.gd")
func _ready() -> void:
	var r = Renderer.new()
	add_child(r)
	var vehicles: Array = []
	for id: int in range(2):
		vehicles.append({"id":id,"kind":"puma","x":-2.2 if id == 0 else 2.2,"y":0,"z":0,"yaw":0 if id == 0 else PI,"roll":0,"pitchBody":0,"health":300,"respawnTimer":0,"vx":0,"vz":0,"turretYaw":0,"driver":id})
	r.apply_state({"vehicles":vehicles,"actors":[{"id":0,"team":0},{"id":1,"team":1}],"time":0})
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24,24)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("343e4c")
	ground.material_override = mat
	add_child(ground)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50,-30,0)
	light.shadow_enabled = true
	add_child(light)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("172334")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("bdcee3")
	env.ambient_light_energy = 0.65
	environment.environment = env
	add_child(environment)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(8,6,10)
	camera.look_at(Vector3(0,0.6,0))
	camera.current = true
	var label := Label.new()
	label.text = "PUMA / NATIVE PRESENTATION\nSYNTHETIC visual fixture — red front / blue rear\n+Y up · metres · vehicle nose +Z · no driving acceptance"
	label.position = Vector2(24,24)
	label.add_theme_font_size_override("font_size", 20)
	add_child(label)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			for i: int in range(8): await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var result := get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture="))
			print("PUMA synthetic screenshot save=", result)
			get_tree().quit(0 if result == OK else 1)
