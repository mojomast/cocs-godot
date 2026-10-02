extends RefCounted
## Formats PlayerGameplay's model, never an actor snapshot or local timer.
const Text = preload("res://experience/caption_model.gd")

static func lines(model: Dictionary) -> PackedStringArray:
	if model.is_empty(): return PackedStringArray()
	var power: Dictionary = model.get("power", {})
	var mobility: Dictionary = model.get("mobility", {})
	var power_state := Text.clean(power.get("state"))
	var cooldown: Variant = power.get("cooldown")
	if power_state.begins_with("ACTIVE ") and (cooldown is int or cooldown is float) and is_finite(float(cooldown)) and float(cooldown) > 0:
		power_state += " · cooldown %.1fs" % float(cooldown)
	var result := PackedStringArray([
		"Q · %s · %s" % [Text.clean(power.get("name")), power_state],
		"%s · %s · %s" % [Text.clean(mobility.get("input")), Text.clean(mobility.get("name")), Text.clean(mobility.get("state"))],
		Text.clean(model.get("passive")),
		Text.clean(model.get("passive_description"), 1200),
		Text.clean(model.get("grenade"))])
	var statuses: Variant = model.get("statuses", [])
	if statuses is Array:
		for status: Variant in statuses:
			var line := Text.clean(status)
			if not line.is_empty(): result.append(line)
	return result

static func text(model: Dictionary) -> String:
	return "\n".join(lines(model))
