extends RefCounted
## Bounded, read-only projections for the source RESULTS / award surface.
##
## Nothing here computes a win/loss, invents a zero, stores a full snapshot or
## keeps an identity/token. It only narrows one accepted source frame into the
## few public scalars the native reader shows. An unknown field stays unknown
## (the key is omitted) rather than becoming a fabricated zero.
##
## The authoritative source distinguishes the two `progression` replies by their
## exact top-level shape (server/progression.mjs + server/room.mjs):
##   * GEAR write  -> {type:'progression', profile, gear, attachments}
##   * match award -> {type:'progression', profile, gained, baseGained,
##                     prestigeBonus, achievementXp, levelUp, prestigeUp,
##                     unlocked, achievements, progress, toNext, result, actor,
##                     mode, flagged}
## An equipment reply never carries `gained`; an award never carries `gear`.
## Keeping the test on the exact marker means an equipment-only reply can never
## be mistaken for an accepted award.

const MAX_ACTORS := 64
const MAX_REWARDS := 16

static func number(value: Variant) -> Variant:
	if value is bool: return null
	if value is int or value is float:
		return int(value) if is_finite(float(value)) else null
	return null

static func nonneg(value: Variant) -> Variant:
	var n: Variant = number(value)
	if n == null or int(n) < 0: return null
	return int(n)

static func unit(value: Variant) -> Variant:
	if value is bool or not (value is int or value is float): return null
	if not is_finite(float(value)): return null
	return clampf(float(value), 0.0, 1.0)

static func text(value: Variant, limit: int) -> String:
	if not value is String: return ""
	var clean: String = value.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges()
	return clean.left(limit)

static func is_equipment(frame: Dictionary) -> bool:
	return frame.get("gear") is Dictionary and frame.get("attachments") is Dictionary

static func is_award(frame: Dictionary) -> bool:
	if str(frame.get("type", "")) != "progression" or is_equipment(frame): return false
	if not frame.has("gained"): return false
	return nonneg(frame.get("gained")) != null

## Project one accepted source `results` state. `actor_id` and `round_key` come
## from the seated connection, never from the frame. Returns {} for a missing or
## unusable state so the reader can keep its last known facts.
static func project(state: Variant, actor_id: int, round_key: String, replayed: bool) -> Dictionary:
	if not state is Dictionary: return {}
	var source: Dictionary = state
	var out: Dictionary = {"round_key": text(round_key, 96), "replayed": replayed}
	var config: Variant = source.get("config")
	if config is Dictionary:
		var configured := text(config.get("mode"), 40)
		if not configured.is_empty(): out.mode = configured
	if not out.has("mode"):
		var named := text(source.get("modeName"), 40)
		if not named.is_empty(): out.mode = named
	var map_name := text(source.get("mapName"), 64)
	if map_name.is_empty(): map_name = text(source.get("mapId"), 64)
	if not map_name.is_empty(): out.map = map_name
	var ending := text(source.get("overReason"), 40)
	if not ending.is_empty(): out.ending = ending
	var elapsed: Variant = nonneg(source.get("time"))
	if elapsed != null: out.time = elapsed
	if source.get("actors") is Array:
		var actors: Array = source.actors
		out.actor_count = mini(actors.size(), MAX_ACTORS)
		if actor_id >= 0:
			for entry: Variant in actors:
				if not entry is Dictionary: continue
				if number(entry.get("id")) != actor_id: continue
				out.actor_id = actor_id
				var frags: Variant = nonneg(entry.get("frags"))
				var deaths: Variant = nonneg(entry.get("deaths"))
				if frags != null: out.frags = frags
				if deaths != null: out.deaths = deaths
				break
	if not out.has("mode") and not out.has("map") and not out.has("actor_count"): return {}
	return out

## Project one confirmed source award frame into public reward facts only.
## `profile` is deliberately not copied: the service correlates identity itself.
static func project_award(frame: Dictionary) -> Dictionary:
	if not is_award(frame): return {}
	var out: Dictionary = {}
	for key: String in ["gained", "baseGained", "prestigeBonus", "achievementXp"]:
		var amount: Variant = nonneg(frame.get(key))
		if amount != null: out[key] = amount
	for key: String in ["levelUp", "prestigeUp"]:
		if frame.get(key) is bool: out[key] = frame[key]
	if frame.get("flagged") is bool: out.flagged = frame.flagged
	var progress: Variant = unit(frame.get("progress"))
	if progress != null: out.progress = progress
	var to_next: Variant = nonneg(frame.get("toNext"))
	if to_next != null: out.toNext = to_next
	var mode := text(frame.get("mode"), 40)
	if not mode.is_empty(): out.mode = mode
	var result := text(frame.get("result"), 16)
	if not result.is_empty(): out.result = result
	var unlocked: Array = reward_items(frame.get("unlocked"))
	if not unlocked.is_empty(): out.unlocked = unlocked
	var achievements: Array = reward_items(frame.get("achievements"))
	if not achievements.is_empty(): out.achievements = achievements
	if out.is_empty(): return {}
	return out

static func reward_items(value: Variant) -> Array:
	var out: Array = []
	if not value is Array: return out
	var list: Array = value
	for item: Variant in list:
		if out.size() >= MAX_REWARDS: break
		if not item is Dictionary: continue
		var id := text(item.get("id"), 64)
		var name := text(item.get("name"), 64)
		if id.is_empty() and name.is_empty(): continue
		var entry: Dictionary = {}
		if not id.is_empty(): entry.id = id
		if not name.is_empty(): entry.name = name
		var level: Variant = nonneg(item.get("level"))
		if level != null: entry.level = level
		var xp: Variant = nonneg(item.get("xp"))
		if xp != null: entry.xp = xp
		out.append(entry)
	return out
