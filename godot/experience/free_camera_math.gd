extends RefCounted
## game/camera-modes.mjs integrateFreeMove: source defaults, look-forward,
## horizontal strafe, world-up, exponential velocity and trapezoid integration.
static func integrate(position: Vector3, velocity: Vector3, yaw: float, pitch: float, input: Vector3, boost: bool, dt: float) -> Dictionary:
	var step := clampf(dt if is_finite(dt) else 0.0, 0, 0.1)
	var top := 16.0 * (2.4 if boost else 1.0)
	var moving := input.length() > 0.000000001
	var axes := input.normalized() if moving else Vector3.ZERO # forward, right, up
	var angle := clampf(pitch, -1.5, 1.5)
	var target := Vector3(-axes.x * cos(angle) * sin(yaw) + axes.y * cos(yaw), axes.x * sin(angle) + axes.z, -axes.x * cos(angle) * cos(yaw) - axes.y * sin(yaw)) * top
	var half_life := 0.12 if moving else 0.08
	var factor := 1.0 - pow(2.0, -step / half_life) if step > 0 else 1.0
	var next := velocity.lerp(target, factor).limit_length(top)
	var point := position + (velocity + next) * 0.5 * step
	point.y = maxf(0.4, point.y)
	return {"position":point, "velocity":next}
