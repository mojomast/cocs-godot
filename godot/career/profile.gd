extends RefCounted
## A display projection, never a profile store. Reject malformed replies rather
## than rendering fabricated zeroes or copying ownerToken into UI state.
const FIELDS := ["xp", "level", "prestige", "matches", "wins", "kills", "deaths", "bestKills"]

static func project(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not raw.get("id") is String or raw.id.length() < 8 or raw.id.length() > 64: return {}
	for code: int in raw.id.to_ascii_buffer():
		if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code == 45): return {}
	var result := {"id": raw.id}
	for field: String in FIELDS:
		var value: Variant = raw.get(field)
		if (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and floorf(float(value)) == float(value):
			result[field] = int(value)
	for key: String in ["gear", "attachments"]:
		if raw.get(key) is Dictionary:
			result[key] = {}
			for slot: Variant in raw[key]:
				if slot is String and slot.length() < 32 and raw[key][slot] is String and raw[key][slot].length() < 64: result[key][slot] = raw[key][slot]
	if raw.get("unlocks") is Dictionary and raw.unlocks.size() <= 128:
		result.unlocks = {}
		for key: Variant in raw.unlocks:
			if key is String and key.length() < 128 and raw.unlocks[key] is bool:
				if raw.unlocks[key]: result.unlocks[key] = true
			else:
				result.erase("unlocks")
				break
	if raw.get("byMode") is Dictionary and raw.byMode.size() <= 32:
		result.byMode = {}
		for mode: Variant in raw.byMode:
			if mode is String and mode.length() <= 48 and mode.replace("-", "_").is_valid_identifier() and raw.byMode[mode] is Dictionary:
				var stats := {}
				for key: String in ["matches", "wins", "kills"]:
					var value: Variant = raw.byMode[mode].get(key)
					if (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and floorf(float(value)) == float(value): stats[key] = int(value)
				result.byMode[mode] = stats
	for key: String in ["finish", "crosshair"]:
		if raw.get(key) is String and raw[key].length() < 64: result[key] = raw[key]
	return result

static func item_state(profile: Dictionary, item: Dictionary) -> String:
	if profile.is_empty(): return "NOT LOADED"
	var granted := profile.get("unlocks", {}).get(item.get("unlockId", "")) == true
	var level_known := profile.get("level") is int
	if not granted and not level_known: return "NOT LOADED"
	var unlocked := granted or (level_known and int(profile.level) >= int(item.get("level", 999)))
	if not unlocked and not profile.has("unlocks"): return "NOT LOADED"
	if not unlocked: return "LOCKED · LV %d" % int(item.get("level", 999))
	var id: String = str(item.get("id", ""))
	match str(item.get("kind", "")):
		"gear", "attachment":
			var equipped: Variant = profile.get("gear" if item.kind == "gear" else "attachments", {}).get(item.get("slot", ""))
			if equipped == id: return "EQUIPPED"
		"finish", "crosshair":
			if profile.get(item.kind) == id: return "EQUIPPED"
	return "UNLOCKED"
