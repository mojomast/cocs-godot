extends SceneTree
## Actual rendered source-driven rig poses; explicitly controlled inspection.
const Robot = preload("res://campaign/robot_visual.gd")
const Adapter = preload("res://robot_assets/switchyard/skin_adapter.gd")
const Terrain = preload("res://campaign/terrain.gd")
var world: Node3D
var camera: Camera3D
var robots: Array[Node3D] = []
var report: Dictionary = {"frames":[], "kind":"controlled native production-asset inspection", "humanFeel":false}
var out := ""
var title: Label
var compact := false

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := out.path_join(name + ".png")
	var error := root.get_texture().get_image().save_png(path)
	assert(error == OK)
	report.frames.append({"name":name,"ticksUsec":Time.get_ticks_usec(),"unix":Time.get_unix_time_from_system(),"path":path})

func pose(mode: String, dt: float) -> void:
	for robot: Node3D in robots:
		var actor: Dictionary = robot.snapshot.duplicate(true)
		actor.health = 0 if mode == "death" else 100
		actor.vz = -1.5 if mode == "walk" else 0.0
		actor.vx = 0.7 if mode == "walk" else 0.0
		actor.campaignAttackWindup = 0.5 if mode == "attack" else 0.0
		robot.apply_actor(actor)
		if mode == "react": robot.hit_reaction = 0.8
		robot.advance(dt)

func view(point: Vector3, target: Vector3, size: float) -> void:
	camera.position = point
	camera.look_at(target)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size

