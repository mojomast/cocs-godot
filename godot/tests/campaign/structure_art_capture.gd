extends SceneTree
## Eight actual in-map architecture views at supported player eye height.
## --render=/absolute/dir (all images share this fixture and its lighting).
const Terrain = preload("res://campaign/terrain.gd")
const TARGETS := {
	"rootfall-verge":{"relay":"landmark-1-Fallen relay", "outpost":"fight-1-cover--1"},
	"siltwake-crossing":{"pump":"pump-0--1", "abutment":"bridgeworks-16--1"},
	"emberline-ascent":{"refinery":"fight-1-cover--1", "uplink":"basalt-uplink-0-3"},
	"crown-array":{"gate":"court-buttress-0--1", "receiver":"crown-fin-5"},
}
var output := ""

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--render="): output = arg.trim_prefix("--render=")
	if output.is_empty() or not DirAccess.dir_exists_absolute(output):
		push_error("--render must name an existing absolute directory")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.far = 1200.0
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
	var manifest: Array = []
	for id: String in Terrain.IDS:
		var terrain := Terrain.new()
		world.add_child(terrain)
		assert(terrain.build(id))
		for style: String in TARGETS[id]:
			var block: Dictionary = {}
			for b: Dictionary in terrain.recipe.arena.blocks:
				if b.id == TARGETS[id][style]:
					block = b
					break
			assert(not block.is_empty())
			var route: Array = terrain.recipe.campaign.criticalPath
			var eye: Dictionary = route[0]
			var best := INF
			for point: Dictionary in route:
				var distance := Vector2(point.x, point.z).distance_to(Vector2(block.x, block.z))
				if distance < best:
					best = distance
					eye = point
			var ground: float = terrain.height_at(float(block.x), float(block.z))
			var face_y: float = minf(float(block.h)-0.5, ground + (8.0 if style in ["receiver", "abutment", "uplink"] else 1.35))
			camera.position = Vector3(eye.x, eye.y+1.65, eye.z)
			# The approach route to this uplink is behind a solid ridge. Its
			# north-facing service elevation has clear supported ground nearby.
			if style == "uplink":
				var detail_z: float = float(block.z) + 11.0
				camera.position = Vector3(float(block.x)+0.5, terrain.height_at(float(block.x)+0.5, detail_z)+1.65, detail_z)
			camera.fov = 65.0 if style in ["receiver", "abutment", "uplink"] else 40.0 if best > 15.0 else 50.0
			camera.look_at(Vector3(block.x, face_y, block.z))
			label.text = "%s / %s" % [terrain.recipe.name, style.capitalize()]
			for frame: int in 3: await process_frame
			await RenderingServer.frame_post_draw
			var file := output.path_join(id + "-" + style + ".png")
			assert(root.get_texture().get_image().save_png(file) == OK)
			manifest.append({"map":id,"style":style,"block":block.id,"eye":[camera.position.x,camera.position.y,camera.position.z],"range":best,"target_y":face_y})
		terrain.queue_free()
		await process_frame
	var document := FileAccess.open(output.path_join("detail-cameras.json"), FileAccess.WRITE)
	assert(document != null)
	document.store_string(JSON.stringify(manifest, "\t"))
	print("STRUCTURE_DETAIL views=", manifest.size())
	quit()
