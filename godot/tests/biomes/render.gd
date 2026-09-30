extends SceneTree
const Biome = preload("res://biomes/map.gd")
const Atmosphere = preload("res://native_arenas/identity_environment.gd")
const Visual = preload("res://source_operators/operator_visual.gd")
var output := "/tmp/opencode/biome-upgrade"
var stage: Node3D
var camera: Camera3D

func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check_save(image.save_png(output.path_join(name+".png")))

func check_save(code: int) -> void:
	if code != OK:
		push_error("Could not save biome screenshot")
		quit(1)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,800)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for id: String in ["canopy-divide","basalt-reach"]:
		stage = Node3D.new()
		root.add_child(stage)
		var map := Biome.new()
		stage.add_child(map)
		if not map.build(id): quit(1); return
		var atmosphere := Atmosphere.new()
		stage.add_child(atmosphere)
		atmosphere.build(map.recipe)
		camera = Camera3D.new()
		stage.add_child(camera)
		camera.far = 350
		camera.make_current()
		for pose: Dictionary in map.recipe.cameras:
			camera.position = Vector3(pose.at[0],pose.at[1],pose.at[2])
			camera.look_at(Vector3(pose.target[0],pose.target[1],pose.target[2]))
			await capture(id+"-"+str(pose.id))
		stage.free()
	stage = Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("202b37")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.65
	world.environment = environment
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35,-25,0)
	sun.light_energy = 1.8
	stage.add_child(sun)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(3.0,2.3,-5.6)
	camera.look_at(Vector3(0,1,0))
	camera.fov = 45
	camera.make_current()
	var actors: Array[Node3D] = []
	for i in 3:
		var actor := Visual.new()
		actor.position = Vector3((i-1)*1.2,0.9,0)
		stage.add_child(actor)
		actor.automatic_animation = false
		actor.configure({"id":i,"character":["claude","grok","meta"][i],"health":100,"weapon":0})
		for frame in 30: actor.advance(1.0/60)
		actors.append(actor)
	await capture("operators-upgraded")
	for pose: String in ["walk","strafe","crouch","airborne"]:
		for actor in actors:
			actor.reset_pose()
			actor.apply_actor({"id":2,"character":actor.character,"health":100,"weapon":0,"vx":3.0 if pose=="strafe" else 0.0,"vz":-3.0 if pose=="walk" else 0.0,"crouching":pose=="crouch","grounded":pose!="airborne"})
			for frame in 30: actor.advance(1.0/60)
		await capture("operators-"+pose)
	for actor in actors:
		actor.reset_pose()
		actor.apply_actor({"id":2,"character":actor.character,"health":100,"weapon":0,"vx":0.0,"vz":-3.6,"grounded":true})
	for frame in 16:
		for actor in actors:
			for step in 5: actor.advance(1.0/60)
		await capture("motion-%02d" % frame)
	stage.free()
	print("BIOME_UPGRADE_RENDER_OK renderer="+RenderingServer.get_video_adapter_name())
	quit()
