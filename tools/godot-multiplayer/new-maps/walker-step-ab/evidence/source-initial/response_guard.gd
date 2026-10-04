extends RefCounted
## Conservative observer of the pinned parent's CLEAR-forward, static-floor branch.
## Does not reconstruct unobservable internal slide/recovery motion. Any slide
## collision is rejected; no collision-travel ledger is falsely called complete.
const LIMIT := .0001
const Proposal = preload("sweep_proposal.gd")

static func numeric_budget(points: Array) -> float:
	var magnitude := 1.0
	for point: Vector3 in points:
		if not point.is_finite(): return -1.0
		magnitude = maxf(magnitude,maxf(absf(point.x),maxf(absf(point.y),absf(point.z))))
	# Eight float32 ULPs at this coordinate scale, capped by refusing the domain,
	# not by admitting a .02m safe-margin-sized endpoint error. Queries and actual
	# motion already share that margin; it is not a free drift allowance.
	var budget := 8.0*pow(2.0,floor(log(magnitude)/log(2.0))-23.0)
	return maxf(0.000001,budget) if budget<=LIMIT else -1.0

static func inspect(body: CharacterBody3D, plan: Dictionary) -> Dictionary:
	var expected: Vector3 = plan.expectedFinal
	var raised: Transform3D = plan.raised
	var horizontal: Vector3 = plan.horizontalBudget
	var endpoint: Vector3 = raised.origin+horizontal
	var epsilon := numeric_budget([plan.from.origin,raised.origin,endpoint,expected,body.global_position])
	var report := {"passed":false,"epsilon":epsilon,"actualFinal":body.global_position,"expectedFinal":expected,
		"lastMotion":body.get_last_motion(),"slideCount":body.get_slide_collision_count(),"observedSlides":[]}
	for index in body.get_slide_collision_count():
		var collision := body.get_slide_collision(index)
		report.observedSlides.append({"travel":collision.get_travel(),"remainder":collision.get_remainder(),
			"normal":collision.get_normal(),"point":collision.get_position(),"colliderShape":collision.get_collider_shape()})
	if epsilon<0.0 or epsilon>body.safe_margin/100.0: report.reason = "unsupported_float32_domain"; return report
	if body.global_position.distance_to(expected)>epsilon: report.reason = "endpoint_differs_from_proof"; return report
	if body.get_slide_collision_count()!=0: report.reason = "unproved_parent_collision_path"; return report
	if not body.get_platform_velocity().is_zero_approx() or not body.get_platform_angular_velocity().is_zero_approx(): report.reason = "platform_path_not_proved"; return report
	if body.floor_constant_speed: report.reason = "unproved_constant_speed_branch"; return report
	# The pinned no-slide, no-platform branch has one forward motion, followed
	# by apply_floor_snap's Y-only projection. Check that exact vector, not length.
	if not body.get_last_motion().is_finite() or body.get_last_motion().distance_to(horizontal)>epsilon: report.reason = "forward_vector_differs_from_proof"; return report
	if (body.global_position-endpoint).slide(Vector3.UP).length()>epsilon: report.reason = "off_proved_down_axis"; return report
	if not body.is_on_floor() or body.get_floor_normal().dot(Vector3.UP)<cos(body.floor_max_angle): report.reason = "not_valid_native_floor"; return report
	var support: Dictionary = Proposal.sweep(body,body.global_transform,-Vector3.UP*(body.safe_margin+LIMIT),true)
	report.support = Proposal.log_sweep("actual-final-support",support)
	var result: PhysicsTestMotionResult3D = support.result
	if not support.valid or not support.hit or result.get_collision_count()==0 or result.get_collision_count()>=32: report.reason = "no_positive_final_capsule_support"; return report
	for index in result.get_collision_count():
		if result.get_collider_rid(index)!=plan.supportRid or result.get_collider_shape(index)!=int(plan.supportShape) or result.get_collision_local_shape(index)!=0:
			report.reason = "actual_support_identity_differs"; return report
		if result.get_collision_normal(index).dot(Vector3.UP)<cos(body.floor_max_angle) or not result.get_collider_velocity(index).is_zero_approx(): report.reason = "invalid_final_support_normal_or_velocity"; return report
		if absf(result.get_collision_point(index).y-float(plan.landingY))>epsilon: report.reason = "actual_contact_off_landing_plane"; return report
	report.passed = true
	report.reason = "endpoint_and_pinned_clear_branch_and_live_support_agree"
	report.pathQualification = "conditional on pinned static/no-slide parent branch; no general internal-path reconstruction"
	return report
