extends "res://tests/sports/soccer_observe.gd"
## Bounded test-only physical driver. The source forcibly fills bots; this is
## explicitly an ordinary 2v2 attempt, not a zero-bot practice acceptance.
var committed := false

func drive_soccer(race: Dictionary, _delta: float) -> void:
	var v: Dictionary = demo.vehicle
	var p := Vector2(v.x, v.z)
	var speed := Vector2(v.vx, v.vz).length()
	var b := Vector2(race.ball.x, race.ball.z)
	var velocity := Vector2(race.ball.vx, race.ball.vz)
	var goal := Vector2.ZERO
	for g: Dictionary in race.goals:
		if g.team != demo.actor.get("team"): goal = Vector2(g.x, g.z)
	var pitch: Dictionary = race.pitch
	# Public velocity predicts a short contact horizon, not a hidden future state.
	var horizon := minf(0.25, p.distance_to(b)/maxf(8, speed)*0.15)
	var predicted := b + velocity*horizon
	var bank := b.y < float(pitch.minZ)+4 or b.y > float(pitch.maxZ)-4
	if bank: goal.y = 2*(float(pitch.maxZ) if b.y > 0 else float(pitch.minZ))-goal.y
	var shot := (goal-predicted).normalized()
	var side := Vector2(-shot.y, shot.x)
	var relative := p-predicted
	var behind := -relative.dot(shot)
	var lateral := relative.dot(side)
	# Approach plane is farther than CAR_RADIUS 1.7 + public ball radius 1.1.
	# Commit with hysteresis, then hit along the centre-to-opponent direction.
	if behind > 3.5 and absf(lateral) < 0.9: committed = true
	if behind < 0.4 or absf(lateral) > 3.0: committed = false
	var approach := predicted-shot*5.5
	drive_target = approach
	strategy = "line-up"
	if committed:
		drive_target = predicted + shot*2
		strategy = "contact-through"
	elif behind < 3 and relative.length() < 12:
		drive_target = approach + side*(6.0 if lateral >= 0 else -6.0)
		strategy = "circle-behind"
	# Source board inner faces bound the reachable chassis route. A reflected
	# goal permits approaching a side-board ball from the open interior.
	drive_target.x = clampf(drive_target.x, float(pitch.minX)+2.3, float(pitch.maxX)-2.3)
	drive_target.y = clampf(drive_target.y, float(pitch.minZ)+2.3, float(pitch.maxZ)-2.3)
	var error := wrapf(atan2(drive_target.x-p.x, drive_target.y-p.y)-float(v.yaw), -PI, PI)
	var reverse := reverse_left > 0
	if reverse: strategy = "reverse-out"
	key(KEY_S, reverse)
	key(KEY_D, error < -0.10 if reverse else error > 0.055)
	key(KEY_A, error > 0.10 if reverse else error < -0.055)
	var cap := 1.5 if absf(error) > 0.65 else (6.0 if absf(error) > 0.25 else 15.0)
	if not committed: cap = minf(cap, maxf(2.5, p.distance_to(drive_target)*1.1))
	var boost := not reverse and committed and absf(error) < 0.10 and relative.length() < 10
	if boost: cap = 26
	key(KEY_W, not reverse and absf(error) < 0.65 and speed < cap)
	key(KEY_SPACE, not reverse and speed > cap+0.5)
	key(KEY_SHIFT, boost)
	if bank: strategy = "board-bank-" + strategy
