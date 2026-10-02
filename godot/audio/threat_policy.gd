extends RefCounted
## Presentation scheduling only. Source simulation exclusively owns cooldowns.
const VOICES := 4
const RADIUS := 30.0
const AUDIBLE := 0.03
const STEAL_MARGIN := 0.15
const ATTACK_GUARD := 0.08

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func position(value: Variant) -> bool:
	return value is Dictionary and number(value.get("x")) and number(value.get("z"))

static func gain_at(point: Dictionary, listener: Dictionary) -> float:
	if not position(point) or not position(listener): return 0.0
	return maxf(0.0, 1.0 - Vector2(float(point.x) - float(listener.x), float(point.z) - float(listener.z)).length() / RADIUS)

static func priority(kind: String, gain: float) -> float:
	return gain + (1.0 if kind == "boss" else 0.0)

static func slot(active: Array, weights: Array, starts: Array, weight: float, now: float) -> int:
	for i in active.size():
		if not active[i]: return i
	var weakest := -1
	for i in active.size():
		if now - float(starts[i]) < ATTACK_GUARD: continue
		if weakest < 0 or float(weights[i]) < float(weights[weakest]): weakest = i
	if weakest >= 0 and weight > float(weights[weakest]) + STEAL_MARGIN: return weakest
	return -1
