extends RefCounted
## Pure, read-only projection of a source-confirmed career profile into the
## user-facing "saved loadout" overview.
##
## This model never reads live actor state, never reverse-resolves resolved
## modifiers back into item names, never balances stats and never stores a
## credential. The caller passes the **confirmed** profile (the one the source
## acknowledged) plus the shipped catalog; only then can a slot claim a readable
## name.
##
## The saved loadout applies to the **next** match. The current match actor is
## constructed once from the profile at round start; a mid-match GEAR write only
## updates the profile. The source `gear`/`attachments` maps carry item IDs, so
## the saved overview can name them. The live actor carries resolved modifiers,
## not IDs, so this model never claims an "effective current item". The only
## current-vs-saved distinction it can make is an optional finish snapshot the
## parent may expose (a cosmetic is an ID on both sides); without that hook the
## finish is reported as saved-for-next-match only.
##
## States per slot:
##   equipped   - the field is known and the slot names a catalog item
##   stock      - the field is known and the slot is absent from it (the source
##                emits only equipped slots, so absence means unselected)
##   unknown    - the field itself is missing/malformed (source never said), or
##                the slot holds a null/non-string value
##   unknown-id - the slot names an ID the catalog cannot resolve (bounded label)
## A known empty map ("{}") makes every slot `stock`. A missing/omitted field
## leaves every slot `unknown`, never an invented empty or stock value.

const GEAR_SLOTS := ["primary", "armor", "utility"]
const ATTACHMENT_SLOTS := ["optic", "barrel", "magazine", "underbarrel"]
const SLOT_LABELS := {
	"primary": "Primary", "armor": "Armor", "utility": "Utility",
	"optic": "Optic", "barrel": "Barrel", "magazine": "Magazine", "underbarrel": "Underbarrel",
}
const STATE_EQUIPPED := "equipped"
const STATE_STOCK := "stock"
const STATE_UNKNOWN := "unknown"
const STATE_UNKNOWN_ID := "unknown-id"
const MAX_ID := 64
const MAX_NAME := 128

static func slots_for(kind: String) -> Array:
	return GEAR_SLOTS if kind == "gear" else ATTACHMENT_SLOTS

static func slot_label(slot: String) -> String:
	return str(SLOT_LABELS.get(slot, slot.capitalize()))

## Source catalog name for one (kind, slot, id). Empty when the ID is not a
## known catalog item; callers report that as a bounded unknown ID, never stock.
static func catalog_name(catalog: Dictionary, kind: String, slot: String, id: String) -> String:
	if id.is_empty(): return ""
	for item: Variant in catalog.get("items", []):
		if not item is Dictionary: continue
		if str(item.get("kind", "")) != kind: continue
		if str(item.get("id", "")) != id: continue
		if kind == "gear" or kind == "attachment":
			if str(item.get("slot", "")) != slot: continue
		return str(item.get("name", "")).left(MAX_NAME)
	return ""

static func slot_entry(known: bool, map: Dictionary, catalog: Dictionary, kind: String, slot: String) -> Dictionary:
	var entry := {"slot": slot, "label": slot_label(slot)}
	if not known:
		entry.state = STATE_UNKNOWN
		return entry
	if not map.has(slot):
		entry.state = STATE_STOCK
		return entry
	var id: Variant = map[slot]
	if not id is String or id.is_empty():
		entry.state = STATE_UNKNOWN
		return entry
	var bounded: String = id.left(MAX_ID)
	var resolved: String = catalog_name(catalog, kind, slot, bounded)
	if resolved.is_empty():
		entry.state = STATE_UNKNOWN_ID
		entry.id = bounded
		return entry
	entry.state = STATE_EQUIPPED
	entry.id = bounded
	entry.name = resolved
	return entry

## Saved finish plus an optional live-actor finish. `current` is null unless the
## parent exposed an actor snapshot; a snapshot only ever carries a cosmetic ID,
## so this is the one place a current-vs-saved split is honest. Unknown IDs stay
## literal; a missing saved field is `unknown`, an explicit null is `stock`.
static func finish_entry(profile: Dictionary, catalog: Dictionary, current: Variant = null) -> Dictionary:
	var entry := {"slot": "finish", "label": "Finish"}
	if not profile.has("finish"):
		entry.state = STATE_UNKNOWN
	else:
		var saved: Variant = profile.get("finish")
		if saved == null:
			entry.state = STATE_STOCK
		elif saved is String and not str(saved).is_empty():
			var id: String = str(saved).left(MAX_ID)
			var resolved: String = catalog_name(catalog, "finish", "", id)
			if resolved.is_empty():
				entry.state = STATE_UNKNOWN_ID
				entry.id = id
			else:
				entry.state = STATE_EQUIPPED
				entry.id = id
				entry.name = resolved
		else:
			entry.state = STATE_UNKNOWN
	if current is Dictionary:
		entry.current = current_finish_entry(catalog, current)
	return entry

