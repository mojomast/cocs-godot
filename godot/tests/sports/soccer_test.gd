extends SceneTree
## Synthetic JSON-float authority/geometry regressions; not a live goal claim.
const Guidance = preload("res://sports/soccer_guidance.gd")
const HUD = preload("res://sports/hud.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func fixture(team: int) -> Dictionary:
	# JSON decode is intentional: numeric wire IDs/teams arrive as floats.
	var state: Dictionary = JSON.parse_string('{"actors":[{"id":7,"team":0,"health":100,"dead":0,"vehicleId":3,"vehicleSeat":"driver"}],"race":{"kind":"soccer","phase":"playing","ball":{"x":0,"y":1.1,"z":0,"r":1.1},"pitch":{"minX":-44,"maxX":44,"minZ":-24,"maxZ":24},"goals":[{"team":0,"x":-44,"z":0,"nx":-1,"nz":0,"halfWidth":7,"height":5,"depth":4},{"team":1,"x":44,"z":0,"nx":1,"nz":0,"halfWidth":7,"height":5,"depth":4}]}}')
	state.actors[0].team = float(team)
	return state

func run() -> void:
	var marker := Guidance.new()
	root.add_child(marker)
	var v: Dictionary = JSON.parse_string('{"id":3,"driver":7,"x":-10,"z":0,"yaw":1.5707963267949,"health":300,"respawnTimer":0}')
	for team in [0, 1]:
		var state := fixture(team)
		var before := JSON.stringify(state)
		var target := marker.apply(state, 7, v, true)
		check(target.team == team and marker.visible, "wire local team selects guidance")
		check(target.own.team == team and target.opponent.team == 1-team, "goal team denotes defender, not scorer")
		check(marker.markers[0].position.x == (-44 if team == 0 else 44), "own source goal position")
		check(marker.markers[1].basis.z.is_equal_approx(Vector3.RIGHT if team == 0 else Vector3.LEFT), "goal stripe follows outward goal normal")
		check(marker.markers[0].get_child(0).material_override.albedo_color == Guidance.team_color(team), "own marker uses actual team color")
		check(marker.markers[1].get_child(0).material_override.albedo_color == Guidance.team_color(1-team), "opponent marker uses opposing team color")
		check(marker.markers[0].get_child(1).text.begins_with("OWN") and marker.markers[1].get_child(1).text.begins_with("ATTACK"), "explicit friendly/opponent roles regardless of color")
		check(Guidance.describe(target).contains("Ball Ahead · 10 m"), "ball distance/bearing is accepted source geometry")
		check(marker.markers[1].get_child(0).scale.x == 14, "goal width from public snapshot")
		for i in range(100): marker.apply(state, 7, v, true)
		check(marker.get_child_count() == 3 and JSON.stringify(state) == before, "bounded markers never mutate source state")
		marker.apply(state, 7, v, false)
		check(not marker.visible and marker.selection.is_empty() and marker.markers[0].position == Vector3.ZERO and marker.markers[1].get_child(1).text.is_empty(), "stale/results gate clears selected geometry and captions")
	var state := fixture(0)
	check(Guidance.select(state, -1, v, true).is_empty(), "unknown local actor cannot show target")
	check(Guidance.select(state, 8, v, true).is_empty(), "absent local actor cannot infer team from standings")
	check(Guidance.select(state, 7, {}, true).is_empty(), "absent vehicle hides arrow")
	for mutation in ["missing-ball", "bad-ball", "bad-pitch", "bad-normal", "inward-normal", "missing-goal", "duplicate-team", "bad-width", "absent-actor", "invalid-team", "dead", "no-driver", "over", "phase"]:
		var bad := fixture(0)
		match mutation:
			"missing-ball": bad.race.erase("ball")
			"bad-ball": bad.race.ball.x = NAN
			"bad-pitch": bad.race.pitch.minX = 44
			"bad-normal": bad.race.goals[0].nx = 0
			"inward-normal": bad.race.goals[0].nx = 1
			"missing-goal": bad.race.goals.pop_back()
			"duplicate-team": bad.race.goals[1].team = 0
			"bad-width": bad.race.goals[0].halfWidth = -1
			"absent-actor": bad.actors.clear()
			"invalid-team": bad.actors[0].team = "0"
			"dead": bad.actors[0].dead = 1
			"no-driver": bad.actors[0].vehicleSeat = "gunner"
			"over": bad.over = true
			"phase": bad.race.phase = "over"
		marker.apply(state, 7, v, true)
		marker.apply(bad, 7, v, true)
		check(not marker.visible and marker.selection.is_empty(), "invalid/missing replacement clears old target: " + mutation)
	check(Guidance.bearing({"x":-20,"z":0}, v).begins_with("Behind"), "behind ball not forward arrow")
	check(Guidance.bearing({"x":-10,"z":10}, v).begins_with("Left"), "heading-relative left")
	check(Guidance.bearing({"x":-10,"z":-10}, v).begins_with("Right"), "heading-relative right")
	var hud := HUD.new()
	root.add_child(hud)
	var view := {"mode":"puma-soccer", "state":state, "phase":"active", "age":0, "soccer_guidance":Guidance.select(state, 7, v, true)}
	hud.update(view)
	check(hud.text.contains("OWN Red goal · ATTACK Blue goal") and hud.soccer_label.visible, "observer-friendly summary retains soccer guidance")
	view.age = 1
	hud.update(view)
	check(not hud.text.contains("ATTACK") and not hud.soccer_label.visible, "stale HUD removes guidance")
	hud.reset()
	check(hud.text.is_empty() and not hud.soccer_label.visible, "restart immediately clears soccer HUD")
	hud.free()
	marker.free()
	print("SOCCER_SYNTHETIC_CHECKS ", checks, " failures=", failures)
	quit(1 if failures else 0)
