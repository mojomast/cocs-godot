extends SceneTree
const Controller = preload("res://combat_shields/controller.gd")
const Actor = preload("res://player_models/candidate.gd")
var fx: Node3D
var rig: Node3D
var camera: Camera3D
var model: Node3D
var output := ""
var size := Vector2i(960,640)
var failed := false
var measurements := {}
var fixture: Dictionary

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(parts[0]),int(parts[1]))
	create_timer(120.0).timeout.connect(func() -> void: push_error("COMBAT_SHIELDS_RENDER watchdog"); quit(1))
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error("COMBAT_SHIELDS_RENDER: " + message)

func box(pos: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = mat
	node.position = pos
	rig.add_child(node)
	return node

func capture(name: String = "") -> Image:
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if not name.is_empty(): check(image.save_png(output.path_join(name + ".png")) == OK, "save " + name)
	return image

func difference(a: Image, b: Image, area: Rect2i) -> Dictionary:
	var changed := 0
	var total := 0.0
	var maximum := 0.0
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var ca := a.get_pixel(x,y)
			var cb := b.get_pixel(x,y)
			var delta := maxf(absf(ca.r-cb.r),maxf(absf(ca.g-cb.g),absf(ca.b-cb.b)))
			if delta > 0.025: changed += 1
			total += delta
			maximum = maxf(maximum,delta)
	return {"changed_pixels":changed,"mean_delta":total/float(area.size.x*area.size.y),"max_delta":maximum,"area":[area.position.x,area.position.y,area.size.x,area.size.y]}

func roi(point: Vector3, half_size: Vector2i) -> Rect2i:
	return Rect2i(Vector2i(camera.unproject_position(point))-half_size,half_size*2)

func run() -> void:
	check(not output.is_empty(), "output required")
	if failed: quit(1); return
	root.size = size
	fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/combat_shields/source.json"))
	rig = Node3D.new()
	root.add_child(rig)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("121d2c")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c6deed")
	environment.environment.ambient_light_energy = 0.7
	rig.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30,-25,0)
	sun.light_energy = 1.3
	rig.add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.4
	camera.position = Vector3(0,1.05,7)
	camera.current = true
	rig.add_child(camera)
	box(Vector3(0,-0.18,-1),Vector3(14,0.3,16),Color("24384b"))
	for i in range(-10,11):
		box(Vector3(i*0.3,1.7,-1.5),Vector3(0.012,3.8,0.04),Color("688291"))
	for i in range(12): box(Vector3(0,i*0.3,-1.5),Vector3(7,0.012,0.04),Color("455c73"))
	var blocker := box(Vector3(-0.50,0.85,1.4),Vector3(0.24,2.1,0.25),Color("bd814f"))
	model = Actor.new()
	model.apply_identity({"character":"claude","team":0})
	model.position = Vector3(0,0.9,0)
	rig.add_child(model)
	fx = Controller.new()
	rig.add_child(fx)
	fx.configure(camera)
	fx.set_process(false)
	fx.apply_state(fixture.frames[1].snapshot.state,0)
	fx._process(0.15)
	var hud := Label.new()
	hud.text = "COMBAT INTERFERENCE / SOURCE SHIELD POOL\nOpaque cover · readable actor · no local first-person shell"
	hud.position = Vector2(28,24)
	hud.add_theme_font_size_override("font_size",20)
	root.add_child(hud)
	fx.visible = false
	var before := await capture("before")
	fx.visible = true
	var after := await capture("after")
	var entire := Rect2i(0,0,size.x,size.y)
	measurements.effect = difference(before,after,entire)
	check(measurements.effect.changed_pixels > 400,"source shield visibly contributes")
	measurements.opaque_depth = difference(before,after,roi(Vector3(-0.50,0.85,1.6),Vector2i(8,65)))
	check(measurements.opaque_depth.max_delta == 0.0,"opaque world occludes shell exactly")
	measurements.actor_readability = difference(before,after,roi(Vector3(0,1.1,0),Vector2i(20,48)))
	check(measurements.actor_readability.mean_delta < 0.20,"actor remains readable through shell")
	var repeat := await capture()
	check(difference(after,repeat,entire).max_delta == 0.0,"caller clock yields deterministic paused rendering")
	fx.apply_events(fixture.frames[2].events.items,0)
	fx._process(0.16)
	var hit := await capture("directional-hit")
	measurements.ripple = difference(after,hit,entire)
	check(measurements.ripple.changed_pixels > 100,"real source directional ripple renders")
	fx.apply_events(fixture.frames[3].events.items,0)
	fx.apply_state(fixture.frames[3].snapshot.state,0)
	fx._process(0.1)
	var shatter := await capture("armor-break")
	measurements.shatter = difference(before,shatter,entire)
	check(measurements.shatter.changed_pixels > 100,"real armor depletion shards render")
	fx._process(0.5)
	fx.apply_state(fixture.frames[3].snapshot.state,0)
	var depleted := await capture("depleted")
	check(difference(before,depleted,entire).max_delta == 0.0,"depleted pool despite running powerup timer has zero rendered protection")
	fx.apply_state(fixture.frames[4].snapshot.state,0)
	fx.apply_events(fixture.frames[4].events.items,0)
	fx._process(0.15)
	var recovery := await capture("recovery")
	check(difference(before,recovery,entire).changed_pixels > 50,"genuine recovery halo visible")
	# Local camera and a remote shell close enough to intersect it are both absent.
	fx.reset()
	var local_state: Dictionary = fixture.frames[1].snapshot.state.duplicate(true)
	local_state.actors[1].id = 0
	local_state.actors = [local_state.actors[1]]
	fx.apply_state(local_state,0)
	var local_image := await capture("local-camera-clear")
	measurements.local_center = difference(before,local_image,Rect2i(size/2-Vector2i(60,60),Vector2i(120,120)))
	check(difference(before,local_image,entire).max_delta == 0.0,"local player creates no full-screen or world-shell coverage")
	local_state.actors[0].id = 3
	local_state.actors[0].z = 6.5
	fx.apply_state(local_state,0)
	check(fx.debug_state().visible_shells == 0,"camera-adjacent remote shell hidden")
	# Reset phase is visual geometry only. Source spawn supplies actor/position.
	fx.reset()
	fx.apply_events(fixture.frames[5].events.items,0)
	fx.apply_state(fixture.frames[5].snapshot.state,0)
	var spawn_actor: Dictionary = fixture.frames[5].snapshot.state.actors[1]
	camera.position = Vector3(spawn_actor.x,spawn_actor.y+1.05,spawn_actor.z+7)
	model.position = Vector3(spawn_actor.x,spawn_actor.y+0.9,spawn_actor.z)
	fx._process(0.18)
	await capture("source-spawn-phase")
	check(fx.debug_state().active_bursts > 0,"genuine source spawn phase")
	# Rendering pressure is explicitly a replicated visual fixture, not 16 players.
	blocker.visible = false
	model.visible = false
	camera.position = Vector3(0,3,16)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.look_at(Vector3(0,1,-3))
	var pressure: Dictionary = fixture.frames[1].snapshot.state.duplicate(true)
	pressure.actors = []
	for id in range(16):
		var a: Dictionary = fixture.frames[1].snapshot.state.actors[1].duplicate(true)
		a.id = id + 1
		a.x = float(id%8)*1.65-5.8
		a.z = -float(id/8)*3.0
		pressure.actors.append(a)
		var actor_model := Actor.new()
		actor_model.apply_identity({"character":"claude","team":id%2})
		actor_model.position = Vector3(a.x,0.9,a.z)
		rig.add_child(actor_model)
	measurements.pressure = {}
	for level in [1,0]:
		fx.reset()
		fx.set_quality(level)
		fx.apply_state(pressure,0)
		var samples: Array[float] = []
		for index in range(45):
			var start := Time.get_ticks_usec()
			fx._process(1.0/60.0)
			await process_frame
			samples.append(float(Time.get_ticks_usec()-start)/1000.0)
		samples.sort()
		await capture("pressure-" + ("high" if level == 1 else "low"))
		measurements.pressure[str(level)] = {"frame_median_ms":samples[22],"frame_p95_ms":samples[42],"draw_calls":root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),"primitives":root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),"controller":fx.debug_state(),"note":"45-frame software wall-clock proxy, not hardware GPU acceptance"}
		check(fx.debug_state().visible_shells == 16,"16 simultaneous visible shells at quality " + str(level))
	fx.reset()
	check(fx.factory.state().materials == 0,"render reset releases all registered materials")
	measurements.renderer = {"method":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"api":RenderingServer.get_video_adapter_api_version(),"size":[size.x,size.y]}
	measurements.passed = not failed
	FileAccess.open(output.path_join("measurements.json"),FileAccess.WRITE).store_string(JSON.stringify(measurements,"\t")+"\n")
	rig.free()
	hud.free()
	print("COMBAT_SHIELDS_RENDER_%s size=%s" % ["OK" if not failed else "FAIL",size])
	quit(1 if failed else 0)
