extends RefCounted
var seeded := false
var eye := Vector3.ZERO
var target := Vector3.ZERO
var last := Vector3.ZERO

func reset() -> void:
	seeded = false

func follow(v: Dictionary, delta: float) -> Dictionary:
	var p := Vector3(v.x, v.y, v.z)
	var forward := Vector3(sin(float(v.yaw)), 0, cos(float(v.yaw)))
	# Heading, never velocity: reverse cannot flip the rig. Source chase offsets.
	var desired := p - forward * 9 + Vector3.UP * 5
	var aim := p + forward * 6 + Vector3.UP
	if not seeded or last.distance_to(p) > 8:
		eye = desired
		target = aim
		seeded = true
	else:
		var weight := 1.0 - exp(-10.0 * clampf(delta, 0, 0.1))
		eye = eye.lerp(desired, weight)
		target = target.lerp(aim, weight)
	last = p
	return {"eye":eye,"target":target}
