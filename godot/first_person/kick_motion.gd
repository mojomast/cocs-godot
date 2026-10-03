extends RefCounted
## Accepted-action sequence, not damage authority. No input queue or network writes.
const DURATION := 0.29
const CHAIN_WINDOW := 0.85
const CONTACT := 0.095
const STRIKES := ["lead_push", "cross_snap", "heel_drive"]
var step := 0
var last_time := -INF
var last_id := -1
var age := DURATION
var continuing := false
var confirmed := false
var accepted := 0

func accept(event: Dictionary) -> bool:
	var id: Variant = event.get("id")
	var time: Variant = event.get("time")
	if event.get("type") != "melee" or not (id is int or id is float) or not (time is int or time is float): return false
	if not is_finite(float(id)) or float(id) < 0 or float(id) != floor(float(id)) or not is_finite(float(time)) or float(time) < 0: return false
	if int(id) <= last_id or float(time) <= last_time: return false
	var gap := float(time) - last_time
	step = (step + 1) % 3 if continuing and gap <= CHAIN_WINDOW and gap >= 0.299 else 0
	last_time = float(time)
	last_id = int(id)
	var hit: Variant = event.get("hit")
	confirmed = (hit is int or hit is float) and is_finite(float(hit)) and float(hit) >= 0 and float(hit) == floor(float(hit)) and hit != event.get("actor") and event.get("blocked") != true and event.get("protected") != true
	continuing = confirmed
	age = 0.0
	accepted += 1
	return true

func advance(delta: float) -> void:
	if is_finite(delta) and delta >= 0: age = minf(DURATION, age + delta)

func interrupt() -> void:
	age = DURATION
	continuing = false
	step = 0

func reset() -> void:
	interrupt()
	last_time = -INF
	last_id = -1
	accepted = 0

func sample(reduced: bool = false) -> Dictionary:
	return pose(step, age, confirmed, reduced)

static func pose(index: int, seconds: float, hit: bool = true, reduced: bool = false) -> Dictionary:
	var t := clampf(seconds, 0.0, DURATION)
	# Individually eased phases: load, chamber, snap, contact, recoil, seat.
	var times := [0.0, 0.035, 0.065, CONTACT, 0.12, 0.185, DURATION]
	var hips := [-0.10, -0.22, 0.94, 1.38, 1.39, 0.85, -0.10]
	var knees := [0.18, 0.42, 1.62, 0.16, 0.18, 1.25, 0.18]
	var ankles := [0.0, -0.12, -0.30, -0.38, -0.35, -0.15, 0.0]
	var shifts := [0.0, 0.3, 0.7, 1.0, 0.96, 0.48, 0.0]
	var segment := 0
	for i: int in range(times.size() - 1):
		if t >= times[i]: segment = i
	var u := smoothstep(float(times[segment]), float(times[segment + 1]), t)
	var lift := lerpf(hips[segment], hips[segment + 1], u)
	var bend := lerpf(knees[segment], knees[segment + 1], u)
	var flex := lerpf(ankles[segment], ankles[segment + 1], u)
	var weight := lerpf(shifts[segment], shifts[segment + 1], u)
	var side := 1.0 if index == 1 else -1.0
	var yaw: float = [0.06, -0.52, 0.23][clampi(index, 0, 2)] * weight
	lift += (0.10 if index == 2 else -0.06 if index == 1 else 0.0) * weight
	bend *= 0.72 if index == 2 else 1.0
	var scale := 0.65 if reduced else 1.0
	# Miss follows through a little farther; contact itself remains server-owned.
	var follow := (0.0 if hit else 0.08) * smoothstep(CONTACT, 0.12, t) * (1.0 - smoothstep(0.12, DURATION, t))
	return {"visible":t < DURATION, "strike":STRIKES[clampi(index, 0, 2)], "step":index + 1,
		"root":Vector3(side * (0.22 - 0.065 * weight), -0.69 + 0.25 * weight, -0.20 - follow),
		"hip":Vector3(lift, yaw, side * weight * (0.15 if index == 2 else 0.08)),
		"knee":Vector3(-bend, 0, 0), "ankle":Vector3(flex, 0, side * weight * 0.06),
		"toe":Vector3(weight * 0.12, 0, 0), "weight":weight,
		"weapon_position":Vector3(-side * 0.035, -0.13, 0.055) * weight * scale,
		"weapon_rotation":Vector3(-0.10, side * 0.06, side * 0.10) * weight * scale}
