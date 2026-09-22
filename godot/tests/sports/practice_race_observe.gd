extends "res://tests/sports/progression_observe.gd"
## Target victory, using the previously accepted 17-gate physical-key route.
var finish_events: Array = []
var gates_seen: Array = []

func connect_observer() -> void:
	super.connect_observer()
	demo.net.events.connect(func(items: Array) -> void:
		for item: Dictionary in items:
			if item.get("type") == "race-finish": finish_events.append(item))

func _process(delta: float) -> bool:
	age += delta
	if age > 110:
		push_error("Target victory deadline")
		quit(1)
		return false
	if not is_instance_valid(demo) or not demo.is_node_ready(): return false
	if demo.phase == "error":
		push_error(demo.error)
		quit(1)
		return false
	var race: Dictionary = demo.state.get("race", {})
	if round_number == 1:
		if race.get("phase") == "countdown" and age > 1: capture("countdown")
		if demo.eligible():
			if not demo.controls.engaged: tap(KEY_ENTER)
			control_age += delta
			if control_age > 0.07:
				control_age = 0
				drive(race)
			for row: Dictionary in race.get("standings", []):
				if row.get("actorId") != demo.net.actor_id: continue
				if int(row.nextGate) != last_gate:
					last_gate = int(row.nextGate)
					gates_seen.append(last_gate)
					print("VICTORY_GATE ", JSON.stringify({"elapsed":race.elapsed,"row":row,"vehicle":demo.vehicle,"seq":demo.net.last_snapshot_seq,"ack":demo.net.last_ack}))
					if last_gate > 0: capture("checkpoint")
		if demo.phase == "results":
			results_age += delta
			if results_age < 0.2: release()
			assert(not demo.controls.engaged and demo.controls.keys.is_empty())
			assert(demo.state.get("overReason") == "race-finish", "target finish, never time-limit")
			assert(int(race.laps) == 1 and int(race.winnerId) == demo.net.actor_id)
			assert(int(race.standings[0].completedLaps) == 1 and race.standings[0].finishTime != null)
			capture("results")
			if results_age > 1.5 and captures.has("results"):
				assert(finish_events.size() == 1 and finish_events[0].actor == demo.net.actor_id)
				print("VICTORY_RESULT ", JSON.stringify({"state":demo.state,"events":finish_events,"gates":gates_seen,"seq":demo.net.last_snapshot_seq,"ack":demo.net.last_ack}))
				key(KEY_W, true)
				tap(KEY_F5)
				assert(demo.state.is_empty() and demo.vehicle.is_empty() and demo.actor.is_empty())
				assert(not demo.chase.seeded and demo.chase.eye == Vector3.ZERO)
				assert(not demo.ball.visible and not demo.guidance.visible and demo.progression.message.is_empty())
	elif round_number == 2:
		if race.get("phase") == "countdown": capture("restart-countdown")
		if demo.eligible():
			restart_age += delta
			if stage == 0:
				origin = position()
				stage = 1
			if stage == 1 and restart_age > 1:
				assert(not demo.controls.engaged and position().distance_to(origin) < 0.15)
				capture("restart-held-blocked")
				if captures.has("restart-held-blocked"):
					print("VICTORY_INPUT_STAGE ", JSON.stringify({"stage":"enter-only","seq":demo.net.input_seq,"ack":demo.net.last_ack,"vehicle":demo.vehicle}))
					tap(KEY_ENTER)
					stage = 2
			if stage == 2 and restart_age > 2:
				assert(demo.controls.engaged and position().distance_to(origin) < 0.15)
				capture("restart-enter-neutral")
				if captures.has("restart-enter-neutral"):
					print("VICTORY_INPUT_STAGE ", JSON.stringify({"stage":"fresh-movement","seq":demo.net.input_seq,"ack":demo.net.last_ack,"vehicle":demo.vehicle}))
					key(KEY_W, false)
					key(KEY_W, true)
					stage = 3
			if stage == 3 and restart_age > 3.2:
				assert(position().distance_to(origin) > 0.5)
				capture("restart-fresh-driving")
				if captures.has("restart-fresh-driving"):
					release()
					stage = 4
			if stage == 4 and restart_age > 4.2 and not busy:
				print("VICTORY_ENDED ", JSON.stringify({"map":demo.map_id,"gates":gates_seen,"events":finish_events,"captures":captures,"seq":demo.net.last_snapshot_seq,"ack":demo.net.last_ack,"fresh_displacement":position().distance_to(origin)}))
				quit()
	return false
