extends RefCounted
const Legacy = preload("res://tests/walker_step_up/sweep_proposal.gd")
## Read-only explicit PhysicsServer requests; backend identity remains unknown.
static func query(body: CharacterBody3D, start: Transform3D, motion: Vector3, count: int, recovery: bool, rays: bool) -> Dictionary:
	var p := PhysicsTestMotionParameters3D.new()
	p.from = start
	p.motion = motion
	p.margin = body.safe_margin
	p.max_collisions = count
	p.recovery_as_collision = recovery
	p.collide_separation_ray = rays
	var result := PhysicsTestMotionResult3D.new()
	var hit := PhysicsServer3D.body_test_motion(body.get_rid(),p,result)
	var valid := result.get_travel().is_finite() and result.get_remainder().is_finite()
	valid = valid and is_finite(result.get_collision_safe_fraction()) and is_finite(result.get_collision_unsafe_fraction())
	valid = valid and result.get_collision_safe_fraction()>=0.0 and result.get_collision_safe_fraction()<=result.get_collision_unsafe_fraction() and result.get_collision_unsafe_fraction()<=1.0
	for i in result.get_collision_count():
		valid = valid and result.get_collision_normal(i).is_finite() and result.get_collision_point(i).is_finite()
		valid = valid and result.get_collider_velocity(i).is_finite() and is_finite(result.get_collision_depth(i)) and result.get_collision_depth(i)>=0.0
	var row := {"from":start,"motion":motion,"margin":p.margin,"hit":hit,"result":result,"travel":result.get_travel(),
		"valid":valid,"recoveryAsCollision":recovery,"collideSeparationRay":rays}
	var record := Legacy.log_sweep("query-parity",row)
	for i in result.get_collision_count(): record.contacts[i].colliderRid = result.get_collider_rid(i)
	record.maxCollisions = count
	record.bodyRid = body.get_rid()
	record.excludeBodies = []
	record.excludeObjects = []
	record.collisionMask = body.collision_mask
	record.bodyExceptions = body.get_collision_exceptions().map(func(b: PhysicsBody3D) -> int: return b.get_rid().get_id())
	var shape: Shape3D = body.shape_owner_get_shape(body.get_shape_owners()[0],0)
	record.shapeRid = shape.get_rid()
	record.actualShape = PhysicsServer3D.shape_get_data(shape.get_rid())
	record.shapeTransform = body.shape_owner_get_transform(body.get_shape_owners()[0])
	row.record = record
	return row

static func compare(body: CharacterBody3D, plan: Dictionary) -> Dictionary:
	assert(plan.accepted)
	var before := body.global_transform
	var velocity := body.velocity
	var old_down: Dictionary
	for stage: Dictionary in plan.stages:
		if stage.name=="down": old_down = stage
	var edge: Transform3D = old_down.from
	var short := query(body,edge,old_down.motion,32,true,true)
	var full := query(body,edge,-body.up_direction*maxf(body.floor_snap_length,body.safe_margin),4,true,true)
	var forward := query(body,plan.raised,plan.horizontalBudget,6,true,false)
	assert(body.global_transform==before and body.velocity==velocity)
	return {"short":short,"parentSnap":full,"parentForward":forward,
		"receipt":{"frame":Engine.get_physics_frames(),"actualDelta":body.get_physics_process_delta_time(),
			"physicsHz":Engine.physics_ticks_per_second,"timeScale":Engine.time_scale,"engine":Engine.get_version_info(),
			"configuredPhysicsEngineSetting":ProjectSettings.get_setting("physics/3d/physics_engine","DEFAULT"),
			"backendImplementationVerified":false,"short32":short.record,"parentSnap4":full.record,
			"parentForward6":forward.record,"bodyUnchanged":true,"edgeSource":"predicted pose, not observed internal pre-snap transform",
			"parentSnapProjectedTravel":body.up_direction*full.travel.dot(body.up_direction) if full.travel.length()>body.safe_margin else Vector3.ZERO}}
