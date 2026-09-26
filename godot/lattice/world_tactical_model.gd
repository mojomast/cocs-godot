extends RefCounted
## Compact, recipient-only copy for the in-world instrument panel. This is
## display data: no local wave clock, guessed enemies, purchase debit or orders.

static func known(value: Variant) -> String:
	if value is int: return str(value)
	if value is float and is_finite(value):
		return str(int(value)) if floorf(value) == value else "%.1f" % value
	return "—"

static func safe(value: Variant, fallback: String = "UNKNOWN") -> String:
	return str(value).left(64).to_upper() if value is String and not value.is_empty() else fallback

static func projection(projection: Dictionary, target: Dictionary, topology: Dictionary, actor: Dictionary) -> Dictionary:
	if projection.is_empty(): return {}
	var req := known(projection.get("req"))
	var flux := known(projection.get("flux"))
	var result := {"mode":"OPERATIONS" if projection.get("coop") == true else "LATTICE / PVP",
		"goal":"HOLD KNOWN GROUND", "direction":"No confirmed legal objective · open the deck for details",
		"objective":"TARGET UNKNOWN", "req":req, "flux":flux, "health":known(actor.get("health")),
		"progress":"AWAITING SOURCE PROGRESS", "detail":"No source progress published", "intel":""}
	var target_id: Variant = target.get("target_id")
	var fact: Variant = topology.get("by_id", {}).get(target_id) if target_id is String else null
	if fact is Dictionary and not fact.is_empty():
		result.goal = safe(fact.get("label", target_id), "OBJECTIVE")
		result.objective = "%s  ·  %s" % ["CAPTURE LEGAL" if fact.get("capture_legal") == true else "HOLD / CHECK LINK", safe(fact.get("supply"), "SUPPLY UNKNOWN")]
		var x: Variant = actor.get("x")
		var z: Variant = actor.get("z")
		if (x is int or x is float) and (z is int or z is float) and is_finite(float(x)) and is_finite(float(z)):
			result.goal += "  ·  %.0f m" % Vector2(float(x), float(z)).distance_to(Vector2(float(fact.get("x", x)), float(fact.get("z", z))))
	result.direction = str(target.get("text", result.direction)).left(225)
	if projection.get("coop") == true:
		var recruitment: Variant = projection.get("recruitment")
		var outcome: Variant = projection.get("outcome")
		var wave: Variant = recruitment.get("wave") if recruitment is Dictionary else null
		var waves: Variant = outcome.get("waves") if outcome is Dictionary else null
		var hq: Variant = outcome.get("hq") if outcome is Dictionary else null
		result.progress = "WAVE %s / %s  ·  %s" % [known(wave), known(waves.get("total") if waves is Dictionary else null), safe(recruitment.get("phase") if recruitment is Dictionary else null, "PHASE UNKNOWN")]
		var threat: Variant = projection.get("threat")
		var threat_text := " · FORCE %s / %s" % [known(threat.get("alive") if threat is Dictionary else null), known(threat.get("total") if threat is Dictionary else null)]
		result.detail = "CLEARED %s  ·  HQ %s / %s%s" % [known(waves.get("cleared") if waves is Dictionary else null), known(hq.get("health") if hq is Dictionary else null), known(hq.get("max") if hq is Dictionary else null), threat_text]
		if threat is Dictionary and threat.get("wave_label") is String: result.intel = safe(threat.wave_label)
	else:
		var dom: Variant = projection.get("dominance")
		if dom is Dictionary:
			result.progress = "DOMINANCE  ·  %s / %s s" % [known(dom.get("progress")), known(dom.get("target"))]
			result.detail = "HOLDER %s  ·  %s FLIPS TO BREAK" % [known(dom.get("team")), known(dom.get("breakCount"))]
		var contacts: Variant = projection.get("recon_contacts")
		if contacts is Array and not contacts.is_empty():
			result.intel = "TEAM RECON  ·  %d REVEALED ENEMY CONTACTS" % contacts.size()
	return result

static func buy_receipt(actions: Array) -> String:
	var latest: Dictionary = {}
	for action: Variant in actions:
		if action is Dictionary and action.get("kind") == "buy": latest = action
	if latest.is_empty(): return ""
	var status := str(latest.get("status", ""))
	var name := safe(latest.get("target", latest.get("item", "REQ ITEM")), "REQ ITEM")
	if status == "queued": return "%s  ·  QUEUED LOCALLY — NOT ACCEPTED" % name
	if status.begins_with("pending"): return "%s  ·  ACCEPTED BY SERVER — AWAIT SETTLEMENT" % name
	if status == "confirmed": return "%s  ·  SETTLED BY SERVER — CHECK REQ" % name
	if status == "rejected": return "%s  ·  REFUSED BY SERVER (%s)" % [name, safe(latest.get("reason"), "REASON UNKNOWN")]
	return ""
