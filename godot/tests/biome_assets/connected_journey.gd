extends SceneTree
## Real campaign scene, native keyboard/mouse events and public source receipts.
const Pack = preload("res://biomes/expansion/scenery_pack.gd")
const Geometry = preload("res://tests/biome_assets/imported_geometry.gd")
const Settings = preload("res://ui/settings_access.gd")
var session: Node
var latest: Dictionary = {}
var events: Array = []
var plan: Dictionary
var output := ""
var plan_path := ""
var observations: Array = []
var failure := ""
var finished := false
var held: Dictionary = {}
var input_epoch := -1
var combat_captured := {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--journey-plan="): plan_path = arg.trim_prefix("--journey-plan=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func key(code: int, pressed: bool) -> void:
	if held.get(code, false) == pressed: return
	held[code] = pressed
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func mouse(pressed: bool) -> void:
	if held.get(-1, false) == pressed: return
	held[-1] = pressed
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = root.size / 2
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func release() -> void:
	key(KEY_W, false)
	key(KEY_E, false)
	key(KEY_R, false)
	mouse(false)

func point_at(target: Vector3) -> void:
	var direction: Vector3 = target - session.presentation.eye_position()
	var wanted_yaw := atan2(-direction.x, -direction.z)
	var wanted_pitch := atan2(direction.y, Vector2(direction.x,direction.z).length())
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(wrapf(float(session.yaw)-wanted_yaw,-PI,PI),float(session.pitch)-wanted_pitch) / (.003 * Settings.sensitivity())
	event.screen_relative = event.relative
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func v(p: Dictionary) -> Vector3: return Vector3(p.x,p.y,p.z)
func actor() -> Dictionary: return session.presentation.local_actor

func verify_geometry() -> bool:
	var path := ProjectSettings.globalize_path("res://../tools/godot-biomes/expansion/meshes.json")
	if FileAccess.get_sha256(path)!=plan.recipeHash: return false
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var checked := 0
	for asset: Dictionary in data.assets:
		if asset.id not in plan.assets: continue
		for lod: int in 2:
			var expected: Dictionary={}
			var expected_triangles: Array=[]
			for part: Dictionary in asset.parts:
				if lod==1 and bool(part.detail): continue
				for face: Array in part.triangles:
					var vertices := [Pack.vector(part.vertices[int(face[0])]),Pack.vector(part.vertices[int(face[1])]),Pack.vector(part.vertices[int(face[2])])]
					expected_triangles.append(vertices)
					var k := Geometry.key(vertices)
					expected[k]=int(expected.get(k,0))+1
			var packed := load(Pack.ART+str(asset.id)+"-%d.glb"%lod) as PackedScene
			if packed==null: return false
			var instance := packed.instantiate()
			var actual: Dictionary={}
			var counts := {"meshes":0,"surfaces":0,"triangles":[]}
			Geometry.collect(instance,Transform3D.IDENTITY,actual,counts)
			instance.free()
			if not Geometry.same_triangles(counts.triangles,expected_triangles) or counts.meshes!=1 or counts.surfaces>4: return false
			checked+=1
	return checked==6

func target_point(target: Dictionary) -> Vector3:
	var volume: Dictionary=plan.hitVolumes[str(target.npcModel)]
	return v(target)+Vector3(0,(float(volume.bottom)+float(volume.top))*.5,0)

func visible_target(target: Dictionary) -> bool:
	var query := PhysicsRayQueryParameters3D.create(session.presentation.eye_position(),target_point(target))
	return session.world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func collider_signature(node: Node, out: Array) -> void:
	if node is CollisionObject3D: out.append([node.get_instance_id(),node.collision_layer,node.collision_mask])
	if node is CollisionShape3D:
		var shape: Shape3D=node.shape
		var geometry: Variant=shape.get_faces() if shape is ConcavePolygonShape3D else shape.size if shape is BoxShape3D else str(shape)
		out.append([node.get_instance_id(),shape.get_instance_id(),hash(geometry),str(node.global_transform)])
	for child: Node in node.get_children(): collider_signature(child,out)

func wait_start() -> bool:
	var deadline := Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline:
		if session.client.input_epoch!=input_epoch:
			release()
			input_epoch=session.client.input_epoch
			await process_frame
		if session.phase==3 and session.received_pose and session.client.last_ack>0: return true
		if not str(session.startup_error).is_empty(): failure=str(session.startup_error); return false
		await process_frame
	failure="campaign start timeout"
	return false

func capture(label: String) -> void:
	await process_frame
	RenderingServer.force_draw()
	var stamp := Time.get_ticks_usec()
	if root.get_texture().get_image().save_png(output.path_join(label+".png")) != OK: failure="capture failed"
	observations.append({"capture":label,"capturedUsec":stamp,"sourceTime":latest.get("time"),"ack":session.client.last_ack})

func perform(stage: Dictionary) -> bool:
	var deadline := Time.get_ticks_msec() + (150000 if stage.kind=="encounter" else 30000)
	var tick := 0
	while Time.get_ticks_msec()<deadline:
		if session.client.input_epoch!=input_epoch:
			release()
			input_epoch=session.client.input_epoch
			await process_frame
		if not str(session.startup_error).is_empty() or actor().get("health",0)<=0 or latest.get("campaign",{}).get("phase")!="playing": failure="source death/transport failure"; return false
		if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:
			release(); root.grab_focus(); mouse(true); await process_frame; mouse(false)
		var campaign: Dictionary=latest.campaign
		if stage.kind=="interact":
			var beat: Dictionary={}
			for item: Dictionary in campaign.interludes.beats:
				if item.id==stage.id: beat=item
			if int(beat.get("stage",0))>=int(stage.stage): release(); return true
		elif stage.kind=="encounter":
			if int(campaign.stepIndex)>=int(stage.step): release(); return true
		elif Vector2(actor().x-stage.point.x,actor().z-stage.point.z).length()<.65:
			release()
			if absf(float(actor().y)-float(stage.point.y))>1.0: failure="source route elevation mismatch"; return false
			return true
		# Fighting uses the same actual mouse-input aiming convention as feel_live.
		# No invulnerability, actor pose, ammo, checkpoint or source-state writes.
		var targets: Array=latest.get("actors",[]).filter(func(a: Dictionary) -> bool: return a.get("isNpc",false) and float(a.get("health",0))>0 and visible_target(a))
		if not targets.is_empty():
			key(KEY_W,false);key(KEY_E,false)
			targets.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return v(a).distance_squared_to(v(actor()))<v(b).distance_squared_to(v(actor())))
			var target: Dictionary=targets[0]
			point_at(target_point(target))
			mouse(true); key(KEY_R,tick%30==0)
			var combat_key := str(campaign.stepIndex)
			if not combat_captured.has(combat_key):
				combat_captured[combat_key]=true
				await create_timer(.12).timeout
				await capture("ordinary-combat-"+combat_key)
		elif stage.kind=="interact":
			mouse(false);key(KEY_W,false)
			if stage.look is Dictionary: point_at(v(stage.look)+Vector3(0,1.4,0))
			key(KEY_E,tick%12<3)
		else:
			mouse(false)
			var target := v(stage.point)
			point_at(target+Vector3(0,1.4,0))
			key(KEY_W,Vector2(actor().x-target.x,actor().z-target.z).length()>.65)
			key(KEY_E,stage.kind=="encounter" and tick%12<3)
		tick+=1
		await create_timer(.05).timeout
	failure="ordinary input timeout: "+JSON.stringify(stage)
	release()
	return false

