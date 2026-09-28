extends RefCounted
## GEAR has no request ID: only its distinctive progression reply can settle it.
const CareerProfile = preload("res://career/profile.gd")
const TIMEOUT_MS := 8000

static func available(profile: Dictionary, item: Dictionary) -> bool:
	return CareerProfile.item_state(profile, item) in ["UNLOCKED", "EQUIPPED"]

static func request(profile: Dictionary, item: Dictionary) -> Dictionary:
	if not available(profile, item) or item.get("kind") == "crosshair": return {}
	var gear: Dictionary = profile.get("gear", {}).duplicate()
	var attachments: Dictionary = profile.get("attachments", {}).duplicate()
	var kind: String = item.get("kind", "")
	var id: String = item.get("id", "")
	var slot: String = item.get("slot", "")
	if kind == "gear" and slot in ["primary", "armor", "utility"]: gear[slot] = id
	elif kind == "attachment" and slot in ["optic", "barrel", "magazine", "underbarrel"]: attachments[slot] = id
	elif kind != "finish": return {}
	var frame := {"type":"gear", "gear":gear, "attachments":attachments}
	# Omitting finish leaves it intact at the source; include only on selection.
	if kind == "finish": frame.finish = id
	return frame

static func settles(frame: Dictionary) -> bool:
	return frame.get("type") == "progression" and frame.get("gear") is Dictionary and frame.get("attachments") is Dictionary

static func outcome(pending: Dictionary, frame: Dictionary, next: Dictionary) -> String:
	if pending.is_empty() or not settles(frame) or next.get("id") != pending.get("identity"): return "pending"
	var requested: Dictionary = pending.get("frame", {})
	var exact: bool = next.get("gear") == requested.get("gear") and next.get("attachments") == requested.get("attachments")
	if requested.has("finish"): exact = exact and next.get("finish") == requested.finish
	return "applied" if exact else "adjusted"
