extends RefCounted
## Read-only source snapshot projection. No local timers, tickets or winner rules.
const NAMES := {"arsenal":"FULL ARSENAL", "juggernaut":"JUGGERNAUT", "team-elimination":"TEAM ELIMINATION", "vip-escort":"VIP ESCORT"}
var text := ""
var markers: Array[Dictionary] = []

func apply(state: Dictionary, local_id: int) -> void:
	markers.clear()
	var mode: String = str(state.get("config", {}).get("mode", ""))
	var objective: Dictionary = state.get("objectives") if state.get("objectives") is Dictionary else {}
	var actors: Array = state.get("actors", [])
	var me: Dictionary = actor(actors, local_id)
	text = str(NAMES.get(mode, mode))
	match mode:
		"arsenal":
			text += " · All ten weapons · Unlimited ammo\n1–9 / 0 or wheel: switch · First to %s frags" % str(state.get("config", {}).get("fragLimit", 15))
		"juggernaut":
			var carrier := actor(actors, int(objective.get("juggernautId", -1)))
			var points: Dictionary = objective.get("points", {})
			text += " · Crown: %s · Your points %.1f\nHold to score; kill the carrier to take the crown." % [str(carrier.get("name", "Unassigned")), float(points.get(str(local_id), 0))]
			if not carrier.is_empty():
				text += " Shield %d" % int(carrier.get("juggernautShield", 0))
				markers.append({"id":"crown", "x":carrier.x, "y":float(carrier.y) + 3.0, "z":carrier.z, "label":"CROWN · %.1f" % float(points.get(str(carrier.id), 0)), "color":Color("ffd36c")})
		"team-elimination":
			var lives: Dictionary = objective.get("lives", {})
			text += " · Red %s / Blue %s lives\nEvery death spends a team ticket · Respawn in 3 seconds · Preserve your lives." % [str(lives.get("0", 0)), str(lives.get("1", 0))]
			if bool(objective.get("suddenDeath", false)): text += " SUDDEN DEATH"
		"vip-escort":
			var vip := actor(actors, int(objective.get("vipId", -1)))
			var escort: bool = me.get("team", -1) == objective.get("escortTeam", 0)
			text += " · %s · VIP health %d\n%s · Extraction %.1f / %.1fs" % ["ESCORT" if escort else "HUNTER", int(vip.get("health", 0)), "Stay within %sm to move the VIP" % str(objective.get("escortRadius", 7)) if escort else "Eliminate the VIP or deny extraction until time expires", float(objective.get("progress", 0)), float(objective.get("captureSeconds", 4))]
			if not vip.is_empty() and not bool(objective.get("vipDead", false)):
				markers.append({"id":"vip", "x":vip.x, "y":float(vip.y) + 3.0, "z":vip.z, "label":"VIP · %d HP" % int(vip.health), "color":Color("ffd36c")})
			var extract: Dictionary = objective.get("extract", {})
			if not extract.is_empty(): markers.append({"id":"extract", "x":extract.x, "y":float(extract.get("y", 0)) + 1.0, "z":extract.z, "label":"EXTRACTION · %.1fs" % float(objective.get("progress", 0)), "color":Color("62deca")})
	if bool(state.get("over", false)):
		text += "\nROUND COMPLETE · " + result_text(state)

static func actor(actors: Array, id: int) -> Dictionary:
	for item: Dictionary in actors:
		if int(item.get("id", -2)) == id: return item
	return {}

static func result_text(state: Dictionary) -> String:
	# Actor zero and team zero are valid winners; never test truthiness.
	var winner: Variant = state.get("winner")
	if winner == null: return "Draw / no winner"
	var mode: String = str(state.get("config", {}).get("mode", ""))
	if mode in ["team-elimination", "vip-escort"]:
		return ("Red" if int(winner) == 0 else "Blue") + " team wins"
	return str(actor(state.get("actors", []), int(winner)).get("name", "Operator %s" % str(winner))) + " wins"
