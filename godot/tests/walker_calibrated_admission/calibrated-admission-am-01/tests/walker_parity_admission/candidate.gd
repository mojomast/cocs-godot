extends "res://exploration/walker.gd"
## Lifecycle adapter; apply_single_response/state/up_contacts are exact AG copies.
const StepProposal = preload("res://tests/walker_parity_response/planner.gd")
const ResponseGuard = preload("res://tests/walker_step_up/response_guard.gd")
const Slides = preload("res://tests/walker_admission/slide_telemetry.gd")
var last_step_proposal: Dictionary = {}
var candidate_fault := ""
var response_attempts := 0
var applied_up_count := 0
var parent_response_count := 0
var candidate_response_collected := false
var response_guard_passed := false
var telemetry: Dictionary = {}
const Original = preload("res://tests/walker_step_up/sweep_proposal.gd")
const Guard = preload("res://tests/walker_step_up/response_guard.gd")
var allow_positive := false
var target_rid := RID()
var target_shape := 0
var target_y := 0.0
var lift_limit := 0
var total_attempts := 0
var total_applied := 0
var total_verified := 0
var total_parent_calls := 0
var last_response_frame := -1
var lifecycle: Dictionary = {}

func configure(positive: bool, rid: RID, shape: int, plane_y: float, radius: float) -> void:
	allow_positive = positive;target_rid = rid;target_shape = shape;target_y = plane_y
	lift_limit = int(ceil(2.0*radius/(WALK_SPEED/60.0)))+2

func step(delta: float, direction: Vector2, sprint: bool = false, jump: bool = false) -> void:
	if not candidate_fault.is_empty(): return
	var frame := Engine.get_physics_frames()
	if frame==last_response_frame:
		candidate_fault = "duplicate_response_frame"
		return
	last_response_frame = frame
	# Reset only per-response instrumentation, never body pose/velocity/floor state.
	response_attempts = 0;applied_up_count = 0;parent_response_count = 0
	candidate_response_collected = false;response_guard_passed = false
	last_step_proposal = {};telemetry = {}
	lifecycle = {"frame":frame,"startUsec":Time.get_ticks_usec(),"returned":false,"parentCalls":0,"ordinary":false,
		"before":state(),"totalAttemptsBefore":total_attempts,"totalAppliedBefore":total_applied,"totalVerifiedBefore":total_verified}
	last_step_proposal = Original.propose(self,delta,direction,sprint,jump)
	lifecycle.originalProof = last_step_proposal
	lifecycle.afterOriginalProof = state()
	if lifecycle.before!=lifecycle.afterOriginalProof:
		candidate_fault = "original_query_mutated_body";complete();return
	if not last_step_proposal.accepted:
		super.step(delta,direction,sprint,jump)
		lifecycle.parentCalls = 1;lifecycle.ordinary = true;total_parent_calls += 1
		complete();return
	if not allow_positive:
		candidate_fault = "original_eligibility_in_negative_group";complete();return
	var epsilon := Guard.numeric_budget([global_position])
	if epsilon<0.0 or last_step_proposal.supportRid!=target_rid or int(last_step_proposal.supportShape)!=target_shape or absf(float(last_step_proposal.landingY)-target_y)>epsilon:
		candidate_fault = "original_certificate_not_fixed_tread";complete();return
	if total_applied>=lift_limit:
		candidate_fault = "profile_lift_budget_exhausted";complete();return
	# The exact AG method copy owns one UP / one parent / unchanged guard/checks.
	apply_single_response(delta,direction,sprint,jump)
	total_attempts += response_attempts;total_applied += applied_up_count;total_parent_calls += parent_response_count
	lifecycle.parentCalls = parent_response_count
	if candidate_fault.is_empty() and not last_step_proposal.accepted: candidate_fault = "parity_policy_rejected:"+str(last_step_proposal.reason)
	if candidate_fault.is_empty():
		if response_attempts!=1 or applied_up_count!=1 or parent_response_count!=1 or not candidate_response_collected or not response_guard_passed: candidate_fault = "incomplete_inherited_response"
		elif last_step_proposal.supportRid!=target_rid or int(last_step_proposal.supportShape)!=target_shape or absf(float(last_step_proposal.landingY)-target_y)>epsilon: candidate_fault = "parity_certificate_changed_target"
		elif global_position.y>target_y+safe_margin+.0001: candidate_fault = "grounded_profile_height_cap"
		elif telemetry.afterParent!=telemetry.afterGuard: candidate_fault = "guard_query_mutated_body"
		else: total_verified += 1
	complete()

func complete() -> void:
	lifecycle.returned = true;lifecycle.endUsec = Time.get_ticks_usec();lifecycle.after = state()
	lifecycle.totalAttempts = total_attempts;lifecycle.totalApplied = total_applied;lifecycle.totalVerified = total_verified
	lifecycle.totalParentCalls = total_parent_calls;lifecycle.liftLimit = lift_limit

