extends RefCounted
## Transient messages are sourced only from deduplicated network events.
var message := ""
var remaining := 0.0

func reset() -> void:
	message = ""
	remaining = 0

func advance(delta: float) -> void:
	remaining = maxf(0, remaining-delta)
	if remaining == 0: message = ""

func events(items: Array, actor_id: int) -> void:
	for item: Dictionary in items:
		# JSON numbers arrive as floats; Array.has/in compares Variant types.
		if item.get("type") == "soccer-goal" and (item.get("team") == 0 or item.get("team") == 1):
			message = "%s GOAL · Ball reset to centre" % ("Red" if item.team == 0 else "Blue")
			remaining = 5
		elif item.get("type") == "race-lap" and item.get("actor") == actor_id:
			message = "Lap %d complete" % int(item.get("lap", 0))
			remaining = 4

static func clock(value: Variant) -> String:
	if not (value is float or value is int) or not is_finite(float(value)): return "—:—"
	var seconds := maxi(0, floori(float(value)))
	return "%d:%02d" % [seconds/60, seconds%60]

static func results(state: Dictionary, actor_id: int, soccer: bool) -> String:
	var race: Dictionary = state.get("race", {})
	var reason: String = {"time":"Time limit reached", "race-finish":"Lap target reached", "score":"Goal limit reached"}.get(state.get("overReason", ""), "Round ended")
	var lines := PackedStringArray([reason + " · " + clock(race.get("elapsed"))])
	if soccer:
		var winner: Variant = race.get("winnerTeam")
		lines.append("Draw" if winner == null else ("Red wins" if winner == 0 else "Blue wins"))
		var scores: Dictionary = race.get("scores", {})
		lines.append("Red %s  —  %s Blue" % [integer(scores.get("0", scores.get(0))), integer(scores.get("1", scores.get(1)))])
	else:
		for row: Dictionary in race.get("standings", []):
			var finish: Variant = row.get("finishTime")
			var who := "You" if row.get("actorId") == actor_id else "Driver %s" % integer(row.get("actorId"))
			var laps := integer(row.get("completedLaps"))
			var completed := "%s %s completed" % [laps, "lap" if laps == "1" else "laps"]
			lines.append("#%s  %s · %s" % [integer(row.get("position")), who, "Finished " + clock(finish) if finish != null else completed])
			if lines.size() >= 9: break
	lines.append("F5  New round · Then Enter + fresh movement keys")
	return "\n".join(lines)

static func integer(value: Variant) -> String:
	if (value is float or value is int) and is_finite(float(value)): return str(maxi(0, int(value)))
	return "—"
