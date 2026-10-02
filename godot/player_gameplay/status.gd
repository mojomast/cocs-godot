extends RefCounted
## Read-only public snapshot projection. Timers are never predicted locally.
var catalog: Dictionary = {}

func _init() -> void:
	var file := FileAccess.open("res://player_gameplay/catalog.json", FileAccess.READ)
	if file != null: catalog = JSON.parse_string(file.get_as_text())

static func number(value: Variant) -> float:
	return maxf(0.0, float(value)) if (value is float or value is int) and is_finite(float(value)) else 0.0

func project(actor: Dictionary, config: Dictionary = {}, allowed: bool = true) -> Dictionary:
	if not allowed or actor.is_empty() or number(actor.get("health")) <= 0.0 or number(actor.get("dead")) > 0.0: return {}
	var kit: Dictionary = catalog.get("operators", {}).get(actor.get("character", ""), {})
	if kit.is_empty(): return {}
	var power: Dictionary = catalog.get("harnesses", {}).get(actor.get("harness", ""), {})
	var movement: Dictionary = actor.get("movement") if actor.get("movement") is Dictionary else {}
	var verb: Dictionary = actor.get("verbState") if actor.get("verbState") is Dictionary else {}
	var mounted: bool = actor.get("vehicleId") != null
	var disabled: bool = config.get("mode") in ["race", "soccer", "puma-race", "puma-soccer", "instagib"] or config.get("instagib", false) == true or "instagib" in config.get("mutators", [])
	var reason := "IN VEHICLE" if mounted else ("MODE DISABLED" if disabled else ("CARRIER LOCK" if actor.get("carryingFlag", false) or actor.get("isVip", false) else ""))
	var cooldown := number(actor.get("cooldown"))
	var active := number(actor.get("active"))
	var power_state := reason if not reason.is_empty() else ("ACTIVE %.1fs" % active if active > 0.0 else ("COOLDOWN %.1fs" % cooldown if cooldown > 0.0 else "READY"))
	var move_state := "UNAVAILABLE"
	if not mounted and movement.get("enabled", false):
		move_state = str(movement.get("phase", "idle")).to_upper()
		if number(movement.get("cooldown")) > 0.0: move_state = "COOLDOWN %.1fs" % number(movement.cooldown)
		if number(movement.get("maxFuel")) > 0.0: move_state += " · FUEL %d%%" % roundi(100.0 * number(movement.get("fuel")) / number(movement.maxFuel))
		if number(movement.get("maxCharges")) > 0.0: move_state += " · %d/%d" % [number(movement.get("charges")), number(movement.maxCharges)]
		if number(movement.get("miss")) > 0.0: move_state += " · NO ANCHOR"
	var inputs := {"mobility":"X", "jump":"AIR + SPACE", "jump-hold":"HOLD SPACE", "crouch":"HOLD CTRL → SPACE", "crouch-jump":"CTRL + SPACE"}
	var passive := str(kit.passive.name)
	if verb.get("active") != true: passive += " · DISABLED"
	else:
		match str(verb.get("verb", "")):
			"heat": passive += " · +%d%% FIRE RATE" % roundi(number(verb.get("heat")) * 100.0)
			"deep-compute": passive += " · CHARGE %d%%" % roundi(number(verb.get("charge")) * 100.0)
			"alignment-review": passive += " · ABSORB %d · CHARGE %d%%" % [number(verb.get("pool")), roundi(number(verb.get("meter")) * 100.0)]
			"adaptive", "tool-use": passive += " · HANDLING %.1fs" % number(verb.get("windowIn"))
			"braced": passive += " · RECOVERY %.1fs" % number(verb.get("combatIn"))
			"long-context": passive += " · %d TRAILS" % (verb.get("trails", []) as Array).size()
	var statuses: Array[String] = []
	if number(actor.get("slow")) > 0.0: statuses.append("JAMMED %.1fs" % number(actor.slow))
	if actor.get("sliding", false): statuses.append("SLIDING")
	if actor.get("zipRide") != null: statuses.append("ROPE / ZIPLINE RIDE")
	if number(actor.get("riderSpeedTimer")) > 0.0: statuses.append("RIDER SPEED %.1fs" % number(actor.riderSpeedTimer))
	var grenade := number(actor.get("grenadeCooldown"))
	return {"power":{"name":power.get("name", "Power"), "state":power_state, "active":active, "cooldown":cooldown}, "mobility":{"name":kit.movement.name, "input":inputs.get(kit.movement.input, ""), "state":move_state}, "passive":passive, "passive_description":kit.passive.description, "statuses":statuses, "grenade":"G · FRAG READY" if grenade <= 0.0 else "G · FRAG %.1fs" % grenade}

static func text(model: Dictionary) -> String:
	if model.is_empty(): return ""
	return "Q · %s · %s\n%s · %s · %s\n%s\n%s%s" % [model.power.name, model.power.state, model.mobility.input, model.mobility.name, model.mobility.state, model.passive, model.grenade, " · " + " · ".join(model.statuses) if not model.statuses.is_empty() else ""]
