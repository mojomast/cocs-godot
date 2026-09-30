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
	if not state.is_empty() and (state.get("mapId") != value.mapId or state.get("checkpoint") != value.get("checkpoint")):
		checkpoint_notice = "Checkpoint secured · " + str(value.get("checkpoint", ""))
	state = value.duplicate(true)
	return true

func action() -> String:
	match state.get("phase", ""):
		"dead": return "retry"
		"level-complete": return "continue"
	return ""

func playing() -> bool:
	return state.get("phase") == "playing"
