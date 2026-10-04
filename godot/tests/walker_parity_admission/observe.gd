extends RefCounted
const Walker = preload("res://exploration/walker.gd")
const Proposal = preload("res://tests/walker_step_up/sweep_proposal.gd")
const Guard = preload("res://tests/walker_step_up/response_guard.gd")
static func encode(v: Variant) -> Variant:
	if v is Vector3: return [v.x,v.y,v.z]
	if v is Vector2: return [v.x,v.y]
	if v is RID: return v.get_id()
	if v is Transform3D: return {"origin":encode(v.origin),"basis":[encode(v.basis.x),encode(v.basis.y),encode(v.basis.z)]}
	if v is Dictionary:
		var result := {}
		for key: Variant in v: result[str(key)] = encode(v[key])
		return result
	if v is Array or v is PackedVector3Array or v is PackedVector2Array:
		var result: Array = []
		for item: Variant in v: result.append(encode(item))
		return result
	return v
static func read_json(path: String) -> Dictionary:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}
static func state(body: Walker) -> Dictionary:
	return {"transform":body.global_transform,"velocity":body.velocity,"grounded":body.is_on_floor(),"floorNormal":body.get_floor_normal(),
		"onWall":body.is_on_wall(),"onCeiling":body.is_on_ceiling(),"platformVelocity":body.get_platform_velocity(),"platformAngularVelocity":body.get_platform_angular_velocity(),
		"slideCount":body.get_slide_collision_count(),"lastMotion":body.get_last_motion(),"parentPositionDelta":body.get_position_delta(),"parentRealVelocity":body.get_real_velocity(),"resetCount":body.reset_count}
static func footprint(body: Walker, fixture: Dictionary) -> bool:
	var radius: float = body.get_child(0).shape.radius
	var along: float = body.global_position.dot(fixture.direction)
	var lateral: float = absf(body.global_position.dot(fixture.direction.cross(Vector3.UP)))
	return along>=radius+body.safe_margin and along<=3.0-radius-body.safe_margin and lateral<=2.0-radius-body.safe_margin
static func landing(body: Walker, fixture: Dictionary) -> Dictionary:
	var result := {"passed":false,"bodyBefore":state(body),"footprintInside":footprint(body,fixture)}
	if not result.footprintInside or not body.is_on_floor() or absf(body.global_position.y-.15)>body.safe_margin+.0001: result.reason = "arrival_pose";return result
	var q := Proposal.sweep(body,body.global_transform,-Vector3.UP*(body.safe_margin+.0001),true)
	result.query = Proposal.log_sweep("fresh-full-tread-support",q);result.bodyAfter = state(body)
	var hit: PhysicsTestMotionResult3D = q.result
	if result.bodyBefore!=result.bodyAfter or not q.valid or not q.hit or hit.get_collision_count()==0 or hit.get_collision_count()>=32: result.reason = "support_missing_or_mutated";return result
	var epsilon := Guard.numeric_budget([body.global_position]);result.epsilon = epsilon
	if epsilon<0.0: result.reason = "unsupported_coordinate_domain";return result
	for i in hit.get_collision_count():
		result.query.contacts[i].colliderRid = hit.get_collider_rid(i)
		if hit.get_collider_rid(i)!=fixture.topRid or hit.get_collider_shape(i)!=0 or hit.get_collision_local_shape(i)!=0 or not hit.get_collider_velocity(i).is_zero_approx() or hit.get_collision_normal(i).dot(Vector3.UP)<cos(body.floor_max_angle) or absf(hit.get_collision_point(i).y-float(fixture.faces[0].y))>epsilon: result.reason = "wrong_support_identity_normal_or_plane";return result
	result.passed = true;result.reason = "full_footprint_and_fresh_target_support";return result
