extends RefCounted
## Pure snapshot projection; never advances gameplay or retains stale authority.
var state: Dictionary = {}
var text := "Waiting for Horde authority"
## Pending-offer projection. `singleplayer.upgrades` in the source snapshot is
## the live offer (singlePlayerSnapshot maps pendingUpgrade.choices through
## hordeUpgradeInfo), never the run's applied upgrades: upgradeCount is the
## applied total and upgradeSelected is the last authoritative pick. The offer
## is projected from wherever the source publishes it, intermission or wave.
var offers: Array[Dictionary] = []
var offer_pending := false
var offer_wave := 0
var applied_count := 0
var selected_id := ""
const OFFER_ROWS := 9
const CHOICE_CHARS := 64
const ROW_NAME_CHARS := 64
const ROW_DESCRIPTION_CHARS := 160

func clear() -> void:
	state.clear()
	text = "Waiting for Horde authority"
	offers.clear()
	offer_pending = false
	offer_wave = 0
	applied_count = 0
	selected_id = ""

static func number(value: Variant, fallback: float = 0.0) -> float:
	return float(value) if (value is int or value is float) and is_finite(float(value)) else fallback

## JSON numbers may arrive as int or float; only exact integers are accepted.
static func wire_int(value: Variant, fallback: int = 0) -> int:
	if value is int: return value
	if value is float and is_finite(value) and floorf(value) == value: return int(value)
	return fallback

## Control characters are never rendered; overlong values are refused, not cut.
static func clean_text(value: Variant, limit: int) -> String:
	if not value is String: return ""
	var source: String = value
	var cleaned := ""
	for index in source.length():
		var code := source.unicode_at(index)
		if code < 32 or code == 127: return ""
		cleaned += source[index]
		if cleaned.length() > limit: return ""
	return cleaned

func project_offer(raw: Dictionary) -> void:
	offers.clear()
	offer_pending = false
	offer_wave = 0
	applied_count = maxi(0, wire_int(raw.get("upgradeCount"), 0))
	selected_id = clean_text(raw.get("upgradeSelected"), CHOICE_CHARS)
	offer_wave = maxi(0, wire_int(raw.get("upgradeWave"), 0))
	var rows: Variant = raw.get("upgrades")
	if not rows is Array: return
	var seen := {}
	for row: Variant in rows:
		if offers.size() >= OFFER_ROWS: break
		if not row is Dictionary: continue
		var id := clean_text(row.get("id"), CHOICE_CHARS)
		if id.is_empty() or seen.has(id): continue
		seen[id] = true
		offers.append({
			"id":id,
			"name":clean_text(row.get("name"), ROW_NAME_CHARS),
			"description":clean_text(row.get("description"), ROW_DESCRIPTION_CHARS),
		})
	offer_pending = not offers.is_empty()

func offer_id(index: int) -> String:
	if index < 1 or index > offers.size(): return ""
	return str(offers[index - 1].get("id", ""))

func offer_index(id: String) -> int:
	for index in offers.size():
		if str(offers[index].get("id", "")) == id: return index + 1
	return 0

## Handoff to the intent guards; the client owns the single-flight decision.
func offer_view() -> Dictionary:
	var ids: Array = []
	for row: Dictionary in offers: ids.append(str(row.get("id", "")))
	return {"pending":offer_pending, "wave":offer_wave, "ids":ids,
		"count":applied_count, "selected":selected_id}

func offer_line() -> String:
	var parts := PackedStringArray()
	for index in offers.size():
		var row: Dictionary = offers[index]
		var name: String = str(row.get("name", ""))
		parts.append("%d %s" % [index + 1, name if not name.is_empty() else str(row.get("id", ""))])
	return "UPGRADES · PICK 1..%d: %s" % [offers.size(), " · ".join(parts)]

func applied_line() -> String:
	var line := "UPGRADES APPLIED · %d" % applied_count
	if not selected_id.is_empty(): line += " · " + selected_id
	return line

func apply(snapshot: Dictionary, stale: bool = false) -> void:
	clear()
	if stale:
		text = "Horde snapshot stalled — release controls"
		return
	var raw: Variant = snapshot.get("singleplayer")
	if not raw is Dictionary or raw.get("kind") != "horde": return
	state = raw.duplicate(true)
	var phase: String = str(state.get("phase", "unknown"))
	var outcome := phase.to_upper()
	if phase == "won" and state.get("winner") != null and number(state.winner, -1) == 0: outcome = "VICTORY"
	elif phase == "lost": outcome = "DEFEAT"
	elif phase == "intermission": outcome = "NEXT WAVE IN %ds" % int(ceil(number(state.get("waveTimer"))))
	text = "HORDE · WAVE %d / %d · %s\nENEMIES %d / %d · LIVES %d · SCORE %d" % [int(number(state.get("wave"))), int(number(state.get("waveTarget"))), outcome, int(number(state.get("enemiesAlive"))), int(number(state.get("enemiesTotal"))), int(number(state.get("lives"))), int(number(state.get("score")))]
	var modifier: Variant = state.get("waveModifier")
	if modifier is Dictionary: text += " · " + str(modifier.get("name", ""))
	var boss: Variant = state.get("boss")
	if boss is Dictionary and boss.get("alive") == true:
		text += "\n%s · HP %d/%d · PHASE %d" % [str(boss.get("name", "Boss")), int(number(boss.get("hp"))), int(number(boss.get("maxHp"))), int(number(boss.get("phase")))]
	project_offer(state)
	if offer_pending: text += "\n" + offer_line()
	if applied_count > 0 or not selected_id.is_empty(): text += "\n" + applied_line()
	if snapshot.get("over") == true: text += "\nEnter: restart · release held controls, then click to engage"
