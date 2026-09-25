extends RefCounted
## Pure advisory selector. It consumes only the recipient projection, topology
## model and local pose; it never schedules or authorizes an order.
const Guidance = preload("res://lattice/world_guidance.gd")

func team_id(value: Variant) -> int:
	if (value is int or value is float) and is_finite(float(value)) and float(value) in [0.0, 1.0]:
		return int(value)
	return -1

func select(projection: Dictionary, topology: Dictionary, pose: Dictionary,
		previous: Dictionary = {}, selected_id: String = "", yaw: float = 0.0) -> Dictionary:
	var result := {"target_id":"", "intent":"fallback", "reason_code":"unknown",
		"text":"No confirmed legal target; hold known ground or check the board.",
		"capture_legal":false, "supply":"UNKNOWN", "source_sequence":projection.get("source_sequence"),
		"context":projection.get("context", {})}
	if projection.is_empty(): return result
	var team: int = team_id(projection.get("team"))
	var entries: Array = topology.get("nodes", [])
	var candidates: Array = []
	for entry: Dictionary in entries:
		if entry.get("capture_legal") == true:
			candidates.append(entry)
	var dom_value: Variant = projection.get("dominance")
	var dom: Dictionary = dom_value if dom_value is Dictionary else {}
	var break_count: Variant = dom.get("breakCount")
	var dominance_team: int = team_id(dom.get("team"))
	var rank_enemy: bool = team >= 0 and dominance_team >= 0 and dominance_team != team
	var own_threat := false
	for entry: Dictionary in entries:
		if entry.get("mine") == true and entry.get("contested") == true: own_threat = true
	if candidates.is_empty() and not (team >= 0 and own_threat and dominance_team == team):
		result.reason_code = "dominance-prerequisite" if rank_enemy else "no-legal-frontier" if topology.get("complete") == true else "incomplete-topology"
		result.text = "Opponent dominance: no directly legal enemy target. Capture an adjacent legal prerequisite before ownership flips can break the clock." if rank_enemy else "No confirmed legal frontier; hold owned ground and approach a linked neighbor." if topology.get("complete") else "Topology or ownership incomplete; legal target unknown. Hold known ground."
		return result
	var chosen: Dictionary = {}
	var intent := "push"
	var code := "legal-frontier"
	if rank_enemy:
		intent = "break-dominance"; code = "enemy-dominance"
		for entry: Dictionary in candidates:
			if entry.get("enemy") == true and (chosen.is_empty() or _tie(entry, chosen, pose)): chosen = entry
		if chosen.is_empty():
			# A legal neutral node may be the prerequisite to reach the enemy.
			for entry: Dictionary in candidates:
				if entry.get("enemy") != true and (chosen.is_empty() or _tie(entry, chosen, pose)): chosen = entry
			if chosen.is_empty():
				result.merge({"intent":intent, "reason_code":"dominance-prerequisite", "text":"Opponent dominance: no directly legal enemy target. An adjacent legal frontier is required before a dominance break can be advised; flip count unknown unless published."}, true)
				return result
			intent = "push"; code = "dominance-prerequisite"
	if chosen.is_empty() and team >= 0 and own_threat and dominance_team == team:
		intent = "defend"; code = "own-contest"
		for entry: Dictionary in entries:
			if entry.get("mine") == true and entry.get("contested") == true and (chosen.is_empty() or _tie(entry, chosen, pose)): chosen = entry
	if chosen.is_empty():
		intent = "push"; code = "legal-frontier"
		for entry: Dictionary in candidates:
			if chosen.is_empty() or _tie(entry, chosen, pose): chosen = entry
	if chosen.is_empty(): return result
	if not selected_id.is_empty():
		for entry: Dictionary in entries:
			if entry.get("id") == selected_id and entry.get("capture_legal") == true and (code != "enemy-dominance" or entry.get("enemy") == true): chosen = entry; break
	var stable: Dictionary = {}
	for entry: Dictionary in entries:
		if entry.get("id") == previous.get("target_id") and ((intent == "defend" and entry.get("mine") and entry.get("contested")) or (intent != "defend" and entry.get("capture_legal") and (code != "enemy-dominance" or entry.get("enemy") == true))): stable = entry
	if not stable.is_empty() and selected_id.is_empty() and str(previous.get("intent")) == intent: chosen = stable
	var bearing := Guidance.bearing(pose, chosen, yaw) if not pose.is_empty() else "bearing unknown"
	var distance := Vector2(float(pose.get("x", 0)), float(pose.get("z", 0))).distance_to(Vector2(float(chosen.get("x", 0)), float(chosen.get("z", 0)))) if not pose.is_empty() else -1.0
	var has_break_count: bool = (break_count is int or break_count is float) and is_finite(float(break_count)) and float(break_count) >= 0.0 and floorf(float(break_count)) == float(break_count)
	var flips_text := "%d flip%s still needed." % [int(break_count), "s" if int(break_count) != 1 else ""] if has_break_count else "flip count unknown."
	var reason := "Break opponent dominance; %s" % flips_text if code == "enemy-dominance" else "Legal frontier prerequisite to opponent dominance; %s" % flips_text if code == "dominance-prerequisite" else "Defend a contested owned node." if code == "own-contest" else "Legal frontier; adjacency confirmed, supply %s." % str(chosen.get("supply", "UNKNOWN"))
	result.merge({"target_id":chosen.id, "intent":intent, "reason_code":code, "capture_legal":chosen.get("capture_legal", false), "supply":chosen.get("supply", "UNKNOWN"), "text":"%s · %s · %s%s" % [str(chosen.get("label", chosen.id)), bearing, reason, " · %.0f m planar" % distance if distance >= 0 else ""]}, true)
	return result

func _tie(a: Dictionary, b: Dictionary, pose: Dictionary) -> bool:
	var da := _distance(a, pose); var db := _distance(b, pose)
	return da < db or (is_equal_approx(da, db) and str(a.id) < str(b.id))

func _distance(entry: Dictionary, pose: Dictionary) -> float:
	if pose.is_empty(): return INF
	return Vector2(float(entry.get("x", 0)), float(entry.get("z", 0))).distance_to(Vector2(float(pose.get("x", 0)), float(pose.get("z", 0))))
