extends "res://exploration/walker.gd"
## Isolated copy of original candidate application order. Only planner binding
## and post-decision numeric diagnostics differ; guard remains original preload.
const StepProposal = preload("planner.gd")
const ResponseGuard = preload("res://tests/walker_step_up/response_guard.gd")
const Slides = preload("res://tests/walker_admission/slide_telemetry.gd")
var last_step_proposal: Dictionary = {}
var candidate_fault := ""
var last_attempt_frame := -1

func step(delta: float, direction: Vector2, sprint: bool = false, jump: bool = false) -> void:
	if not candidate_fault.is_empty(): return
	var frame := Engine.get_physics_frames()
	if last_attempt_frame==frame:
		candidate_fault = "duplicate candidate step in one physics frame"
		return
	last_attempt_frame = frame
	last_step_proposal = StepProposal.propose(self,delta,direction,sprint,jump)
	var before := global_transform
	if last_step_proposal.accepted:
		var epsilon := ResponseGuard.numeric_budget([before.origin,last_step_proposal.raised.origin,last_step_proposal.expectedFinal])
		if epsilon<0.0:
			candidate_fault = "unsupported float32 proof domain"
			return
		var collision := move_and_collide(last_step_proposal.upMotion,false,safe_margin,false,32)
		if collision!=null or global_position.distance_to(last_step_proposal.raised.origin)>epsilon:
			candidate_fault = "committed up sweep differs from proof; no rollback teleport"
			return
	super.step(delta,direction,sprint,jump)
	if last_step_proposal.accepted:
		var actual := global_position-before.origin
		var budget: Vector3 = last_step_proposal.horizontalBudget
		last_step_proposal["actualWholeFrameDelta"] = actual
		last_step_proposal["parentRealVelocity"] = get_real_velocity()
		last_step_proposal["parentPositionDelta"] = get_position_delta()
		last_step_proposal["actualVelocity"] = velocity
		last_step_proposal["actualGrounded"] = is_on_floor()
		var response := ResponseGuard.inspect(self,last_step_proposal)
		response.observedSlides = Slides.capture(self)
		last_step_proposal["responseGuard"] = response
		if not response.passed: candidate_fault = str(response.reason)
		elif not is_on_floor() or get_floor_normal().dot(Vector3.UP)<cos(floor_max_angle): candidate_fault = "parent did not land on valid floor"
		elif actual.slide(Vector3.UP).length()>budget.length()+StepProposal.GUARD: candidate_fault = "horizontal budget exceeded"
		elif actual.slide(Vector3.UP).dot(budget)<=0.0: candidate_fault = "no forward progress"
		elif actual.y<=0.0 or actual.y+StepProposal.GUARD>=StepProposal.STEP_LIMIT: candidate_fault = "unexpected vertical response"
		elif absf(velocity.y)>StepProposal.GUARD: candidate_fault = "unexpected grounded vertical velocity"
