extends RefCounted
## EXPERIMENT v1 — source-reviewed proposal only; not engine-parsed or production.
## Read-only lookahead on the actual body RID. Never moves a node or changes velocity.
const STEP_LIMIT := .25
const ADMISSION_LIMIT := .3
const GUARD := .0001 # conservative 0.1mm identity/geometry guard, not extra step height
const HEAD_ON := .98
const MAX_CONTACTS := 32

static func reject(reason: String, stages: Array = []) -> Dictionary:
	return {"accepted":false,"reason":reason,"stages":stages}

static func static_body(body: Object) -> bool:
	if body==null or body.get_class()!="StaticBody3D": return false
	var fixed := body as StaticBody3D
	return fixed.constant_linear_velocity.is_zero_approx() and fixed.constant_angular_velocity.is_zero_approx()

static func sweep(body: CharacterBody3D, start: Transform3D, motion: Vector3, down: bool = false) -> Dictionary:
	var parameters := PhysicsTestMotionParameters3D.new()
	parameters.from = start # global body frame, including yaw; shape offset stays on the live RID
	parameters.motion = motion
	parameters.margin = body.safe_margin
	parameters.max_collisions = MAX_CONTACTS
	parameters.recovery_as_collision = down
	parameters.collide_separation_ray = down
	var result := PhysicsTestMotionResult3D.new()
	var hit := PhysicsServer3D.body_test_motion(body.get_rid(),parameters,result)
	var valid := result.get_travel().is_finite() and result.get_remainder().is_finite()
	valid = valid and is_finite(result.get_collision_safe_fraction()) and is_finite(result.get_collision_unsafe_fraction())
	valid = valid and result.get_collision_safe_fraction()>=0.0 and result.get_collision_safe_fraction()<=result.get_collision_unsafe_fraction() and result.get_collision_unsafe_fraction()<=1.0
	for index in result.get_collision_count():
		valid = valid and result.get_collision_point(index).is_finite() and result.get_collision_normal(index).is_finite()
		valid = valid and absf(result.get_collision_normal(index).length()-1.0)<GUARD and result.get_collider_velocity(index).is_finite()
		valid = valid and is_finite(result.get_collision_depth(index)) and result.get_collision_depth(index)>=0.0
	return {"hit":hit,"result":result,"from":start,"motion":motion,"margin":parameters.margin,
		"valid":valid,"recoveryAsCollision":down,"collideSeparationRay":down,"travel":result.get_travel()}

static func log_sweep(name: String, query: Dictionary) -> Dictionary:
	var result: PhysicsTestMotionResult3D = query.result
	var contacts: Array = []
	for index in result.get_collision_count():
		var collider: Object = result.get_collider(index)
		contacts.append({"point":result.get_collision_point(index),"normal":result.get_collision_normal(index),
			"depth":result.get_collision_depth(index),"velocity":result.get_collider_velocity(index),
			"localShape":result.get_collision_local_shape(index),"colliderShape":result.get_collider_shape(index),
			"colliderId":result.get_collider_id(index),"collider":str(collider.get_path()) if collider is Node else "unattached"})
	return {"name":name,"from":query.from,"motion":query.motion,"margin":query.margin,"hit":query.hit,
		"maxCollisions":MAX_CONTACTS,"validResult":query.valid,
		"recoveryAsCollision":query.recoveryAsCollision,"collideSeparationRay":query.collideSeparationRay,
		"travel":result.get_travel(),"remainder":result.get_remainder(),"safeFraction":result.get_collision_safe_fraction(),
		"unsafeFraction":result.get_collision_unsafe_fraction(),"contacts":contacts}

static func polygon_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for index in points.size(): area += points[index].cross(points[(index+1)%points.size()])
	return absf(area)*.5

static func triangulation_covers_hull(vertices: PackedVector3Array, points: PackedVector2Array, hull: PackedVector2Array) -> bool:
	# Normalize every triangle CCW. Interior edges must cancel exactly; the
	# remaining edges must tile each convex-hull edge once, with no hole/overlap.
	# No welding, epsilon gap closure, sparse rays or area-only coverage claims.
	var edges := {}
	for index in range(0,vertices.size(),3):
		var ids: Array[int] = []
		for corner in range(3): ids.append(points.find(Vector2(vertices[index+corner].x,vertices[index+corner].z)))
		var signed_area: float = (points[ids[1]]-points[ids[0]]).cross(points[ids[2]]-points[ids[0]])
		if signed_area==0.0: return false
		if signed_area<0.0: ids.reverse()
		for corner in range(3):
			var edge := Vector2i(ids[corner],ids[(corner+1)%3])
			if edges.has(edge): return false
			edges[edge] = true
	var boundary: Array[Vector2i] = []
	for edge: Vector2i in edges:
		if not edges.has(Vector2i(edge.y,edge.x)): boundary.append(edge)
	var assigned := 0
	for index in hull.size():
		var start := hull[index]
		var delta := hull[(index+1)%hull.size()]-start
		var segments: Array = []
		for edge: Vector2i in boundary:
			var a := points[edge.x]-start
			var b := points[edge.y]-start
			if delta.cross(a)!=0.0 or delta.cross(b)!=0.0: continue
			var low := a.dot(delta)/delta.length_squared()
			var high := b.dot(delta)/delta.length_squared()
			if low<0.0 or high>1.0 or high<=low: continue
			segments.append([low,high]);assigned += 1
		segments.sort_custom(func(a: Array,b: Array) -> bool: return a[0]<b[0])
		var covered := 0.0
		for interval: Array in segments:
			if interval[0]!=covered: return false
			covered = interval[1]
		if covered!=1.0: return false
	return assigned==boundary.size()

