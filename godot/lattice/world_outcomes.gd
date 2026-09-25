extends RefCounted
## Recipient-only result/round copy. No local timer, score or winner inference.
static func value(raw: Variant) -> String:
	if raw is int: return str(raw)
	if raw is float and is_finite(raw):
		return str(int(raw)) if floor(raw) == raw else "%.1f" % raw
	return raw if raw is String and not raw.is_empty() else "unknown"

static func progress(mode: String, source: Variant, dominance: Variant = null, recruitment: Variant = null) -> String:
	if mode == "cocs-coop":
		if not source is Dictionary: return "Operations waves/HQ unknown"
		var waves: Variant = source.get("waves")
		var hq: Variant = source.get("hq")
		var line := "Operations waves %s/%s · HQ %s/%s" % [value(waves.get("cleared") if waves is Dictionary else null), value(waves.get("total") if waves is Dictionary else null), value(hq.get("health") if hq is Dictionary else null), value(hq.get("max") if hq is Dictionary else null)]
		if recruitment is Dictionary: line += " · Director %s" % value(recruitment.get("phase"))
		return line
	if not dominance is Dictionary: return "PvP dominance unknown"
	var counts: Variant = dominance.get("counts")
	return "PvP nodes %s:%s · holder %s · %s/%s s (%s remaining) · majority %s / fast %s · flips to break %s%s" % [value(counts.get("0") if counts is Dictionary else null), value(counts.get("1") if counts is Dictionary else null), value(dominance.get("team")), value(dominance.get("progress")), value(dominance.get("target")), value(dominance.get("remaining")), value(dominance.get("count")), value(dominance.get("fastCount")), value(dominance.get("breakCount")), " · FAST" if dominance.get("fast") == true else ""]

static func live(projection: Dictionary) -> String:
	if projection.is_empty(): return "Awaiting fresh source progress"
	return progress(str(projection.get("mode", "")), projection.get("outcome"), projection.get("dominance"), projection.get("recruitment"))

static func final_result(result: Dictionary, host: bool) -> String:
	if result.is_empty(): return "Awaiting authoritative final result"
	var outcome: Variant = result.get("outcome")
	var winner: Variant = outcome.get("winner") if outcome is Dictionary else null
	var numeric_winner: bool = (winner is int or winner is float) and is_finite(float(winner)) and floor(float(winner)) == float(winner) and int(winner) in [0, 1]
	var winner_text := "draw" if outcome is Dictionary and outcome.has("winner") and winner == null else "team %s" % int(winner) if numeric_winner else "unknown"
	var reason: Variant = outcome.get("reason") if outcome is Dictionary else null
	var scores: Variant = result.get("scores")
	return "RESULT · winner %s · reason %s\nScore %s:%s · source time %s · round %s\n%s\n%s" % [winner_text, value(reason), value(scores.get("0") if scores is Dictionary else null), value(scores.get("1") if scores is Dictionary else null), value(result.get("source_time")), value(result.get("revision")), progress(str(result.get("mode", "")), result.get("mode_progress"), result.get("dominance")), "Host: Enter to request restart" if host else "Guest: waiting for host restart"]
