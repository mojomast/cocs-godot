extends SceneTree
## Actual production chapter composition, matched full-viewport before/after.
## Needs owned --endpoint and --map, exactly as campaign/demo.gd. Camera staging
## is explicitly recorded; this is art inspection, not ordinary-input journey proof.
const Pack = preload("res://biomes/expansion/scenery_pack.gd")
var session: Node
var output := ""
var compact := false
var rows: Array = []
var start_usec := 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--compact": compact = true
	call_deferred("run")

func collider_signature(node: Node, out: Array) -> void:
	if node is CollisionObject3D:
		out.append([str(node.get_path()), node.get_instance_id(), node.collision_layer, node.collision_mask])
	if node is CollisionShape3D:
		var shape: Shape3D = node.shape
		var geometry: Variant = shape.get_faces() if shape is ConcavePolygonShape3D else shape.size if shape is BoxShape3D else str(shape)
		out.append([str(node.get_path()), node.get_instance_id(), shape.get_instance_id(), hash(geometry), str(node.global_transform)])
	for child: Node in node.get_children(): collider_signature(child, out)

func mesh_counts(node: Node, result: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		result.meshes += 1
		result.surfaces += node.mesh.get_surface_count()
		result.triangles += node.mesh.get_faces().size() / 3
	for child: Node in node.get_children(): mesh_counts(child, result)

func capture(label: String, camera_kind: String) -> void:
	session.campaign_hud._process(0.0)
	for frame: int in 4: await process_frame
	await RenderingServer.frame_post_draw
	var now := Time.get_ticks_usec()
	var file := output.path_join(label + ".png")
	assert(root.get_texture().get_image().save_png(file) == OK)
	rows.append({"file":file, "capturedUsec":now, "elapsedUsec":now-start_usec,
		"cameraKind":camera_kind, "camera":str(session.camera.global_transform),
		"viewport":[root.size.x,root.size.y], "uiScale":150 if compact else 100,
		"drawCalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"videoMemory":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"frameSeconds":Performance.get_monitor(Performance.TIME_PROCESS)})
	# Persist each capture, including evidence before a later assertion fails.
	var report := FileAccess.open(output.path_join("captures.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"evidence":"staged production-session art inspection", "captures":rows}, "\t"))

func run() -> void:
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(760,520) if compact else Vector2i(1280,800)
	var settings := root.get_node_or_null("LocalSettings")
	assert(settings != null)
	settings.set_value("ui_scale", 150 if compact else 100, false)
	var scene: PackedScene = load("res://campaign/demo.tscn")
	session = scene.instantiate()
	root.add_child(session)
	current_scene = session
	assert(str(session.startup_error).is_empty())
	session.launch_campaign()
	var deadline := Time.get_ticks_msec() + 30000
	while session.phase != 3 or not session.received_pose or session.client.last_ack <= 0:
		assert(Time.get_ticks_msec() < deadline, "Production source connection did not start")
		await process_frame
	session.release_pointer()
	var world: Node3D = session.world
	var original_pose: Transform3D = session.camera.global_transform
	var original_fov: float = session.camera.fov
	var baseline: Array = []
	collider_signature(world, baseline)
	var pack: Node3D = world.get_node_or_null("BiomeExpansionFour")
	if pack == null:
		pack = Pack.new()
		pack.name = "BiomeExpansionFour"
		world.add_child(pack)
	assert(pack.build(world, true))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Pack.CATALOG))
	var placements: Array = catalog.chapters[str(world.recipe.id)].placements
	var counts := {"meshes":0,"surfaces":0,"triangles":0}
	mesh_counts(pack, counts)
	assert(counts.meshes == 6 and pack.loaded_assets.size()==3 and counts.surfaces <= 24 and counts.triangles < 27000)
	var after: Array = []
	collider_signature(world, after)
	assert(after == baseline, "Original collider IDs, transforms and geometry changed")
	# Hold the session and weather clocks identically for paired still images.
	# Production resources/HUD remain visible; source time is not fabricated.
	session.process_mode = Node.PROCESS_MODE_DISABLED
	start_usec = Time.get_ticks_usec()
	for placement: Dictionary in placements:
		var route: Array = world.recipe.campaign.criticalPath
		var near: Dictionary = route[0]
		var target := Pack.vector(placement.origin) + Vector3(0, float(placement.scale[1])*.5,0)
		for p: Dictionary in route:
			if Vector2(p.x,p.z).distance_to(Vector2(target.x,target.z)) < Vector2(near.x,near.z).distance_to(Vector2(target.x,target.z)): near = p
		for view: String in ["approach", "eye"]:
			var eye := Vector3(near.x,near.y+1.65,near.z)
			if view == "approach":
				var index := maxi(0,route.find(near)-5)
				var p: Dictionary = route[index]
				eye = Vector3(p.x,p.y+1.65,p.z)
			session.camera.global_position = eye
			session.camera.look_at(target)
			session.camera.fov = 65.0
			for phase: String in ["before","after","reduced"]:
				pack.visible = phase != "before"
				pack.set_reduced_detail(phase == "reduced")
				await capture(str(placement.asset)+"-"+view+"-"+phase,"staged supported eye; production scene/HUD")
	pack.visible = true
	pack.set_reduced_detail(false)
	if str(world.recipe.id)=="emberline-ascent":
		var workshop: Node3D=world.get_node("SwitchyardWorkshop")
		assert(workshop.installed.size()==6 and workshop.get_child_count()==6)
		for prop: Node3D in workshop.get_children():
			var near: Dictionary=world.recipe.campaign.criticalPath[0]
			for point: Dictionary in world.recipe.campaign.criticalPath:
				if Vector2(point.x,point.z).distance_to(Vector2(prop.global_position.x,prop.global_position.z))<Vector2(near.x,near.z).distance_to(Vector2(prop.global_position.x,prop.global_position.z)): near=point
			session.camera.global_position=Vector3(near.x,near.y+1.65,near.z)
			session.camera.look_at(prop.global_position+Vector3(0,0.6,0))
			await capture("preserved-robot-prop-"+str(prop.name),"staged supported route; unchanged original robot workshop prop")
	session.camera.global_transform = original_pose
	session.camera.fov = original_fov
	session.process_mode = Node.PROCESS_MODE_INHERIT
	await capture("source-camera-return","production snapshot camera")
	# Teardown/rebuild owns no source/collider/material mutations.
	pack.clear()
	await process_frame
	assert(pack.get_child_count() == 0 and pack.loaded_assets.is_empty())
	assert(pack.build(world,true))
	var restored: Array = []
	collider_signature(world,restored)
	assert(restored == baseline)
	var report := FileAccess.open(output.path_join("resources.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"imported":counts,"recipe":pack.recipe_hash,"collidersUnchanged":true,
		"captureCount":rows.size(),"captureSpanSeconds":float(Time.get_ticks_usec()-start_usec)/1000000.0,
		"ordinaryInputJourney":"pending separate walk/shot acceptance"},"\t"))
	session.free()
	await process_frame
	quit()
