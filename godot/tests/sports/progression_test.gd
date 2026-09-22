extends SceneTree
## Synthetic guidance/lifecycle edge cases; no live acceptance claim.
const Guidance = preload("res://sports/guidance.gd")
const Progression = preload("res://sports/progression.gd")
const Demo = preload("res://sports/demo.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var marker := Guidance.new()
	root.add_child(marker)
	var gate := {"x":10.0,"z":20.0,"nx":1.0,"nz":0.0,"halfWidth":13.0}
	var race := {"gates":[gate],"standings":[{"actorId":7,"nextGate":0,"finishTime":null}]}
	var original := JSON.stringify(race)
	marker.apply(race, 7, true)
	check(marker.visible and marker.gate_index == 0, "accepted actor selects next gate")
	check(marker.position == Vector3(10,0,20), "marker uses source gate XZ at ground")
	check(marker.basis.z.is_equal_approx(Vector3.RIGHT), "arrow follows +X source forward normal")
	check(marker.bars[2].position.y == 3 and marker.bars[0].scale.y == 3.25, "source crossing ceiling/floor, not arbitrary arch height")
	check(marker.bars[2].scale.x == 26, "source finite gate width")
	for i in range(300): marker.apply(race, 7, true)
	check(marker.get_child_count() == 8, "one bounded reused marker across snapshots")
	check(JSON.stringify(race) == original, "presentation never changes checkpoint state")
	marker.apply(race, 8, true)
	check(not marker.visible, "absent actor hides guidance")
	marker.apply(race, 7, false)
	check(not marker.visible and marker.gate_index == -1, "stale/results/reset clears marker selection")
	for invalid in [-1, 1, 0.5, NAN, "0"]:
		race.standings[0].nextGate = invalid
		check(Guidance.expected(race, 7).is_empty(), "invalid gate index rejected")
	race.standings[0].nextGate = 0
	race.gates[0].nx = 0
	check(Guidance.expected(race, 7).is_empty(), "zero gate normal cannot direct player")
	race.gates[0].nx = 1
	race.standings[0].finishTime = 10
	check(Guidance.expected(race, 7).is_empty(), "finished racer has no next gate")
	race.standings[0].finishTime = null
	check(Guidance.describe(race, 7, {"x":0,"z":20,"yaw":PI/2}).contains("Ahead · 10 m"), "heading/distance is source geometry derived")
	var progression := Progression.new()
	progression.events([{"type":"soccer-goal","team":1}], 7)
	check(progression.message == "Blue GOAL · Ball reset to centre", "actual goal event explains source reset")
	progression.events([JSON.parse_string('{"type":"soccer-goal","team":0,"actor":7}')], 7)
	check(progression.message == "Red GOAL · Ball reset to centre", "wire JSON float team IDs produce the goal/reset notification")
	progression.advance(5)
	check(progression.message.is_empty(), "goal notification expires")
	progression.events([{"type":"ball-moved","team":0}], 7)
	check(progression.message.is_empty(), "ball motion cannot invent a goal")
	progression.events([{"type":"race-lap","actor":9,"lap":1}], 7)
	check(progression.message.is_empty(), "another racer does not claim your lap")
	progression.events([{"type":"race-lap","actor":7,"lap":1}], 7)
	check(progression.message == "Lap 1 complete", "own lap event")
	progression.reset()
	check(progression.message.is_empty() and progression.remaining == 0, "restart clears event message and lifetime")
	check(Progression.clock(61.9) == "1:01" and Progression.clock(null) == "—:—", "clock floors source elapsed and preserves unknown")
	var result := Progression.results({"overReason":"time","race":{"elapsed":60,"standings":[{"actorId":7,"position":1,"completedLaps":0,"finishTime":null}]}}, 7, false)
	check(result.contains("Time limit reached") and result.contains("0 laps completed") and not result.contains("Finished"), "time-limit placing never fabricates lap finish")
	result = Progression.results({"overReason":"time","race":{"elapsed":60,"winnerTeam":null,"scores":{"0":0,"1":0}}}, 7, true)
	check(result.contains("Draw") and result.contains("Red 0"), "authoritative soccer draw")
	var demo := Demo.new() # deliberately outside tree: avoid opening a connection
	demo.state = {"over":true}
	demo.actor = {"id":7}
	demo.vehicle = {"id":0}
	demo.controls.engaged = true
	demo.controls.keys[KEY_W] = true
	demo.progression.events([{"type":"soccer-goal","team":0}], 7)
	demo.chase.seeded = true
	demo.chase.eye = Vector3.ONE
	demo.send_age = 0.02
	demo.hud.text = "Old results"
	demo.clear_round()
	check(demo.state.is_empty() and demo.actor.is_empty() and demo.vehicle.is_empty(), "restart clears accepted references")
	check(not demo.controls.engaged and demo.controls.keys.is_empty(), "restart requires new Enter and movement")
	check(not demo.chase.seeded and demo.chase.eye == Vector3.ZERO and demo.send_age == 0, "restart clears camera pose and input cadence")
	check(demo.progression.message.is_empty() and not demo.ball.visible and demo.guidance.gate_index == -1, "restart clears ball marker and messages")
	check(demo.hud.text.is_empty(), "restart immediately clears observer-friendly HUD summary")
	# Free children of the intentionally unparented demo explicitly.
	for node in [demo.world.camera, demo.world.label, demo.world.selector, demo.world.environment, demo.world.sun]: node.free()
	for node in [demo.net, demo.world, demo.fleet, demo.hud, demo.ball, demo.guidance]: node.free()
	demo.free()
	marker.free()
	print("SPORTS_PROGRESSION_SYNTHETIC_CHECKS ", checks, " failures=", failures)
	quit(1 if failures else 0)
