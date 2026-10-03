extends SceneTree
## FUTURE EXPLICIT GRANT ONLY. Actual exploration controller, no invented step-up.
const Walker = preload("res://exploration/walker.gd")
const WorldMap = preload("res://multiplayer_worlds/map.gd")
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

func run() -> void:
	var version := Engine.get_version_info()
	assert(version.major==4 and version.minor==5 and version.patch==2, "Pinned Godot 4.5.2 required")
	assert(Engine.physics_ticks_per_second == 60, "Fixture requires actual 60Hz physics")
	var config := json(directory+"source.json")
	for path: String in config.files:
		assert(FileAccess.get_sha256(path)==config.files[path], "Source fixture drift: "+path)
	assert(config.groups.has(group_id))
	var group: Dictionary = config.groups[group_id]
	var output := directory+group_id+"-journey.json"
	assert(not FileAccess.file_exists(output), "Fresh attempt required")
	var data := json(directory+str(group.variant)+".json")
	var world := WorldMap.new()
	root.add_child(world)
	assert(world.build(data))
	await physics_frame
	var failed := false
	for trial: Dictionary in group.trials:
		var walker := Walker.new()
		root.add_child(walker)
		walker.set_physics_process(false)
		var capsule: CapsuleShape3D
		for child: Node in walker.get_children():
			if child is CollisionShape3D: capsule = child.shape
		assert(capsule != null and is_equal_approx(capsule.radius,.35) and is_equal_approx(capsule.height,1.8))
		capsule.radius = float(group.radius) # .35 exact controller, .42 explicitly test-only envelope
		var start := Vector3(trial.start[0],trial.start[1],trial.start[2])
		var goal := Vector3(trial.goal[0],trial.goal[1],trial.goal[2])
		walker.set_spawn(start+Vector3.UP*.05)
		# Initial spawn separation only; from here every response comes from step().
		for settle in range(20):
			await physics_frame
			walker.step(1.0/60.0,Vector2.ZERO)
		var trace: Array = []
		var reached := false
		var stalled := 0
		for frame in range(900):
			await physics_frame
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
			trace.append({"frame":frame,"position":vector(walker.position),"velocity":vector(walker.velocity),
				"grounded":walker.is_on_floor(),"support":vector(support.position) if not support.is_empty() else null,"collisions":collisions,"resetCount":walker.reset_count})
			stalled = stalled+1 if walker.position.distance_to(before)<.0001 else 0
			if stalled>=120 or walker.reset_count!=1: break
		failed = failed or not reached
		records.append({"trial":trial,"reached":reached,"stalledFrames":stalled,"frames":trace,"radius":capsule.radius,
			"height":capsule.height,"safeMargin":walker.safe_margin,"floorSnap":walker.floor_snap_length,"floorMaxAngle":walker.floor_max_angle})
		walker.queue_free()
		await process_frame
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"case":group_id,"geometryHash":data.geometryHash,"sourceSha256":FileAccess.get_sha256(directory+"source.json"),
		"godot":Engine.get_version_info(),"failed":failed,"records":records,
		"scope":"actual exploration CharacterBody.step; .42 case is test-only envelope, not authoritative multiplayer movement; no stair lift/teleport/waiver"},"\t")+"\n")
	file.close()
	quit(1 if failed else 0)
