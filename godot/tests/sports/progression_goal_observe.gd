extends "res://tests/sports/progression_observe.gd"
## Separate bounded Aurora attempt: native keys only; no lifecycle claim here.
var stuck_age := 0.0
var reverse_age := 0.0
var local_goal := false

func _process(delta: float) -> bool:
	age += delta
	if not is_instance_valid(demo) or not demo.is_node_ready(): return false
	if demo.phase == "error":
		push_error(demo.error)
		quit(1)
		return false
	for item: Dictionary in goals:
		if item.get("actor") == demo.net.actor_id and item.get("team") == demo.actor.get("team"): local_goal = true
	if not goals.is_empty(): capture("goal")
	if local_goal or age > 135 or demo.phase == "results":
		release()
		if busy: return false
		print("PROGRESSION_GOAL_ATTEMPT_ENDED ", JSON.stringify({"local_goal":local_goal,"goals":goals,"elapsed":demo.state.get("race", {}).get("elapsed"),"seq":demo.net.last_snapshot_seq,"ack":demo.net.last_ack}))
		quit()
		return false
	var race: Dictionary = demo.state.get("race", {})
	if race.get("phase") == "kickoff" and age > 1: capture("countdown")
	if not demo.eligible(): return false
	if not demo.controls.engaged: tap(KEY_ENTER)
	drive_age += delta
	if drive_age > 3: capture("driving")
	var v: Dictionary = demo.vehicle
	var p := Vector2(v.x, v.z)
	var speed := Vector2(v.vx, v.vz).length()
	var b: Dictionary = race.ball
	var ball_pos := Vector2(b.x, b.z)
	var goal := Vector2.ZERO
	for g: Dictionary in race.goals:
		if g.team != demo.actor.get("team", 0): goal = Vector2(g.x, g.z)
	var approach := ball_pos-(goal-ball_pos).normalized()*4
	var pitch: Dictionary = race.pitch
	approach.x = clampf(approach.x, float(pitch.minX)+3, float(pitch.maxX)-3)
	approach.y = clampf(approach.y, float(pitch.minZ)+3, float(pitch.maxZ)-3)
	var target := ball_pos if p.distance_to(approach) < 4 else approach
	var error := wrapf(atan2(target.x-p.x,target.y-p.y)-float(v.yaw), -PI, PI)
	stuck_age = stuck_age+delta if speed < 0.8 else 0.0
	if stuck_age > 1.2 and reverse_age <= 0:
		reverse_age = 0.8
		stuck_age = 0
	if reverse_age > 0:
		reverse_age -= delta
		key(KEY_W, false)
		key(KEY_S, true)
		key(KEY_A, error > 0.12)
		key(KEY_D, error < -0.12)
		key(KEY_SPACE, false)
	else:
		key(KEY_S, false)
		key(KEY_D, error > 0.12)
		key(KEY_A, error < -0.12)
		var cap := 10.0 if absf(error) > 0.6 else 18.0
		key(KEY_W, speed < cap)
		key(KEY_SPACE, speed > cap+2)
	return false
