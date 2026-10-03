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

## Operator-only velocity-continuous gait. Legacy robot/puppy contact stays above.
static func stride_contact(phase: float, cycle_length: float, lift: float, stance: float) -> Vector2:
	var t := fposmod(phase / TAU, 1.0)
	stance = clampf(stance,0.18,0.75)
	var reach := cycle_length * stance * 0.5
	if t < stance: return Vector2(lerpf(reach, -reach, t / stance), 0.0)
	var swing := (t - stance) / (1.0 - stance)
	# Match the stance velocity at both ends of swing. A zero-tangent lerp
	# makes the world foot abruptly accelerate on lift-off and skid at touchdown.
	var tangent := -cycle_length*(1.0-stance)
	# Localize the endpoint tangent: a full-span Hermite would overshoot the
	# short stance reach by tens of centimetres at sprint duty factors.
	var edge := swing*pow(1.0-swing,12.0)-(1.0-swing)*pow(swing,12.0)
	var along := lerpf(-reach,reach,smooth(swing))+tangent*edge
	return Vector2(along, lift * pow(sin(PI * swing), 2.0))

## One complete left/right cycle. Running shortens support, rather than scaling
## foot travel a second time (which makes the planted foot skate).
static func gait(speed: float, crouch: float, leg_length: float) -> Vector3:
	var run := smooth((speed-1.8)/4.5)
	var stance := lerpf(0.64,0.24,run)
	var cadence := lerpf(1.25,2.8,run)
	var cycle := clampf(speed/cadence,0.32,leg_length/stance)
	cycle *= lerpf(1.0,0.7,crouch)
	return Vector3(cycle,stance,lerpf(0.055,0.16,run)*(1.0-crouch*0.45))

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
