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

func clear() -> void:
	projection.clear()
	error = "Waiting for zone authority"

func apply(state: Dictionary, local_id: int, map_id: String, mode: String) -> bool:
	clear()
	if mode not in ["koth", "domination"] or state.get("mapId") != map_id:
		return false
	var config: Variant = state.get("config")
	var objective: Variant = state.get("objectives")
	if not config is Dictionary or config.get("mode") != mode or not objective is Dictionary or objective.get("kind") != mode:
		return false
	var zones: Variant = objective.get("zones")
	if not zones is Array or zones.size() != (1 if mode == "koth" else 3): return false
	if not state.get("actors") is Array or not state.get("teamScores") is Dictionary: return false
	if not number(state.get("time")) or not number(config.get("timeLimit")): return false
	if not state.get("over") is bool or not state.has("winner") or not nullable_team(state.winner): return false
	if not objective.has("winner") or not nullable_team(objective.winner): return false
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
		for field: String in ["owner", "captureTeam"]:
			if not zone.has(field) or not nullable_team(zone[field]): return false
		# Source's initial start may omit contested; snapshots after the first tick
		# always carry it. Missing state is unknown, never presented as uncontested.
		if not zone.get("contested") is bool: return false
		parsed.append(zone.duplicate(true))
	projection = {"mode":mode, "zones":parsed, "team":int(local.team), "scores":scores,
		"actor":local.duplicate(true), "time":float(state.time), "limit":float(config.timeLimit),
		"over":state.over, "winner":state.winner, "objective_winner":objective.winner}
	error = ""
	return true

static func allegiance(value: Variant, local_team: int) -> String:
	if value == null: return "NEUTRAL"
	return "FRIENDLY" if int(value) == local_team else "ENEMY"

func target() -> Dictionary:
	if projection.is_empty(): return {}
	var best: Dictionary = {}
	var distance := INF
	for zone: Dictionary in projection.zones:
		var candidate := Vector2(zone.x - projection.actor.x, zone.z - projection.actor.z).length()
		if candidate < distance:
			best = zone
			distance = candidate
	return best

func text() -> Dictionary:
	if projection.is_empty(): return {"title":error, "detail":"", "hint":""}
	var p := projection
	var title := "%s · YOU: TEAM %d · %.1f : %.1f · %.0fs remaining" % ["KING OF THE HILL" if p.mode == "koth" else "DOMINATION", p.team, p.scores[p.team], p.scores[1-p.team], maxf(0, p.limit-p.time)]
	if p.over: title = "RESULTS · " + ("DRAW" if p.winner == null else ("VICTORY" if int(p.winner) == p.team else "DEFEAT")) + " · %.1f : %.1f" % [p.scores[p.team], p.scores[1-p.team]]
	var lines: PackedStringArray = []
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
	var hint := "%s %s · %.0fm %s · radius %.1fm" % ["ACTIVE" if p.mode == "koth" else "NEAREST", zone.id.to_upper(), distance, direction, zone.radius]
	hint += " · INSIDE" if inside else " · enter ring"
	hint += "\nHold uncontested inside to capture / score. Release keys, then click to resume."
	return {"title":title, "detail":"\n".join(lines), "hint":hint, "progress":zone.progress}
