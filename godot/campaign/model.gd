extends RefCounted
## Authoritative UI state: never advances objectives locally.
const Catalog = preload("res://campaign/catalog.gd")
const ROBOTS := ["scrapper", "skirmisher", "sentinel", "mortar", "bulwark", "warden"]
var state: Dictionary = {}
var checkpoint_notice := ""
var error := ""

func apply(value: Variant) -> bool:
	if not value is Dictionary or value.get("id") != "quiet-relay" or value.get("mapId") not in Catalog.MAP_IDS or value.get("phase") not in ["playing", "dead", "level-complete", "campaign-complete"]:
		error = "Invalid campaign state"
		return false
	for field: String in ["title", "objective", "detail"]:
		if not value.get(field) is String:
			error = "Missing campaign " + field
			return false
	if not value.get("transmission") is Dictionary or not value.transmission.get("speaker") is String or not value.transmission.get("text") is String:
		error = "Missing campaign transmission"
		return false
	var checkpoint: Variant = value.get("checkpoint")
	if not (checkpoint is int or checkpoint is float) or not is_finite(float(checkpoint)) or float(checkpoint) < 0 or floorf(float(checkpoint)) != float(checkpoint):
		error = "Invalid campaign checkpoint"
		return false
	if value.get("nextMapId") != null and value.nextMapId not in Catalog.MAP_IDS:
		error = "Invalid next chapter"
		return false
	if value.phase == "playing":
		if not value.get("marker") is Dictionary:
			error = "Missing campaign marker"
			return false
		for field: String in ["x", "y", "z", "radius"]:
			var number: Variant = value.marker.get(field)
			if not (number is int or number is float) or not is_finite(float(number)):
				error = "Invalid campaign marker"
				return false
	elif value.get("marker") != null:
		error = "Terminal campaign marker must be null"
		return false
	if value.has("story") and not valid_story(value.story):
		error = "Invalid campaign story"
		return false
	if not state.is_empty() and (state.get("mapId") != value.mapId or state.get("checkpoint") != value.get("checkpoint")):
		checkpoint_notice = "Checkpoint secured · " + str(value.get("checkpoint", ""))
	state = value.duplicate(true)
	return true

static func valid_story(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 1 or not value.get("entities") is Array or not value.get("completed") is Array or not valid_count(value.get("pets")): return false
	if value.get("prompt") != null:
		var prompt: Variant = value.prompt
		if not prompt is Dictionary or not prompt.get("entityId") is String or prompt.get("action") != "pet" or not prompt.get("text") is String: return false
	if value.get("caption") != null:
		var caption: Variant = value.caption
		if not caption is Dictionary or not caption.get("id") is String or not caption.get("speaker") is String or not caption.get("text") is String: return false
	for beat: Variant in value.completed:
		if not beat is String: return false
	var ids := {}
	for entry: Variant in value.entities:
		if not entry is Dictionary or not entry.get("id") is String or str(entry.id).is_empty() or ids.has(entry.id) or entry.get("kind") not in ["operator", "puppy"] or not entry.get("name") is String or not entry.get("pose") in ["idle", "wave", "work", "point", "sit", "happy", "walk"] or not entry.get("active") is bool or not valid_count(entry.get("reactionSerial")): return false
		ids[entry.id] = true
		for field: String in ["x", "y", "z", "yaw"]:
			var number: Variant = entry.get(field)
			if not (number is int or number is float) or not is_finite(float(number)): return false
		if entry.kind == "operator" and (not entry.get("character") is String or str(entry.character).is_empty()): return false
	return true

static func valid_count(value: Variant) -> bool:
	# Godot JSON.parse_string may decode integer JSON literals as floats.
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= 2147483647.0 and floorf(float(value)) == float(value)

func action() -> String:
	match state.get("phase", ""):
		"dead": return "retry"
		"level-complete": return "continue"
	return ""

func playing() -> bool:
	return state.get("phase") == "playing"
