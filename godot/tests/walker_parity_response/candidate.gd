extends "res://exploration/walker.gd"
const StepProposal = preload("planner.gd")
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

func ordinary_step(delta: float, direction: Vector2) -> void:
	if response_attempts!=0:
		candidate_fault = "ordinary_step_after_single_attempt"
		return
	super.step(delta,direction,false,false)

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

func step(delta: float, direction: Vector2, sprint: bool = false, jump: bool = false) -> void:
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