static func flat_patch(body: Object, shape_index: int) -> Dictionary:
	# A continuous convex face certificate, not sparse support rays. Bounded
	# to a box top or at most 32 triangles forming one complete convex patch.
	if not static_body(body): return {}
	var owner: int = body.shape_find_owner(shape_index)
	if body.is_shape_owner_disabled(owner): return {}
	var shape: Shape3D
	for local in body.shape_owner_get_shape_count(owner):
		if body.shape_owner_get_shape_index(owner,local)==shape_index: shape = body.shape_owner_get_shape(owner,local)
	var transform: Transform3D = body.global_transform*body.shape_owner_get_transform(owner)
	if not transform.is_finite() or absf(transform.basis.determinant()-1.0)>GUARD: return {}
	if not transform.basis.is_equal_approx(transform.basis.orthonormalized()): return {}
	var vertices := PackedVector3Array()
	if shape is BoxShape3D:
		var half: Vector3 = shape.size*.5
		for point: Vector3 in [Vector3(-half.x,half.y,-half.z),Vector3(half.x,half.y,-half.z),Vector3(half.x,half.y,half.z),Vector3(-half.x,half.y,half.z)]: vertices.append(transform*point)
	elif shape is ConcavePolygonShape3D:
		var faces: PackedVector3Array = shape.get_faces()
		if faces.size()<3 or faces.size()>96 or faces.size()%3!=0: return {}
		for point: Vector3 in faces: vertices.append(transform*point)
	else: return {}
	var points := PackedVector2Array()
	var y := vertices[0].y
	for point: Vector3 in vertices:
		if not point.is_finite() or point.y!=y: return {} # exact planar native geometry, no flattening
		var projected := Vector2(point.x,point.z)
		if not points.has(projected): points.append(projected)
	if points.size()<3: return {}
	var hull := Geometry2D.convex_hull(points)
	if hull.size()<4: return {}
	hull.remove_at(hull.size()-1) # Geometry2D returns a closed hull
	var signed_area := 0.0
	for index in hull.size(): signed_area += hull[index].cross(hull[(index+1)%hull.size()])
	if signed_area<0.0: hull.reverse()
	if polygon_area(hull)<=GUARD: return {}
	if shape is ConcavePolygonShape3D and not triangulation_covers_hull(vertices,points,hull): return {}
	return {"polygon":hull,"y":y,"worldVertices":vertices,"shapeType":shape.get_class()}

static func landing_patch(quad: Dictionary, contact: Vector3, forward: Vector3, radius: float, margin: float) -> bool:
	var side := forward.cross(Vector3.UP).normalized()
	# Certify a continuous support strip at least a radius deep and a full
	# diameter wide, including existing collision margin. No centre teleport.
	for lateral: float in [-radius-margin,radius+margin]:
		for depth: float in [margin+GUARD,radius+3*margin+GUARD]:
			var point := contact+side*lateral+forward*depth
			if not Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),quad.polygon): return false
	return true

