extends SceneTree
## Native world transition frames from source-produced workshop fixtures.
## Vehicle section is a labelled source-shaped renderer fixture, not live input.
const Terrain = preload("res://campaign/terrain.gd")
const Atmosphere = preload("res://campaign/environment.gd")
const Director = preload("res://campaign/interlude_director.gd")
const Renderer = preload("res://vehicles/renderer.gd")
var output := ""
var source := ""
var frames := 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg.begins_with("--fixtures="): source = arg.trim_prefix("--fixtures=")
	call_deferred("run")

func snap(name_: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(name_+".png")) == OK)
	frames += 1

func run() -> void:
	assert(not output.is_empty() and not source.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(960,600)
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string(source))
	var fixture := {}
	for entry: Dictionary in fixtures:
		if entry.id == "waterwheel": fixture = entry
	assert(not fixture.is_empty())
	var world := Terrain.new()
	root.add_child(world)
	assert(world.build(fixture.mapId))
	var atmosphere := Atmosphere.new()
	assert(atmosphere.build(world.recipe))
	world.add_child(atmosphere)
	var director := Director.new()
	root.add_child(director)
	director.set_process(false)
	director.apply(fixture.before.interludes,fixture.mapId)
	director._process(2.0)
	var beat := {}
	for entry: Dictionary in fixture.before.interludes.beats:
		if entry.id == "waterwheel": beat = entry
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.far = 2000
	var machine: Vector3 = director.point(beat.machine)
	camera.position = machine + Vector3(7,5,9)
	camera.look_at(machine + Vector3.UP*2.2)
	await snap("workshop-rest")
	director.apply(fixture.after.interludes,fixture.mapId)
	for frame: int in 60:
		director._process(1.0/30.0)
		await snap("workshop-%03d" % frame)
	world.free()
	director.free()
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30,30)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("45505a")
	ground.material_override = mat
	root.add_child(ground)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-25,0)
	light.light_energy = 1.8
	root.add_child(light)
	var renderer := Renderer.new()
	root.add_child(renderer)
	var vehicle := {"id":0,"kind":"puma","x":0.0,"y":0.0,"z":0.0,"yaw":0.0,"roll":0.0,"pitchBody":0.0,"health":300,"respawnTimer":0.0,"vx":0.0,"vz":4.2,"turretYaw":0.0,"driver":0}
	var state := {"vehicles":[vehicle],"actors":[],"time":1.0}
	assert(renderer.apply_state(state))
	var car: Node3D = renderer.vehicle_node(0)
	car.set_process(false)
	camera.position = Vector3(4,2.1,4)
	camera.look_at(Vector3(0,0.7,0))
	for frame: int in 60:
		if frame % 3 == 0:
			state.time = 1.0+float(frame)/60.0
			renderer.apply_state(state)
		if car.has_method("_process"): car.call("_process",1.0/60.0)
		await snap("vehicle-%03d" % frame)
	renderer.free()
	ground.free()
	light.free()
	camera.free()
	print("WORLD_PHYSICS_CAPTURE ",JSON.stringify({"frames":frames,"workshop":"source-produced waterwheel completion","vehicle":"synthetic 20Hz velocity samples, cosmetic fixture","network_input":false}))
	quit()
