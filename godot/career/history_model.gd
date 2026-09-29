extends RefCounted
## Bounded, read-only projection of the source `history` reply.
##
## The source `MatchHistory` (server/history.mjs) returns the most recent 50
## *server* matches, not a personal timeline: an ordinary recorded player carries
## a display name, character, harness, frags and deaths and no stable career id.
## This model never associates a record with the local profile, never guesses an
## owner from a name and never turns an unknown stat into a zero.
##
## A malformed top-level `matches` value returns {} so the service can report an
## error and keep its last known list. A malformed record is counted and skipped;
## every remaining record keeps whatever known facts it carried.

const MAX_RECORDS := 50
const MAX_PLAYERS := 32
const SCORE_STAT_KEYS := [
	"captures", "flagReturns", "flagPickups", "flagDrops", "objectiveTime",
	"objectiveCaptures", "objectiveNeutralizations", "objectiveContests",
	"goals", "assists", "revives", "damage", "shots", "hits",
]

static func number(value: Variant) -> Variant:
	if value is bool: return null
	if value is int or value is float:
		return int(value) if is_finite(float(value)) else null
	return null

static func nonneg(value: Variant) -> Variant:
	var n: Variant = number(value)
	if n == null or int(n) < 0: return null
	return int(n)

static func text(value: Variant, limit: int) -> String:
	if not value is String: return ""
	var clean: String = value.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges()
	return clean.left(limit)

## Returns {records, invalid, total} or {} when the reply envelope is malformed.
static func project(matches: Variant) -> Dictionary:
	if not matches is Array: return {}
	var list: Array = matches
	var records: Array = []
	var invalid := 0
	var seen := 0
	for raw: Variant in list:
		if seen >= MAX_RECORDS: break
		seen += 1
		var record: Dictionary = project_record(raw)
		if record.is_empty(): invalid += 1
		else: records.append(record)
	return {"records": records, "invalid": invalid, "total": seen}

## One record. Empty when the entry carries nothing a reader could show.
static func project_record(raw: Variant) -> Dictionary:
	if not raw is Dictionary: return {}
	var out: Dictionary = {}
	var mode := text(raw.get("mode"), 40)
	if not mode.is_empty(): out.mode = mode
	var map_id := text(raw.get("mapId"), 64)
	if not map_id.is_empty(): out.map = map_id
	var room := text(raw.get("roomId"), 48)
	if not room.is_empty(): out.room = room
	var ended := text(raw.get("endedBy"), 40)
	if not ended.is_empty(): out.ending = ended
	var duration: Variant = nonneg(raw.get("duration"))
	if duration != null: out.duration = duration
	var frag_limit: Variant = nonneg(raw.get("fragLimit"))
	if frag_limit != null: out.frag_limit = frag_limit
	var time_limit: Variant = nonneg(raw.get("timeLimit"))
	if time_limit != null: out.time_limit = time_limit
	var leader := text(raw.get("leader"), 80)
	if not leader.is_empty(): out.leader = leader
	if raw.get("players") is Array:
		var source_players: Array = raw.players
		var players: Array = []
		for entry: Variant in source_players:
			if players.size() >= MAX_PLAYERS: break
			var player: Dictionary = project_player(entry)
			if not player.is_empty(): players.append(player)
		if not players.is_empty(): out.players = players
	if out.is_empty(): return {}
	return out

static func project_player(raw: Variant) -> Dictionary:
	if not raw is Dictionary: return {}
	var out: Dictionary = {}
	var player_name := text(raw.get("name"), 64)
	if not player_name.is_empty(): out.name = player_name
	var character := text(raw.get("character"), 40)
	if not character.is_empty(): out.character = character
	var harness := text(raw.get("harness"), 40)
	if not harness.is_empty(): out.harness = harness
	var frags: Variant = nonneg(raw.get("frags"))
	if frags != null: out.frags = frags
	var deaths: Variant = nonneg(raw.get("deaths"))
	if deaths != null: out.deaths = deaths
	var goals: Variant = nonneg(raw.get("goals"))
	if goals != null: out.goals = goals
	var stats: Variant = raw.get("scoreStats")
	if stats is Dictionary:
		var kept: Dictionary = {}
		for key: String in SCORE_STAT_KEYS:
			var amount: Variant = nonneg(stats.get(key))
			if amount != null and int(amount) > 0: kept[key] = amount
		if not kept.is_empty(): out.score_stats = kept
	if out.is_empty(): return {}
	return out
