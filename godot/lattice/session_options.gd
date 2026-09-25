extends RefCounted
## Shared parser/model for the LATTICE world route. Requests are never echoes.
const MAPS := ["asterion-relay", "monsoon-foundry"]
const MODES := ["cocs", "cocs-coop"]
const Loadout = preload("res://ui/loadout.gd")

static func defaults() -> Dictionary:
	return {"map":"asterion-relay", "mode":"cocs", "rung":null, "bots":2,
		"time_limit":900, "operator":"chatgpt", "harness":"openclaw",
		"endpoint":"", "room":"", "join":false, "supplied":[], "error":""}

static func parse(args: PackedStringArray) -> Dictionary:
	var o := defaults()
	for arg: String in args:
		if arg.begins_with("--map="): o.map = arg.trim_prefix("--map=")
		elif arg.begins_with("--mode="): o.mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--rung="): o.rung = arg.trim_prefix("--rung=")
		elif arg.begins_with("--bots="):
			var n := arg.trim_prefix("--bots=")
			if not n.is_valid_int(): o.error = "--bots must be an integer"
			else: o.bots = int(n)
		elif arg.begins_with("--time-limit="):
			var n := arg.trim_prefix("--time-limit=")
			if not n.is_valid_int(): o.error = "--time-limit must be an integer"
			else: o.time_limit = int(n)
		elif arg.begins_with("--operator="): o.operator = arg.trim_prefix("--operator=")
		elif arg.begins_with("--harness="): o.harness = arg.trim_prefix("--harness=")
		elif arg.begins_with("--endpoint="): o.endpoint = arg.trim_prefix("--endpoint=")
		elif arg.begins_with("--join-room="):
			o.room = arg.trim_prefix("--join-room=").strip_edges()
			o.join = true
		if arg.begins_with("--") and arg.contains("="): o.supplied.append(arg.substr(2, arg.find("=") - 2))
	if o.join:
		for key: String in ["bots", "rung", "time-limit", "operator", "harness"]:
			if key in o.supplied: o.error = "Guest join cannot include host configuration"
	if o.error.is_empty(): o.error = validate(o)
	if o.error.is_empty():
		var pair: Dictionary = Loadout.resolve(o.operator, o.harness)
		o.operator = pair.character
		o.harness = pair.harness
	return o

static func validate(o: Dictionary) -> String:
	if o.get("map") not in MAPS: return "Unsupported LATTICE map"
	if o.get("mode") not in MODES: return "Unsupported LATTICE mode"
	if not o.get("time_limit") is int or o.time_limit < 60 or o.time_limit > 900: return "Time limit must be 60..900 seconds"
	if not o.get("bots") is int or o.bots < 0 or o.bots > 16: return "Bot count must be 0..16"
	if o.get("rung") != null and (o.mode != "cocs" or o.rung not in ["4v4", "8v8"]): return "Rung is PvP-only and must be 4v4 or 8v8"
	if o.join and o.room.is_empty(): return "Guest requires --join-room"
	if o.get("endpoint", "").is_empty(): return "Explicit --endpoint is required"
	if not (o.endpoint.begins_with("ws://") or o.endpoint.begins_with("wss://")) or o.endpoint.contains("@") or o.endpoint.contains("\n"): return "Invalid WebSocket endpoint"
	return ""

static func host_frame(o: Dictionary) -> Dictionary:
	var config := {"mode":o.mode, "timeLimit":o.time_limit}
	if o.rung != null: config.rung = o.rung
	else: config.botCount = o.bots
	return {"type":"host", "mapId":o.map, "config":config}
