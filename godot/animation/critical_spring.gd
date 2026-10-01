extends RefCounted
## Exact solution of x'' + 2*w*x' + w*w*(x-goal) = 0.
## Cosmetic scalar only. omega is radians/second, not a lerp factor.
## Constant goal over each call; composition is frame-rate independent until
## deliberate safety limits/settle threshold engage. No fixed-step catch-up loop.
var value := 0.0
var velocity := 0.0

func reset(at: float = 0.0) -> void:
	value = at if is_finite(at) else 0.0
	velocity = 0.0

func impulse(amount: float, limit: float = 2.0) -> void:
	if is_finite(amount): velocity = clampf(velocity + amount, -limit, limit)

func advance(delta: float, goal: float = 0.0, omega: float = 18.0, limit: float = 0.1) -> float:
	if not is_finite(delta) or delta < 0.0 or not is_finite(goal): return value
	var w := clampf(omega, 0.1, 200.0)
	var offset := value - goal
	var j := velocity + w * offset
	var decay := exp(-w * minf(delta, 10.0))
	value = goal + (offset + j * minf(delta, 10.0)) * decay
	velocity = (velocity - w * j * minf(delta, 10.0)) * decay
	var bounded := clampf(value, -limit, limit)
	if bounded != value:
		value = bounded
		velocity = 0.0
	if absf(value - goal) < 0.000001 and absf(velocity) < 0.00001:
		value = goal
		velocity = 0.0
	return value
