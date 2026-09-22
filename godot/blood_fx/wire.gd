extends RefCounted
## Bounded numeric helpers for untrusted wire values. Mirrors the identity rules
## already used by world/weapon_effects so a malformed frame can never create a
## visual hit, a NaN position or an actor-0 impersonation.

const MAX_IDENTITY := 9007199254740991


static func numeric(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func number(value: Variant, fallback: float = 0.0) -> float:
	return float(value) if numeric(value) else fallback


static func identity(value: Variant) -> int:
	if not numeric(value) or value < 0 or value > MAX_IDENTITY or float(value) != floor(float(value)):
		return -1
	return int(value)


static func point(value: Variant) -> Variant:
	if not value is Dictionary:
		return null
	for key: String in ["x", "y", "z"]:
		if not numeric(value.get(key)) or absf(float(value[key])) > 100000.0:
			return null
	return Vector3(value.x, value.y, value.z)


static func safe_direction(value: Variant, fallback: Vector3 = Vector3.DOWN) -> Vector3:
	var vector: Variant = point(value)
	if vector == null:
		return fallback
	var direction: Vector3 = vector
	if direction.length_squared() < 0.000001:
		return fallback
	return direction.normalized()


## Deterministic unit azimuth for events with no authoritative direction.
## Presentation only: it chooses a fluid axis, never a hit or a target.
static func fallback_direction(seed: int) -> Vector3:
	var angle := float(posmod(seed, 360)) * PI / 180.0
	return Vector3(sin(angle), 0.0, cos(angle))
