extends RefCounted
## Confirmed Node-source projection only. No rotation, counters or XP arithmetic.
const Results = preload("res://career/results_model.gd")

static func rows(raw: Variant, completed: bool = false) -> Array:
	if not raw is Array or raw.size() > 6: return []
	var out: Array = []
	var seen := {}
	for value: Variant in raw:
		if not value is Dictionary: return []
		var id := Results.text(value.get("id"), 80)
		var label := Results.text(value.get("label"), 180)
		var reward: Variant = Results.count(value.get("reward"))
		if id.is_empty() or label.is_empty() or reward == null or seen.has(id): return []
		seen[id] = true
		var row := {"id": id, "label": label, "reward": reward}
		if not completed:
			var progress: Variant = Results.count(value.get("progress"))
			var target: Variant = Results.count(value.get("target"))
			if progress == null or target == null or target <= 0 or progress > target or not value.get("done") is bool: return []
			row.merge({"progress": progress, "target": target, "done": value.done})
		out.append(row)
	return out

static func project(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.get("version") != 1: return {}
	var daily := rows(raw.get("daily"))
	var weekly := rows(raw.get("weekly"))
	if daily.size() != 3 or weekly.size() != 3: return {}
	return {"daily": daily, "weekly": weekly}

static func award(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.get("version") != 1: return {}
	var gained: Variant = Results.count(raw.get("gained"))
	if gained == null or not raw.get("completed") is Array: return {}
	var completed := rows(raw.completed, true)
	if completed.size() != raw.completed.size(): return {}
	return {"gained": gained, "completed": completed}
