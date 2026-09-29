extends RefCounted
## Read-only projection of the full source zone snapshot. No local objective clock.
var projection: Dictionary = {}
var error := "Waiting for zone authority"

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func team(value: Variant) -> bool:
	return number(value) and float(value) in [0.0, 1.0]

static func nullable_team(value: Variant) -> bool:
	return value == null or team(value)

static func count(value: Variant, maximum: int) -> bool:
	return number(value) and float(value) == floorf(float(value)) and value >= 0 and value <= maximum

static func pair(value: Variant, maximum: float) -> bool:
	if not value is Dictionary: return false
	for id: String in ["0", "1"]:
		var n: Variant = value.get(id, value.get(int(id)))
		if not number(n) or n < 0 or n > maximum: return false
	return true

func clear() -> void:
	projection.clear()
	error = "Waiting for zone authority"

func apply(state: Dictionary, local_id: int, map_id: String, mode: String) -> bool:
	clear()
	if mode not in ["koth", "domination", "uplink", "holdout"] or state.get("mapId") != map_id:
		return false
	var config: Variant = state.get("config")
	var objective: Variant = state.get("objectives")
	var kind := "koth" if mode == "uplink" else ("domination" if mode == "holdout" else mode)
	if not config is Dictionary or config.get("mode") != mode or not objective is Dictionary or objective.get("kind") != kind:
		return false
	var zones: Variant = objective.get("zones")
	if not zones is Array or zones.size() != (1 if kind == "koth" else 3): return false
	if not state.get("actors") is Array or not state.get("teamScores") is Dictionary: return false
	if not number(state.get("time")) or not number(config.get("timeLimit")): return false
	if not state.get("over") is bool or not state.has("winner") or not nullable_team(state.winner): return false
	if not objective.has("winner") or not nullable_team(objective.winner): return false
	var variant: Dictionary = {}
	if mode == "uplink":
		if not count(objective.get("stage"), 3) or objective.get("stageCount") != 3 or not pair(objective.get("stageCaptures"), 3): return false
		var captures: Dictionary = objective.stageCaptures
		if not count(captures.get("0", captures.get(0)), 3) or not count(captures.get("1", captures.get(1)), 3): return false
		if int(captures.get("0", captures.get(0))) + int(captures.get("1", captures.get(1))) != int(objective.stage): return false
		if not zones[0] is Dictionary: return false
		var expected_id := "hill" if int(objective.stage) == 0 else "uplink-%d" % mini(3, int(objective.stage) + 1)
		if zones[0].get("id") != expected_id: return false
		variant = {"stage":int(objective.stage), "stage_count":3, "captures":[int(captures.get("0", captures.get(0))), int(captures.get("1", captures.get(1)))]}
	elif mode == "holdout":
		if objective.get("holdCount") != 2 or not number(objective.get("holdSeconds")) or objective.holdSeconds != 30 or not pair(objective.get("holdProgress"), 30): return false
		if not objective.has("holdTeam") or not nullable_team(objective.holdTeam): return false
		if objective.holdTeam != null and (not state.over or objective.winner != objective.holdTeam): return false
		var progress: Dictionary = objective.holdProgress
		variant = {"hold_count":2, "hold_seconds":30.0, "hold_progress":[float(progress.get("0", progress.get(0))), float(progress.get("1", progress.get(1)))], "hold_team":objective.holdTeam}
	var local: Dictionary = {}
	for actor: Variant in state.actors:
		if actor is Dictionary and number(actor.get("id")) and actor.id == local_id: local = actor
	if local.is_empty() or not team(local.get("team")): return false
	for field: String in ["x", "y", "z", "health"]:
		if not number(local.get(field)): return false
	var scores: Array = []
	for id: String in ["0", "1"]:
		var score: Variant = state.teamScores.get(id, state.teamScores.get(int(id)))
		if not number(score): return false
		scores.append(float(score))
	var parsed: Array[Dictionary] = []
	var seen: Dictionary = {}
	for zone: Variant in zones:
		if not zone is Dictionary or not zone.get("id") is String or zone.id.is_empty() or seen.has(zone.id): return false
		seen[zone.id] = true
		for field: String in ["x", "y", "z", "radius", "progress", "captureSeconds"]:
			if not number(zone.get(field)): return false
		if zone.radius <= 0 or zone.progress < 0 or zone.progress > 100 or zone.captureSeconds <= 0: return false
		if mode == "uplink" and zone.captureSeconds != 4: return false
		for field: String in ["owner", "captureTeam"]:
			if not zone.has(field) or not nullable_team(zone[field]): return false
		# Source's initial start may omit contested; snapshots after the first tick
		# always carry it. Missing state is unknown, never presented as uncontested.
		if not zone.get("contested") is bool: return false
		parsed.append(zone.duplicate(true))
	projection = {"mode":mode, "zones":parsed, "team":int(local.team), "scores":scores,
		"actor":local.duplicate(true), "time":float(state.time), "limit":float(config.timeLimit),
		"over":state.over, "winner":objective.winner if objective.winner != null else state.winner, "objective_winner":objective.winner}
	projection.merge(variant)
	error = ""
	return true

