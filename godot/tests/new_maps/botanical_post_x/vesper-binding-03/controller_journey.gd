extends SceneTree
## FUTURE EXPLICIT GRANT ONLY. Actual exploration controller, no invented step-up.
const Walker = preload("res://exploration/walker.gd")
const ArtBinding = preload("art_binding.gd")
var directory := ""
var group_id := ""
var records: Array = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="): directory = arg.trim_prefix("--fixture=")
		if arg.begins_with("--case="): group_id = arg.trim_prefix("--case=")
	assert(directory.begins_with("res://tests/new_maps/botanical_post_x/"))
	call_deferred("run")
	create_timer(170).timeout.connect(func() -> void: push_error("Controller journey bound exceeded"); quit(2))

func json(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(value is Dictionary)
	return value

func vector(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func write_once(path: String, value: Dictionary) -> void:
	assert(not FileAccess.file_exists(path),"Attempt receipt already exists")
	var file := FileAccess.open(path,FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(value,"\t")+"\n")
	file.close()

func clock() -> Dictionary:
	return {"physicsFrame":Engine.get_physics_frames(),"physicsTicksPerSecond":Engine.physics_ticks_per_second,
		"timeScale":Engine.time_scale,"monotonicUsec":Time.get_ticks_usec(),"inPhysicsFrame":Engine.is_in_physics_frame()}

func run() -> void:
	var version := Engine.get_version_info()
	assert(version.major==4 and version.minor==5 and version.patch==2, "Pinned Godot 4.5.2 required")
	assert(Engine.physics_ticks_per_second == 60, "Fixture requires actual 60Hz physics")
	assert(Engine.time_scale==1.0,"No time warp")
	var config := json(directory+"source.json")
	for path: String in config.files:
		assert(FileAccess.get_sha256(path)==config.files[path], "Source fixture drift: "+path)
	assert(config.groups.has(group_id))
	var group: Dictionary = config.groups[group_id]
	assert(group_id.begins_with(str(group.variant)+"-"+str(group.run)+"-"),"Case/variant substitution")
	var output := directory+group_id+"-journey.json"
	assert(not FileAccess.file_exists(output), "Fresh attempt required")
	var data := json(directory+str(group.variant)+".json")
	var bound := ArtBinding.make_world(root,directory,config,str(group.variant))
	assert(bound.receipt.bindingReady and bound.receipt.bothVariantsRuntimeVerified)
	var world: Node3D = bound.world
	write_once(directory+group_id+"-binding.json",{"binding":bound.receipt,"clock":clock(),"godot":version,
		"physicsEngine":ProjectSettings.get_setting("physics/3d/physics_engine","DEFAULT"),"sourceSha256":FileAccess.get_sha256(directory+"source.json"),
		"scope":"Pre-trial binding only; walk-only JSON/art diagnostic, empty Binder state; no Weather acceptance"})
	await physics_frame
	var failed := false
	for trial: Dictionary in group.trials:
		var walker := Walker.new()
		root.add_child(walker)
		walker.set_physics_process(false)
		var capsule: CapsuleShape3D
		var collider: CollisionShape3D
		for child: Node in walker.get_children():
			if child is CollisionShape3D:
				collider = child
				capsule = child.shape
		assert(capsule != null and is_equal_approx(capsule.radius,.35) and is_equal_approx(capsule.height,1.8))
		assert(collider.position.is_equal_approx(Vector3(0,.9,0)) and not collider.disabled)
		assert(is_equal_approx(walker.safe_margin,.02) and is_equal_approx(walker.floor_snap_length,.3))
		assert(is_equal_approx(walker.floor_max_angle,deg_to_rad(46.0)) and walker.floor_stop_on_slope)
		assert(Walker.WALK_SPEED==6.0 and Walker.SPRINT_SPEED==10.0 and Walker.GRAVITY==20.0)
		assert(group.radius==.35 or group.radius==.42)
		capsule.radius = float(group.radius) # .35 exact controller, .42 explicitly test-only envelope
		var shape_data: Dictionary = PhysicsServer3D.shape_get_data(capsule.get_rid())
		assert(is_equal_approx(shape_data.radius,group.radius) and is_equal_approx(shape_data.height,1.8))
		var parameters := {"radius":capsule.radius,"height":capsule.height,"physicsShape":shape_data,"colliderOffset":vector(collider.position),
			"safeMargin":walker.safe_margin,"floorSnap":walker.floor_snap_length,"floorMaxAngle":walker.floor_max_angle,
			"walkSpeed":Walker.WALK_SPEED,"sprintSpeed":Walker.SPRINT_SPEED,"gravity":Walker.GRAVITY,
			"maxSlides":walker.max_slides,"collisionLayer":walker.collision_layer,"collisionMask":walker.collision_mask,
			"spawnSeparation":.05,"clock":clock(),"sprint":false,"jump":false}
		write_once(directory+group_id+"-trial-"+str(records.size())+"-parameters.json",parameters)
		var start := Vector3(trial.start[0],trial.start[1],trial.start[2])
		var goal := Vector3(trial.goal[0],trial.goal[1],trial.goal[2])
		walker.set_spawn(start+Vector3.UP*.05)
		# Initial spawn separation only; from here every response comes from step().
		for settle in range(20):
			await physics_frame
			assert(Engine.is_in_physics_frame() and is_equal_approx(walker.get_physics_process_delta_time(),1.0/60.0))
			walker.step(1.0/60.0,Vector2.ZERO)
		var trace: Array = []
		var reached := false
		var stalled := 0
		for frame in range(900):
			await physics_frame
			assert(Engine.is_in_physics_frame() and Engine.time_scale==1.0 and is_equal_approx(walker.get_physics_process_delta_time(),1.0/60.0))
			var before: Vector3 = walker.position
			var delta := goal-walker.position
			# Arrival must be on the actual landing, with only the controller's
			# own 2cm safe margin plus 1mm numeric headroom. No one-tread waiver.
			if Vector2(delta.x,delta.z).length()<.15 and absf(delta.y)<=walker.safe_margin+.001 and walker.is_on_floor():
				reached = true
				break
			var wish := Vector2(delta.x,-delta.z).normalized()
			walker.step(1.0/60.0,wish,false,false)
			assert(walker.position.is_finite())
			var collisions: Array = []
			for index in walker.get_slide_collision_count():
				var hit := walker.get_slide_collision(index)
				collisions.append({"collider":str(hit.get_collider().name),"normal":vector(hit.get_normal()),"position":vector(hit.get_position())})
			var query := PhysicsRayQueryParameters3D.create(walker.position+Vector3.UP*.3,walker.position-Vector3.UP*.8,1,[walker.get_rid()])
			var support := world.get_world_3d().direct_space_state.intersect_ray(query)
			trace.append({"frame":frame,"clock":clock(),"before":vector(before),"position":vector(walker.position),"velocity":vector(walker.velocity),
				"grounded":walker.is_on_floor(),"support":vector(support.position) if not support.is_empty() else null,
				"supportCollider":str(support.collider.name) if not support.is_empty() else null,
				"supportNormal":vector(support.normal) if not support.is_empty() else null,"collisions":collisions,"resetCount":walker.reset_count})
			stalled = stalled+1 if walker.position.distance_to(before)<.0001 else 0
			if stalled>=120 or walker.reset_count!=1: break
		failed = failed or not reached
		records.append({"trial":trial,"parameters":parameters,"reached":reached,"stalledFrames":stalled,"frames":trace,"radius":capsule.radius,
			"height":capsule.height,"safeMargin":walker.safe_margin,"floorSnap":walker.floor_snap_length,"floorMaxAngle":walker.floor_max_angle})
		walker.queue_free()
		await process_frame
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"case":group_id,"geometryHash":data.geometryHash,"sourceSha256":FileAccess.get_sha256(directory+"source.json"),
		"godot":Engine.get_version_info(),"failed":failed,"records":records,"binding":bound.receipt,"walkOnly":true,"sprint":false,
		"scope":"direct exploration Walker.step walk-only API diagnostic; .42 is test-only envelope; no keyboard/focus/network or full-flight clearance gate; no stair lift/teleport/waiver or full-map acceptance"},"\t")+"\n")
	file.close()
	quit(1 if failed else 0)
