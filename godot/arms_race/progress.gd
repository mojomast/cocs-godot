extends RefCounted
## Presentation only. Never infer a rung from frags, events or elapsed time.
const Weapons = preload("res://world/weapon_selection.gd")
const COUNT := 10
var local_id := -1
var rung := -1
var weapon := -1
var transition := ""
var outcome := ""
var current := "Awaiting authoritative ladder"
var next := "Next weapon unavailable"

static func integer(value: Variant, low: int, high: int) -> int:
	if not (value is int or value is float): return -1
	if not is_finite(float(value)) or floorf(float(value)) != float(value): return -1
	return int(value) if value >= low and value <= high else -1

func clear() -> void:
	local_id = -1
	rung = -1
	weapon = -1
	transition = ""
	outcome = ""
	current = "Awaiting authoritative ladder"
	next = "Next weapon unavailable"

func apply_state(state: Dictionary, id: int) -> void:
	if id != local_id: clear()
	local_id = id
	var actor: Dictionary = {}
	for item: Variant in state.get("actors", []):
		if item is Dictionary and integer(item.get("id"), 0, 2147483647) == id and id >= 0: actor = item
	var previous := rung
	rung = integer(actor.get("ladder"), 0, COUNT)
	weapon = integer(actor.get("weapon"), 0, COUNT - 1)
	if rung < 0 or weapon < 0:
		current = "Authoritative ladder unavailable"
		next = "Next weapon unavailable"
		transition = ""
	else:
		current = "RUNG %d / %d  ·  %s" % [mini(rung + 1, COUNT), COUNT, Weapons.weapon_name(weapon)]
		next = "Next: %s" % Weapons.weapon_name(rung + 1) if rung < COUNT - 1 else ("Final weapon: one more kill to finish" if rung == COUNT - 1 else "Ladder completed")
		if previous >= 0 and rung != previous:
			transition = "PROMOTED +%d  ·  Source-confirmed" % (rung - previous) if rung > previous else "DEMOTED  ·  Death costs one rung"
		elif previous < 0: transition = "Kill to climb · Death drops a rung · Catch-up may advance two"
	outcome = result_text(state) if state.get("over", false) else ""

static func before(a: Dictionary, b: Dictionary) -> bool:
	var ar := integer(a.get("ladder"), 0, COUNT)
	var br := integer(b.get("ladder"), 0, COUNT)
	if ar != br: return ar > br
	return float(a.get("frags", 0)) > float(b.get("frags", 0))

static func result_text(state: Dictionary) -> String:
	var actors: Array = state.get("actors", []).duplicate()
	var winner := integer(state.get("winner"), 0, 2147483647)
	if winner >= 0:
		for actor: Dictionary in actors:
			if integer(actor.get("id"), 0, 2147483647) == winner:
				return "LADDER FINISH · %s wins" % str(actor.get("name", "Player")).replace("\n", " ").left(40)
		return "LADDER FINISH · Actor %d wins" % winner
	actors.sort_custom(before)
	if actors.is_empty() or integer(actors[0].get("ladder"), 0, COUNT) < 0: return "RESULT · Ranking unavailable"
	var top: Dictionary = actors[0]
	if top.ladder == 0 and top.get("frags", 0) == 0: return "TIME LIMIT · Draw (no ladder progress or frags)"
	var winners: PackedStringArray = []
	for actor: Dictionary in actors:
		if actor.get("ladder") == top.ladder and actor.get("frags", 0) == top.get("frags", 0):
			winners.append(str(actor.get("name", "Player")).replace("\n", " ").left(24))
	return "TIME LIMIT · %s · Ranked by ladder, then frags" % ", ".join(winners)
