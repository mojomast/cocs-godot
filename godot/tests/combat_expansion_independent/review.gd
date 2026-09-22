extends SceneTree
## Independent API/source oracle + real Compatibility framebuffer review.
const Rig = preload("res://first_person/rig.gd")
const Shields = preload("res://combat_shields/controller.gd")
var output := ""
var size := Vector2i(960,640)
var checks: Array[Dictionary] = []
var observations: Array[Dictionary] = []
var measured := {}
var oracle: Dictionary
var camera: Camera3D
var rig: Node

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--size="):
			var bits := arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(bits[0]),int(bits[1]))
	create_timer(150.0).timeout.connect(func() -> void: push_error("independent review timeout"); quit(1))
	call_deferred("run")

func check(ok: bool, label: String, value: Variant = null) -> void:
	checks.append({"label":label,"passed":ok,"value":value})
	if not ok: print("CHECK_FAILED ",label," ",value)

func settle(aim: bool, count: int = 150) -> void:
	for n in range(count):
		rig.apply_aim(aim)
		rig.advance(1.0/60.0)

func frame(view: Viewport) -> Image:
	for n in range(3): await process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()

func save(image: Image, name: String) -> void:
	check(image.save_png(output.path_join(name + ".png")) == OK,"save " + name)

func box(parent: Node3D, position: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	node.material_override = material
	node.position = position
	parent.add_child(node)
	return node

func delta(a: Image, b: Image, roi: Rect2i) -> Dictionary:
	var changed := 0
	var total := 0.0
	var maximum := 0.0
	for y in range(roi.position.y,roi.end.y):
		for x in range(roi.position.x,roi.end.x):
			var ca := a.get_pixel(x,y)
			var cb := b.get_pixel(x,y)
			var d := maxf(absf(ca.r-cb.r),maxf(absf(ca.g-cb.g),absf(ca.b-cb.b)))
			if d > 1.0/255.0: changed += 1
			maximum = maxf(maximum,d)
			total += d
	return {"changed":changed,"mean":total/float(roi.size.x*roi.size.y),"max":maximum}

func tip_geometry(index: int) -> Dictionary:
	var anchor: Node3D = rig.anchors["Muzzle%d" % index]
	var closest_plane := INF
	var front := INF
	var radial := INF
	for mesh: MeshInstance3D in anchor.get_parent().find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var p := anchor.to_local(mesh.to_global(vertex))
				front = minf(front,p.z)
				closest_plane = minf(closest_plane,absf(p.z))
				if absf(p.z) < 0.002: radial = minf(radial,Vector2(p.x,p.y).length())
	return {"front_of_assembly_relative_to_tip_m":front,"nearest_vertex_plane_m":closest_plane,"nearest_rim_radius_m":radial}

func run_ads() -> void:
	camera = Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.position = Vector3(4,2,3)
	camera.rotation = Vector3(-0.11,0.37,0)
	camera.h_offset = 0.17
	camera.v_offset = -0.08
	rig = Rig.new()
	root.add_child(rig)
	rig.attach_to(camera)
	rig.set_process(false)
	rig.external_muzzle_fx = true
	var sheet := Image.create(1024,800,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("182332"))
	var weapon_measurements := []
	for fixture: Dictionary in oracle.weapons:
		var actor: Dictionary = fixture.before.duplicate(true)
		var id := int(fixture.id)
		rig.reset()
		camera.fov = 75
		rig.apply_actor(actor,true)
		settle(false)
		check(rig.get_muzzle_count() == (2 if id == 3 else 1),"source weapon muzzle count %d" % id)
		var hip := await frame(root)
		hip.resize(256,160)
		sheet.blit_rect(hip,Rect2i(0,0,256,160),Vector2i((id%2)*512,(id/2)*160))
		var report := {"id":id,"tips":[],"fov":[]}
		for i in range(rig.get_muzzle_count()):
			var tip := tip_geometry(i)
			report.tips.append(tip)
			check(absf(tip.front_of_assembly_relative_to_tip_m) < 0.022 and tip.nearest_vertex_plane_m < 0.002 and tip.nearest_rim_radius_m < 0.13,"muzzle at real imported bore rim %d/%d" % [id,i],tip)
			var world: Transform3D = rig.get_muzzle_world_transform(i)
			var error := camera.unproject_position(world.origin).distance_to(rig.get_muzzle_screen_position(i))
			check(error < 0.001,"offset camera/world muzzle projection %d/%d" % [id,i],error)
		settle(true)
		var resting: Transform3D = rig.get_muzzle_world_transform()
		for fov: Dictionary in fixture.fov:
			var state: Dictionary = rig.get_aim_state(fov.base)
			report.fov.append({"base":fov.base,"actual":state.fov,"source":fov.expected})
			check(absf(state.fov-fov.expected) < 0.001,"executed JS FOV oracle %d/%s" % [id,str(fov.base)])
		check(camera.fov == 75,"ADS API leaves source camera under caller authority %d" % id)
		camera.fov = rig.get_aim_state(75).fov
		rig.advance(0)
		var sights: Dictionary = rig.get_sight_screen_positions()
		check(sights.rear.distance_to(Vector2(size)/2) < 0.002 and sights.front.distance_to(Vector2(size)/2) < 0.002,"settled real sights align after caller FOV %d" % id)
		var ads := await frame(root)
		ads.resize(256,160)
		sheet.blit_rect(ads,Rect2i(0,0,256,160),Vector2i((id%2)*512+256,(id/2)*160))
		rig.apply_events(fixture.fire,int(actor.id))
		rig.advance(0)
		var kicked: Transform3D = rig.get_muzzle_world_transform()
		report.recoil_tip_travel_m = kicked.origin.distance_to(resting.origin)
		check(rig.recoil_count == 1 and report.recoil_tip_travel_m > 0.001,"actual source volley drives exactly one physical recoil %d" % id,report.recoil_tip_travel_m)
		rig.apply_events(fixture.fire,int(actor.id))
		check(rig.recoil_count == 1,"actual source volley replay coalesces %d" % id)
		settle(true)
		check(rig.get_muzzle_world_transform().origin.distance_to(resting.origin) < 0.00001,"ADS barrel recovers after source recoil %d" % id)
		var reload: Dictionary = fixture.reload.duplicate(true)
		if not fixture.reloadAccepted:
			# Pulse is source infinite-ammo; exercise the public API using an
			# explicitly synthetic lifecycle state, not a claimed source reload.
			reload.reloading = true
			reload.reloadDuration = 1.0
		reload.reloadTimer = reload.reloadDuration*0.5
		rig.apply_actor(reload,true)
		check(not rig.apply_aim(true),"reload rejects held ADS %d (source=%s)" % [id,str(fixture.reloadAccepted)])
		settle(true)
		check(rig.get_aim_state(75).weight == 0 and rig.get_aim_state(75).fov == 75,"reload exits ADS and restores FOV recommendation %d" % id)
		if id == 3:
			var opening: Transform3D = rig.get_muzzle_world_transform()
			rig.apply_actor(actor,true)
			rig.advance(0)
			var closed: Transform3D = rig.get_muzzle_world_transform()
			check(opening.basis.z.angle_to(closed.basis.z) > 0.2,"break-action barrel direction follows opened geometry")
		rig.apply_actor(actor,true)
		settle(true)
		for hidden in [{"health":0},{"dead":1},{"vehicleId":0},{"spectating":true}]:
			var blocked: Dictionary = actor.duplicate(true)
			blocked.merge(hidden,true)
			rig.apply_actor(blocked,true)
			check(rig.get_aim_state(75).weight == 0 and rig.get_muzzle_count() == 0 and rig.get_sight_screen_positions().is_empty(),"hidden source transition resets API %d %s" % [id,str(hidden)])
			check(rig.get_muzzle_world_transform() == Transform3D.IDENTITY and not rig.get_muzzle_screen_position().is_finite(),"hidden muzzle sentinels %d" % id)
			rig.apply_actor(actor,true)
			settle(true)
		rig.apply_actor(actor,false) # Session's focus/pointer/stale gate.
		check(not rig.apply_aim(true) and rig.get_aim_state(75).weight == 0,"visibility/focus contract immediately clears held ADS %d" % id)
		var hidden_events: Array = fixture.fire.duplicate(true)
		for event: Dictionary in hidden_events:
			event.id += 100
			event.time += 1
		rig.apply_events(hidden_events,int(actor.id))
		rig.apply_actor(actor,true)
		rig.apply_events(hidden_events,int(actor.id))
		check(rig.recoil_count == 1 and rig.recoil == 0,"fire received while unfocused cannot replay on recovery %d" % id)
		weapon_measurements.append(report)
	# A held aim request across a real source weapon change must lower first.
	rig.apply_actor(oracle.weapons[0].before,true)
	settle(true)
	rig.apply_actor(oracle.weapons[2].before,true)
	rig.apply_aim(true)
	rig.advance(0.05)
	check(rig.get_aim_state(75).weight == 0 and not rig.get_aim_state().ready,"held-ADS weapon switch lowers before new sight")
	settle(true)
	check(rig.get_aim_state().ready and rig.get_aim_state().kind == "scope","held-ADS switch resolves new integrated scope")
	rig.reset()
	check(rig.get_aim_state(75).fov == 75 and not rig.showing,"round reset clears scope zoom recommendation")
	save(sheet,"independent-all-ten-hip-ads")
	measured.ads = weapon_measurements
	rig.free()
	camera.free()

func run_shields() -> void:
	var view := SubViewport.new()
	view.size = size
	view.transparent_bg = true
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var world := Node3D.new()
	view.add_child(world)
	var cam := Camera3D.new()
	cam.position = Vector3(0,0.9,6)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4
	cam.current = true
	world.add_child(cam)
	var fx := Shields.new()
	world.add_child(fx)
	fx.configure(cam)
	fx.set_process(false)
	var expected := {"spawn-immunity":"spawn protection","active-is-not-immunity":"","expired-overshield-pool":"","temporary-absorb":"temporary shield","armor-is-partial":"armor energy","juggernaut-absorb":"juggernaut shield","bulwark-front":"directional damage reduction","bulwark-rear":"directional damage reduction","bulwark-yaw-quarter":"directional damage reduction","armor-depleted":"armor energy"}
	var source_results := []
	for fixture: Dictionary in oracle.cases:
		fx.reset()
		fx.apply_state(fixture.before,1)
		check(fx.debug_state().kinds[0] == expected[fixture.label],"source damage semantics " + fixture.label,fixture.healthLoss)
		var pristine := JSON.stringify(fixture)
		fx.apply_events(fixture.events,1)
		var ripples: int = fx.debug_state().counters.ripples
		fx.apply_events(fixture.events,1)
		check(fx.debug_state().counters.ripples == ripples,"numeric source event replay " + fixture.label)
		fx.apply_state(fixture.after,1)
		check(JSON.stringify(fixture) == pristine,"shield presentation preserves source snapshot/events " + fixture.label)
		if fixture.label in ["temporary-absorb","juggernaut-absorb","armor-depleted"]:
			check(fx.debug_state().visible_shells == 0 and fx.debug_state().counters.shatters == 1,"genuine source pool depletion renders break once " + fixture.label)
		source_results.append({"case":fixture.label,"health_loss":fixture.healthLoss,"controller":fx.debug_state()})
	measured.source_cases = source_results
	# Render the actual source spawn immunity envelope onto transparent RGBA.
	var state: Dictionary = oracle.cases[0].before.duplicate(true)
	fx.reset()
	fx.apply_state(state,1)
	fx._process(0.15)
	var alpha_image := await frame(view)
	var max_alpha := 0.0
	var partial := 0
	for y in range(size.y):
		for x in range(size.x):
			var a := alpha_image.get_pixel(x,y).a
			max_alpha = maxf(max_alpha,a)
			if a > 0 and a < 1: partial += 1
	check(max_alpha <= 0.63 and max_alpha > 0.05 and partial > 1000,"actual transparent render has bounded nonopaque shell",{"max_alpha":max_alpha,"partial_pixels":partial})
	save(alpha_image,"shield-alpha")
	var backdrop := box(world,Vector3(0,0.9,-1.5),Vector3(7,4,0.1),Color("25384b"))
	for i in range(-9,10): box(world,Vector3(i*0.25,0.9,-1.3),Vector3(0.015,4,0.1),Color("b8c8d8"))
	var body := box(world,Vector3(0,0.9,0),Vector3(0.45,1.6,0.3),Color("c04731"))
	var occluder := box(world,Vector3(-0.38,0.9,1.2),Vector3(0.22,2.8,0.2),Color("e3b46d"))
	fx.hide()
	var before := await frame(view)
	fx.show()
	var after := await frame(view)
	save(before,"shield-before")
	save(after,"shield-after")
	var wall_point := Vector2i(cam.unproject_position(occluder.position))
	var wall_roi := Rect2i(wall_point-Vector2i(8,100),Vector2i(16,200))
	var body_point := Vector2i(cam.unproject_position(body.position))
	var body_roi := Rect2i(body_point-Vector2i(15,65),Vector2i(30,130))
	var wall := delta(before,after,wall_roi)
	var center := delta(before,after,body_roi)
	check(wall.max == 0,"opaque wall blocks real shader fragments exactly",wall)
	check(center.mean < 0.15 and center.max > 0,"opaque body remains visible through actual alpha",center)
	measured.shield_render = {"max_alpha":max_alpha,"partial_pixels":partial,"wall":wall,"body":center,"whole":delta(before,after,Rect2i(Vector2i.ZERO,size))}
	# Actual front-vs-back source cone: yaw 0 faces -Z, camera is +Z.
	body.hide()
	occluder.hide()
	fx.reset()
	fx.hide()
	var empty := await frame(view)
	fx.show()
	var cone: Dictionary = oracle.cases[6].before.duplicate(true)
	fx.apply_state(cone,1)
	var back := await frame(view)
	cone.actors[0].yaw = PI
	fx.apply_state(cone,1)
	var front := await frame(view)
	var rear_change := delta(empty,back,Rect2i(Vector2i.ZERO,size))
	var front_change := delta(empty,front,Rect2i(Vector2i.ZERO,size))
	check(rear_change.changed == 0 and front_change.changed > 500,"rendered bulwark cone follows actual source damage-facing convention",{"rear":rear_change,"front":front_change})
	measured.directional_render = {"rear":rear_change,"front":front_change}
	# Under a fixed pool budget, irrelevant actor ordering can starve real shields.
	fx.reset()
	fx.set_quality("low")
	var crowded := {"time":0,"actors":[]}
	for i in range(17):
		var a: Dictionary = state.actors[0].duplicate(true)
		a.id = i
		a.protection = 0 if i < 16 else 1
		a.x = 0
		crowded.actors.append(a)
	fx.apply_state(crowded,-1)
	var normal_order := fx.debug_state()
	var starved := await frame(view)
	fx.reset()
	crowded.actors.reverse()
	fx.apply_state(crowded,-1)
	var reversed_order := fx.debug_state()
	var prioritized := await frame(view)
	starved.resize(size.x/2,size.y/2)
	prioritized.resize(size.x/2,size.y/2)
	var ordering_image := Image.create(size.x,size.y/2,false,Image.FORMAT_RGBA8)
	ordering_image.blit_rect(starved,Rect2i(Vector2i.ZERO,size/2),Vector2i.ZERO)
	ordering_image.blit_rect(prioritized,Rect2i(Vector2i.ZERO,size/2),Vector2i(size.x/2,0))
	save(ordering_image,"shield-order-defect-left-starved-right-reversed")
	observations.append({"id":"SHIELD-CAP-ORDER","first_16_unprotected":normal_order,"protected_first":reversed_order})
	# Wire identity is numeric, including zero; strings must not alias source IDs.
	fx.reset()
	fx.apply_state(state,1)
	fx.apply_events([{"type":"damage","id":"7","actor":0,"source":1,"amount":5}],1)
	check(fx.debug_state().counters.ripples == 0,"string event IDs do not alias numeric source serials")
	fx.apply_events([{"type":"damage","id":0,"actor":0,"source":1,"amount":5}],1)
	check(fx.debug_state().counters.ripples == 1,"numeric event zero and remote actor zero are valid")
	fx.apply_events([{"type":"damage","id":1,"actor":"0","source":1,"amount":5}],1)
	check(fx.debug_state().counters.ripples == 1,"string actor IDs do not alias remote actor zero")
	# Quality/resource teardown, including real OS notification contract.
	fx.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(fx.debug_state().visible_shells == 0,"OS focus out hides actual controller")
	fx.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	fx._process(0.01)
	check(fx.debug_state().visible_shells == 0,"OS focus in requires fresh state")
	fx.apply_state(crowded,-1)
	check(fx.debug_state().visible_shells == 1,"fresh snapshot restores post-focus shield")
	fx._process(1.01)
	check(fx.debug_state().visible_shells == 0,"snapshot staleness removes shields")
	var factory = fx.factory
	fx.reset()
	check(factory.state().materials == 0 and fx.get_child_count() == 0,"reset releases registered materials AND render nodes",factory.state())
	fx.apply_state(state,1)
	fx.free()
	check(factory.state().materials == 0,"tree teardown releases factory registrations",factory.state())
	backdrop.free()
	view.free()

func run() -> void:
	root.size = size
	oracle = JSON.parse_string(FileAccess.get_file_as_string("res://tests/combat_expansion_independent/oracle.json"))
	await run_ads()
	await run_shields()
	var failed := checks.filter(func(item: Dictionary) -> bool: return not item.passed)
	var report := {"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"size":[size.x,size.y],"checks":checks,"failures":failed,"observations":observations,"measurements":measured}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("INDEPENDENT_REVIEW ",JSON.stringify({"size":[size.x,size.y],"checks":checks.size(),"failures":failed,"observations":observations}))
	quit(0 if failed.is_empty() else 1)
