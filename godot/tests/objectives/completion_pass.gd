extends "res://tests/objectives/completion_live.gd"
## Single bounded flag-pass run. Same ordinary native events and lifecycle checks.
var pass_seen := false
var flag_captured := false
var pass_time := 0.0

func _ready() -> void:
	super._ready()
	client.events.connect(func(items: Array) -> void:
		for event: Dictionary in items:
			if event.get("type") == "flag-pass": print("COMPLETION_PASS_EVENT ", JSON.stringify(event)))

func on_lobby(frame: Dictionary) -> void:
	if phase == 2 and frame.get("players", []).size() < 3: return
	super.on_lobby(frame)

func on_snapshot(frame: Dictionary) -> void:
	super.on_snapshot(frame)
	if round_starts != 1: return
	for flag: Dictionary in state.get("flags", []):
		if flag.team == 1 and flag.state == "carried" and flag.carrier == 2:
			pass_seen = true
			screenshot("pass")
	flag_captured = state.get("teamScores", {}).get("0", 0) > 0
	if flag_captured: screenshot("capture")

func completion_success() -> bool:
	return pass_seen and flag_captured

func drive_objective(position: Vector2) -> void:
	var a: Dictionary = presentation.local_actor
	if route.is_empty(): route.assign([Vector2(-72,0),Vector2(-54,0),Vector2(-26,0),Vector2(0,8),Vector2(26,0),Vector2(54,0),Vector2(72,0)])
	if stage == "approach" and a.get("carryingFlag", false): stage = "rendezvous"
	if stage == "rendezvous":
		follow(Vector2(62,0))
		for ally: Dictionary in state.actors:
			if ally.id == 2 and ally.team == a.team and ally.health > 0 and position.distance_to(Vector2(ally.x,ally.z)) < 2.25:
				neutral()
				aim_at_point(Vector2(ally.x,ally.z))
				key(KEY_E, true)
				stage = "pass"
				pass_time = state.time
		return
	if stage == "pass":
		if state.time > pass_time + 0.2: key(KEY_E, false)
		if pass_seen:
			stage = "home"
			route.assign([Vector2(54,0),Vector2(26,0),Vector2(0,8),Vector2(-26,0),Vector2(-54,0),Vector2(-68,3)])
			index = 0
		elif state.time > pass_time + 4:
			finishing = true
			neutral()
			print("COMPLETION_BLOCKED ", JSON.stringify({"stage":stage,"time":state.time,"actor":a,"flags":state.flags}))
			get_tree().quit(1)
		return
	if follow(route[index]) and index < route.size()-1: index += 1
	if stage == "home" and index == route.size()-1 and flag_captured: aim_at_point(Vector2(-72,0))
	if position.distance_to(last_progress_position) > 0.5:
		last_progress_position = position
		last_progress_time = state.time
	if stage == "approach" and state.time > last_progress_time + 12:
		finishing = true
		neutral()
		print("COMPLETION_BLOCKED ", JSON.stringify({"stage":stage,"time":state.time,"actor":a}))
		get_tree().quit(1)