static func allegiance(value: Variant, local_team: int) -> String:
	if value == null: return "NEUTRAL"
	return "FRIENDLY" if int(value) == local_team else "ENEMY"

func target() -> Dictionary:
	if projection.is_empty(): return {}
	var best: Dictionary = {}
	var distance := INF
	var owned := 0
	if projection.mode == "holdout":
		for zone: Dictionary in projection.zones:
			if zone.owner == projection.team: owned += 1
	for zone: Dictionary in projection.zones:
		if projection.mode == "holdout" and owned < projection.hold_count and zone.owner == projection.team: continue
		var candidate := Vector2(zone.x - projection.actor.x, zone.z - projection.actor.z).length()
		if candidate < distance:
			best = zone
			distance = candidate
	return best

func text() -> Dictionary:
	if projection.is_empty(): return {"title":error, "detail":"", "hint":""}
	var p := projection
	var names := {"koth":"KING OF THE HILL", "domination":"DOMINATION", "uplink":"UPLINK", "holdout":"HOLDOUT"}
	var title := "%s · YOU: TEAM %d · %.1f : %.1f · %.0fs remaining" % [names[p.mode], p.team, p.scores[p.team], p.scores[1-p.team], maxf(0, p.limit-p.time)]
	if p.over: title = "RESULTS · " + ("DRAW" if p.winner == null else ("VICTORY" if int(p.winner) == p.team else "DEFEAT")) + " · %.1f : %.1f" % [p.scores[p.team], p.scores[1-p.team]]
	var lines: PackedStringArray = []
	if p.mode == "uplink":
		lines.append("RELAY %d / %d · COMPLETED %d · BANKED %d : %d" % [mini(p.stage + 1, p.stage_count), p.stage_count, p.stage, p.captures[p.team], p.captures[1-p.team]])
	elif p.mode == "holdout":
		var friendly := 0
		var enemy := 0
		for entry: Dictionary in p.zones:
			if entry.owner == p.team: friendly += 1
			elif entry.owner == 1-p.team: enemy += 1
		lines.append("QUORUM %d/%d · OWN %d:%d · CONTINUOUS %.1f/%.0fs (ENEMY %.1fs)" % [p.hold_count, p.zones.size(), friendly, enemy, p.hold_progress[p.team], p.hold_seconds, p.hold_progress[1-p.team]])
	for zone: Dictionary in p.zones:
		var status := "CONTESTED" if zone.contested else allegiance(zone.owner, p.team)
		var capture := " · %s capturing" % allegiance(zone.captureTeam, p.team) if zone.captureTeam != null else ""
		lines.append("%s  %s  %.0f%%%s" % [zone.id.to_upper(), status, zone.progress, capture])
	var zone := target()
	var dx: float = zone.x-p.actor.x
	var dz: float = zone.z-p.actor.z
	var distance := Vector2(dx,dz).length()
	var inside: bool = distance <= zone.radius and absf(p.actor.y-zone.y) <= 5 and p.actor.health > 0
	var direction := ("N" if dz < -1 else ("S" if dz > 1 else "")) + ("E" if dx > 1 else ("W" if dx < -1 else ""))
	var hint := "%s %s · %.0fm %s · radius %.1fm" % ["ACTIVE" if p.mode in ["koth", "uplink"] else ("CAPTURE" if p.mode == "holdout" and zone.owner != p.team else "NEAREST"), zone.id.to_upper(), distance, direction, zone.radius]
	hint += " · INSIDE" if inside else " · enter ring"
	if p.mode == "uplink": hint += "\nCapture this relay to bank a stage; 3 total captures finish."
	elif p.mode == "holdout": hint += "\nOwn 2 zones continuously for 30s; losing quorum resets the timer."
	else: hint += "\nHold uncontested inside to capture / score. Release keys, then click to resume."
	return {"title":title, "detail":"\n".join(lines), "hint":hint, "progress":100.0 * p.hold_progress[p.team] / p.hold_seconds if p.mode == "holdout" else zone.progress}
