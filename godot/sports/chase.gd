extends RefCounted
## Camera-only read of semantic boxes, never authoritative collision/physics.
const CELL := 8.0
const CLEARANCE := 0.35
const MAX_BOXES := 4096
const MAX_MEMBERSHIPS := 32768
var map_id := ""
var boxes: Array[AABB] = []
var cells: Dictionary = {}
var last_candidates := 0
var obstructed := false
var seeded := false
var eye := Vector3.ZERO
var target := Vector3.ZERO
var last := Vector3.ZERO
var heading := 0.0
var heading_velocity := 0.0
var eye_velocity := Vector3.ZERO
var target_velocity := Vector3.ZERO
var first_person := false

func toggle_view() -> void:
	first_person = not first_person
	reset_motion()

func reset_motion() -> void:
	seeded = false
	eye_velocity = Vector3.ZERO
	target_velocity = Vector3.ZERO
	heading_velocity = 0.0

static func spring(current: Vector3, velocity: Vector3, desired: Vector3, dt: float, rate: float) -> Array:
	var decay := exp(-rate * dt)
	var offset := current - desired
	var impulse := velocity + offset * rate
	return [desired + (offset + impulse * dt) * decay, (velocity - impulse * rate * dt) * decay]

static func spring_angle(current: float, velocity: float, desired: float, dt: float, rate: float) -> Vector2:
	var offset := wrapf(current - desired, -PI, PI)
	var impulse := velocity + offset * rate
	var decay := exp(-rate * dt)
	return Vector2(wrapf(desired + (offset + impulse * dt) * decay, -PI, PI), (velocity - impulse * rate * dt) * decay)

static func forward(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0, cos(yaw))

static func seat(v: Dictionary, role: String, index: int = 0) -> Vector3:
	# Eye above the source seat anchor, with the nose kept in front of the near plane.
	var kind: String = v.get("kind", "puma")
	var offset := Vector3.ZERO
	match kind:
		"scout": offset = Vector3(-0.2, 1.12, 0.6)
		"titan": offset = Vector3(-0.6, 1.62, 1.05)
		"transport": offset = Vector3(-0.7, 2.24, 2.0)
		"hornet": offset = Vector3(-0.7, 1.21, 1.05)
		_: offset = Vector3(-0.4, 1.53, 1.05)
	if role == "gunner":
		offset = Vector3(0, 2.28 if kind == "titan" else (2.48 if kind == "transport" else 1.76), -0.75 if kind == "titan" else -0.4)
	elif role == "passenger":
		offset.x = absf(offset.x) if index % 2 == 0 else -absf(offset.x)
		offset.z = -0.65 if index > 0 else 0.4
	return Vector3(v.x, v.y, v.z) + Basis(Vector3.UP, float(v.yaw)) * offset

func configure_map(id: String, map: Dictionary) -> bool:
	# One selected map only. Repeated rounds keep the immutable spatial cache.
	if id == map_id and not id.is_empty(): return true
	map_id = ""
	boxes.clear()
	cells.clear()
	reset()
	if map.get("blocks", []).size() > MAX_BOXES: return false
	var memberships := 0
	for b: Dictionary in map.get("blocks", []):
		var bounds := AABB(Vector3(float(b.x)-float(b.w)/2, 0, float(b.z)-float(b.d)/2), Vector3(b.w, b.h, b.d)).grow(CLEARANCE)
		var low := cell(bounds.position)
		var high := cell(bounds.end)
		memberships += (high.x-low.x+1)*(high.y-low.y+1)
		if memberships > MAX_MEMBERSHIPS:
			boxes.clear()
			cells.clear()
			return false
		var index := boxes.size()
		boxes.append(bounds)
		for x in range(low.x, high.x+1):
			for z in range(low.y, high.y+1):
				var key := Vector2i(x, z)
				if not cells.has(key): cells[key] = []
				cells[key].append(index)
	map_id = id
	return true

func cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))

static func entry_fraction(start: Vector3, finish: Vector3, box: AABB) -> float:
	var direction := finish-start
	var near := 0.0
	var far := 1.0
	for axis in range(3):
		if absf(direction[axis]) < 0.000001:
			if start[axis] < box.position[axis] or start[axis] > box.end[axis]: return 1.0
		else:
			var a: float = (box.position[axis]-start[axis])/direction[axis]
			var b: float = (box.end[axis]-start[axis])/direction[axis]
			near = maxf(near, minf(a, b))
			far = minf(far, maxf(a, b))
			if near > far: return 1.0
	return near

