extends RefCounted
## Recipient presentation only. No command permission, capture credit or debit.

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func word(value: Variant) -> String:
	if not value is String: return ""
	return " ".join(value.replace("\n", " ").replace("\r", " ").replace("\t", " ").split(" ", false)).left(64).to_upper()

## cocs-orders.mjs cocsOrderNextAction refusal copy. Only presentation; a fresh
## activation still rechecks the normal transport and source gates.
static func recovery(reason: Variant) -> String:
	return str({"contested":"CLEAR THE NODE, THEN ISSUE AGAIN",
		"no-relay":"PICK A NODE NEXT TO GROUND YOU OWN",
		"flux":"EARN FLUX OR HOLD THE LINE", "out-of-flux":"EARN FLUX OR HOLD THE LINE",
		"slice":"WAIT FOR THE NEXT SLICE OR LET THE CHIEF SPEND",
		"executor":"TAKE THE COMMAND LEASE, THEN REISSUE",
		"thread":"FREE A THREAD OR PICK A NODE WITHIN REACH",
		"no-thread":"FREE A THREAD OR PICK A NODE WITHIN REACH",
		"dependency":"PICK A LEGAL ADJACENT NODE", "target":"PICK A LEGAL ADJACENT NODE",
		"no-response":"RETRY OR PICK A NODE NEXT TO GROUND YOU OWN"}.get(str(reason).to_lower(), "CHECK THE COMMAND BOARD FOR A LEGAL TARGET"))

## Mirrors hud.mjs cocsBoard: the largest published team progress, not an
## extrapolated timer. Range is explicitly planar; height/contest/adjacency and
## physical presence still belong to core's capture test.
static func objective(node: Dictionary, actor: Dictionary) -> Dictionary:
	var progress := "CAPTURE UNKNOWN"
	var values: Variant = node.get("progress")
	if values is Array and values.size() == 2 and number(values[0]) and number(values[1]):
		progress = "CAPTURE %d%%" % roundi(clampf(maxf(float(values[0]), float(values[1])), 0.0, 1.0) * 100.0)
	if node.get("contested") == true: progress = "CONTESTED · " + progress
	var distance := "RANGE UNKNOWN"
	if number(node.get("x")) and number(node.get("z")) and number(actor.get("x")) and number(actor.get("z")):
		var meters := Vector2(float(node.x), float(node.z)).distance_to(Vector2(float(actor.x), float(actor.z)))
		distance = "%.0f m planar" % meters
		if number(node.get("r")) and float(node.r) > 0.0:
			distance += " · radius %.0f m" % float(node.r)
	return {"progress":progress, "range":distance, "text":progress + " · " + distance}

## Most recent exact local card, including HOLD and recruitment. Never infer a
## successful effect from an ACK, wallet delta, nearby capture or another card.
static func receipt(actions: Array, revision: Variant = null) -> Dictionary:
	var latest: Dictionary = {}
	for raw: Variant in actions:
		if not raw is Dictionary: continue
		if revision != null and raw.get("roundRev") != revision: continue
		if raw.get("kind") not in ["buy", "hold", "fighter", "reinforce", "unsupported-fortify"]: continue
		latest = raw
	if latest.is_empty(): return {}
	var kind := word(latest.get("kind"))
	var target := word(latest.get("target"))
	var heading := kind + (" · " + target if not target.is_empty() else "")
	var status := str(latest.get("status", ""))
	var detail := "OUTCOME UNKNOWN"
	if status == "queued": detail = "QUEUED LOCALLY — NOT ACCEPTED"
	elif status.begins_with("pending"): detail = "ACCEPTED — AWAIT SETTLEMENT"
	elif status == "confirmed": detail = "SETTLED — CHECK REQ" if kind == "BUY" else "CARD SETTLED — EFFECT NOT PROVEN"
	elif status == "rejected":
		var reason := word(latest.get("reason"))
		detail = "REFUSED · " + (reason if not reason.is_empty() else "REASON UNKNOWN")
	return {"text":heading + " · " + detail, "status":status, "cardId":latest.get("cardId"), "reason":latest.get("reason"),
		"recovery":recovery(latest.get("reason")) if kind == "HOLD" else "CHECK CURRENT ELIGIBILITY IN THE COMMAND DECK"}
