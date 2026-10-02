extends RefCounted
## Source page noteDamage journey: only received local incoming damage, at most
## three hits. Actor lookup is limited to the current supplied snapshot.
const Text = preload("res://experience/caption_model.gd")
const Weapons = preload("res://ui/weapon_names.gd")
var actors: Dictionary = {}
var hits: Array[Dictionary] = []
var local_id := -1
var dead := false
var time := 0.0
var latest_kill := ""
var kill_at := -1000.0

static func number(value: Variant, fallback: float = 0.0) -> float:
	return float(value) if (value is float or value is int) and is_finite(float(value)) else fallback

static func badges(entry: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	if entry.get("self") == true or entry.get("fall") == true: return result
	if entry.get("assist") == true: result.append("ASSIST")
	if floorf(number(entry.get("victimStreak"))) >= 2: result.append("STREAK ENDED")
	if floorf(number(entry.get("overkill")) + 0.5) >= 55: result.append("OVERKILL")
	var streak := int(floorf(number(entry.get("killerStreak"))))
	if streak >= 2: result.append("×%d STREAK" % streak)
	return result

func snapshot(state: Dictionary, id: int) -> void:
	var next_time := number(state.get("time"))
	if id != local_id or next_time < time: clear()
	local_id = id
	time = next_time
	actors.clear()
	var values: Variant = state.get("actors", [])
	if values is Array:
		for value: Variant in values.slice(0, 64):
			if not value is Dictionary: continue
			var actor_id := int(number(value.get("id"), -1))
			if actor_id < 0: continue
			# Retain attribution scalars only. No positions, targets or enemy health.
			actors[actor_id] = {"name":Text.clean(value.get("name"), 36), "weapon":value.get("weapon")}
			if actor_id == id:
				var was_dead := dead
				dead = number(value.get("health")) <= 0
				if was_dead and not dead: hits.clear()
	if id < 0 or not actors.has(id):
		dead = false
		hits.clear()

func events(items: Array) -> void:
	if local_id < 0: return
	for value: Variant in items.slice(0, 512):
		if not value is Dictionary: continue
		if value.get("type") == "spawn" and value.get("actor") == local_id:
			hits.clear()
			dead = false
		if value.get("type") == "damage" and value.get("actor") == local_id:
			var amount := number(value.get("amount"))
			if amount <= 0: continue
			var source: Dictionary = actors.get(value.get("source"), {})
			var detail := Text.clean(value.get("abilityName", value.get("ability")), 48)
			var weapon: Variant = source.get("weapon")
			if detail.is_empty() and (weapon is int or weapon is float) and float(weapon) == floorf(float(weapon)) and int(weapon) in range(10): detail = Weapons.display_name(int(weapon))
			var source_name := str(source.get("name", ""))
			if source_name.is_empty(): source_name = "Unknown source"
			hits.append({"name":source_name, "detail":detail, "amount":int(floorf(amount + 0.5)), "at":time})
			while hits.size() > 3: hits.pop_front()
		if value.get("type") == "death" and value.get("actor") == local_id: dead = true
		if value.get("type") == "death" and value.get("killer") == local_id and value.get("actor") != local_id and value.get("self") != true:
			var victim: Dictionary = actors.get(value.get("actor"), {})
			latest_kill = "ELIMINATED · " + str(victim.get("name", "Opponent"))
			# Only event-supplied badges. Do not guess snapshot/event ordering or assists.
			var tags := badges(value)
			if not tags.is_empty(): latest_kill += "\n" + " · ".join(tags)
			kill_at = time

func recap() -> String:
	if not dead or hits.is_empty(): return ""
	var rows := PackedStringArray(["LAST INCOMING HITS"])
	for index: int in range(hits.size() - 1, -1, -1):
		var hit: Dictionary = hits[index]
		var detail := " · " + str(hit.detail) if not str(hit.detail).is_empty() else ""
		rows.append("%s%s · %d damage · %.1fs ago" % [hit.name, detail, hit.amount, maxf(0, time - float(hit.at))])
	return "\n".join(rows)

func clear() -> void:
	actors.clear()
	hits.clear()
	local_id = -1
	dead = false
	time = 0
	latest_kill = ""
	kill_at = -1000
