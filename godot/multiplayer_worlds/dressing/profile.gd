extends RefCounted
## Closed schema: invalid author input is never silently repaired.
const Language = preload("res://material_language/library.gd")
const Moth = preload("res://moth/library.gd")
const IDENTITIES := {
	"helix-conservatory": "f068d1abe262907659f1f02205e2bf56b7c5dbe298191f66d008b420965fa9b2",
	"gravemill-foundry": "8ebb148f209aca14c54246517f7332a18e5fbb5c68f7b607d980f5664fcde25f",
	"parallax-observatory": "906be2ae3df33f54f779df3963a5985376ac96bb75bda94578ca4d3deb6d4554",
	"vesper-viaduct": "27c71cc8895eab2ca3a0b5cae3c2b8f96ed9afd75db3deec4a5c96bd2f395ea7",
	"abyssal-pressureworks": "32366a6c3df7f95f8d89281c5f83b24d9583cefeb4c0099790303d15349b53be",
	"stormglass-causeway": "6afb8a36ee954ff9457a5522a7412c809191fb070eb7fe9eda4d379753acce48",
}
const WEAR_BOUNDS := {
	"macro_tiles_per_metre": [0.01, 0.25], "macro_strength": [0.0, 0.5],
	"wear_strength": [0.0, 0.65], "wear_height_min": [-100.0, 100.0],
	"wear_height_max": [-100.0, 100.0], "wear_roughness": [0.0, 1.0],
}
const VARIATION_BOUNDS := {
	"variation_strength": [0.0, 1.0], "variation_scale": [0.01, 1.0],
}
const VARIATION_MODES := ["none", "organic", "manufactured"]
const CAPS := {"material_variants": 32, "panels": 96, "signs": 24, "motes": 96}

static func validate(value: Variant, map_id: String, geometry_hash: String) -> Array[String]:
	var errors: Array[String] = []
	if not value is Dictionary: return ["profile must be an object"]
	var p: Dictionary = value
	_closed(p, ["version", "map_id", "geometry_hash", "materials", "panels", "signs", "pockets", "preserve_materials", "budgets"], "profile", errors)
	if p.get("version") != 1: errors.append("version must be 1")
	if not IDENTITIES.has(map_id) or geometry_hash != IDENTITIES.get(map_id): errors.append("unaccepted geometry identity")
	if p.get("map_id") != map_id or p.get("geometry_hash") != geometry_hash: errors.append("profile identity mismatch")
	var budgets: Variant = p.get("budgets")
	if not budgets is Dictionary:
		errors.append("budgets must be an object")
		budgets = {}
	_closed(budgets, CAPS.keys(), "budgets", errors)
	var safe_budgets := {}
	for key: String in CAPS:
		if not _integer(budgets.get(key), 0, CAPS[key]): errors.append("invalid budget " + key)
		safe_budgets[key] = int(budgets[key]) if _integer(budgets.get(key), 0, CAPS[key]) else 0
	budgets = safe_budgets
	var ids := {}
	var selectors := {}
	var total_motes := 0
	for group: String in ["materials", "panels", "signs", "pockets", "preserve_materials"]:
		if not p.get(group) is Array:
			errors.append(group + " must be an array")
			continue
		var entries: Array = p[group]
		var cap := 32 if group in ["materials", "preserve_materials"] else (12 if group == "pockets" else int(CAPS[group]))
		if entries.size() > cap: errors.append(group + " exceeds hard cap")
		if group in ["materials", "panels", "signs"] and entries.size() > int(budgets.get("material_variants" if group == "materials" else group, 0)): errors.append(group + " exceeds profile budget")
		for entry: Variant in entries:
			if group == "preserve_materials":
				if not _text(entry, 128) or selectors.has(entry): errors.append("invalid/duplicate preserved selector")
				if entry is String: selectors[entry] = true
				continue
			if not entry is Dictionary:
				errors.append(group + " entry must be object")
				continue
			var e: Dictionary = entry
			if group == "materials":
				_closed(e, ["source", "family", "options"], group, errors)
				if not _text(e.get("source"), 128) or selectors.has(e.get("source")): errors.append("invalid/duplicate material selector")
				selectors[str(e.get("source", ""))] = true
				var family: String = str(e.get("family", ""))
				if not Language.has_family(family): errors.append("unknown family " + family)
				_options(e.get("options", {}), family, errors)
				continue
			var keys := ["id", "position", "size"]
			if group != "pockets": keys.append("rotation_degrees")
			keys.append_array(["texture", "tint", "essential", "normal", "wear_mask", "opacity", "feather", "seed"] if group == "panels" else (["text", "foreground", "background", "essential"] if group == "signs" else ["kind", "color", "count"]))
			_closed(e, keys, group, errors)
			if not _text(e.get("id"), 80) or ids.has(e.get("id")): errors.append("invalid/duplicate placement id")
			ids[str(e.get("id", ""))] = true
			if not _vector(e.get("position"), 3, -512, 512): errors.append("invalid position")
			if group != "pockets" and not _vector(e.get("rotation_degrees"), 3, -360, 360): errors.append("invalid rotation")
			if not _vector(e.get("size"), 3 if group == "pockets" else 2, 0.05, 8 if group == "pockets" else 16): errors.append("invalid size")
			if group != "pockets" and not e.get("essential", false) is bool: errors.append("essential must be boolean")
			if group == "panels":
				if not Moth.manifest().get("textures", {}).has(e.get("texture")): errors.append("unknown panel texture")
				if not _color(e.get("tint")): errors.append("invalid panel tint")
				if e.has("normal") and not _normal_key(e.normal): errors.append("unknown panel normal")
				if e.has("wear_mask"):
					if not Moth.manifest().get("textures", {}).has(e.wear_mask): errors.append("unknown wear mask")
					if not _number(e.get("opacity", 1.0), 0, 1) or not _number(e.get("feather", 0.15), 0, 0.5) or not _integer(e.get("seed", 0), 0, 2147483647): errors.append("invalid wear controls")
				elif e.has("opacity") or e.has("feather") or e.has("seed"): errors.append("wear controls require wear_mask")
			elif group == "signs":
				if not _text(e.get("text"), 96): errors.append("invalid sign text")
				if not _color(e.get("foreground")) or not _color(e.get("background")): errors.append("invalid sign colors")
				elif _contrast(Color(e.foreground), Color(e.background)) < 4.5: errors.append("sign contrast below 4.5:1")
			else:
				if not e.get("kind") in ["dust", "pollen", "ash", "mist", "vent"]: errors.append("unknown pocket kind")
				if not _color(e.get("color")): errors.append("invalid pocket color")
				if not _integer(e.get("count"), 1, 32): errors.append("invalid pocket count")
				else: total_motes += int(e.count)
	if total_motes > int(budgets.get("motes", 0)): errors.append("motes exceed budget")
	return errors

