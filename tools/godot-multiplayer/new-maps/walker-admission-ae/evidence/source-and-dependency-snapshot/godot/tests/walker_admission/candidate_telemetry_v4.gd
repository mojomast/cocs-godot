extends "res://tests/walker_step_up/candidate_walker.gd"
const Slides = preload("slide_telemetry.gd")
## Only serializable diagnostic metadata changes, AFTER the unchanged guard.
func step(delta: float, direction: Vector2, sprint: bool = false, jump: bool = false) -> void:
	super.step(delta,direction,sprint,jump)
	if last_step_proposal.has("responseGuard"):
		last_step_proposal.responseGuard.observedSlides = Slides.capture(self)
		last_step_proposal.responseGuard.telemetryVersion = "numeric-index-v4"
