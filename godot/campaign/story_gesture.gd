extends RefCounted
## Unarmed story performance, sampled analytically from a delta-time clock.
## Joint angles use CharacterRig's source convention (it flips pitch on apply).
## No animation tracks accumulate transforms, use wall time, or loop greetings.
const Rig = preload("res://source_operators/character_rig.gd")
const JOINTS := ["armUpperL", "armUpperR", "forearmL", "forearmR", "handL", "handR", "torso", "chest", "head"]
const POSES := ["idle", "walk", "wave", "point", "work"]
var pose := "idle"
var age := 0.0
var time := 0.0
var entry: Dictionary = rest()
var entry_walk := 0.0

static func rest() -> Dictionary:
	return {"armUpperL":Vector3(0.035, 0, -0.055), "armUpperR":Vector3(0.035, 0, 0.055),
		"forearmL":Vector3(-0.12, 0, 0), "forearmR":Vector3(-0.12, 0, 0),
		"handL":Vector3.ZERO, "handR":Vector3.ZERO,
		"torso":Vector3.ZERO, "chest":Vector3.ZERO, "head":Vector3.ZERO}

static func smooth_weight(value: float) -> float:
	var x := clampf(value, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

static func blend(a: Dictionary, b: Dictionary, weight: float) -> Dictionary:
	var out := {}
	for joint: String in JOINTS:
		var from: Vector3 = a[joint]
		out[joint] = from.lerp(b[joint], weight)
	return out

static func changed(values: Dictionary) -> Dictionary:
	var out := rest()
	out.merge(values, true)
	return out

func select(next: String) -> void:
	if next not in POSES: next = "idle"
	if next == pose: return
	# Preserve the exact currently displayed gesture across an interrupted pose.
	entry = sample()
	entry_walk = walk_weight()
	pose = next
	age = 0.0

func advance(dt: float) -> void:
	if not is_finite(dt) or dt <= 0.0: return
	age += dt
	time += dt

func walk_weight() -> float:
	return lerpf(entry_walk, 1.0 if pose == "walk" else 0.0, smooth_weight(age / 0.45))

func sample() -> Dictionary:
	var keys: Array = []
	var relaxed := rest()
	match pose:
		"wave":
			# R shoulder abduction is POSITIVE roll: palm stays outside the face.
			# The elbow holds its bend; one small wrist acknowledgment does the work.
			var prepare := changed({"armUpperR":Vector3(0.09, 0, 0.08), "forearmR":Vector3(-0.22, 0, 0)})
			var greet := changed({"armUpperR":Vector3(-0.55, 0.02, 0.95), "forearmR":Vector3(-1.15, 0, 0),
				"handR":Vector3(0.06, -0.12, 0), "head":Vector3(0.025, -0.025, 0)})
			var acknowledge: Dictionary = greet.duplicate()
			acknowledge.handR = Vector3(0.06, -0.12, 0.15)
			var return_palm: Dictionary = greet.duplicate()
			return_palm.handR = Vector3(0.06, -0.12, -0.07)
			keys = [[0.0, relaxed], [0.18, prepare], [0.70, greet], [1.00, greet],
				[1.20, acknowledge], [1.43, return_palm], [1.63, greet], [2.35, relaxed]]
		"point":
			var prepare := changed({"forearmR":Vector3(-0.28, 0, 0), "head":Vector3(0, -0.06, 0)})
			var indicate := changed({"armUpperR":Vector3(-1.0, 0, 0.18), "forearmR":Vector3(-0.20, 0, 0),
				"handR":Vector3(0.035, -0.06, 0.035), "chest":Vector3(0, -0.045, 0), "head":Vector3(0.02, -0.10, 0)})
			keys = [[0.0, relaxed], [0.20, prepare], [0.75, indicate], [1.80, indicate], [2.65, relaxed]]
		"work":
			# Inspect the left service board, make one deliberate right-hand touch,
			# then lower both hands. No combat crouch or weapon-grip pose.
			var inspect := changed({"armUpperL":Vector3(-0.40, 0, -0.15), "forearmL":Vector3(-0.95, 0, 0),
				"handL":Vector3(0, 0.12, 0.10), "armUpperR":Vector3(-0.30, 0, -0.18),
				"forearmR":Vector3(-0.75, 0, 0), "handR":Vector3(0, -0.08, -0.08),
				"torso":Vector3(0.045, 0, 0), "head":Vector3(0.10, 0.10, 0)})
			var touch: Dictionary = inspect.duplicate()
			touch.forearmR = Vector3(-0.87, 0, 0)
			touch.handR = Vector3(0.06, -0.08, -0.08)
			keys = [[0.0, relaxed], [0.65, inspect], [1.05, inspect], [1.30, touch],
				[1.65, inspect], [2.10, inspect], [2.95, relaxed]]
	var target := relaxed
	for i: int in range(1, keys.size()):
		if age <= float(keys[i][0]):
			var start: float = keys[i - 1][0]
			var end: float = keys[i][0]
			target = blend(keys[i - 1][1], keys[i][1], smooth_weight((age - start) / (end - start)))
			break
	return blend(entry, target, smooth_weight(age / 0.35))

func apply_to(visual: Node3D) -> void:
	var rig: RefCounted = visual.get("rig")
	var weight := walk_weight()
	var phase := time * TAU * 0.60
	var body: Dictionary = Rig.solve({"speedNorm":weight * 0.175, "forward":weight,
		"time":time, "phase":phase, "grounded":true, "contactGait":true})
	var angles := sample()
	# Retain the production planted-foot gait, with quiet unarmed torso/head idle.
	body.torso = Vector3(0.025, 0, 0) + angles.torso
	body.chest = Vector3(sin(time * 1.4) * 0.005, 0, 0) + angles.chest
	body.head = Vector3(sin(time * 0.8) * 0.006, 0, 0) + angles.head
	rig.apply_pose(body)
	for side: String in ["L", "R"]:
		var swing := sin(phase) * 0.10 * weight * (1.0 if side == "L" else -1.0)
		rig.rotate_joint("armUpper" + side, angles["armUpper" + side] + Vector3(swing, 0, 0))
		rig.rotate_joint("forearm" + side, angles["forearm" + side])
		rig.rotate_joint("hand" + side, angles["hand" + side])
