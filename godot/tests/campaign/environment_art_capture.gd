extends SceneTree
## Matched cameras from tests/campaign/terrain.gd, plus low asset-detail views.
## -- --render=/absolute/output/directory
const Terrain = preload("res://campaign/terrain.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var output := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--render="): output = arg.trim_prefix("--render=")
	if output.is_empty():
		push_error("Supply --render=/absolute/output/directory")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.far = 1200.0
	camera.fov = 65.0
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("9bb8bb")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("cfddd8")
	environment.environment.ambient_light_energy = .35
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-28,0)
	sun.light_color = Color("fff0d7")
	sun.light_energy = .8
	sun.shadow_enabled = true
	world.add_child(sun)
	var label := Label.new()
	label.position = Vector2(24,18)
	label.add_theme_font_size_override("font_size",25)
	label.add_theme_color_override("font_outline_color",Color.BLACK)
	label.add_theme_constant_override("outline_size",5)
	root.add_child(label)
	var manifest: Array = []
	for id: String in Terrain.IDS:
		var terrain := Terrain.new()
		world.add_child(terrain)
		assert(terrain.build(id))
		var decorator: Node3D = terrain.get_node("CampaignEnvironmentArt")
		assert(decorator.replacement_instances > 200)
		var recipe: Dictionary = terrain.recipe
		var bounds: Dictionary = recipe.arena.bounds
		var width: float = bounds.maxX - bounds.minX
		var height: float = bounds.maxZ - bounds.minZ
		var base: float = recipe.campaign.anchors.start.y
		var views := [{"id":"vista","at":Vector3(-width*.50,base+width*.75,height*.70),"target":Vector3(0,base+20,0)}]
		var path: Array = recipe.campaign.criticalPath
		for encounter: int in [1,5]:
			var p: Dictionary = recipe.campaign.anchors["encounter-%d" % encounter]
			var nearest := 0
			var best := INF
			for j: int in path.size():
				var distance := Vector2(path[j].x-p.x,path[j].z-p.z).length()
				if distance < best:
					best = distance
					nearest = j
			var eye: Dictionary = path[maxi(0,nearest-9)]
			views.append({"id":"route-%d" % encounter,"at":Vector3(eye.x,eye.y+1.65,eye.z),"target":Vector3(p.x,p.y+2,p.z)})
		for fraction: float in [.23,.62]:
			var j := int(float(path.size()-1)*fraction)
			var p: Dictionary = path[j]
			var q: Dictionary = path[mini(j+6,path.size()-1)]
			var direction := Vector2(q.x-p.x,q.z-p.z).normalized()
			var side := Vector2(-direction.y,direction.x)*(1.0 if fraction < .5 else -1.0)
			views.append({"id":"ridge-%d" % (1 if fraction < .5 else 2),"at":Vector3(p.x,p.y+1.65,p.z),"target":Vector3(p.x+direction.x*18+side.x*18,p.y+6,p.z+direction.y*18+side.y*18)})
		# Site detail is shot from an actual traversable support point nearest a
		# recipe prop; it samples the placed production batch, not a studio mesh.
		var details := ["tree","fern","crag"] if int(recipe.campaign.index) in [0,3] else ["fern","crag"]
		for kind: String in details:
			var site := Vector3.ZERO
			for prop: Dictionary in recipe.art:
				if prop.kind != kind: continue
				var p: Array = prop.position
				var candidate := Vector3(float(p[0]),float(p[1]),float(p[2]))
				if Vector2(candidate.x,candidate.z).length() < 65.0:
					site = candidate
					break
			if site == Vector3.ZERO: continue
			var eye := Vector3(site.x+9.0,terrain.height_at(site.x+9,site.z+7)+1.65,site.z+7)
			if not is_finite(eye.y): continue
			views.append({"id":"detail-"+kind,"at":eye,"target":site+Vector3.UP*2.0})
		for view: Dictionary in views:
			camera.position = view.at
			camera.look_at(view.target)
			label.text = str(recipe.name) + " / " + str(view.id)
			for frame: int in 3: await process_frame
			await RenderingServer.frame_post_draw
			var filename := output+"/"+id+"-"+str(view.id)+".png"
			assert(root.get_texture().get_image().save_png(filename) == OK)
			manifest.append({"map":id,"view":view.id,"at":[view.at.x,view.at.y,view.at.z],"target":[view.target.x,view.target.y,view.target.z]})
		print("ENV_CAPTURE ",id," views=",views.size()," replaced=",decorator.replacement_instances," accents=",decorator.accent_instances)
		terrain.queue_free()
		await process_frame
	var file := FileAccess.open(output+"/cameras.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"))
	world.queue_free()
	quit()