func run() -> void:
	out = OS.get_environment("ASSET_STAGE_EVIDENCE")
	assert(not out.is_empty())
	compact = "--compact" in OS.get_cmdline_user_args()
	root.size = Vector2i(760,520) if compact else Vector2i(1280,800)
	root.get_node("LocalSettings").set_value("ui_scale", 150 if compact else 100, false)
	report.profile = "760x520 UI150" if compact else "1280x800 UI100"
	report.renderer = RenderingServer.get_video_adapter_name()
	world = Node3D.new(); root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("17222c")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("adbac7")
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48,-35,0); light.light_energy = 1.7; light.shadow_enabled = not compact
	light.directional_shadow_max_distance = 40
	light.shadow_bias = .1; light.shadow_normal_bias = .2
	world.add_child(light)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25,145,0); rim.light_energy = .8
	rim.light_color = Color("9dbedf"); world.add_child(rim)
	camera = Camera3D.new(); world.add_child(camera); camera.current = true
	title = Label.new(); title.position = Vector2(22,18)
	title.add_theme_font_size_override("font_size", 18 if compact else 24)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size = Vector2(float(root.size.x)/(1.5 if compact else 1.0)-44,110)
	root.add_child(title)
	var floor_mesh := MeshInstance3D.new()
	var plane := BoxMesh.new(); plane.size = Vector3(30,.1,20); floor_mesh.mesh = plane
	floor_mesh.position.y = -.06
	var floor_mat := StandardMaterial3D.new(); floor_mat.albedo_color = Color("2b3741")
	floor_mesh.material_override = floor_mat; world.add_child(floor_mesh)
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var index := 0
	for skin: String in Adapter.SKINS:
		var robot := Robot.new(); robot.automatic_animation = false; robot.automatic_lod = false
		world.add_child(robot); robot.position = Vector3((index-1)*3.4,.9,0)
		var role: String = Adapter.SKINS[skin]
		robot.configure({"id":index+1,"npcModel":role,"health":100,"grounded":true,"npcProfile":{"scale":{"skirmisher":.86,"bulwark":1.5,"mortar":1.15}[role]}})
		assert(Adapter.install_role(robot)); robots.append(robot); index += 1
	view(Vector3(8,6,-13),Vector3(0,1,0),11)
	title.text = "SWITCHYARD / source-scale roles\nNeedle Surveyor · Caisson Guard · Kiln Tender"
	await capture("roles-front")
	view(Vector3(-8,6,13),Vector3(0,1,0),11)
	await capture("roles-rear")
	for i in robots.size():
		for j in robots.size(): robots[j].visible = i == j
		var r := robots[i]; var x: float = r.position.x
		for side: String in ["front", "rear", "underside"]:
			floor_mesh.visible = side != "underside"
			view(Vector3(x+2.8,2.7 if side != "underside" else -.5,-4.0 if side != "rear" else 4.0),Vector3(x,1.1,0),3.5)
			title.text = str(r.get_meta("switchyard_skin")) + " / " + side
			await capture("close-" + r.model_id + "-" + side)
	floor_mesh.show()
	for r in robots: r.show()
	view(Vector3(8,6,-13),Vector3(0,1,0),11)
	for lod in range(3):
		for r in robots: r.set_lod(lod)
		title.text = "SWITCHYARD / geometric transition / LOD " + str(lod)
		await capture("lod-"+str(lod))
	for distance: float in [12.0,22.1,48.1]:
		for r in robots: r.select_distance(distance)
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 70; camera.position = Vector3(0,1.7,-distance); camera.look_at(Vector3(0,1.1,0))
		title.text = "SWITCHYARD / combat distance %.1fm" % distance
		await capture("distance-"+str(int(distance)))
	view(Vector3(8,6,-13),Vector3(0,1,0),11)
	for r in robots: r.set_lod(0); r.reset_pose()
	var previous := Time.get_ticks_usec()
	for frame in range(120):
		var modes := ["idle","walk","attack","react","death","reset"]
		var mode: String = modes[frame/20]
		var now := Time.get_ticks_usec()
		pose(mode, float(now-previous)/1000000.0); previous = now
		title.text = "SWITCHYARD / native " + mode + " / captured wall-clock cadence"
		await capture("animation-%03d" % frame)
		await create_timer(.08).timeout
	for r in robots: r.free()
	robots.clear(); floor_mesh.hide()
	var props: Array[Node3D] = []
	index = 0
	for name: String in ["relay_console","repair_dock","battery_rack","blast_shutter_frame","cargo_stack","cable_junction"]:
		var packed := load(Adapter.DIRECTORY+name+".glb") as PackedScene
		var prop := packed.instantiate() as Node3D
		world.add_child(prop); props.append(prop)
		prop.position = Vector3((index%3-1)*3.3,0,(index/3)*3.2)
		index += 1
	view(Vector3(9,9,-13),Vector3(0,.6,1),12)
	title.text = "SWITCHYARD / six workshop assemblies / no added colliders"
	await capture("props-six")
	for i in props.size():
		for j in props.size(): props[j].visible = i == j
		var p := props[i].position
		view(p+Vector3(2.8,2.7,-4),p+Vector3(0,.9,0),3.7)
		title.text = str(props[i].name)
		await capture("prop-"+str(i))
	for p in props: p.free()
	var terrain := Terrain.new(); world.add_child(terrain); assert(terrain.build("emberline-ascent"))
	# Actual campaign lighting is inspected in production_capture; this gallery's
	# fixed studio key otherwise causes distant terrain self-shadow aliasing.
	light.shadow_enabled = false
	var workshop: Node3D = terrain.get_node("SwitchyardWorkshop")
	assert(workshop.installed.size() == 6)
	report.productionMounts = workshop.installed
	for prop: Node3D in workshop.get_children():
		var p := prop.global_position
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.position = p + Vector3(2.2,1.5,-4); camera.look_at(p+Vector3(0,.65,0))
		title.text = "EMBERLINE / " + str(prop.name) + " / existing cover mount"
		await capture("production-"+str(prop.name))
	terrain.free()
	var file := FileAccess.open(out.path_join("inspection.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")); file.close()
	world.free(); title.free()
	print("SWITCHYARD_INSPECTION_OK frames=",report.frames.size()," renderer=",report.renderer)
	quit()
