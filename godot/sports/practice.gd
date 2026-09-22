extends RefCounted
## Passive shot coaching, using the already validated public guidance selection.
## This source always fills soccer to four actors (game/core.mjs). Do not claim
## that requesting botCount=0 creates a solo practice match.
static func option_error(arguments: PackedStringArray) -> String:
	for argument: String in arguments:
		if argument == "--practice" or argument.begins_with("--practice="):
			return "Solo --practice is unavailable: the source fills soccer to four players with bots. Launch ordinary soccer for shot coaching."
	return ""

static func describe(target: Dictionary, pitch: Dictionary) -> String:
	if target.is_empty(): return ""
	var ball := Vector2(target.ball.x, target.ball.z)
	var goal := Vector2(target.opponent.x, target.opponent.z)
	var car := Vector2(target.vehicle.x, target.vehicle.z)
	var shot := (goal-ball).normalized()
	if shot.is_zero_approx(): return "Shot practice · Follow the ball through the ATTACK goal"
	var relative := car-ball
	var behind := -relative.dot(shot)
	var lateral := absf(relative.cross(shot))
	if pitch.has_all(["minZ", "maxZ"]) and (ball.y < float(pitch.minZ)+4 or ball.y > float(pitch.maxZ)-4):
		return "Shot practice · Ball at side board: approach along the board, then aim inward"
	if behind < 2.5:
		return "Shot practice · Circle behind the ball, on the OWN-goal side"
	if lateral > maxf(1.0, behind*0.12):
		return "Shot practice · Line up car → ball → ATTACK goal; Space brakes"
	var heading := Vector2(sin(float(target.vehicle.yaw)), cos(float(target.vehicle.yaw)))
	if heading.dot(shot) < 0.98:
		return "Shot practice · Brake and turn toward ATTACK before accelerating"
	return "Shot practice · Aligned: W to push straight; Shift for a stronger shot"
