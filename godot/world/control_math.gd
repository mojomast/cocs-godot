extends RefCounted

# Native input conditioning only; movement remains server authoritative.
static func look(yaw: float, pitch: float) -> Vector2:
	return Vector2(wrapf(yaw, -PI, PI) if is_finite(yaw) else 0.0,
		clampf(pitch, -1.45, 1.45) if is_finite(pitch) else 0.0)

static func movement(yaw: float, forward: float, right: float) -> Vector2:
	if not is_finite(yaw) or not is_finite(forward) or not is_finite(right):
		return Vector2.ZERO
	var axes := Vector2(right, forward).limit_length(1.0)
	return Vector2(-sin(yaw) * axes.y + cos(yaw) * axes.x,
		-cos(yaw) * axes.y - sin(yaw) * axes.x)
