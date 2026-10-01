extends SceneTree
## Captures actual campaign terrain and source-produced workshop snapshots.
const Terrain = preload("res://campaign/terrain.gd")
const EnvironmentArt = preload("res://campaign/environment.gd")
const Director = preload("res://campaign/interlude_director.gd")
const Widgets = preload("res://campaign/story_widgets.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var source := ""
	var output := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fixtures="): source = arg.trim_prefix("--fixtures=")
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	assert(not source.is_empty() and not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string(source))
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.far = 2000
	camera.make_current()
	var director := Director.new()
	root.add_child(director)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var widgets := Widgets.new()
	layer.add_child(widgets)
	var world: Node3D
	var map_id := ""
	for fixture: Dictionary in fixtures:
		if fixture.mapId != map_id:
			if is_instance_valid(world): world.free()
			world = Terrain.new()
			root.add_child(world)
			assert(world.build(fixture.mapId))
			var atmosphere := EnvironmentArt.new()
			assert(atmosphere.build(world.recipe))
			world.add_child(atmosphere)
			map_id = fixture.mapId
		var beat: Dictionary
		for entry: Dictionary in fixture.before.interludes.beats:
			if entry.id == fixture.id: beat = entry
		camera.position = director.point(beat.entry)+Vector3(0,2.0,0)
		camera.look_at(director.point(beat.machine)+Vector3(0,-0.5,0))
		for phase: String in ["before","after"]:
			var state: Dictionary = fixture[phase]
			director.apply(state.interludes,map_id)
			widgets.observe(state.story,true,state.interludes)
			for i: int in 12: await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			assert(image.save_png(output+"/"+map_id+"-"+str(fixture.id)+"-"+phase+".png") == OK)
			print("INTERLUDE_CAPTURE ",map_id," ",fixture.id," ",phase)
	world.free()
	layer.free()
	director.free()
	camera.free()
	quit()
