extends Node3D
const Map = preload("res://horde_maps/blackwater.gd")
const Atmosphere = preload("res://native_arenas/identity_environment.gd")
const FILE := "res://horde_maps/generated/blackwater-reclamation.json"
var camera := Camera3D.new()

func _ready() -> void:
	var directory := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-directory="): directory = arg.trim_prefix("--capture-directory=")
	if directory.is_empty():
		push_error("Blackwater inspection needs --capture-directory")
		get_tree().quit(2)
		return
	var envelope: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	var map := Map.new()
	add_child(map)
	if not map.build("blackwater-reclamation"):
		get_tree().quit(2)
		return
	var light := Atmosphere.new()
	add_child(light)
	light.build(envelope)
	light.world_environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	light.world_environment.environment.ambient_light_color = Color("a3bec6")
	light.world_environment.environment.ambient_light_energy = 0.7
	camera.fov = 75
	camera.far = 650
	add_child(camera)
	camera.make_current()
	var views := {
		"intake-overview":[Vector3(-218, 55, 126), Vector3(-170, 1, 20)],
		"intake-ground":[Vector3(-185, 1.7, 40), Vector3(-164, 2, 79)],
		"distribution-interior":[Vector3(-110, 1.7, -98), Vector3(-82, 2, -78)],
		"switchyard-gantry":[Vector3(0, 6.7, -30), Vector3(28, 5, -12)],
		"settling-court":[Vector3(73, 1.7, 30), Vector3(110, 3, 80)],
		"spillway-bowl":[Vector3(154, 2, -52), Vector3(180, 2, 15)],
		"drainage-tunnel":[Vector3(-84, 1.7, -170), Vector3(0, 2, -170)],
		"site-overview":[Vector3(0, 135, 195), Vector3(0, 2, 0)],
	}
	for label: String in views:
		camera.position = views[label][0]
		camera.look_at(views[label][1])
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		var path: String = directory.path_join("blackwater-" + label + ".png")
		if image.save_png(path) != OK:
			push_error("Blackwater image failed: " + path)
			get_tree().quit(2)
			return
		print("BLACKWATER_CAPTURE ", path, " ", JSON.stringify({"camera":[camera.position.x,camera.position.y,camera.position.z],"meshes":map.metrics}))
	get_tree().quit()
