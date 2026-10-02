extends RefCounted
## Only allowlisted scalars from the recipient's accepted public actor list.
## Never accepts an event, a local actor model, or a team/private context.
const Text = preload("res://experience/caption_model.gd")
var actors: Array[Dictionary] = []
var target_id: Variant = null
var mode := "follow"

static func valid_id(value: Variant) -> bool:
	return value is String or value is int or (value is float and is_finite(value) and value == floorf(value))

static func same_id(a: Variant, b: Variant) -> bool:
	return (valid_id(a) and valid_id(b) and typeof(a) == typeof(b) and a == b) or ((a is int or a is float) and (b is int or b is float) and a == b)

func clear() -> void:
	actors.clear()
	target_id = null
	mode = "follow"

func snapshot(state: Dictionary) -> void:
	actors.clear()
	var values: Variant = state.get("actors", [])
	if values is Array:
		for item: Variant in values:
			if not item is Dictionary or not valid_id(item.get("id")): continue
			var row: Dictionary = {"id":item.id, "name":Text.clean(item.get("name"), 36)}
			for key: String in ["health", "team", "x", "y", "z", "yaw", "pitch", "eyeHeight"]:
				var value: Variant = item.get(key)
				if (value is float or value is int) and is_finite(float(value)): row[key] = value
			actors.append(row)
	var selected := target()
	target_id = selected.get("id")

func target() -> Dictionary:
	for actor: Dictionary in actors:
		if same_id(actor.id, target_id) and float(actor.get("health", 0)) > 0: return actor
	for actor: Dictionary in actors:
		if float(actor.get("health", 0)) > 0: return actor
	return actors[0] if not actors.is_empty() else {}

func cycle(step: int) -> void:
	var live: Array[Dictionary] = []
	var current := -1
	for actor: Dictionary in actors:
		if float(actor.get("health", 0)) <= 0: continue
		if same_id(actor.id, target_id): current = live.size()
		live.append(actor)
	if live.is_empty():
		target_id = null
		return
	var index := (0 if step >= 0 else live.size() - 1) if current < 0 else posmod(current + (1 if step >= 0 else -1), live.size())
	target_id = live[index].id

func heading() -> String:
	var actor := target()
	var name := str(actor.get("name", ""))
	if name.is_empty(): name = "A%s" % str(actor.get("id", "?"))
	return "SPECTATOR · READ ONLY · %s\n%s" % [mode.to_upper(), "No public target" if actor.is_empty() else "%s · HP %s · Team %s" % [name, actor.get("health", "—"), actor.get("team", "—")]]
