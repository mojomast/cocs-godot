extends RefCounted
## Pure social helpers for the native room browser and room-scoped chat.
##
## Nothing here touches the authority, the seat or the wire: it mirrors the
## source `sanitizeText` exactly (control strip, JS `trim`, 200 **UTF-16 unit**
## slice), normalizes the room summaries the server already advertises
## (`roomId`, `name`, `mapId`, `config.mode`, `players`, `started`), and formats
## them without ever guessing a value the authority did not send. Every untrusted
## field must already be a `String`; a non-string is dropped, never `str()`-cast
## into content. Display labels are plain strings so callers can render them in a
## plain `Label` (no BBCode/RichText parsing of untrusted names).

# Source `sanitizeText(value, 200)` ceiling (game/protocol.mjs) used by
# Room.chat, and the 32-char room-name slice used by RoomRegistry.create.
# These are UTF-16 code units, matching JavaScript `String.prototype.slice`.
const CHAT_TEXT_LIMIT := 200
const CHAT_NAME_LIMIT := 32
# Source Room.chat per-peer floor: messages inside 300 ms are dropped.
const CHAT_COOLDOWN_MS := 300
# Presentation bounds. The authority caps rooms at 64 (RoomRegistry).
const ROOM_ROWS_LIMIT := 24
const CHAT_LOG_LIMIT := 120

# ECMAScript `String.prototype.trim` whitespace + line terminators.
static func is_js_whitespace(code: int) -> bool:
	if code in [0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x20, 0xa0, 0x1680, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000, 0xfeff]:
		return true
	return code >= 0x2000 and code <= 0x200a

static func js_trim(text: String) -> String:
	var start := 0
	var end := text.length()
	while start < end and is_js_whitespace(text.unicode_at(start)): start += 1
	while end > start and is_js_whitespace(text.unicode_at(end - 1)): end -= 1
	return text.substr(start, end - start)

# JavaScript string length is UTF-16 code units; a supplementary codepoint (for
# example an emoji) costs two. GDScript `String.length()` counts codepoints.
static func utf16_length(text: String) -> int:
	var units := 0
	for index: int in text.length():
		units += 2 if text.unicode_at(index) > 0xffff else 1
	return units

# Slice to at most `max_units` UTF-16 units without splitting a codepoint.
static func truncate_utf16(text: String, max_units: int) -> String:
	var units := 0
	var kept := ""
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		var cost := 2 if code > 0xffff else 1
		if units + cost > max_units: break
		kept += text[index]
		units += cost
	return kept

# Exact mirror of the source sanitizer for one untrusted String value:
# `String(value).replace(/[\u0000-\u001f\u007f]/g, '').trim().slice(0, max)`.
# A non-String value yields "" (never a coerced "123"/"null").
static func sanitize(value: Variant, max_units: int) -> String:
	if not value is String: return ""
	var text: String = value
	var kept := ""
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		if code <= 0x1f or code == 0x7f: continue
		kept += text[index]
	return truncate_utf16(js_trim(kept), maxi(0, max_units))

# Normalize one authority room summary. Returns {} unless `roomId` is a non-empty
# String. Fields the authority omitted stay explicit unknowns:
#   players  == -1    -> count not advertised or not a whole number
#   started  == null  -> lifecycle not advertised
#   mode     == ""    -> config/mode not advertised (never inferred available)
static func normalize_room(record: Variant) -> Dictionary:
	if not record is Dictionary: return {}
	if not record.get("roomId") is String: return {}
	var room_id := sanitize(record.get("roomId"), 64)
	if room_id.is_empty(): return {}
	var players := -1
	var raw_players: Variant = record.get("players")
	if raw_players is int:
		players = int(raw_players)
	elif raw_players is float and is_finite(float(raw_players)) and float(raw_players) >= 0.0 and float(raw_players) == floorf(float(raw_players)):
		# Accept an integral JSON float; a fractional count stays unknown rather
		# than being floored into a fake availability.
		players = int(raw_players)
	var started: Variant = record.get("started")
	var config: Variant = record.get("config")
	var mode := ""
	var mode_known := false
	if config is Dictionary and config.get("mode") is String:
		mode = sanitize(config.get("mode"), 32)
		mode_known = true
	return {
		"roomId": room_id,
		"name": sanitize(record.get("name"), CHAT_NAME_LIMIT),
		"mapId": sanitize(record.get("mapId"), 64),
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

# Stable, locale-aware ordering. `key` is "players" or "name"; unknown keys fall
# back to name order. Ties break on the room code so a refresh never reshuffles.
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

# Case-insensitive search over the fields the browser shows: code, name, map,
# mode. An empty query keeps every room.
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
# player's own line. Non-string text/name are dropped/blank, never coerced; a
# fractional peer id is not a valid seat and never claims "self".
static func chat_line(frame: Dictionary, self_peer: int) -> Dictionary:
	if not frame.get("text") is String: return {}
	var text := sanitize(frame.get("text"), CHAT_TEXT_LIMIT)
	if text.is_empty(): return {}
	var raw_peer: Variant = frame.get("peerId")
	var peer := -1
	if raw_peer is int:
		peer = int(raw_peer)
	elif raw_peer is float and is_finite(float(raw_peer)) and float(raw_peer) == floorf(float(raw_peer)):
		peer = int(raw_peer)
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