func state() -> Dictionary:
	return {"transform":global_transform,"velocity":velocity,"grounded":is_on_floor(),"floorNormal":get_floor_normal(),
		"onWall":is_on_wall(),"onCeiling":is_on_ceiling(),"platformVelocity":get_platform_velocity(),
		"platformAngularVelocity":get_platform_angular_velocity(),"slideCount":get_slide_collision_count(),
		"lastMotion":get_last_motion(),"parentPositionDelta":get_position_delta(),"parentRealVelocity":get_real_velocity(),"resetCount":reset_count}

func up_contacts(hit: KinematicCollision3D) -> Array:
	var contacts: Array = []
	if hit==null: return contacts
	for index in hit.get_collision_count():
		contacts.append({"contactIndex":index,"colliderRid":hit.get_collider_rid(index),"colliderShapeIndex":hit.get_collider_shape_index(index),
			"normal":hit.get_normal(index),"point":hit.get_position(index),"motionDepth":hit.get_depth(),
			"travel":hit.get_travel(),"remainder":hit.get_remainder(),"colliderVelocity":hit.get_collider_velocity(index)})
	return contacts

func apply_single_response(delta: float, direction: Vector2, sprint: bool = false, jump: bool = false) -> void:
	if response_attempts!=0 or not candidate_fault.is_empty():
		candidate_fault = "duplicate_single_response_attempt"
		return
	response_attempts += 1
	telemetry = {"frame":Engine.get_physics_frames(),"beforePlanning":state()}
	last_step_proposal = StepProposal.propose(self,delta,direction,sprint,jump)
	telemetry.afterPlanning = state()
	if telemetry.beforePlanning!=telemetry.afterPlanning:
		candidate_fault = "planner_mutated_body_state"
		candidate_response_collected = true
		return
	if not last_step_proposal.accepted:
		candidate_response_collected = true # policy rejection is collected, not passed
		return
	var before := global_transform
	var epsilon := ResponseGuard.numeric_budget([before.origin,last_step_proposal.raised.origin,last_step_proposal.expectedFinal])
	if epsilon<0.0:
		candidate_fault = "unsupported float32 proof domain"
		candidate_response_collected = true
		return
	telemetry.upRequest = {"from":before,"motion":last_step_proposal.upMotion,"margin":safe_margin,
		"maxCollisions":32,"recoveryAsCollision":false,"collideSeparationRay":false,"testOnly":false,
		"bodyRid":get_rid(),"before":state(),"modeledRaised":last_step_proposal.raised,"epsilon":epsilon,
		"fractionsUnavailableOnKinematicCollisionAPI":true}
	var collision := move_and_collide(last_step_proposal.upMotion,false,safe_margin,false,32)
	applied_up_count += 1 # counts a physical call even if its actual travel is zero/faulted
	telemetry.upAfter = state()
	telemetry.actualUpTravel = global_position-before.origin
	telemetry.upContacts = up_contacts(collision)
	telemetry.upCollisionReturned = collision!=null
	if collision!=null or global_position.distance_to(last_step_proposal.raised.origin)>epsilon:
		candidate_fault = "committed up sweep differs from proof; no rollback teleport"
		candidate_response_collected = true
		return
	telemetry.beforeParent = state()
	super.step(delta,direction,sprint,jump)
	parent_response_count += 1
	telemetry.afterParent = state()
	var actual := global_position-before.origin
	var budget: Vector3 = last_step_proposal.horizontalBudget
	last_step_proposal["actualWholeFrameDelta"] = actual
	last_step_proposal["parentRealVelocity"] = get_real_velocity()
	last_step_proposal["parentPositionDelta"] = get_position_delta()
	last_step_proposal["actualVelocity"] = velocity
	last_step_proposal["actualGrounded"] = is_on_floor()
	var response := ResponseGuard.inspect(self,last_step_proposal)
	response.observedSlides = Slides.capture(self) # numeric shape indices, every subcontact
	telemetry.finalSupportQueryReached = response.has("support")
	telemetry.finalSupportIdentities = []
	if response.has("support"):
		for contact: Dictionary in response.support.contacts:
			var collider := instance_from_id(int(contact.colliderId)) as CollisionObject3D
			telemetry.finalSupportIdentities.append({"colliderId":contact.colliderId,
				"ridResolved":collider!=null,"colliderRid":collider.get_rid() if collider!=null else RID(),
				"colliderShapeIndex":contact.colliderShape,"localShapeIndex":contact.localShape})
	last_step_proposal["responseGuard"] = response
	response_guard_passed = response.passed
	if not response.passed: candidate_fault = str(response.reason)
	elif not is_on_floor() or get_floor_normal().dot(Vector3.UP)<cos(floor_max_angle): candidate_fault = "parent did not land on valid floor"
	elif actual.slide(Vector3.UP).length()>budget.length()+StepProposal.GUARD: candidate_fault = "horizontal budget exceeded"
	elif actual.slide(Vector3.UP).dot(budget)<=0.0: candidate_fault = "no forward progress"
	elif actual.y<=0.0 or actual.y+StepProposal.GUARD>=StepProposal.STEP_LIMIT: candidate_fault = "unexpected vertical response"
	elif absf(velocity.y)>StepProposal.GUARD: candidate_fault = "unexpected grounded vertical velocity"
	telemetry.afterGuard = state()
	telemetry.wholeFrameDelta = actual
	candidate_response_collected = true
