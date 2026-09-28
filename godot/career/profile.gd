extends RefCounted
## A display projection, never a profile store. Reject malformed replies rather
## than rendering fabricated zeroes or copying ownerToken into UI state.
const FIELDS := ["xp", "level", "prestige", "matches", "wins", "kills", "deaths", "bestKills"]

static func project(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not raw.get("id") is String or raw.id.is_empty(): return {}
	var result := {"id": raw.id, "gear": {}, "attachments": {}, "unlocks": {}, "byMode": {}}
	for field: String in FIELDS:
		var value: Variant = raw.get(field)
		if (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and floorf(float(value)) == float(value):
			result[field] = int(value)
	for key: String in ["gear", "attachments"]:
		if raw.get(key) is Dictionary:
			for slot: Variant in raw[key]:
				if slot is String and raw[key][slot] is String: result[key][slot] = raw[key][slot]
	if raw.get("unlocks") is Dictionary:
		for key: Variant in raw.unlocks:
			if key is String and raw.unlocks[key] == true: result.unlocks[key] = true
	if raw.get("byMode") is Dictionary:
		for mode: Variant in raw.byMode:
			if mode is String and raw.byMode[mode] is Dictionary:
				var stats := {}
				for key: String in ["matches", "wins", "kills"]:
					var value: Variant = raw.byMode[mode].get(key)
					if (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and floorf(float(value)) == float(value): stats[key] = int(value)
				result.byMode[mode] = stats
	for key: String in ["finish", "crosshair"]:
		if raw.get(key) is String: result[key] = raw[key]
	return result

static func item_state(profile: Dictionary, item: Dictionary) -> String:
	if profile.is_empty() or not profile.get("level") is int: return "NOT LOADED"
	var unlocked := int(profile.level) >= int(item.get("level", 999)) or profile.get("unlocks", {}).get(item.get("unlockId", "")) == true
	if not unlocked: return "LOCKED · LV %d" % int(item.get("level", 999))
	var id: String = str(item.get("id", ""))
	match str(item.get("kind", "")):
		"gear", "attachment":
			var equipped: Variant = profile.get("gear" if item.kind == "gear" else "attachments", {}).get(item.get("slot", ""))
			if equipped == id: return "EQUIPPED"
		"finish", "crosshair":
			if profile.get(item.kind) == id: return "EQUIPPED"
	return "UNLOCKED"
