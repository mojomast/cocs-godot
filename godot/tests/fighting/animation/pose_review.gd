extends SceneTree
## Native five-phase art strips; manual seek into real exported skeletal clips.
const Visual = preload("res://fighting/visuals/fighter_visual.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var selected: Array[String] = ["meta","mistral"]
	var output := "user://pose-review"
	var only_clip := ""
	var finish_off := false
	var args := OS.get_cmdline_user_args()
	for i: int in range(args.size()-1):
		if args[i]=="--operators": selected.assign(args[i+1].split(","))
		if args[i]=="--output": output=args[i+1]
		if args[i]=="--clip": only_clip=args[i+1]
		if args[i]=="--finish": finish_off=args[i+1]=="off"
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1600,600)
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=3.2
	camera.position=Vector3(0,1.3,8)
	camera.current=true
	var env := WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("222b35")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE
	env.environment.ambient_light_energy=.65
	world.add_child(env)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-35,-25,0)
	light.light_energy=.9
	world.add_child(light)
	var floor:=MeshInstance3D.new()
	var box:=BoxMesh.new()
	box.size=Vector3(20,.06,2)
	floor.mesh=box
	floor.position.y=-.03
	world.add_child(floor)
	var layer:=CanvasLayer.new()
	root.add_child(layer)
	var heading:=Label.new()
	heading.position=Vector2(18,15)
	heading.add_theme_font_size_override("font_size",22)
	layer.add_child(heading)
	var actors:Array=[]
	for i:int in 5:
		var actor:=Visual.new()
		world.add_child(actor)
		actors.append(actor)
	var records:Array=[]
	for operator:String in selected:
		for actor in actors: assert(actor.configure(operator),actor.unavailable_reason)
		if finish_off:
			for actor in actors: actor._finish.clear()
		var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Visual.ASSET_ROOT+operator+".json"))
		for clip:String in manifest.clips:
			if clip.begins_with("victim_"):continue
			if not only_clip.is_empty() and clip != only_clip:continue
			var data:Dictionary=manifest.clips[clip]
			var frames:Array=[]
			for i:int in 5:
				var frame:float
				if data.seek_keys.size()>=5:
					var index:int = [0,1,3,4,5][i] if data.seek_keys.size()==6 else i
					frame=float(data.seek_keys[index][0])
				else:frame=float(data.seek_keys[-1][0])*float(i)/4.0
				frames.append(frame)
				actors[i].reset()
				actors[i].present({"animation":clip,"animation_frame":frame,"x":(i-2)*1650,"facing":1},0.0)
			heading.text=operator+" / "+clip+"     SIM frames "+str(frames)
			await process_frame
			await RenderingServer.frame_post_draw
			var path:=output.path_join(operator+"-"+clip+".png")
			assert(root.get_texture().get_image().save_png(path)==OK)
			records.append({"operator":operator,"clip":clip,"frames":frames,"path":path,"finish":actors[0].finish_report.installed})
	var file:=FileAccess.open(output.path_join("index.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"\t"))
	world.free()
	layer.free()
	quit(0)
