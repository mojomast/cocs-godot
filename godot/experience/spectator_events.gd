extends RefCounted
## Defense in depth for a queued old-seat batch. Authority filtering remains the
## source of truth; this allowlist is extracted from game/cocs-intel.mjs.
static var types: Variant = null

static func public_event(event: Dictionary) -> bool:
	var kind := str(event.get("type", ""))
	if not kind.begins_with("cocs-"): return true
	if types == null: types = JSON.parse_string(FileAccess.get_file_as_string("res://experience/public_event_types.json"))
	return types is Array and kind in types