func clear_eye(anchor: Vector3, candidate: Vector3) -> Vector3:
	var low := cell(anchor.min(candidate))
	var high := cell(anchor.max(candidate))
	var candidates: Dictionary = {}
	for x in range(low.x, high.x+1):
		for z in range(low.y, high.y+1):
			for index: int in cells.get(Vector2i(x, z), []): candidates[index] = true
	last_candidates = candidates.size()
	var fraction := 1.0
	for index: int in candidates:
		fraction = minf(fraction, entry_fraction(anchor, candidate, boxes[index]))
	obstructed = fraction < 1
	# Extra epsilon keeps the eye off the expanded face on grazing contact.
	if fraction < 1: fraction = maxf(0, fraction - 0.002)
	return anchor.lerp(candidate, fraction)

func reset() -> void:
	reset_motion()
	first_person = false
	obstructed = false
	eye = Vector3.ZERO
	target = Vector3.ZERO
	last = Vector3.ZERO
	last_candidates = 0

func follow(v: Dictionary, delta: float, look_yaw: float = NAN, look_pitch: float = 0.0, role: String = "driver", index: int = 0, reduced: bool = false) -> Dictionary:
	var p := Vector3(v.x, v.y, v.z)
	var yaw: float = float(v.yaw)
	var dt := clampf(delta, 0.0, 0.1)
	var snap := not seeded or last.distance_to(p) > 8.0 or not is_finite(delta)
	if snap:
		heading = yaw
		heading_velocity = 0.0
	elif reduced:
		heading = yaw
		heading_velocity = 0.0
	else:
		var angle_step := spring_angle(heading, heading_velocity, yaw, dt, 12.0)
		heading = angle_step.x
		heading_velocity = angle_step.y
	# Source heading drives the boom even in reverse. Never integrate a second
	# vehicle pose from velocity or extrapolate beyond the newest snapshot.
	var direction := forward(heading)
	var anchor := p + Vector3.UP * (1.4 if v.get("kind") == "scout" else (2.25 if v.get("kind") == "hornet" else 1.8))
	if first_person:
		var cockpit := seat(v, role, index)
		var sight_yaw := float(v.yaw) - PI if is_nan(look_yaw) else look_yaw
		var sight := Basis.from_euler(Vector3(look_pitch, sight_yaw, 0)) * Vector3.FORWARD
		# The seat tracks snapshots with bounded lag; the sight itself responds to
		# mouse look immediately. Never extrapolate beyond the authoritative seat.
		if snap or reduced:
			eye = cockpit
			eye_velocity = Vector3.ZERO
		else:
			var seat_step := spring(eye, eye_velocity, cockpit, dt, 18.0)
			eye = seat_step[0]
			eye_velocity = seat_step[1]
			if eye.distance_to(cockpit) > 0.35:
				eye = cockpit + (eye - cockpit).limit_length(0.35)
				eye_velocity = Vector3.ZERO
		target = eye + sight * 20.0
		last = p
		seeded = true
		obstructed = false
		return {"eye":eye, "target":target}
	var distance := 10.5 if v.get("kind") == "hornet" else (11.0 if v.get("kind") == "titan" else (7.0 if v.get("kind") == "scout" else 9.0))
	var height := 5.0 if v.get("kind") != "scout" else 3.35
	var desired := p - direction * distance + Vector3.UP * height
	var aim := anchor + direction * 7.0
	if snap or reduced:
		eye = desired
		target = aim
		seeded = true
		eye_velocity = Vector3.ZERO
		target_velocity = Vector3.ZERO
	else:
		var e := spring(eye, eye_velocity, desired, dt, 12.0)
		eye = e[0]
		eye_velocity = e[1]
		var t := spring(target, target_velocity, aim, dt, 12.0)
		target = t[0]
		target_velocity = t[1]
	# Spring overshoot must never place the camera ahead of the vehicle or beyond
	# the boom; reset momentum at the boundary rather than fighting the clamp.
	var boom := eye - anchor
	if boom.dot(direction) > -0.4 or boom.length() > distance + height:
		eye = anchor + boom.limit_length(distance + height)
		if (eye - anchor).dot(direction) > -0.4: eye = anchor - direction * 0.4 + Vector3.UP * height
		eye_velocity = Vector3.ZERO
	# Clip AFTER smoothing so interpolation cannot carry the eye through a wall.
	eye = clear_eye(anchor, eye)
	if obstructed: eye_velocity = Vector3.ZERO
	if (target - eye).dot(direction) < 1.0:
		target = eye + direction * 7.0
		target_velocity = Vector3.ZERO
	last = p
	return {"eye":eye,"target":target}
