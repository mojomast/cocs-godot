extends SceneTree
## Explicit static-pose fixture: actual exported chassis, catalogue tip anchors,
## ADS-like stub pose (not the production ADS rig), source-shaped all-weapon
## events. Separate replay uses unmodified Match.fire source-event recordings.
const FX = preload("res://weapon_effects/controller.gd")
const Catalog = preload("res://first_person/generated/catalog.gd")
const Origin = preload("res://weapon_effects/origin.gd")
var directory := ""
var source_path := ""
var state: Dictionary
var metrics: Array = []
var errors := 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-out="): directory = arg.trim_prefix("--evidence-out=")
		if arg.begins_with("--source-events="): source_path = arg.trim_prefix("--source-events=")
	call_deferred("run")

func provider() -> Dictionary:
	return state

func cube(parent: Node, at: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	node.material_override = material
	node.position = at
	parent.add_child(node)

func run() -> void:
	if directory.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(directory)
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(0,1.6,4)
	camera.fov = 75
	world.add_child(camera)
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-25,0)
	world.add_child(sun)
	cube(world,Vector3(0,-0.2,-15),Vector3(40,0.4,50),Color("263840"))
	cube(world,Vector3(0,3,-26),Vector3(25,6,1),Color("566b74"))
	for x: int in [-7,-3,3,7]: cube(world,Vector3(x,2,-12),Vector3(0.18,4,0.18),Color("77acb4"))
	for z: int in [-4,-8,-12,-16,-20]: cube(world,Vector3(0,0.01,z),Vector3(12,0.025,0.04),Color("60909b"))
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view_camera := Camera3D.new()
	view_camera.fov = 75
	view_camera.near = 0.025
	viewport.add_child(view_camera)
	view_camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30,-40,0)
	light.light_energy = 2.0
	viewport.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("b4cde0")
	env.environment.ambient_light_energy = 0.6
	viewport.add_child(env)
	var pivot := Node3D.new()
	viewport.add_child(pivot)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var image := TextureRect.new()
	image.texture = viewport.get_texture()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(image)
	var caption := Label.new()
	caption.position = Vector2(22,22)
	caption.add_theme_font_size_override("font_size",18)
	layer.add_child(caption)
	var fx := FX.new()
	world.add_child(fx)
	fx.configure(camera,provider)
	fx.physics_occlusion_enabled = true # Known-clear fixture convergence region.
	fx.set_process(false)
	var actor := {"id":7,"health":100,"weapon":0}
	for size: Vector2i in [Vector2i(960,640),Vector2i(1280,800)]:
		root.size = size
		viewport.size = size
		image.size = Vector2(size)
		await process_frame
		for weapon: int in 10:
			var scene: PackedScene = load("res://first_person/generated/weapon-%d.glb" % weapon)
			var body := scene.instantiate() as Node3D
			pivot.add_child(body)
			var tips: Array = []
			for xyz: Array in Catalog.WEAPONS[weapon].muzzles:
				var tip := Node3D.new()
				body.add_child(tip)
				tip.position = Vector3(xyz[0],xyz[1],xyz[2])
				tips.append(tip)
			actor.weapon = weapon
			state = {"visible":true,"actor_id":7,"weapon":weapon,"camera":view_camera,"muzzles":tips}
			for pose: String in ["hip","ads-stub"]:
				pivot.position = Vector3(0.34,-0.26,-0.88) if pose == "hip" else Vector3(0,-0.14,-0.90)
				pivot.rotation = Vector3(-0.04,0.22,-0.025) if pose == "hip" else Vector3.ZERO
				fx.reset()
				var count := 12 if weapon == 7 else (8 if weapon == 3 else 1)
				var events: Array = []
				for pellet: int in count:
					var endpoint := Vector3(sin(pellet*2.4)*0.7,1.6+cos(pellet*2.4)*0.5,-25.4) if count > 1 else Vector3(0,1.6,-25.4)
					events.append({"id":pellet+1,"time":1.0,"actor":7,"weapon":weapon,"type":"launch" if weapon in [1,4,5] else "shot","from":{"x":0.24,"y":1.36,"z":3.58},"pos":{"x":0.24,"y":1.36,"z":3.58},"to":{"x":endpoint.x,"y":endpoint.y,"z":endpoint.z},"hit":false})
				fx.consume(events,7,[actor])
				fx.advance(0.012)
				var mapped := Origin.map_tip(camera,view_camera,tips[0])
				var start_error := 0.0
				var endpoint_error := 0.0
				for line: Dictionary in fx.lines:
					var projected := Origin.map_tip(camera,view_camera,line.tip)
					start_error = maxf(start_error,camera.unproject_position(line.start).distance_to(projected.pixel))
					# Compare each line with its originating recorded event by order.
					var index := fx.lines.find(line)
					endpoint_error = maxf(endpoint_error,line.end.distance_to(FX.point(events[index].to)))
				caption.text = "WEAPON FX FIXTURE · %s · %s · %dx%d\nStatic catalog anchors / exported chassis / source-shaped events\nVisual projection error %.5f px · endpoint change %.6f m\nWorld depth −25.4m · no damage/impact assertions" % [Catalog.WEAPONS[weapon].name,pose,size.x,size.y,start_error,endpoint_error]
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(directory.path_join("%dx%d-%02d-%s.png" % [size.x,size.y,weapon,pose]))
				metrics.append({"size":[size.x,size.y],"weapon":weapon,"pose":pose,"visual_tip_projection_error_px":mapped.projection_error_px,"tracer_start_error_px":start_error,"authoritative_endpoint_delta_m":endpoint_error,"flash_instances":fx.flashes,"tracers":fx.tracer_count,"isolated_depth_m":mapped.depth,"simulation_origin_match_claimed":false})
				if start_error > 0.01 or endpoint_error > 0.00001 or fx.flashes < 1: errors += 1
				if size.x == 960 and pose == "hip":
					var previous_age := 0.012
					for age: float in [0.045,0.12,0.30]:
						fx.advance(age-previous_age)
						previous_age = age
						caption.text = "ANIMATION FIXTURE · %s · age %.3f s\nStatic catalog anchors / hip pose / source-shaped event\nFlash → expanding smoke / cooling bore · GL Compatibility" % [Catalog.WEAPONS[weapon].name,age]
						await RenderingServer.frame_post_draw
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png(directory.path_join("animation-%02d-%03dms.png" % [weapon,int(age*1000)]))
			fx.reset()
			body.free()
	# Replay actual source events with original wire IDs/times and normal-rate dt.
	if not source_path.is_empty():
		var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(source_path))
		for record: Dictionary in records:
			var scene: PackedScene = load("res://first_person/generated/weapon-%d.glb" % int(record.weapon))
			var body := scene.instantiate() as Node3D
			pivot.add_child(body)
			pivot.position = Vector3(0.34,-0.26,-0.88)
			pivot.rotation = Vector3(-0.04,0.22,-0.025)
			var tip := Node3D.new()
			var xyz: Array = Catalog.WEAPONS[int(record.weapon)].muzzles[0]
			tip.position = Vector3(xyz[0],xyz[1],xyz[2])
			body.add_child(tip)
			state = {"visible":true,"actor_id":int(record.actor.id),"weapon":int(record.weapon),"camera":view_camera,"muzzles":[tip]}
			fx.reset()
			var previous := 0.0
			for event: Dictionary in record.events:
				fx.advance(maxf(0,event.time-previous))
				previous = event.time
				fx.consume([event],int(record.actor.id),[record.actor])
				await RenderingServer.frame_post_draw
			caption.text = "SOURCE-EVENT REPLAY · %s\nMatch.fire + step (60 Hz, 2 seconds), original IDs/times\n%d source shots / %d muzzle volleys / %d tracers\nStatic catalog anchors; replay, not a live network session" % [Catalog.WEAPONS[int(record.weapon)].name,record.events.size(),fx.flashes,fx.tracer_count]
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(directory.path_join("source-replay-%d.png" % int(record.weapon)))
			metrics.append({"source_weapon":record.weapon,"source_shots":record.events.size(),"rendered_volleys":fx.flashes,"tracers":fx.tracer_count,"source_nominal_interval":record.interval,"last_source_time":previous})
			if fx.flashes != record.events.size(): errors += 1
			fx.reset()
			body.free()
	# Mesh-only geometry fixture: its exact rendered solid is passed as semantic
	# occlusion, exercising the original-map integration contract without bodies.
	var scene: PackedScene = load("res://first_person/generated/weapon-0.glb")
	var body := scene.instantiate() as Node3D
	pivot.add_child(body)
	pivot.position = Vector3(0.34,-0.26,-0.88)
	pivot.rotation = Vector3(-0.04,0.22,-0.025)
	var tip := Node3D.new()
	body.add_child(tip)
	tip.position = Vector3(0,0.01,-0.85)
	state = {"visible":true,"actor_id":7,"weapon":0,"camera":view_camera,"muzzles":[tip]}
	var wall := AABB(Vector3(-3,-1,3.35),Vector3(6,6,0.1))
	cube(world,wall.get_center(),wall.size,Color("42555d"))
	fx.configure_occlusion(func(from: Vector3,to: Vector3) -> bool: return wall.has_point(from) or wall.intersects_segment(from,to) != null)
	fx.consume([{"id":1,"time":1.0,"type":"shot","actor":7,"weapon":0,"from":{"x":0.24,"y":1.36,"z":3.58},"to":{"x":0,"y":1.6,"z":-25.4}}],7,[{"id":7,"health":100,"weapon":0}])
	caption.text = "NEAR-WALL FIXTURE · exact mesh-solid semantic occlusion\nIsolated weapon remains visible; muzzle FX and world tracer suppressed\nSpawned flashes %d · tracers %d · no invented impact" % [fx.flashes,fx.tracer_count]
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join("near-wall-semantic.png"))
	metrics.append({"fixture":"near-wall-semantic","flashes":fx.flashes,"tracers":fx.tracer_count})
	if fx.flashes != 0 or fx.tracer_count != 0: errors += 1
	fx.reset()
	FileAccess.open(directory.path_join("metrics.json"),FileAccess.WRITE).store_string(JSON.stringify(metrics,"\t")+"\n")
	print("WEAPON_EFFECTS_FRAMING records=%d errors=%d" % [metrics.size(),errors])
	quit(1 if errors else 0)
