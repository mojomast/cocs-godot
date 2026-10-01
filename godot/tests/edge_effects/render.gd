extends SceneTree
const Marks = preload("res://player_fx/mark_pool.gd")
const Impacts = preload("res://player_fx/impacts.gd")
const Occlusion = preload("res://world/combat_occlusion.gd")
const Structures = preload("res://campaign/structure_art.gd")
const Effects = preload("res://weapon_effects/controller.gd")
const Terrain = preload("res://campaign/terrain.gd")
var failures: Array[String] = []
var checks := 0
var out := ""
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var pool: Node3D
class Host extends Node3D:
	var recipe: Dictionary
	func height_at(_x: float, _z: float) -> float: return 0.0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
func save(name: String) -> Image:
	var image := viewport.get_texture().get_image()
	image.save_png(out.path_join(name+".png"))
	return image
func difference(a: Color,b: Color) -> float:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
func run() -> void:
	out = OS.get_environment("EDGE_RENDER_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	viewport = SubViewport.new()
	viewport.size = Vector2i(640,480)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("182633")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.8
	environment.environment = settings
	stage.add_child(environment)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	pool = Marks.new()
	stage.add_child(pool)
	pool.configure(camera)
	var wall := MeshInstance3D.new()
	wall.mesh = QuadMesh.new()
	wall.mesh.size = Vector2(40,40)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	wall.material_override = material
	stage.add_child(wall)
	var cases := 0
	for brightness: String in ["bright","dark"]:
		material.albedo_color = Color("ded5bf") if brightness == "bright" else Color("222c36")
		for surface: String in ["wall","floor","ceiling"]:
			var normal := Vector3.BACK if surface == "wall" else Vector3.UP if surface == "floor" else Vector3.DOWN
			wall.basis = Marks.basis(normal,0)
			for distance: float in [3.0,8.0]:
				for grazing: bool in [false,true]:
					var tangent: Vector3 = wall.basis.x
					camera.position = normal*distance + tangent*(distance*1.7 if grazing else 0.0)
					camera.look_at(Vector3.ZERO,wall.basis.y)
					pool.reset()
					await frame()
					var name := "%s-%s-%d-%s" % [brightness,surface,int(distance),"grazing" if grazing else "front"]
					var background := save(name+"-clean")
					for kind: int in [Marks.POCK,Marks.SCORCH,Marks.RING]:
						pool.reset()
						pool.place(Vector3.ZERO,normal,"metal" if brightness=="dark" else "stone",kind,1.8,0)
						await frame()
						var marked := save(name+"-kind%d" % kind)
						var node: MeshInstance3D = pool.slots[0].node
						var changed := 0
						for y: int in range(480):
							for x: int in range(640):
								if difference(background.get_pixel(x,y),marked.get_pixel(x,y)) > 0.012: changed += 1
						check(changed>3,name+" visible kind"+str(kind))
						for x: float in [-0.48,0.48]:
							for y: float in [-0.48,0.48]:
								var screen := camera.unproject_position(node.global_transform*Vector3(x,y,0))
								var pixel := Vector2i(screen)
								check(difference(background.get_pixelv(pixel),marked.get_pixelv(pixel))<0.008,name+" transparent corner kind"+str(kind))
						cases += 1
	# Reproduce the actual square culprit next to its replacement, with the same
	# real production slot. Baseline is the old untextured StandardMaterial card.
	pool.reset()
	wall.basis = Basis.IDENTITY
	material.albedo_color = Color("ded5bf")
	camera.position = Vector3(0,0,3)
	camera.look_at(Vector3.ZERO)
	await frame()
	var depth_clean := save("depth-clean")
	pool.place(Vector3(0,0,-0.1),Vector3.BACK,"metal",Marks.POCK,1.8,0)
	await frame()
	check(depth_clean.get_data()==save("depth-behind").get_data(),"opaque cover hides every mark pixel")
	pool.reset()
	wall.hide()
	await frame()
	var back_clean := save("backface-clean")
	pool.place(Vector3.ZERO,Vector3.FORWARD,"metal",Marks.POCK,1.8,0)
	await frame()
	check(back_clean.get_data()==save("backface-mark").get_data(),"back of receiving face never draws a decal")
	pool.reset()
	wall.show()
	var effects := Impacts.new()
	stage.add_child(effects)
	effects.configure(camera,Occlusion.new())
	effects._spawn(Vector3.ZERO,Vector3.BACK,"stone")
	effects.advance(0.12)
	var dust: MeshInstance3D = effects.effects[0].dust
	var repaired: Material = dust.material_override
	var old := StandardMaterial3D.new()
	old.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	old.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	old.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	old.albedo_color = Color(0.62,0.56,0.5,0.28)
	dust.material_override = old
	await frame()
	save("burst-before-square")
	dust.material_override = repaired
	await frame()
	save("burst-after-round")
	effects.free()
	wall.free()
	# Source event endpoints over the actual imported facade, before/after.
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("EDGE_SOURCE_EVENTS")))
	var host := Host.new()
	host.recipe = fixture.data
	stage.add_child(host)
	var art := Structures.new()
	host.add_child(art)
	art.build(host)
	camera.position = Vector3(7,5,12)
	camera.look_at(Vector3(0,2,0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35,-25,0)
	stage.add_child(sun)
	var fx := Effects.new()
	stage.add_child(fx)
	fx.set_process(false)
	fx.source_camera = camera
	for state: String in ["before","after"]:
		fx.reset()
		for record: Dictionary in fixture.records:
			if record.kind != "fire" or int(record.weapon)!=0: continue
			for event: Dictionary in record[state].events:
				if event.type != "shot": continue
				var a := Vector3(event.from.x,event.from.y,event.from.z)
				var b := Vector3(event.to.x,event.to.y,event.to.z)
				fx._spawn_line(a,a,b,0,null,null,a)
		await frame()
		save("source-facade-"+state)
	fx.reset()
	var receiving := Occlusion.new()
	receiving.configure(camera,{"id":"source-cabin","collision_root":host})
	var contacts := Impacts.new()
	stage.add_child(contacts)
	contacts.configure(camera,receiving)
	contacts.set_map({"id":"source-cabin","collision_root":host})
	for record: Dictionary in fixture.records:
		if record.kind != "muzzle-cover": continue
		var event: Dictionary = record.after.events[0]
		var point := Vector3(event.to.x,event.to.y,event.to.z)
		camera.position = point+Vector3(0,0,1.8)
		camera.look_at(point)
		contacts.consume(record.after.events,0)
		check(contacts.counters.confirmed==1,"real short source muzzle-cover event is rendered")
		contacts.advance(0.12)
		await frame()
		save("source-muzzle-cover-impact")
		contacts.advance(1.0)
		await frame()
		save("source-muzzle-cover-settled")
	for record: Dictionary in fixture.records:
		if record.kind != "fire" or int(record.weapon)!=0 or float(record.y)!=3.0: continue
		contacts.reset()
		var event: Dictionary = record.after.events[0]
		var point := Vector3(event.to.x,event.to.y,event.to.z)
		camera.position = point+Vector3(0,0,1.8)
		camera.look_at(point)
		contacts.consume(record.after.events,0)
		check(contacts.counters.marks_placed==1,"real source wall shot leaves a persistent round mark")
		contacts.advance(0.5)
		await frame()
		save("source-wall-pock")
	contacts.free()
	# Exercise every flash/discharge/trail shader under the shipping renderer.
	fx.reset()
	host.hide()
	camera.position = Vector3(0,0,4)
	camera.look_at(Vector3.ZERO)
	for weapon: int in 10:
		var tip := Node3D.new()
		stage.add_child(tip)
		fx._fire(tip,weapon,{"visible":true})
		fx._spawn_line(Vector3(-1,0,0),Vector3(-0.8,0,0),Vector3(1,0,0),weapon,null,null,Vector3(-1,0,0))
		await frame()
		save("weapon-%02d" % weapon)
		fx.reset()
		tip.free()
	for weapon: int in [1,4,5]:
		fx._primary_blast(Vector3.ZERO,weapon)
		await frame()
		save("primary-blast-%d" % weapon)
		fx.reset()
	# Compile and capture the real production material binding on a route beacon.
	host.free()
	var terrain := Terrain.new()
	stage.add_child(terrain)
	check(terrain.build("rootfall-verge"),"production campaign shader binding builds")
	var beacon: Dictionary = {}
	for item: Dictionary in terrain.recipe.art:
		if item.material == "light":
			beacon = item
			break
	var at := Vector3(beacon.position[0],beacon.position[1]+2.0,beacon.position[2])
	camera.position = at + Vector3(2,1,6)
	camera.look_at(at)
	await frame()
	save("production-conduit")
	check(terrain.materials.light is ShaderMaterial,"authored light meshes use conduit shader")
	terrain.free()
	print("EDGE_EFFECTS_RENDER ",checks," checks; ",cases," pixel-mask cases; failures=",failures)
	quit(0 if failures.is_empty() else 1)