static func current_finish_entry(catalog: Dictionary, snapshot: Dictionary) -> Dictionary:
	var entry := {"label": "Current match"}
	if not snapshot.has("finish"):
		entry.state = STATE_UNKNOWN
		return entry
	var value: Variant = snapshot.get("finish")
	if value == null:
		entry.state = STATE_STOCK
		return entry
	if not value is String or str(value).is_empty():
		entry.state = STATE_UNKNOWN
		return entry
	var id: String = str(value).left(MAX_ID)
	var resolved: String = catalog_name(catalog, "finish", "", id)
	if resolved.is_empty():
		entry.state = STATE_UNKNOWN_ID
		entry.id = id
		return entry
	entry.state = STATE_EQUIPPED
	entry.id = id
	entry.name = resolved
	return entry

## Compose the saved overview. `profile` is the confirmed source projection and
## `catalog` the shipped source catalog. `current` is either null (no actor hook)
## or a parent snapshot dictionary such as {"finish": <id|null>}.
static func summary(profile: Dictionary, catalog: Dictionary, current: Variant = null) -> Dictionary:
	var out := {"ready": not profile.is_empty(), "fields": {}, "finish": {}}
	for kind: String in ["gear", "attachment"]:
		var key: String = "gear" if kind == "gear" else "attachments"
		var known: bool = profile.get(key) is Dictionary
		var map: Dictionary = profile[key] if known else {}
		var entries := {}
		for slot: String in slots_for(kind):
			entries[slot] = slot_entry(known, map, catalog, kind, slot)
		out.fields[key] = entries
	out.finish = finish_entry(profile, catalog, current)
	return out

static func entry_text(entry: Dictionary) -> String:
	var state := str(entry.get("state", ""))
	if state == STATE_EQUIPPED: return str(entry.get("name", "Unknown"))
	if state == STATE_UNKNOWN_ID: return "Unknown item (" + str(entry.get("id", "")).left(MAX_ID) + ")"
	if state == STATE_STOCK: return "Stock / unselected"
	return "Unknown"

static func finish_text(entry: Dictionary) -> String:
	if str(entry.get("state", "")) == STATE_STOCK: return "Stock / none"
	return entry_text(entry)

static func field_text(summary: Dictionary, key: String) -> String:
	var entries: Dictionary = summary.get("fields", {}).get(key, {})
	var parts := []
	for slot: String in entries:
		parts.append("%s: %s" % [str(entries[slot].get("label", slot)), entry_text(entries[slot])])
	return " · ".join(parts)

## One bounded, human-readable line for a header or pre-match summary. Equipped
## items are named, stock slots are omitted, unresolved IDs stay literal and an
## all-stock saved loadout says so rather than rendering as empty.
static func short_line(summary: Dictionary) -> String:
	if not summary.get("ready", false): return "Unknown (not connected)"
	var parts: Array = []
	var stock_only := true
	for key: String in ["gear", "attachments"]:
		var entries: Dictionary = summary.get("fields", {}).get(key, {})
		for slot: String in entries:
			var entry: Dictionary = entries[slot]
			var state := str(entry.get("state", ""))
			if state == STATE_EQUIPPED:
				parts.append(str(entry.get("name", "Unknown")))
				stock_only = false
			elif state == STATE_UNKNOWN_ID:
				parts.append("Unknown item (" + str(entry.get("id", "")).left(MAX_ID) + ")")
				stock_only = false
			elif state == STATE_UNKNOWN:
				parts.append("Unknown")
				stock_only = false
	var finish: Dictionary = summary.get("finish", {})
	var finish_state := str(finish.get("state", ""))
	if finish_state == STATE_EQUIPPED:
		parts.append(str(finish.get("name", "Unknown")))
		stock_only = false
	elif finish_state == STATE_UNKNOWN_ID:
		parts.append("Unknown finish (" + str(finish.get("id", "")).left(MAX_ID) + ")")
		stock_only = false
	elif finish_state == STATE_UNKNOWN:
		parts.append("Unknown finish")
		stock_only = false
	if parts.is_empty():
		return "Stock / unselected" if stock_only else "Unknown"
	return " · ".join(parts)
