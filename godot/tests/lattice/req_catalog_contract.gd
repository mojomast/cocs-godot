extends SceneTree
## Native contract for the source-mirrored REQ catalogue. Pure/deterministic:
## no network, no clock, no RNG, no GUI. `_mirror_source()` parses the tracked
## `game/cocs-economy.mjs` `REQ_ITEMS` block and requires an exact bidirectional
## match with the generated mirror, so a source lane that launches a new row
## fails this contract until `port/tools/native_lattice_req_catalog/export.mjs`
## is re-run and reviewed.
const Catalog = preload("res://lattice/req_catalog.gd")

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func _initialize() -> void: call_deferred("run")

func expect_reason(rows: Array, id: String, reason: String, message: String) -> void:
	var found := false
	for candidate: Variant in rows:
		if candidate is Dictionary and candidate.get("id") == id:
			found = true
			check(candidate.get("enabled") != true and candidate.get("disabledReason") == reason, message + " (" + id + ")")
	if not found: check(false, "row present: " + id)

func find_row(rows: Array, id: String) -> Dictionary:
	for candidate: Variant in rows:
		if candidate is Dictionary and candidate.get("id") == id: return candidate
	return {}

func parse_modes(raw: String) -> Array[String]:
	var out: Array[String] = []
	for token: String in raw.replace(" ", "").split(","):
		var clean := token.strip_edges().trim_prefix("'").trim_suffix("'")
		if not clean.is_empty(): out.append(clean)
	return out

func capture(text: String, pattern: String) -> String:
	var regex := RegEx.new()
	if regex.compile(pattern) != OK: return ""
	var match := regex.search(text)
	return match.get_string(1) if match != null else ""

