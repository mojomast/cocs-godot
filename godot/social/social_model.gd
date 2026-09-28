extends RefCounted
## Pure social helpers for the native room browser and room-scoped chat.
##
## Nothing here touches the authority, the seat or the wire: it mirrors the
## source's `sanitizeText` ceiling, normalizes the room summaries the server
## already advertises (`roomId`, `name`, `mapId`, `config.mode`, `players`,
## `started`), and formats them without ever guessing a value the authority did
## not send. Display labels are plain strings so every caller can render them in
## a plain `Label` (no BBCode/RichText parsing of untrusted names).

# Source `sanitizeText(value, 200)` ceiling (game/protocol.mjs) used by
# Room.chat, and the 32-char room-name slice used by RoomRegistry.create.
const CHAT_TEXT_LIMIT := 200
const CHAT_NAME_LIMIT := 32
# Source Room.chat per-peer floor: messages inside 300 ms are dropped. The UI
# mirrors this so a fast typist is told instead of silently losing a line.
const CHAT_COOLDOWN_MS := 300
# Presentation bounds. The authority caps rooms at 64 (RoomRegistry); a client
# that renders only the first N honest rows is bounded without pretending.
const ROOM_ROWS_LIMIT := 24
const CHAT_LOG_LIMIT := 120

# Mirror of the source sanitizer: drop C0/C1-ish control chars, trim edges,
# then slice by characters. Accepts any Variant (untrusted) and never returns
# null, so callers can always render the result.
static func sanitize(value: Variant, max_length: int) -> String:
	var text: String = str(value) if value != null else ""
	var kept := ""
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		if code <= 0x1f or code == 0x7f:
			continue
		kept += text[index]
	return kept.strip_edges().left(maxi(0, max_length))

static func string_or_empty(value: Variant, max_length: int) -> String:
	return sanitize(value, max_length) if value is String else ""

# Normalize one authority room summary. Returns {} when the record has no usable
# identity. Fields the authority omitted stay explicit unknowns:
#   players  == -1  -> count not advertised
#   started  == null -> lifecycle not advertised
#   mode     == ""   -> config/mode not advertised (never inferred available)
static func normalize_room(record: Variant) -> Dictionary:
	if not record is Dictionary: return {}
	var room_id := sanitize(record.get("roomId"), 64)
	if room_id.is_empty(): return {}
	var players := -1
	var raw_players: Variant = record.get("players")
	if (raw_players is int or raw_players is float) and is_finite(float(raw_players)) and float(raw_players) >= 0.0:
		players = int(floor(float(raw_players)))
	var started: Variant = record.get("started")
	var config: Variant = record.get("config")
	var mode := ""
	var mode_known := false
	if config is Dictionary and config.get("mode") is String:
		mode = sanitize(config.get("mode"), 32)
		mode_known = true
	var map_id := string_or_empty(record.get("mapId"), 64)
	return {
		"roomId": room_id,
		"name": sanitize(record.get("name"), CHAT_NAME_LIMIT),
		"mapId": map_id,
		"mode": mode,
		"modeKnown": mode_known,
		"configKnown": config is Dictionary,
		"players": players,
		"started": started if started is bool else null,
	}

static func normalize_rooms(rows: Variant) -> Array:
	var rooms: Array = []
	if not rows is Array: return rooms
	for record: Variant in rows:
		var room: Dictionary = normalize_room(record)
		if not room.is_empty(): rooms.append(room)
	return rooms

# Stable, locale-aware ordering used by the browser. `key` is one of
# "players" / "name" / "status"; unknown keys fall back to name order. Ties break
# on the room code so two refreshes of the same data never reshuffle.
static func sort_rooms(rooms: Array, key: String, ascending: bool) -> Array:
	var copy: Array = rooms.duplicate()
	copy.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var result := 0
		if key == "players":
			var left := int(a.get("players", -1))
			var right := int(b.get("players", -1))
			# An unknown count always sorts last, in either direction.
			if left < 0 and right >= 0: return false
			if right < 0 and left >= 0: return true
			result = left - right
		else:
			result = str(a.get("name", "")).nocasecmp_to(str(b.get("name", "")))
		var code_result: int = str(a.get("roomId", "")).nocasecmp_to(str(b.get("roomId", "")))
		if result == 0: result = code_result
		return result < 0 if ascending else result > 0)
	return copy

# Case-insensitive search over the fields the browser actually shows: code,
# name, map and mode. An empty query keeps every room.
static func filter_rooms(rooms: Array, query: String, hide_started: bool = false) -> Array:
	var needle := query.strip_edges().to_lower()
	var kept: Array = []
	for room: Dictionary in rooms:
		if hide_started and room.get("started") == true: continue
		if needle.is_empty():
			kept.append(room)
			continue
		var haystack := "%s %s %s %s" % [str(room.get("roomId", "")), str(room.get("name", "")), str(room.get("mapId", "")), str(room.get("mode", ""))]
		if haystack.to_lower().contains(needle): kept.append(room)
	return kept

static func players_label(room: Dictionary) -> String:
	var count := int(room.get("players", -1))
	if count < 0: return "player count unknown"
	return "%d player" % count if count == 1 else "%d players" % count

# Truthful lifecycle wording. A started room seats a late joiner as a spectator
# (source Room.join rule), so the row says so instead of implying a free seat.
static func status_label(room: Dictionary) -> String:
	var started: Variant = room.get("started")
	if started == true: return "IN PROGRESS · JOIN AS SPECTATOR"
	if started == false: return "OPEN"
	return "STATUS UNKNOWN"

static func mode_label(room: Dictionary) -> String:
	if room.get("modeKnown", false) == true and not str(room.get("mode", "")).is_empty():
		return str(room.get("mode"))
	return "mode unknown"

static func map_label(room: Dictionary) -> String:
	var map_id := str(room.get("mapId", ""))
	return map_id if not map_id.is_empty() else "map unknown"

static func room_label(room: Dictionary) -> String:
	return "%s / %s · %s · %s" % [map_label(room), mode_label(room), players_label(room), status_label(room)]

# Room-scoped chat line normalized for display. `self_peer` tags the local
# player's own line (still sourced only from the authority's broadcast).
static func chat_line(frame: Dictionary, self_peer: int) -> Dictionary:
	var raw_peer: Variant = frame.get("peerId")
	var peer := int(raw_peer) if (raw_peer is int or raw_peer is float) and is_finite(float(raw_peer)) else -1
	var text := sanitize(frame.get("text"), CHAT_TEXT_LIMIT)
	if text.is_empty(): return {}
	return {
		"peerId": peer,
		"name": sanitize(frame.get("name"), CHAT_NAME_LIMIT),
		"text": text,
		"self": peer >= 0 and peer == self_peer,
	}

static func chat_log_label(line: Dictionary) -> String:
	var who := str(line.get("name", ""))
	if who.is_empty(): who = "Player"
	var suffix := " · you" if line.get("self", false) == true else ""
	return "%s%s: %s" % [who, suffix, str(line.get("text", ""))]
