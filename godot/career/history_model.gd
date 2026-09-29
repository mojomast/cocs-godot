extends RefCounted
## Bounded, read-only projection of the source `history` reply.
##
## The source `MatchHistory` (server/history.mjs) returns the most recent 50
## *server* matches, not a personal timeline: an ordinary recorded player carries
## a display name, character, harness, frags and deaths and no stable career id.
## This model never associates a record with the local profile, never guesses an
## owner from a name and never turns an unknown stat into a zero.
##
## Numeric policy matches results_model.gd: counts are exact safe integers (a
## fractional or negative count is unknown, never floored or zeroed), while
## duration/objectiveTime/damage keep their real source precision as finite
## non-negative decimals. A malformed top-level `matches` value returns {} so the
## service can report an error and keep its last known list. A malformed record
## is counted and skipped; every remaining record keeps whatever known facts it
## carried.

const MAX_RECORDS := 50
const MAX_PLAYERS := 32
const SAFE_INT := 9007199254740991
const SCORE_DECIMAL_KEYS := ["objectiveTime", "damage"]
const SCORE_COUNT_KEYS := [
	"captures", "flagReturns", "flagPickups", "flagDrops",
	"objectiveCaptures", "objectiveNeutralizations", "objectiveContests",
	"goals", "assists", "revives", "shots", "hits",
]

static func safe_int(value: Variant) -> Variant:
	if value is bool or not (value is int or value is float): return null
	var number := float(value)
	if not is_finite(number) or number != floorf(number): return null
	if number > float(SAFE_INT) or number < -float(SAFE_INT): return null
	return int(number)

static func count(value: Variant) -> Variant:
	var number: Variant = safe_int(value)
	if number == null or int(number) < 0: return null
	return int(number)

static func decimal(value: Variant) -> Variant:
	if value is bool or not (value is int or value is float): return null
	var number := float(value)
	if not is_finite(number) or number < 0.0: return null
	return number

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
	var duration: Variant = decimal(raw.get("duration"))
	if duration != null: out.duration = duration
	var frag_limit: Variant = count(raw.get("fragLimit"))
	if frag_limit != null: out.frag_limit = frag_limit
	var time_limit: Variant = count(raw.get("timeLimit"))
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
	var frags: Variant = count(raw.get("frags"))
	if frags != null: out.frags = frags
	var deaths: Variant = count(raw.get("deaths"))
	if deaths != null: out.deaths = deaths
	var goals: Variant = count(raw.get("goals"))
	if goals != null: out.goals = goals
	var stats: Variant = raw.get("scoreStats")
	if stats is Dictionary:
		var kept: Dictionary = {}
		for key: String in SCORE_DECIMAL_KEYS:
			var amount: Variant = decimal(stats.get(key))
			if amount != null and amount > 0.0: kept[key] = amount
		for key: String in SCORE_COUNT_KEYS:
			var amount: Variant = count(stats.get(key))
			if amount != null and int(amount) > 0: kept[key] = amount
		if not kept.is_empty(): out.score_stats = kept
	if out.is_empty(): return {}
	return out