func run() -> void:
	var script: Script = load("res://lattice/req_catalog.gd") as Script
	if script == null or not script.can_instantiate():
		push_error("REQ catalogue script did not compile")
		quit(1)
		return
	_mirror_source()
	_pure_options()
	print("LATTICE_REQ_CATALOG_CONTRACT checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

## Parse the tracked `REQ_ITEMS` block into one dictionary per source row. The
## text shape is the same one the deterministic exporter cross-checks against an
## import, so a drift in either view fails there first.
func _source_rows(block: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var cursor := block.find("{id:'")
	while cursor >= 0:
		var next := block.find("\n {", cursor + 1)
		if next < 0: next = block.length()
		var chunk := block.substr(cursor, next - cursor)
		rows.append({
			"id":capture(chunk, "id:'([^']*)'"),
			"name":capture(chunk, "name:'([^']*)'"),
			"category":capture(chunk, "category:'([^']*)'"),
			"cost":int(capture(chunk, "cost:(\\d+)")),
			"effectCopy":capture(chunk, "effectCopy:'((?:[^'\\\\]|\\\\.)*)'"),
			"target":capture(chunk, "(?:^|[{,])target:'([^']*)'"),
			"modes":parse_modes(capture(chunk, "modes:\\[([^\\]]*)\\]")),
			"personalBuff":chunk.contains("personalBuff:true"),
			"commanderOnly":chunk.contains("commanderOnly:true"),
			"requiresRelay":chunk.contains("requiresRelay:true"),
			"teamWide":chunk.contains("teamWide:true"),
			"launch":chunk.contains("launch:true"),
			"coopLaunch":chunk.contains("coopLaunch:true"),
			"effectKind":capture(chunk, "effect:\\{kind:'([^']*)'"),
		})
		cursor = block.find("{id:'", next)
	return rows

func same_modes(left: Array, right: Variant) -> bool:
	if not right is Array or left.size() != right.size(): return false
	for i: int in range(left.size()):
		if str(left[i]) != str(right[i]): return false
	return true

func _mirror_source() -> void:
	var root := ProjectSettings.globalize_path("res://")
	var source_path := root.path_join("../game/cocs-economy.mjs").simplify_path()
	check(FileAccess.file_exists(source_path), "source economy table is readable at " + source_path)
	if not FileAccess.file_exists(source_path): return
	var text := FileAccess.get_file_as_string(source_path)
	var begin := text.find("export const REQ_ITEMS=deepFreeze([")
	var end := text.find("]);", begin)
	check(begin >= 0 and end > begin, "source REQ_ITEMS block located")
	if begin < 0 or end <= begin: return
	var block := text.substr(begin, end - begin)
	var source_rows := _source_rows(block)
	check(not source_rows.is_empty(), "source table parsed end to end")
	# Every offered row (non-empty modes, the source picker's filter) must be
	# launchable and vice versa; the native mirror must not paper over a source
	# inconsistency that would advertise an unpayable row.
	var launched_ids: Array[String] = []
	var offered_ids: Array[String] = []
	for row: Dictionary in source_rows:
		var modes: Array = row.get("modes", [])
		check((modes.size() > 0) == (row.get("launch") == true or row.get("coopLaunch") == true), "source offered/launched agree: " + str(row.get("id")))
		if row.get("launch") == true or row.get("coopLaunch") == true: launched_ids.append(str(row.get("id")))
		if modes.size() > 0: offered_ids.append(str(row.get("id")))
	# Bidirectional parity: a source row that launches a new effect must be
	# explicitly mirrored, and the mirror must carry no extra row.
	check(launched_ids.size() == Catalog.ITEMS.size(), "mirror size equals launched source rows")
	var mirror_ids: Array[String] = []
	for entry: Dictionary in Catalog.ITEMS: mirror_ids.append(str(entry.get("id")))
	for id: String in launched_ids:
		check(mirror_ids.has(id), "source launched row is mirrored: " + id)
	for id: String in mirror_ids:
		check(launched_ids.has(id), "mirror row is source-launched: " + id)
	for entry: Dictionary in Catalog.ITEMS:
		var id := str(entry.get("id"))
		var occurrences := block.count("id:'" + id + "'")
		check(occurrences == 1, "source has exactly one row for " + id)
		if occurrences != 1: continue
		check(Catalog.KNOWN_EFFECT_KINDS.has(str(entry.get("effectKind", ""))), "native-known effect kind: " + id)
		var source := {}
		for row: Dictionary in source_rows:
			if row.get("id") == id: source = row
		if source.is_empty(): continue
		check(str(source.get("name")) == str(entry.get("name")), "name mirrored for " + id)
		check(str(source.get("category")) == str(entry.get("category")), "category mirrored for " + id)
		check(int(source.get("cost")) == int(entry.get("cost")), "cost mirrored for " + id)
		check(str(source.get("effectCopy")) == str(entry.get("effectCopy")), "effectCopy mirrored for " + id)
		check(str(source.get("target")) == str(entry.get("target")), "target mirrored for " + id)
		check(same_modes(source.get("modes"), entry.get("modes")), "modes mirrored for " + id)
		check(source.get("personalBuff") == entry.get("personalBuff"), "personalBuff mirrored for " + id)
		check(source.get("commanderOnly") == entry.get("commanderOnly"), "commanderOnly mirrored for " + id)
		check(source.get("requiresRelay") == entry.get("requiresRelay"), "requiresRelay mirrored for " + id)
		check(source.get("teamWide") == entry.get("teamWide"), "teamWide mirrored for " + id)
		check(source.get("launch") == entry.get("launch") and source.get("coopLaunch") == entry.get("coopLaunch"), "launch flags mirrored for " + id)
		if not str(source.get("effectKind", "")).is_empty():
			check(str(source.get("effectKind")) == str(entry.get("effectKind")), "effect kind mirrored for " + id)
	# Rows without a shipped effect, and reserved FLUX ids, are never offered.
	for unsupported: String in ["at-mine", "smoke", "barrier", "forward-depot", "supply-drop", "fortify-doctrine", "tier-upgrade", "oracle-unlock", "respawn", "reserve", "flux"]:
		check(Catalog.item(unsupported).is_empty(), "unsupported row absent: " + unsupported)

func _pure_options() -> void:
	var base := {"mode":"cocs", "team":0, "req":100, "activeBuff":null, "depots":[], "depotsKnown":false}
	var rows := Catalog.options(base)
	check(rows.size() == Catalog.ITEMS.size(), "all launched rows rendered")
	check(find_row(rows, "field-repair").get("enabled") == true, "affordable buff enabled")
	check(find_row(rows, "field-repair").get("affordable") == true, "affordable flag from observed balance")
	# Mode gate: Puma is OPERATIONS-only.
	expect_reason(rows, "puma", "wrong-mode", "puma refused in PvP")
	# Unknown balance is never rendered as an unaffordable zero.
	var unknown := {"mode":"cocs", "team":0, "req":null, "activeBuff":null, "depots":[], "depotsKnown":false}
	expect_reason(Catalog.options(unknown), "field-repair", "req-unknown", "missing REQ stays unknown")
	check(find_row(Catalog.options(unknown), "field-repair").get("affordable") == false, "unknown balance is not affordable")
	# Insufficient balance uses the source reason.
	var poor := {"mode":"cocs", "team":0, "req":10, "activeBuff":null, "depots":[], "depotsKnown":false}
	expect_reason(Catalog.options(poor), "field-repair", "insufficient-req", "insufficient REQ refused")
	# One active buff blocks a different buff, not a refresh or equipment.
	var buffed := {"mode":"cocs", "team":0, "req":100, "activeBuff":"haste", "depots":[], "depotsKnown":false}
	var buff_rows := Catalog.options(buffed)
	expect_reason(buff_rows, "field-repair", "one-active-buff", "other buff refused")
	check(find_row(buff_rows, "haste").get("enabled") == true, "rebuying the same buff allowed")
	check(find_row(buff_rows, "spot-drone").get("enabled") == true, "equipment ignores the buff slot")
	# A non-buff `reqBuff` value (vehicle/legacy) never blocks a personal buff.
	var legacy := {"mode":"cocs", "team":0, "req":100, "activeBuff":"puma", "depots":[], "depotsKnown":false}
	check(find_row(Catalog.options(legacy), "field-repair").get("enabled") == true, "non-buff slot value does not block")
	# Puma depot gate: unknown -> unknown; none/enemy -> requires-depot; owned -> enabled.
	var coop := {"mode":"coop", "team":0, "req":200, "activeBuff":null, "depots":[], "depotsKnown":false}
	expect_reason(Catalog.options(coop), "puma", "depot-unknown", "missing depot list stays unknown")
	coop["depotsKnown"] = true
	expect_reason(Catalog.options(coop), "puma", "requires-depot", "no owned depot refused")
	coop["depots"] = [{"id":"depot-b","owner":1},{"id":"depot-a","owner":0}]
	check(find_row(Catalog.options(coop), "puma").get("enabled") == true, "owned depot enables puma")
	var owned := Catalog.owned_depot_ids(coop["depots"], 0)
	check(owned.size() == 1 and owned[0] == "depot-a", "only the recipient team's depots are owned")
	check(Catalog.owned_depot_ids(null, 0).is_empty(), "absent depot list owns nothing")
	# Mode aliases mirror the source.
	check(Catalog.mode_key("operations") == "cocs-coop" and Catalog.mode_key("pvpve") == "cocs", "mode aliases resolve")
	check(Catalog.mode_key("bogus") == "", "unknown mode stays unknown")
	check(Catalog.active_buff_id("overshield") == "overshield" and Catalog.active_buff_id("puma") == "" and Catalog.active_buff_id(null) == "", "buff slot filter mirror")
	# Commander/relay/effect gates are pure and fail closed. The shipped table
	# has no such launched row yet, so they are proven with synthetic entries.
	var commander := {"id":"cmp","name":"","category":"","cost":10,"personalBuff":false,"commanderOnly":true,"requiresRelay":false,"effectKind":"heal","target":"self","modes":["cocs"]}
	check(Catalog.entry_reason(commander, base) == "commander-only", "unobserved commander seat refuses")
	var command_ctx := base.duplicate(true); command_ctx["isCommander"] = true
	check(Catalog.entry_reason(commander, command_ctx).is_empty(), "observed commander seat allows")
	var relay := {"id":"relay-item","name":"","category":"","cost":10,"personalBuff":false,"commanderOnly":false,"requiresRelay":true,"effectKind":"heal","target":"self","modes":["cocs"]}
	check(Catalog.entry_reason(relay, base) == "requires-relay", "absent relay refuses")
	var relay_ctx := base.duplicate(true); relay_ctx["relayOwned"] = true
	check(Catalog.entry_reason(relay, relay_ctx).is_empty(), "owned relay allows")
	var unknown_effect := {"id":"future","name":"","category":"","cost":10,"personalBuff":false,"commanderOnly":false,"requiresRelay":false,"effectKind":"smoke","target":"self","modes":["cocs"]}
	check(Catalog.entry_reason(unknown_effect, base) == "unsupported-effect", "unknown effect kind refuses")
	check(Catalog.reason_text("unsupported-effect") != Catalog.reason_text("bogus-reason"), "unsupported-effect has specific copy")
