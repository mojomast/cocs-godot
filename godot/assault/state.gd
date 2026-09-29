extends RefCounted
## Read-only wire projection. No capture clocks, event mutation, or winner inference.
var objective: Dictionary = {}
var result_team: Variant = null
var over_reason := ""
var error := ""

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func team(value: Variant) -> bool:
	return value == null or (number(value) and value in [0, 1])

func clear_round() -> void:
	objective.clear()
	result_team = null
	over_reason = ""
	error = ""

func reject(message: String) -> bool:
	clear_round()
	error = message
	return false

func apply_state(state: Dictionary) -> bool:
	if not state.get("config") is Dictionary or state.config.get("mode") != "assault": return reject("Expected Assault state")
	var value: Variant = state.get("objectives")
	if not value is Dictionary or value.get("kind") != "assault": return reject("Missing Assault objectives")
	if not number(value.get("attacker")) or not number(value.get("defender")) or value.attacker != 0 or value.defender != 1: return reject("Invalid Assault teams")
	if not value.get("zones") is Array or value.zones.size() < 1 or value.zones.size() > 9: return reject("Invalid sector roster")
	if not number(value.get("active")) or float(value.active) != floorf(float(value.active)) or value.active < 0 or value.active > value.zones.size(): return reject("Invalid active sector")
	if not value.get("breached") is bool or not value.has("winner") or not team(value.winner): return reject("Invalid Assault outcome")
	var seen: Dictionary = {}
	for zone: Variant in value.zones:
		if not zone is Dictionary or not zone.get("id") is String or zone.id.is_empty() or zone.id.length() > 64 or seen.has(zone.id): return reject("Invalid sector identity")
		seen[zone.id] = true
		for key: String in ["x", "y", "z", "radius", "progress", "captureSeconds"]:
			if not number(zone.get(key)): return reject("Invalid sector geometry/progress")
		if zone.radius <= 0 or zone.radius > 1000 or zone.progress < 0 or zone.progress > 100 or zone.captureSeconds <= 0: return reject("Invalid sector range")
		for key: String in ["owner", "captureTeam"]:
			if not zone.has(key) or not team(zone[key]): return reject("Invalid sector team")
	# `contested` is not part of the required Assault wire schema.
	objective = value.duplicate(true)
	result_team = state.get("winner")
	over_reason = str(state.get("overReason", "")) if state.get("overReason") != null else ""
	error = ""
	return true

func active_sector() -> Dictionary:
	if objective.is_empty() or objective.active >= objective.zones.size(): return {}
	return objective.zones[int(objective.active)]

func text(local_team: Variant, complete: bool) -> String:
	if objective.is_empty(): return "ASSAULT · Waiting for authoritative objectives"
	var role := "ATTACK" if local_team == 0 else ("DEFEND" if local_team == 1 else "SPECTATOR")
	var heading := "ASSAULT · %s · Team 0 attacks / Team 1 defends" % role
	if complete:
		var result := "No winner reported" if result_team == null else ("Attackers win" if result_team == 0 else "Defenders win")
		return heading + "\nSOURCE RESULTS · " + result + (" · " + over_reason.to_upper() if not over_reason.is_empty() else "")
	var sector := active_sector()
	if sector.is_empty(): return heading + "\nAwaiting source results"
	return heading + "\nSector %d/%d · %s · %.1f%%\nAttack alone: %.1fs · Defend alone: full drain · Both: 0.6× drain · Empty: retains" % [int(objective.active)+1, objective.zones.size(), str(sector.id).to_upper(), float(sector.progress), float(sector.captureSeconds)]
