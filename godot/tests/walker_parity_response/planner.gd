extends "res://tests/walker_snap_parity/planner.gd"
const FrozenParity = preload("res://tests/walker_snap_parity/planner.gd")
## Live queries only. No AF coordinates/results enter this runtime proof.
static func propose(body: CharacterBody3D, delta: float, axes: Vector2, sprint: bool, jump: bool) -> Dictionary:
	var plan := FrozenParity.propose(body,delta,axes,sprint,jump)
	if not plan.accepted: return plan
	# The raw forward query does not execute PhysicsBody3D's cancellation wrapper.
	# Admit only exact travel==motion with no contacts: no backend-reported
	# recovery. Wrapper normalization/projection can still introduce roundoff;
	# its actual result is NOT observed here and must pass the frozen guard.
	var forward: Dictionary = plan.queryParity.parentForward6
	plan.queryParity.cancellationWrapperExecuted = false
	if forward.travel!=forward.motion or not forward.contacts.is_empty():
		plan.accepted = false
		plan.reason = "forward_wrapper_equivalence_not_proved"
	return plan
