extends RefCounted
## Enrich only authority feed rows matched by source event time + victim name,
## like app/page.tsx decorate(). ASSIST requires an actual local damage event.
const Text = preload("res://experience/caption_model.gd")
const Combat = preload("res://experience/combat_info.gd")
const Identity = preload("res://experience/spectator_model.gd")
const Weapons = preload("res://ui/weapon_names.gd")
var local_id: Variant = null
var time := 0.0
var actors: Dictionary = {}
var marks: Dictionary = {}
var metadata: Array[Dictionary] = []
var rows: Array[Dictionary] = []
var seen: Dictionary = {}
var serial := -1.0

func clear() -> void:
	local_id = null
	time = 0
	actors.clear()
	marks.clear()
	metadata.clear()
	rows.clear()
	seen.clear()
	serial = -1

static func assist_credit(damage_marks: Dictionary, victim: Variant, when: float) -> bool:
	if victim == null or not damage_marks.has(str(victim)): return false
	var age := when - float(damage_marks[str(victim)])
	return age >= 0 and age <= 5

func snapshot(state: Dictionary, id: Variant) -> void:
	var next_time := Combat.number(state.get("time"))
	if id != local_id or next_time < time: clear()
	local_id = id
	time = next_time
	actors.clear()
	for value: Variant in state.get("actors", []):
		if value is Dictionary and Identity.valid_id(value.get("id")):
			actors[value.id] = Text.clean(value.get("name"), 36)
	rows.clear()
	for value: Variant in state.get("feed", []):
		if not value is Dictionary: continue
		var row: Dictionary = {}
		for key: String in ["time", "killer", "victim", "weapon", "ability", "abilityName", "self", "fall", "overkill", "victimStreak", "killerStreak"]:
			if value.has(key): row[key] = value[key]
		rows.append(row)
		if rows.size() >= 12: break
	for key: Variant in marks.keys():
		if time - float(marks[key]) > 5: marks.erase(key)

func events(items: Array) -> void:
	for value: Variant in items:
		if not value is Dictionary or value.get("type") not in ["damage", "death"]: continue
		var id: Variant = value.get("id")
		# Source wire events have stable IDs. Unidentified events cannot credit.
		if not Identity.valid_id(id): continue
		if id is int or id is float:
			if float(id) <= serial: continue
			serial = float(id)
		else:
			if seen.has(id): continue
			# Fail closed after the bounded string-ID ledger fills, rather than
			# evicting IDs and allowing an old reconnect batch to earn credit.
			if seen.size() >= 4096: continue
			seen[id] = true
		var when := Combat.number(value.get("time"), time)
		if value.type == "damage":
			if local_id != null and Identity.same_id(value.get("source"), local_id) and not Identity.same_id(value.get("actor"), local_id) and Combat.number(value.get("amount")) > 0:
				marks[str(value.get("actor"))] = when
			continue
		var credited: bool = value.get("self") != true and value.get("killer") != null
		var meta := {"time":when, "victim":actors.get(value.get("actor"), ""), "overkill":Combat.number(value.get("overkill")), "assist":local_id != null and credited and not Identity.same_id(value.get("killer"), local_id) and assist_credit(marks, value.get("actor"), when)}
		for key: String in ["victimStreak", "killerStreak"]:
			if value.has(key): meta[key] = value[key]
		metadata.append(meta)
		while metadata.size() > 12: metadata.pop_front()
		marks.erase(str(value.get("actor")))

func text() -> String:
	var lines := PackedStringArray()
	for value: Dictionary in rows:
		var row := value.duplicate()
		for meta: Dictionary in metadata:
			if meta.time == Combat.number(row.get("time")) and meta.victim == row.get("victim") and not str(meta.victim).is_empty():
				row.merge(meta, true)
				break
		var killer := Text.clean(row.get("killer"), 36)
		var victim := Text.clean(row.get("victim"), 36)
		if victim.is_empty(): continue
		var detail := Text.clean(row.get("abilityName"), 48) if row.get("ability") == true else ""
		var weapon := int(Combat.number(row.get("weapon"), -1))
		if detail.is_empty() and weapon in range(10): detail = Weapons.display_name(weapon)
		var tags := Combat.badges(row)
		lines.append("%s → %s%s%s" % [killer if not killer.is_empty() else "World", victim, " · " + detail if not detail.is_empty() else "", " · " + " · ".join(tags) if not tags.is_empty() else ""])
		if lines.size() >= 3: break
	return "\n".join(lines)
