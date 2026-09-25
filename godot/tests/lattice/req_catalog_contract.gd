extends SceneTree
## Native contract for the source-mirrored REQ catalogue. Pure/deterministic:
## no network, no clock, no RNG, no GUI. The mirror comparison reads the
## tracked source table directly, so a source cost/copy/launch change fails this
## test instead of drifting silently.
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

func run() -> void:
	_mirror_source()
	_pure_options()
	print("LATTICE_REQ_CATALOG_CONTRACT checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

## Compare every mirrored field to the real tracked table in game/cocs-economy.mjs.
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
	var cost_re := RegEx.new(); cost_re.compile("cost:(\\d+)")
	var copy_re := RegEx.new(); copy_re.compile("effectCopy:'([^']*)'")
	var name_re := RegEx.new(); name_re.compile("name:'([^']*)'")
	var modes_re := RegEx.new(); modes_re.compile("modes:\\[([^\\]]*)\\]")
	check(Catalog.ITEMS.size() == 7, "mirror carries exactly the launched rows")
	for entry: Dictionary in Catalog.ITEMS:
		var id := str(entry.get("id"))
		var needle := "id:'" + id + "'"
		var occurrences := block.count(needle)
		check(occurrences == 1, "source has exactly one row for " + id)
		if occurrences != 1: continue
		# Each source row spans two lines; take the whole object so `effectCopy`
		# (second line) is compared too. `\n {` starts the next row.
		var start := block.find(needle)
		var next_start := block.find("\n {", start)
		if next_start < 0: next_start = block.length()
		var item_text := block.substr(start, next_start - start)
		var name_match := name_re.search(item_text)
		var cost_match := cost_re.search(item_text)
		var copy_match := copy_re.search(item_text)
		var modes_match := modes_re.search(item_text)
		check(name_match != null and name_match.get_string(1) == entry.get("name"), "name mirrored for " + id)
		check(cost_match != null and int(cost_match.get_string(1)) == int(entry.get("cost")), "cost mirrored for " + id)
		check(copy_match != null and copy_match.get_string(1) == entry.get("effectCopy"), "effectCopy mirrored for " + id)
		check(item_text.contains("launch:true") or item_text.contains("coopLaunch:true"), "source row is launched: " + id)
		var modes := models_modes(modes_match)
		check(same_modes(modes, entry.get("modes")), "modes mirrored for " + id)
		check(entry.get("personalBuff") == item_text.contains("personalBuff:true"), "personalBuff mirrored for " + id)
	# Rows without a shipped effect, and reserved FLUX ids, are never offered.
	for unsupported: String in ["at-mine", "smoke", "barrier", "sentry", "forward-depot", "supply-drop", "recon-pulse", "fortify-doctrine", "tier-upgrade", "oracle-unlock", "respawn", "reserve", "flux"]:
		check(Catalog.item(unsupported).is_empty(), "unsupported row absent: " + unsupported)

func models_modes(match: RegExMatch) -> Array[String]:
	if match == null: return parse_modes("")
	return parse_modes(match.get_string(1))

func same_modes(left: Array[String], right: Variant) -> bool:
	if not right is Array or left.size() != right.size(): return false
	for i: int in range(left.size()):
		if left[i] != str(right[i]): return false
	return true

func _pure_options() -> void:
	var base := {"mode":"cocs", "team":0, "req":100, "activeBuff":null, "depots":[], "depotsKnown":false}
	var rows := Catalog.options(base)
	check(rows.size() == 7, "all launched rows rendered")
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
