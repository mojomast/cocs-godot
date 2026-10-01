extends RefCounted
## Presentation math for rigid mesh pivots. All lengths are local metres.
## Exact critical spring (Orange Duck, Spring Roll Call); no Euler integration.
static func spring(value: float, velocity: float, goal: float, rate: float, dt: float) -> Vector2:
	var offset := value - goal
	var j := velocity + rate * offset
	var decay := exp(-rate * dt)
	return Vector2(goal + (offset + j * dt) * decay, (velocity - rate * j * dt) * decay)

static func smooth(value: float) -> float:
	var x := clampf(value, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)

## 62% stance: constant reverse travel, followed by a zero-height smooth swing.
## x = along travel; y = lift. Phase advances by travelled distance/cycle length.
static func contact(phase: float, cycle_length: float, lift: float) -> Vector2:
	var t := fposmod(phase / TAU, 1.0)
	var reach := cycle_length * 0.62 * 0.5
	if t < 0.62: return Vector2(lerpf(reach, -reach, t / 0.62), 0.0)
	var swing := (t - 0.62) / 0.38
	return Vector2(lerpf(-reach, reach, smooth(swing)), lift * pow(sin(PI * swing), 2.0))

## Two rigid links, preferred knee plane. Returns rotations from authored vectors.
static func two_link(upper: Vector3, lower: Vector3, target: Vector3, pole: Vector3) -> Array[Quaternion]:
	var a := upper.length()
	var b := lower.length()
	var distance := clampf(target.length(), absf(a-b) + 0.001, a+b-0.001)
	var axis := target.normalized() if target.length_squared()>0.00000001 else Vector3.DOWN
	var bend := (pole - axis * pole.dot(axis)).normalized()
	if bend.length_squared() < 0.01: bend = axis.cross(Vector3.UP if absf(axis.x)>0.9 else Vector3.RIGHT).normalized()
	var along := (a*a + distance*distance - b*b) / (2.0*distance)
	var knee := axis * along + bend * sqrt(maxf(0.0, a*a-along*along))
	var hip_rotation := Quaternion(upper.normalized(), knee.normalized())
	var shin_direction := hip_rotation.inverse() * (axis * distance-knee)
	return [hip_rotation, Quaternion(lower.normalized(), shin_direction.normalized())]