static func propose(body: CharacterBody3D, delta: float, axes: Vector2, sprint: bool, jump: bool) -> Dictionary:
	if not Engine.is_in_physics_frame() or Engine.physics_ticks_per_second!=60 or Engine.time_scale!=1.0 or not is_finite(delta) or absf(delta-1.0/60.0)>1e-8: return reject("clock")
	if absf(body.get_physics_process_delta_time()-delta)>1e-8: return reject("actual_delta_mismatch")
	if not body.global_transform.is_finite() or not body.velocity.is_finite(): return reject("nonfinite_body")
	if not body.is_on_floor() or jump or absf(body.velocity.dot(Vector3.UP))>GUARD: return reject("not_stationary_grounded_intent")
	if not body.get_platform_velocity().is_zero_approx() or not body.get_platform_angular_velocity().is_zero_approx(): return reject("moving_platform")
	if not axes.is_finite() or axes.length_squared()<=1e-12: return reject("no_input")
	if not body.up_direction.is_equal_approx(Vector3.UP) or absf(body.global_basis.determinant()-1.0)>GUARD: return reject("unsupported_transform")
	if not body.global_basis.is_equal_approx(body.global_basis.orthonormalized()): return reject("unsupported_transform")
	if not (body.global_basis*Vector3.UP).is_equal_approx(Vector3.UP): return reject("non_yaw_rotation")
	if body.get_parent() is Node3D and not body.get_parent().global_transform.is_equal_approx(Transform3D.IDENTITY): return reject("transformed_parent") # parent Walker uses its local basis
	if body.motion_mode!=CharacterBody3D.MOTION_MODE_GROUNDED or not is_equal_approx(body.floor_max_angle,deg_to_rad(46.0)) or not is_equal_approx(body.safe_margin,.02) or not is_equal_approx(body.floor_snap_length,.3): return reject("profile_drift")
	for axis: int in [PhysicsServer3D.BODY_AXIS_LINEAR_X,PhysicsServer3D.BODY_AXIS_LINEAR_Y,PhysicsServer3D.BODY_AXIS_LINEAR_Z]:
		if body.get_axis_lock(axis): return reject("axis_lock")
	var owners: PackedInt32Array = body.get_shape_owners()
	if owners.size()!=1 or body.shape_owner_get_shape_count(owners[0])!=1 or body.is_shape_owner_disabled(owners[0]): return reject("shape_layout")
	var shape: Shape3D = body.shape_owner_get_shape(owners[0],0)
	var offset: Transform3D = body.shape_owner_get_transform(owners[0])
	if not shape is CapsuleShape3D or not offset.basis.is_equal_approx(Basis.IDENTITY) or not offset.origin.is_equal_approx(Vector3(0,.9,0)): return reject("capsule_transform")
	var capsule: CapsuleShape3D = shape
	if not is_equal_approx(capsule.height,1.8) or not (is_equal_approx(capsule.radius,.35) or is_equal_approx(capsule.radius,.42)): return reject("capsule_dimensions")
	var shape_data: Dictionary = PhysicsServer3D.shape_get_data(capsule.get_rid())
	if not is_equal_approx(shape_data.radius,capsule.radius) or not is_equal_approx(shape_data.height,capsule.height): return reject("actual_shape_drift")
	var limited := axes.limit_length(1.0)
	var motion := body.global_basis*Vector3(limited.x,0,-limited.y)*(10.0 if sprint else 6.0)*delta
	var forward := motion.normalized()
	var start := body.global_transform
	var foot := start*offset.origin-Vector3.UP*capsule.height*.5
	var excludes: Array[RID] = [body.get_rid()]
	for exception: PhysicsBody3D in body.get_collision_exceptions(): excludes.append(exception.get_rid())
	var ray := PhysicsRayQueryParameters3D.create(foot+Vector3.UP*(body.safe_margin+GUARD),foot-Vector3.UP*(STEP_LIMIT+body.safe_margin),body.collision_mask,excludes)
	var support := body.get_world_3d().direct_space_state.intersect_ray(ray)
	if support.is_empty() or not support.position.is_finite() or not support.normal.is_finite() or not static_body(support.collider) or support.normal.dot(Vector3.UP)<1.0-GUARD: return reject("no_flat_static_base_support")
	var base_y: float = support.position.y
	var stages: Array = []
	# is_on_floor describes the PREVIOUS move_and_slide. Confirm current finite
	# capsule support too, so a stale flag cannot turn a short fall into a step.
	var grounded := sweep(body,start,-Vector3.UP*(body.safe_margin+GUARD),true)
	stages.append(log_sweep("current-support",grounded))
	var ground_result: PhysicsTestMotionResult3D = grounded.result
	if not grounded.valid or not grounded.hit or ground_result.get_collision_count()>=MAX_CONTACTS: return reject("no_current_capsule_support",stages)
	var floor_found := false
	for index in ground_result.get_collision_count():
		if ground_result.get_collision_normal(index).dot(Vector3.UP)>=cos(body.floor_max_angle) and static_body(ground_result.get_collider(index)):
			floor_found = true
	if not floor_found: return reject("no_current_static_floor",stages)
	var blocked := sweep(body,start,motion)
	stages.append(log_sweep("intent",blocked))
	var obstruction: PhysicsTestMotionResult3D = blocked.result
	if not blocked.valid or not blocked.hit or obstruction.get_collision_count()>=MAX_CONTACTS: return reject("no_bounded_riser",stages)
	var collider: Object
	var collider_shape := -1
	var contact := Vector3.ZERO
	for index in obstruction.get_collision_count():
		var normal := obstruction.get_collision_normal(index)
		var point := obstruction.get_collision_point(index)
		if normal.dot(Vector3.UP)>=cos(body.floor_max_angle):
			if point.y<=foot.y+GUARD: continue
			return reject("ordinary_walkable_contact",stages) # leave already walkable responses to the parent
		if obstruction.get_collision_local_shape(index)!=0 or not obstruction.get_collider_velocity(index).is_zero_approx(): return reject("shape_or_platform_contact",stages)
		if point.y<=foot.y+GUARD or point.y-base_y+GUARD>=STEP_LIMIT or point.y-base_y+GUARD>=ADMISSION_LIMIT: return reject("not_low_riser_band",stages)
		if -normal.slide(Vector3.UP).normalized().dot(forward)<HEAD_ON: return reject("lateral_wall_or_corner",stages)
		if collider!=null and (collider!=obstruction.get_collider(index) or collider_shape!=obstruction.get_collider_shape(index)): return reject("multiple_obstacles",stages)
		collider = obstruction.get_collider(index)
		collider_shape = obstruction.get_collider_shape(index)
		contact = point
	if collider==null: return reject("ordinary_floor",stages)
	var quad := flat_patch(collider,collider_shape)
	if quad.is_empty(): return reject("no_continuous_flat_landing",stages)
	var rise: float = quad.y-base_y
	if rise<=GUARD or rise+GUARD>=STEP_LIMIT or rise+GUARD>=ADMISSION_LIMIT: return reject("strict_surface_rise_limit",stages)
	if absf(contact.y-quad.y)>GUARD or not landing_patch(quad,contact,forward,capsule.radius,body.safe_margin): return reject("unsupported_or_narrow_landing",stages)
	var lift: float = quad.y-foot.y+body.safe_margin+GUARD
	if lift<=0.0 or lift>STEP_LIMIT+body.safe_margin: return reject("lift_bound",stages)
	var up := sweep(body,start,Vector3.UP*lift)
	stages.append(log_sweep("up",up))
	var recovery: Vector3 = up.travel-up.motion
	if not up.valid or up.hit or recovery.slide(Vector3.UP).length()>GUARD or recovery.y < -GUARD or recovery.y>body.safe_margin+GUARD: return reject("up_blocked_or_lateral_recovery",stages)
	var raised := start
	raised.origin += up.travel # actual test result, including bounded existing-margin recovery
	var across := sweep(body,raised,motion)
	stages.append(log_sweep("forward",across))
	if not across.valid or across.hit or (across.travel-motion).length()>GUARD: return reject("raised_path_blocked",stages)
	var edge := raised
	edge.origin += across.travel
	var drop: float = up.travel.y+body.safe_margin+GUARD
	if drop>body.floor_snap_length: return reject("down_exceeds_existing_snap",stages)
	var down := sweep(body,edge,-Vector3.UP*drop,true)
	stages.append(log_sweep("down",down))
	var result: PhysicsTestMotionResult3D = down.result
	if not down.valid or not down.hit or result.get_collision_count()==0 or result.get_collision_count()>=MAX_CONTACTS: return reject("unsupported_drop",stages)
	for index in result.get_collision_count():
		if result.get_collider(index)!=collider or result.get_collider_shape(index)!=collider_shape or result.get_collision_local_shape(index)!=0: return reject("different_down_support",stages)
		if not result.get_collider_velocity(index).is_zero_approx() or result.get_collision_normal(index).dot(Vector3.UP)<cos(body.floor_max_angle): return reject("steep_or_moving_down_support",stages)
	if down.travel.slide(Vector3.UP).length()>GUARD or down.travel.y>0.0 or down.travel.y < -drop-GUARD: return reject("down_recovery",stages)
	var final_origin: Vector3 = edge.origin+down.travel
	if final_origin.y<=start.origin.y+GUARD or final_origin.y-start.origin.y+GUARD>=STEP_LIMIT: return reject("no_bounded_net_rise",stages)
	return {"accepted":true,"reason":"three_sweeps_and_continuous_static_landing","stages":stages,
		"supportRid":collider.get_rid(),"supportShape":collider_shape,
		"from":start,"raised":raised,"expectedFinal":final_origin,"upMotion":up.motion,"horizontalBudget":motion,
		"surfaceRise":rise,"baseSupport":support.position,"landingY":quad.y,"shapeRadius":capsule.radius,"shapeHeight":capsule.height,
		"landingCertificate":quad,"riserCollider":str(collider.get_path()),"riserShape":collider_shape,"foot":foot,"actualShapeData":shape_data,"shapeOffset":offset,
		"scope":"test-only flat static head-on step; no native success yet; no transform has been applied by this helper"}
