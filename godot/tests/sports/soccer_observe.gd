extends "res://tests/sports/progression_observe.gd"
## Test-only steering via normal native InputEventKey. Gameplay has no driver.
## Reads only accepted local vehicle/public soccer snapshot, never hidden actors.
var attempt := 0
var local_goal := false
var goal_age := 0.0
var sample_age := 0.0
var sample_position := Vector2.ZERO
var jam_samples := 0
var reverse_left := 0.0
var recoveries := 0
var strategy := "approach"
var drive_target := Vector2.ZERO

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--soccer-attempt="): attempt = int(arg.trim_prefix("--soccer-attempt="))
	super._initialize()

func _process(delta: float) -> bool:
	age += delta
	if not is_instance_valid(demo) or not demo.is_node_ready(): return false
	if demo.phase == "error":
		push_error(demo.error)
		quit(1)
		return false
	for item: Dictionary in goals:
		if item.get("actorId") == demo.net.actor_id and item.get("team") == demo.actor.get("team"): local_goal = true
	if not goals.is_empty(): capture("goal")
	if local_goal: goal_age += delta
	if (local_goal and goal_age > 1.0) or age > (175 if attempt else 7) or demo.phase == "results":
		release()
		capture("end")
		if busy or not captures.has("end"): return false
		print("SOCCER_ENDED ", JSON.stringify({"attempt":attempt,"local_goal":local_goal,"goals":goals,"elapsed":demo.state.get("race", {}).get("elapsed"),"seq":demo.net.last_snapshot_seq,"ack":demo.net.last_ack,"recoveries":recoveries,"captures":captures,"wallBound":175}))
		quit()
		return false
	var race: Dictionary = demo.state.get("race", {})
	if race.get("phase") == "kickoff" and age > 1: capture("countdown")
	if not demo.eligible(): return false
	if not attempt:
		if age > 5: capture("guidance")
		return false
	if local_goal: return false
	if not demo.controls.engaged:
		for code in held.keys(): key(code, false)
		tap(KEY_ENTER)
	drive_age += delta
	if drive_age > 3: capture("driving")
	control_age += delta
	if control_age >= 0.065:
		control_age = 0
		drive_soccer(race, delta)
	sample_age += delta
	if sample_age > 1.0:
		sample_age = 0
		var pos := Vector2(demo.vehicle.x, demo.vehicle.z)
		# Collision resolution can preserve velocity while actual displacement is zero.
		jam_samples = jam_samples+1 if pos.distance_to(sample_position) < 0.65 else 0
		sample_position = pos
		if jam_samples >= 2 and reverse_left <= 0:
			reverse_left = 1.35
			recoveries += 1
			jam_samples = 0
		print("SOCCER_DRIVER ", JSON.stringify({"elapsed":race.elapsed,"strategy":strategy,"target":[drive_target.x,drive_target.y],"vehicle":demo.vehicle,"ball":race.ball,"recoveries":recoveries,"keys":demo.controls.keys,"seq":demo.net.last_snapshot_seq,"ack":demo.net.last_ack}))
	reverse_left = maxf(0, reverse_left-delta)
	return false

func drive_soccer(race: Dictionary, _delta: float) -> void:
	var v: Dictionary = demo.vehicle
	var p := Vector2(v.x, v.z)
	var speed := Vector2(v.vx, v.vz).length()
	var ball_pos := Vector2(race.ball.x, race.ball.z)
	var goal := Vector2.ZERO
	for g: Dictionary in race.goals:
		if g.team != demo.actor.get("team"): goal = Vector2(g.x, g.z)
	var pitch: Dictionary = race.pitch
	var bank := false
	# Attempt 1 revealed unreachable behind-ball approach points at side boards.
	# Attempt 2 aims at the reflected opponent goal so the ordinary board bounce
	# can carry the ball inward; no collision/ball/source parameter is changed.
	if attempt == 2 and (ball_pos.y > float(pitch.maxZ)-4 or ball_pos.y < float(pitch.minZ)+4):
		goal.y = 2*(float(pitch.maxZ) if ball_pos.y > 0 else float(pitch.minZ))-goal.y
		bank = true
	var shot := (goal-ball_pos).normalized()
	var relative := p-ball_pos
	var behind := -relative.dot(shot)
	var lateral := absf(relative.cross(shot))
	var approach := ball_pos-shot*8
	approach.x = clampf(approach.x, float(pitch.minX)+2.6, float(pitch.maxX)-2.6)
	approach.y = clampf(approach.y, float(pitch.minZ)+2.6, float(pitch.maxZ)-2.6)
	drive_target = approach
	strategy = "approach"
	# Get behind first, rather than continuously circling a point 4 m from the ball.
	# Once lined up, follow through into the ball towards the opponent goal.
	if behind > 1.5 and lateral < maxf(1.4, behind*0.22):
		drive_target = ball_pos + shot*3
		strategy = "strike"
	elif behind < 2.5 and relative.length() < 10:
		var side := Vector2(-shot.y, shot.x)
		var sign_side := 1.0 if relative.dot(side) >= 0 else -1.0
		drive_target = approach + side*sign_side*6
		drive_target.y = clampf(drive_target.y, float(pitch.minZ)+3, float(pitch.maxZ)-3)
		strategy = "go-around"
	var error := wrapf(atan2(drive_target.x-p.x,drive_target.y-p.y)-float(v.yaw), -PI, PI)
	var reverse := reverse_left > 0
	if reverse: strategy = "reverse-out"
	key(KEY_S, reverse)
	key(KEY_D, error < -0.14 if reverse else error > 0.10)
	key(KEY_A, error > 0.14 if reverse else error < -0.10)
	# Brake/turn in place with source Puma's low-speed steering assist for sharp
	# angles; straight strikes retain enough velocity to propel the damped ball.
	var cap := 2.0 if absf(error) > 0.75 else (7.0 if absf(error) > 0.3 else 17.0)
	if strategy == "approach": cap = minf(cap, maxf(3.0, p.distance_to(approach)*1.3))
	var boost := not reverse and absf(error) < 0.12 and ((strategy == "strike" and relative.length() < 9) or (attempt == 2 and p.distance_to(drive_target) > 14))
	if attempt == 2 and boost: cap = 26
	key(KEY_W, not reverse and absf(error) < 0.75 and speed < cap)
	key(KEY_SPACE, not reverse and speed > cap+0.8)
	key(KEY_SHIFT, boost)
	if bank: strategy = "bank-" + strategy
