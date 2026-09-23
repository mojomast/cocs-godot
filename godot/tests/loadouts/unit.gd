extends SceneTree
# RED-first lane test: native operator/harness identity table and normalization.
# The table must mirror game/data.mjs CHARACTERS / HARNESSES / validLoadout /
# resolveLoadout. Source files are read read-only; no value here is invented.
const Loadout = preload("res://ui/loadout.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("LOADOUT_UNIT " + message)

func _initialize() -> void: call_deferred("run")

func source_path() -> String:
	return (ProjectSettings.globalize_path("res://") + "../game/data.mjs").simplify_path()

func block(text: String, name: String) -> String:
	var start := text.find("export const " + name + " = [")
	if start < 0: return ""
	var end := text.find("];", start)
	if end <= start: return ""
	return text.substr(start, end - start)

static func entry_lines(section: String) -> Array:
	var out: Array = []
	for raw: String in section.split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("{id:'"): out.append(line)
	return out

static func field(line: String, key: String) -> String:
	var marker := key + ":'"
	var at := line.find(marker)
	if at < 0: return ""
	var from := at + marker.length()
	var to := line.find("'", from)
	if to < 0: return ""
	return line.substr(from, to - from)

func run() -> void:
	var path := source_path()
	check(FileAccess.file_exists(path), "source data.mjs readable at " + path)
	var text := "" if not FileAccess.file_exists(path) else FileAccess.get_file_as_string(path)
	check(not text.is_empty(), "source data.mjs not empty")

	# 1. Cross-check the mirrored table against the authoritative source lists.
	var source_characters := entry_lines(block(text, "CHARACTERS"))
	var source_harnesses := entry_lines(block(text, "HARNESSES"))
	check(source_characters.size() == 9, "source CHARACTERS count " + str(source_characters.size()))
	check(source_harnesses.size() == 7, "source HARNESSES count " + str(source_harnesses.size()))
	check(Loadout.CHARACTERS.size() == source_characters.size(), "mirrored operator count matches source")
	check(Loadout.HARNESSES.size() == source_harnesses.size(), "mirrored harness count matches source")
	for index: int in mini(Loadout.CHARACTERS.size(), source_characters.size()):
		var source_line: String = source_characters[index]
		check(Loadout.CHARACTERS[index].id == field(source_line, "id"), "operator id " + str(index) + " matches source")
		check(Loadout.CHARACTERS[index].name == field(source_line, "name"), "operator name " + str(index) + " matches source")
	for index: int in mini(Loadout.HARNESSES.size(), source_harnesses.size()):
		var source_line: String = source_harnesses[index]
		check(Loadout.HARNESSES[index].id == field(source_line, "id"), "harness id " + str(index) + " matches source")
		check(Loadout.HARNESSES[index].name == field(source_line, "name"), "harness name " + str(index) + " matches source")
		check(Loadout.HARNESSES[index].power == field(source_line, "power"), "harness power " + str(index) + " matches source")
		check(Loadout.HARNESSES[index].stat == field(source_line, "stat"), "harness stat " + str(index) + " matches source")
	var character_ids: Array = []
	for entry: Dictionary in Loadout.CHARACTERS: character_ids.append(entry.id)
	var harness_ids: Array = []
	for entry: Dictionary in Loadout.HARNESSES: harness_ids.append(entry.id)
	check(Loadout.CHARACTER_IDS == character_ids, "CHARACTER_IDS mirrors CHARACTERS order")
	check(Loadout.HARNESS_IDS == harness_ids, "HARNESS_IDS mirrors HARNESSES order")

	# The generated source-operator catalog is an independent in-repo projection of
	# the same source roster; every mirrored operator must exist there with its name.
	var generated: Script = load("res://source_operators/generated/catalog.gd")
	var operators: Dictionary = generated.OPERATORS if generated != null else {}
	check(operators.size() == Loadout.CHARACTERS.size(), "generated operator catalog count matches")
	for entry: Dictionary in Loadout.CHARACTERS:
		check(operators.has(entry.id), "generated catalog has operator " + str(entry.id))
		if operators.has(entry.id):
			check(operators[entry.id].name == entry.name, "generated catalog name for " + str(entry.id))

	# 2. The source normalization rules this lane mirrors must still exist as written.
	check(text.contains("export const validLoadout="), "source validLoadout present")
	check(text.contains("export const resolveLoadout="), "source resolveLoadout present")
	check(text.contains("character!=='claude'||harness==='claudecode'"), "source lock rule unchanged")
	check(text.contains("character==='claude'?'claudecode'"), "source resolve lock unchanged")
	var server := (ProjectSettings.globalize_path("res://") + "../server/room.mjs").simplify_path()
	var server_text := "" if not FileAccess.file_exists(server) else FileAccess.get_file_as_string(server)
	check(server_text.contains("character = 'chatgpt', harness = 'openclaw'"), "server join defaults unchanged")
	check(server_text.contains("resolveLoadout(character, harness)"), "server join resolves operator/harness")

	# 3. Helper semantics: defaults, resolution and invalidity.
	check(Loadout.DEFAULT_CHARACTER == "chatgpt" and Loadout.DEFAULT_HARNESS == "openclaw", "documented defaults")
	check(Loadout.LOCKED_CHARACTER == "claude" and Loadout.LOCKED_HARNESS == "claudecode", "documented lock pair")
	var defaults: Dictionary = Loadout.resolve()
	check(defaults.character == "chatgpt" and defaults.harness == "openclaw", "resolve() returns source defaults")
	check(Loadout.resolve("grok", "cline") == {"character":"grok", "harness":"cline"}, "valid pair resolves unchanged")
	check(Loadout.resolve("claude", "hermes") == {"character":"claude", "harness":"claudecode"}, "claude locks to claudecode")
	check(Loadout.resolve("chatgpt", "claudecode") == {"character":"chatgpt", "harness":"claudecode"}, "claudecode legal off claude")
	check(Loadout.resolve("bogus", "bogus") == {"character":"chatgpt", "harness":"openclaw"}, "unknown ids fall back to defaults")
	check(Loadout.resolve("bogus", "cline") == {"character":"chatgpt", "harness":"cline"}, "unknown operator keeps valid harness")
	check(Loadout.resolve(7, null) == {"character":"chatgpt", "harness":"openclaw"}, "non-string input falls back")
	check(Loadout.resolve("claude", "") == {"character":"claude", "harness":"claudecode"}, "empty harness locks for claude")

	check(Loadout.valid("chatgpt", "openclaw") and Loadout.valid("mistral", "roo"), "valid pairs accepted")
	check(not Loadout.valid("claude", "hermes") and not Loadout.valid("claude", "openclaw"), "claude pair rejected")
	check(Loadout.valid("claude", "claudecode"), "claude + claudecode accepted")
	check(not Loadout.valid("claude", "claudecode ") and not Loadout.valid(" chatgpt", "openclaw"), "whitespace ids rejected")
	check(not Loadout.valid("", "") and not Loadout.valid(null, null), "empty ids rejected")

	check(Loadout.problem("claude", "claudecode").is_empty(), "valid pair has no problem")
	check(not Loadout.problem("claude", "hermes").is_empty(), "locked pair reports a problem")
	check(not Loadout.problem("bogus", "openclaw").is_empty(), "unknown operator reports a problem")
	check(not Loadout.problem("chatgpt", "bogus").is_empty(), "unknown harness reports a problem")
	check(Loadout.locked_harness("claude") == "claudecode", "locked_harness reports claudecode for claude")
	check(Loadout.locked_harness("grok").is_empty(), "locked_harness empty for free operators")

	check(Loadout.character_name("deepseek") == "DeepSeek", "operator display name")
	check(Loadout.harness_name("claudecode") == "Claude Code", "harness display name")
	check(Loadout.character_name("future-model") == "future-model", "unknown operator name stays visible")
	check(Loadout.harness_name("future-harness") == "future-harness", "unknown harness name stays visible")
	check(Loadout.label("grok", "cline") == "Grok · Cline", "pair label")
	check(Loadout.player_label({"character":"deepseek", "harness":"hermes"}) == "DeepSeek · Hermes", "player row label")
	check(Loadout.player_label({}) == "ChatGPT · OpenClaw", "absent player row falls back to defaults")
	check(Loadout.player_label({"character":"kimi"}) == "Kimi · OpenClaw", "operator-only row keeps default harness")

	# 4. The helper is data only: no scene tree, no popups, no engine classes.
	var instance: Object = Loadout.new()
	check(instance is RefCounted and not instance is Node, "helper is a plain RefCounted, not a Node")
	print("PORT_LOADOUT_UNIT_OK checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
