extends SceneTree
## Matched player-height art review using production campaign/MP map builders.
const Look = preload("res://ambience/weather_look.gd")
const Terrain = preload("res://campaign/terrain.gd")
const Atmosphere = preload("res://campaign/environment.gd")
const WorldMap = preload("res://multiplayer_worlds/map.gd")
const WorldCatalog = preload("res://multiplayer_worlds/catalog.gd")
var report: Array = []

func _initialize() -> void:
	call_deferred("run")
	create_timer(100).timeout.connect(func() -> void: push_error("Style capture watchdog"); quit(1))

func run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() > 0)
	root.size = Vector2i(960, 600)
	var catalog := WorldCatalog.new()
	assert(catalog.open())
	for id: String in ["rootfall-verge", "siltwake-crossing", "emberline-ascent", "crown-array", "rainmarket-exchange", "thermal-divide", "breakwater-exchange", "tern-archipelago"]:
		var campaign: bool = id in Terrain.IDS
		var container := Node3D.new()
		root.add_child(container)
		var world: Node3D
		var environment: WorldEnvironment
		var sun: DirectionalLight3D
		var camera := Camera3D.new()
		container.add_child(camera)
		camera.current = true
		camera.far = 1800
		camera.fov = 72
		if campaign:
			world = Terrain.new()
			container.add_child(world)
			assert(world.build(id))
			var atmosphere := Atmosphere.new()
			world.add_child(atmosphere)
			assert(atmosphere.build(world.recipe))
			environment = atmosphere.world_environment
			sun = atmosphere.sun
			var path: Array = world.recipe.campaign.criticalPath
			var at: Dictionary = path[mini(12, path.size() - 1)]
			var target: Dictionary = path[mini(22, path.size() - 1)]
			camera.position = Vector3(at.x, at.y + 1.65, at.z)
			camera.look_at(Vector3(target.x, target.y + 1.65, target.z))
		else:
			world = WorldMap.new()
			container.add_child(world)
			assert(world.build(catalog.recipes[id]))
			environment = WorldEnvironment.new()
			environment.environment = Environment.new()
			environment.environment.background_mode = Environment.BG_COLOR
			environment.environment.background_color = Color("627985")
			environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			environment.environment.ambient_light_color = Color("a0adb5")
			environment.environment.ambient_light_energy = 0.68
			container.add_child(environment)
			sun = DirectionalLight3D.new()
			sun.rotation_degrees = Vector3(-44,-30,0)
			sun.light_energy = 1.25
			sun.shadow_enabled = true
			container.add_child(sun)
			var arena: Dictionary = catalog.recipes[id].arena
			if not arena.get("overhead", []).is_empty() and id == "rainmarket-exchange":
				var lighting = preload("res://multiplayer_worlds/urban_lighting.gd").new()
				world.add_child(lighting)
				lighting.build(arena, true)
			var spawn: Array = arena.spawns[0]
			await physics_frame
			var query := PhysicsRayQueryParameters3D.create(Vector3(spawn[0], 100, spawn[1]), Vector3(spawn[0], -30, spawn[1]))
			var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
			assert(not hit.is_empty(), "Spawn support collider required for matched camera")
			camera.position = hit.position + Vector3.UP * 1.65
			camera.look_at(Vector3(0, camera.position.y, 0))
		var original: Environment = environment.environment
		var energy := sun.light_energy
		var color := sun.light_color
		var look := Look.new()
		var started := Time.get_ticks_usec()
		look.bind(world, environment, sun)
		var bind_us := Time.get_ticks_usec() - started
		for phase: String in ["before", "wet-only", "weather"]:
			look.apply("clear" if phase == "before" else "storm", 0.0, true)
			if phase == "wet-only":
				environment.environment.fog_density = original.fog_density
				environment.environment.fog_light_color = original.fog_light_color
				environment.environment.tonemap_exposure = original.tonemap_exposure
				environment.environment.ambient_light_energy = original.ambient_light_energy
				environment.environment.ambient_light_color = original.ambient_light_color
				sun.light_energy = energy
				sun.light_color = color
			for frame in 4:
				await process_frame
				await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(args[0].path_join(id + "-" + phase + ".png")) == OK)
			var row := look.diagnostics()
			row.merge({"map":id,"phase":phase,"bind_cpu_us":bind_us,"camera":str(camera.transform),
				"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
			report.append(row)
		look.clear()
		assert(environment.environment == original)
		container.free()
		await process_frame
	FileAccess.open(args[0].path_join("manifest.json"), FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("WORLD_WEATHER_STYLES_OK images=",report.size())
	quit()
