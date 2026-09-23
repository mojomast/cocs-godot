extends RefCounted
# Native mirror of the operator/harness identity authority in game/data.mjs.
# Data only: no scene tree, no popups and no engine UI classes. The source of
# truth stays the Node table; this helper only projects it for the native HUDs,
# the client transport and the session handshake.

const CHARACTERS := [
	{"id":"chatgpt", "name":"ChatGPT"},
	{"id":"claude", "name":"Claude"},
	{"id":"grok", "name":"Grok"},
	{"id":"meta", "name":"Meta"},
	{"id":"gemini", "name":"Gemini"},
	{"id":"deepseek", "name":"DeepSeek"},
	{"id":"mistral", "name":"Mistral"},
	{"id":"kimi", "name":"Kimi"},
	{"id":"qwen", "name":"Qwen"},
]
const HARNESSES := [
	{"id":"openclaw", "name":"OpenClaw", "power":"Claw Burst", "stat":"6m radius · 30 damage"},
	{"id":"hermes", "name":"Hermes", "power":"Courier Rush", "stat":"1.6× speed · 3.5 seconds"},
	{"id":"opencode", "name":"OpenCode", "power":"Parallel Burst", "stat":"1.82× fire rate · 3.5 seconds"},
	{"id":"claudecode", "name":"Claude Code", "power":"Guardrail", "stat":"50% resistance · 3.5 seconds"},
	{"id":"codex", "name":"Codex", "power":"Recompile", "stat":"+45 health · 16s cooldown"},
	{"id":"cline", "name":"Cline", "power":"Phase Step", "stat":"7m dash · 11s cooldown"},
	{"id":"roo", "name":"Roo Code", "power":"Context Jam", "stat":"8m radius · 50% slow"},
]
const CHARACTER_IDS := ["chatgpt", "claude", "grok", "meta", "gemini", "deepseek", "mistral", "kimi", "qwen"]
const HARNESS_IDS := ["openclaw", "hermes", "opencode", "claudecode", "codex", "cline", "roo"]
const DEFAULT_CHARACTER := "chatgpt"
const DEFAULT_HARNESS := "openclaw"
# Source rule: character!=='claude'||harness==='claudecode'
const LOCKED_CHARACTER := "claude"
const LOCKED_HARNESS := "claudecode"

static func has_character(id: Variant) -> bool:
	return id is String and id in CHARACTER_IDS

static func has_harness(id: Variant) -> bool:
	return id is String and id in HARNESS_IDS

static func character_name(id: Variant) -> String:
	for entry: Dictionary in CHARACTERS:
		if entry.id == id: return str(entry.name)
	return str(id)

static func harness_name(id: Variant) -> String:
	for entry: Dictionary in HARNESSES:
		if entry.id == id: return str(entry.name)
	return str(id)

static func harness_stat(id: Variant) -> String:
	for entry: Dictionary in HARNESSES:
		if entry.id == id: return str(entry.stat)
	return ""

# Strict source contract: both ids must exist and claude only pairs with claudecode.
static func valid(character: Variant, harness: Variant) -> bool:
	if not has_character(character) or not has_harness(harness): return false
	return not is_locked(character) or harness == LOCKED_HARNESS

static func problem(character: Variant, harness: Variant) -> String:
	if not has_character(character): return "Unknown operator: " + str(character)
	if not has_harness(harness): return "Unknown harness: " + str(harness)
	if is_locked(character) and harness != LOCKED_HARNESS:
		return "Claude is locked to Claude Code."
	return ""

static func is_locked(character: Variant) -> bool:
	return character is String and character == LOCKED_CHARACTER

static func locked_harness(character: Variant) -> String:
	return LOCKED_HARNESS if is_locked(character) else ""

# Source normalization: per-field fallback to the documented defaults, then the
# claude -> claudecode lock. Mirrors resolveLoadout exactly; never invalid.
static func resolve(character: Variant = DEFAULT_CHARACTER, harness: Variant = DEFAULT_HARNESS) -> Dictionary:
	var picked_character: String = character if has_character(character) else DEFAULT_CHARACTER
	var picked_harness: String = LOCKED_HARNESS if is_locked(character) else (harness if has_harness(harness) else DEFAULT_HARNESS)
	return {"character": picked_character, "harness": picked_harness}

static func label(character: Variant, harness: Variant) -> String:
	var pair: Dictionary = resolve(character, harness)
	return "%s · %s" % [character_name(pair.character), harness_name(pair.harness)]

# Roster rows come from the authority. A missing or empty identity falls back to
# the documented defaults; an unknown id stays visible instead of being hidden.
static func visible_id(value: Variant, fallback: String) -> String:
	if value is String and not (value as String).is_empty(): return value
	return fallback

static func player_label(player: Dictionary) -> String:
	var character := visible_id(player.get("character"), DEFAULT_CHARACTER)
	var harness := visible_id(player.get("harness"), DEFAULT_HARNESS)
	return "%s · %s" % [character_name(character), harness_name(harness)]
