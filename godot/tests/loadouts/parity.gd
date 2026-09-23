extends SceneTree
# Cross-language parity gate: the native mirror of the operator/harness table and
# its normalization is compared against the actual Node source for every one of
# the 9 x 7 pairs. Node reads game/data.mjs read-only; nothing is written.
const Loadout = preload("res://ui/loadout.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("LOADOUT_PARITY " + message)

func _initialize() -> void: call_deferred("run")

func source_url() -> String:
	return "file://" + (ProjectSettings.globalize_path("res://") + "../game/data.mjs").simplify_path()

func run() -> void:
	var data_uri := source_url()
	var script := "const m=await import('" + data_uri + "');" \
		+ "const out={characters:m.CHARACTERS.map(c=>({id:c.id,name:c.name}))," \
		+ "harnesses:m.HARNESSES.map(h=>({id:h.id,name:h.name,power:h.power,stat:h.stat})),pairs:[]};" \
		+ "for(const c of m.CHARACTERS)for(const h of m.HARNESSES)" \
		+ "out.pairs.push({character:c.id,harness:h.id,resolved:m.resolveLoadout(c.id,h.id),valid:m.validLoadout(c.id,h.id)});" \
		+ "process.stdout.write(JSON.stringify(out));"
	var output: Array = []
	var code: int = OS.execute("node", ["--input-type=module", "-e", script], output, true)
	check(code == 0, "node source query exit code " + str(code) + " stderr=" + str(output.slice(1)))
	if code != 0:
		print("PORT_LOADOUT_PARITY_FAILED node_exit=", code, " checks=", checks, " failures=", failures)
		quit(1)
		return
	var value: Variant = JSON.parse_string(str(output[0]))
	check(value is Dictionary, "node table parsed")
	if not value is Dictionary:
		print("PORT_LOADOUT_PARITY_FAILED parse checks=", checks, " failures=", failures)
		quit(1)
		return
	var source: Dictionary = value
	var characters: Array = source.characters
	var harnesses: Array = source.harnesses
	check(characters.size() == 9 and harnesses.size() == 7, "source roster sizes 9/7")
	check(Loadout.CHARACTERS.size() == characters.size(), "mirrored operators match source size")
	check(Loadout.HARNESSES.size() == harnesses.size(), "mirrored harnesses match source size")
	for index: int in mini(characters.size(), Loadout.CHARACTERS.size()):
		var source_entry: Dictionary = characters[index]
		var mirror: Dictionary = Loadout.CHARACTERS[index]
		check(mirror.id == source_entry.id and mirror.name == source_entry.name, "operator parity index " + str(index) + " " + str(source_entry.id))
	for index: int in mini(harnesses.size(), Loadout.HARNESSES.size()):
		var source_entry: Dictionary = harnesses[index]
		var mirror: Dictionary = Loadout.HARNESSES[index]
		check(mirror.id == source_entry.id and mirror.name == source_entry.name and mirror.power == source_entry.power and mirror.stat == source_entry.stat, "harness parity index " + str(index) + " " + str(source_entry.id))
	var pairs: Array = source.pairs
	check(pairs.size() == 63, "source exposed all 63 pairs")
	var mismatches: Array = []
	var valid_pairs: Array = []
	for pair: Dictionary in pairs:
		var resolved: Dictionary = Loadout.resolve(pair.character, pair.harness)
		if resolved.character != pair.resolved.character or resolved.harness != pair.resolved.harness:
			mismatches.append(pair.character + "/" + pair.harness)
		if bool(pair.valid) != Loadout.valid(pair.character, pair.harness):
			mismatches.append("valid " + str(pair.character) + "/" + str(pair.harness))
		if bool(pair.valid): valid_pairs.append(pair.character + "/" + pair.harness)
	check(mismatches.is_empty(), "all 63 resolutions match source: " + str(mismatches))
	check(valid_pairs.size() == 57, "source marks 57 of 63 pairs valid (six claude pairs excluded): " + str(valid_pairs.size()))
	check(not valid_pairs.has("claude/hermes") and valid_pairs.has("claude/claudecode"), "claude lock visible in source table")
	# Unknown ids must resolve exactly like the source defaults.
	var bad: Dictionary = Loadout.resolve("bogus-model", "bogus-harness")
	check(bad.character == "chatgpt" and bad.harness == "openclaw", "unknown pair resolves to source defaults")
	print("PORT_LOADOUT_PARITY_OK checks=", checks, " failures=", failures, " pairs=", pairs.size())
	quit(1 if failures else 0)
