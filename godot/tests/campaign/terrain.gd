extends SceneTree
const Terrain = preload("res://campaign/terrain.gd")
var failures := 0
var render_dir := ""

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--render="): render_dir = arg.trim_prefix("--render=")
	root.size = Vector2i(1280, 720)
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
	environment.environment.ambient_light_energy = 0.35
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -28, 0)
	sun.light_color = Color("fff0d7")
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	world.add_child(sun)
	var label := Label.new()
	label.position = Vector2(24, 18)
	label.add_theme_font_size_override("font_size", 25)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	root.add_child(label)
	for id: String in Terrain.IDS:
		var terrain := Terrain.new()
		world.add_child(terrain)
		check(terrain.build(id), "build " + id)
		check(terrain.build(id), "idempotent build " + id)
		check(not terrain.build("../../invalid"), "reject invalid map")
		check(terrain.get_arena_id() == id, "failed build retains current map")
		check(is_nan(terrain.height_at(1000, 0)), "outside height is not clamped to phantom floor")
		await physics_frame
		await physics_frame
		for route: Dictionary in terrain.recipe.routes:
			for i: int in range(0, route.points.size(), 11):
				var p: Dictionary = route.points[i]
				check(absf(terrain.height_at(p.x, p.z) - float(p.y)) < 0.0001, "feet/triangle agreement %s %s %d" % [id, route.id, i])
				var from := Vector3(p.x, p.y + 1, p.z)
				var to := Vector3(p.x, p.y - 1, p.z)
				var query := PhysicsRayQueryParameters3D.create(from, to)
				var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
				check(not hit.is_empty(), "physical terrain beneath route " + id)
				if not hit.is_empty(): check(absf(hit.position.y - float(p.y)) < 0.002, "physical collision exactly matches feet")
		for child: Node in terrain.get_children():
			if child is MultiMeshInstance3D:
				var multi: MultiMesh = child.multimesh
				var box: AABB = multi.custom_aabb
				for i: int in multi.instance_count:
					var transform: Transform3D = child.get_meta("instance_transforms")[i] if DisplayServer.get_name() == "headless" else multi.get_instance_transform(i)
					var transformed: AABB = transform * multi.mesh.get_aabb()
					check(box.encloses(transformed), "batch cull bounds include transformed mesh %s %s: %s / %s" % [id, child.name, box, transformed])
		check(terrain.terrain_chunks <= 320, "bounded terrain chunks")
		check(terrain.art_instances < 2200, "bounded scenery")
		print("CAMPAIGN_TERRAIN ", id, " ", terrain.visible_cost())
		if not render_dir.is_empty():
			var bounds: Dictionary = terrain.recipe.arena.bounds
			var width: float = bounds.maxX - bounds.minX
			var height: float = bounds.maxZ - bounds.minZ
			var base: float = terrain.recipe.campaign.anchors.start.y
			var views := [{"id":"vista", "at":Vector3(-width*0.50, base+width*0.75, height*0.70), "target":Vector3(0, base+20, 0)}]
			for encounter: int in [1, 5]:
				var p: Dictionary = terrain.recipe.campaign.anchors["encounter-%d" % encounter]
				var direction := 1.0 if encounter == 1 else -1.0
				var x: float = p.x-direction*28
				var z: float = p.z+4
				views.append({"id":"route-%d" % encounter, "at":Vector3(x,terrain.height_at(x,z)+1.65,z), "target":Vector3(p.x+direction*8,p.y+3,p.z-10)})
			for view: Dictionary in views:
				camera.position = view.at
				camera.look_at(view.target)
				label.text = str(terrain.recipe.name) + " / " + str(view.id)
				for frame: int in 3: await process_frame
				await RenderingServer.frame_post_draw
				var image := root.get_texture().get_image()
				check(image.save_png(render_dir + "/" + id + "-" + str(view.id) + ".png") == OK, "capture " + id)
		terrain.queue_free()
		await process_frame
	world.queue_free()
	print("CAMPAIGN_TERRAIN failures=", failures)
	quit(0 if failures == 0 else 1)
