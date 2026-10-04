extends "res://tests/walker_step_up/sweep_proposal.gd"
const Old = preload("res://tests/walker_step_up/sweep_proposal.gd")
const Pair = preload("query_pair.gd")
const Guard = preload("res://tests/walker_step_up/response_guard.gd")
## Additional conservative admission after original complete proof. No fallback
## from old rejection, no relaxed angle/endpoint tolerance, no node mutation.
static func propose(body: CharacterBody3D, delta: float, axes: Vector2, sprint: bool, jump: bool) -> Dictionary:
	var plan := Old.propose(body,delta,axes,sprint,jump)
	if not plan.accepted: return plan
	var pair := Pair.compare(body,plan)
	plan.queryParity = pair.receipt
	plan.originalExpectedFinal = plan.expectedFinal
	var epsilon := Guard.numeric_budget([plan.from.origin,plan.raised.origin,plan.expectedFinal])
	if epsilon<0.0: return denied(plan,"parity_coordinate_domain")
	# In the pinned first grounded iteration floor_stop_on_slope enables
	# cancel_sliding. A clear request with zero perpendicular recovery has no
	# cancellation effect. Reject other forward responses rather than emulate
	# arbitrary body recovery or an internal slide path.
	var forward: Dictionary = pair.parentForward
	if not body.floor_stop_on_slope or body.floor_constant_speed or not forward.valid or forward.hit or (forward.travel-plan.horizontalBudget).length()>epsilon: return denied(plan,"parent_forward_not_clear_equivalent")
	var down: Dictionary = pair.parentSnap
	var result: PhysicsTestMotionResult3D = down.result
	if not down.valid or not down.hit or result.get_collision_count()==0 or result.get_collision_count()>=4: return denied(plan,"parent_snap_missing_or_saturated")
	for i in result.get_collision_count():
		if result.get_collider_rid(i)!=plan.supportRid or result.get_collider_shape(i)!=int(plan.supportShape) or result.get_collision_local_shape(i)!=0: return denied(plan,"parent_snap_support_identity")
		if absf(result.get_collision_point(i).y-float(plan.landingY))>epsilon: return denied(plan,"parent_snap_contact_off_certified_plane")
		if not result.get_collider_velocity(i).is_zero_approx() or not result.get_collision_normal(i).is_normalized() or result.get_collision_normal(i).dot(body.up_direction)<cos(body.floor_max_angle): return denied(plan,"parent_snap_floor_contract")
	# Parent projects on UP only when raw travel length exceeds margin, else
	# applies zero travel. Reject significant lateral recovery; projection alone
	# is not proof that a side excursion was safe. Never add engine's .01rad
	# classification allowance to our unchanged strict46-degree support guard.
	if down.travel.slide(body.up_direction).length()>epsilon: return denied(plan,"parent_snap_lateral_recovery")
	var projected: Vector3 = pair.receipt.parentSnapProjectedTravel
	if projected.dot(body.up_direction)>=0.0 or projected.length()>down.motion.length()+epsilon: return denied(plan,"parent_snap_travel_bound")
	var edge: Transform3D = down.from
	var final_origin := edge.origin+projected
	var rise: float = final_origin.y-plan.from.origin.y
	if rise<=0.0 or rise+GUARD>=STEP_LIMIT: return denied(plan,"parent_snap_net_rise")
	plan.expectedFinal = final_origin
	plan.queryParity.selected = "parentSnap4_projected"
	plan.queryParity.expectedFinal = final_origin
	return plan

static func denied(plan: Dictionary, reason: String) -> Dictionary:
	plan.accepted = false
	plan.reason = reason
	return plan
