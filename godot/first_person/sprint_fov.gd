extends RefCounted
## Small source-confirmed optical sprint cue. The ADS FOV is owned by the rig;
## this additive hip-fire cue never modifies look angles or gameplay aim.
const MAX_DEGREES := 3.0
const RATE := 9.0
var degrees := 0.0

func reset() -> void:
	degrees = 0.0

func advance(delta: float, sprinting: bool, allowed: bool, reduced: bool) -> void:
	if not allowed or reduced:
		reset()
		return
	if not is_finite(delta) or delta < 0.0: return
	var target := MAX_DEGREES if sprinting else 0.0
	degrees = lerpf(degrees, target, 1.0 - exp(-minf(delta, 10.0) * RATE))

func compose(aim_fov: float, aim_weight: float) -> float:
	return aim_fov + degrees * (1.0 - clampf(aim_weight, 0.0, 1.0))