static func _options(value: Variant, family: String, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("options must be object")
		return
	_closed(value, Language.BOUNDS.keys() + WEAR_BOUNDS.keys() + VARIATION_BOUNDS.keys() + ["tint", "variant", "glow", "wear_tint", "variation_mode", "variation_seed"], "options", errors)
	for key: String in value:
		if Language.BOUNDS.has(key) or WEAR_BOUNDS.has(key) or VARIATION_BOUNDS.has(key):
			var bounds: Array = Language.BOUNDS.get(key, WEAR_BOUNDS.get(key, VARIATION_BOUNDS.get(key)))
			if not _number(value[key], bounds[0], bounds[1]): errors.append("invalid option " + key)
		elif key in ["tint", "wear_tint"] and not _color(value[key]): errors.append("invalid " + key)
		elif key == "variant" and not Language.variants(family).has(value[key]): errors.append("unknown family variant")
		elif key == "glow" and not value[key] is bool: errors.append("glow must be boolean")
		elif key == "variation_mode" and not value[key] in VARIATION_MODES: errors.append("invalid variation_mode")
		elif key == "variation_seed" and not _integer(value[key], 0, 2147483647): errors.append("invalid variation_seed")
	if _number(value.get("wear_strength"), 0.001, 0.65):
		if not _color(value.get("wear_tint")) or not _number(value.get("wear_height_min"), -100, 100) or not _number(value.get("wear_height_max"), -100, 100): errors.append("wear requires tint and height interval")
		elif value.wear_height_max <= value.wear_height_min: errors.append("empty wear height interval")

static func _closed(value: Dictionary, keys: Array, context: String, errors: Array[String]) -> void:
	for key: Variant in value:
		if not key in keys: errors.append(context + ": unknown key " + str(key))

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func _integer(value: Variant, low: float, high: float) -> bool:
	return _number(value, low, high) and float(value) == floor(float(value))

static func _vector(value: Variant, count: int, low: float, high: float) -> bool:
	if not value is Array or value.size() != count: return false
	for component: Variant in value:
		if not _number(component, low, high): return false
	return true

static func _text(value: Variant, limit: int) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= limit

static func _color(value: Variant) -> bool:
	if not value is String or value.length() != 6: return false
	for c: String in value.to_lower():
		if not c in "0123456789abcdef": return false
	return true

static func _contrast(a: Color, b: Color) -> float:
	a = a.srgb_to_linear()
	b = b.srgb_to_linear()
	var x := a.r * 0.2126 + a.g * 0.7152 + a.b * 0.0722
	var y := b.r * 0.2126 + b.g * 0.7152 + b.b * 0.0722
	return (maxf(x, y) + 0.05) / (minf(x, y) + 0.05)

static func _normal_key(value: Variant) -> bool:
	if not value is String: return false
	if value.begins_with("baked:"): return Moth.manifest().get("normals", {}).has(value.trim_prefix("baked:"))
	if value.begins_with("derived:"): return value.begins_with("derived:normal--") and not Moth.derived_record(value.trim_prefix("derived:")).is_empty()
	return Moth.manifest().get("normals", {}).has(value) or not Moth.derived_record("normal--" + value).is_empty()
