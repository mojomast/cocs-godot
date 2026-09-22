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
	seeded = false
	obstructed = false
	eye = Vector3.ZERO
	target = Vector3.ZERO
	last = Vector3.ZERO
	last_candidates = 0

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
	var anchor := p + Vector3.UP * 1.2
	# Bound lag/queries to the original boom length, including fast snapshot moves.
	eye = anchor + (eye-anchor).limit_length(10.3)
	# Clip AFTER smoothing so interpolation cannot carry the eye through a wall.
	# Safety pull-in is immediate; the existing exponential recovers smoothly.
	eye = clear_eye(anchor, eye)
	last = p
	return {"eye":eye,"target":target}