func run() -> void:
	plan=JSON.parse_string(FileAccess.get_file_as_string(plan_path))
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(760,520) if "--compact" in OS.get_cmdline_user_args() else Vector2i(1280,800)
	RenderingServer.render_loop_enabled=false
	observations.append({"renderer":RenderingServer.get_video_adapter_name(),"internal3DScale":root.scaling_3d_scale,"viewport":[root.size.x,root.size.y],"renderCadence":"explicit captures only; ordinary input continues between captures","reason":"software llvmpipe exceeds unchanged source input TTL; not continuous rendered playability proof"})
	var settings: Node=root.get_node("LocalSettings")
	settings.set_value("ui_scale",150 if root.size.x==760 else 100,false)
	session=load("res://campaign/demo.tscn").instantiate()
	root.add_child(session)
	current_scene=session
	session.client.snapshot.connect(func(frame: Dictionary) -> void: latest=frame.state)
	session.client.events.connect(func(items: Array) -> void: events.append_array(items))
	session.launch_campaign()
	if not await wait_start(): finish(); return
	var world: Node3D=session.world
	var workshop: Node3D=world.get_node("SwitchyardWorkshop")
	var workshop_before: Array=[]
	for prop: Node3D in workshop.get_children(): workshop_before.append([prop.get_instance_id(),str(prop.transform)])
	if plan.id=="emberline-ascent" and workshop_before.size()!=6:
		failure="missing preserved Emberline workshop props";finish();return
	var pack: Node3D=world.get_node("BiomeExpansionFour")
	if not pack.build(world,true) or pack.loaded_assets!=plan.assets or pack.get_child_count()!=6 or pack.recipe_hash!=plan.recipeHash:
		failure="required actual scenery missing/invalid"; finish(); return
	if FileAccess.get_sha256("res://campaign/generated/"+plan.id+".json")!=plan.sourceSha or world.recipe.geometryHash!=plan.geometryHash:
		failure="chapter binding mismatch"; finish(); return
	if not verify_geometry(): failure="actual imported geometry differs from reviewed recipe"; finish(); return
	var before: Array=[]
	collider_signature(world,before)
	var start_time: float=latest.time
	await capture("start")
	for i: int in plan.stages.size():
		if i%20==0: print("SCENERY_ROUTE_PROGRESS ",i,"/",plan.stages.size()," source=",latest.get("time")," ack=",session.client.last_ack)
		if not await perform(plan.stages[i]): finish(); return
		if plan.stages[i].kind!="walk":
			observations.append({"stage":plan.stages[i],"time":latest.time,"ack":session.client.last_ack,"actor":actor().duplicate(true)})
			await capture("stage-%04d"%i)
		if i%50==0:
			pack.set_reduced_detail(true);pack.set_reduced_detail(true)
			pack.set_reduced_detail(false);pack.set_reduced_detail(false)
	if not events.any(func(e: Dictionary) -> bool: return e.get("type")=="shot" and e.get("actor")==session.client.actor_id):
		failure="no public player shot event"; finish(); return
	for id: String in plan.workshops:
		if not events.any(func(e: Dictionary) -> bool: return e.get("type")=="campaign-interlude" and e.get("sourceId")==id and e.get("completed",false)):
			failure="missing completed workshop event: "+id; finish(); return
	var after: Array=[]
	collider_signature(world,after)
	if after!=before: failure="host collision changed"; finish(); return
	var old: Array=[]
	for child: Node in pack.get_children(): old.append(weakref(child))
	pack.clear();pack.clear()
	if not pack.loaded_assets.is_empty() or pack.get_child_count()!=0 or old.any(func(w: WeakRef) -> bool: return w.get_ref()!=null): failure="clear ownership leak"
	if not pack.build(world,true): failure="strict rebuild failed"
	var workshop_after: Array=[]
	for prop: Node3D in workshop.get_children(): workshop_after.append([prop.get_instance_id(),str(prop.transform)])
	if workshop_after!=workshop_before: failure="scenery lifecycle changed original workshop props"
	await capture("source-camera-return")
	observations.append({"sourceElapsed":float(latest.time)-start_time,"ack":session.client.last_ack,"loadedAssets":pack.loaded_assets.duplicate(),"returnedToStart":v(actor()).distance_to(v(plan.start))<2.0})
	release()
	if not failure.is_empty(): finish(); return
	world.tree_exited.connect(func() -> void: print("SCENERY_WORLD_TREE_EXITED"))
	pack.tree_exited.connect(func() -> void: print("SCENERY_PACK_TREE_EXITED"))
	finish(true)
	# Production campaign Leave returns by process exit; the supervisor then
	# presents Home in a new process. It is not an in-process scene change.
	settings.open_panel()
	print("SCENERY_LEAVE_HOME_REQUESTED")
	settings.rows.leave.pressed.emit()

func finish(leave_to_home := false) -> void:
	if finished: return
	finished=true
	release()
	var file := FileAccess.open(output.path_join("journey.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failure.is_empty(),"failure":failure,"plan":plan,"observations":observations,"events":events,"nativeProof":"ordinary Input events; no source or actor state writes"},"\t"))
	print("SCENERY_JOURNEY_DONE ",failure)
	if leave_to_home: return
	if is_instance_valid(session): session.client.disconnect_server()
	quit(0 if failure.is_empty() else 1)
