extends RefCounted
## Finite, source-mirrored personal REQUISITION (`REQ`) catalogue for the native
## client. This is a *mirror*, never an authority: gameplay rules stay in
## `game/cocs-economy.mjs` and `server/room.mjs`; the native UI only reads
## recipient-observed wire state to decide what it is allowed to *ask* for.
##
## Truth rule (WP1.3): only rows with a shipped simulation effect are offered.
## `ITEMS` is generated from the launched `REQ_ITEMS` rows in
## `game/cocs-economy.mjs` by
## `port/tools/native_lattice_req_catalog/export.mjs`. Do not edit the generated
## region by hand:
##
##     node port/tools/native_lattice_req_catalog/export.mjs
##
## The exporter fails closed on a launched row whose effect the native client
## cannot gate, and `godot/tests/lattice/req_catalog_contract.gd` fails while a
## source-launched row is not mirrored, so a new source row cannot drift in
## silently.
##
## This module performs no I/O, has no clock/RNG and mutates nothing.

## Native-only reason when the recipient-observed `REQ` balance is missing. The
## source `reqPurchaseOptions` always has authoritative actor state and never
## needs it; the native client may not, and must not treat a gap as zero.
const REASON_REQ_UNKNOWN := "req-unknown"

## Effect kinds the native client knows how to gate. Mirrors the exporter
## allowlist in `port/tools/native_lattice_req_catalog/source.mjs`; a row whose
## `effectKind` is not listed is refused rather than offered (fail-closed).
const KNOWN_EFFECT_KINDS := ["heal", "resupply", "haste", "shield", "spot", "repair-link", "vehicle"]

## >>> GENERATED REQ ITEMS — do not edit by hand
## Regenerate with: node port/tools/native_lattice_req_catalog/export.mjs
## Source: game/cocs-economy.mjs REQ_ITEMS (canonical sha256 1a1258e7a084d91dbeb5907854505a5551d9b7ff039c9d2b668aeeafe0a4f2a7).
const SOURCE_SHA256 := "1a1258e7a084d91dbeb5907854505a5551d9b7ff039c9d2b668aeeafe0a4f2a7"
const ITEMS: Array = [
	{"id":"field-repair","name":"Field Repair","category":"buff","cost":40,"personalBuff":true,"commanderOnly":false,"requiresRelay":false,"teamWide":false,"target":"self","modes":["cocs","cocs-coop"],"effectKind":"heal","launch":true,"coopLaunch":false,
		"effectCopy":"Heal 50 health (capped at max health)"},
	{"id":"ammo-crate","name":"Ammo Crate","category":"buff","cost":25,"personalBuff":true,"commanderOnly":false,"requiresRelay":false,"teamWide":false,"target":"self","modes":["cocs","cocs-coop"],"effectKind":"resupply","launch":true,"coopLaunch":false,
		"effectCopy":"Refill every finite weapon magazine to capacity"},
	{"id":"haste","name":"Haste","category":"buff","cost":35,"personalBuff":true,"commanderOnly":false,"requiresRelay":false,"teamWide":false,"target":"self","modes":["cocs","cocs-coop"],"effectKind":"haste","launch":true,"coopLaunch":false,
		"effectCopy":"15 s of Haste speed"},
	{"id":"overshield","name":"Overshield","category":"buff","cost":50,"personalBuff":true,"commanderOnly":false,"requiresRelay":false,"teamWide":false,"target":"self","modes":["cocs","cocs-coop"],"effectKind":"shield","launch":true,"coopLaunch":false,
		"effectCopy":"50-point temporary shield"},
	{"id":"spot-drone","name":"Spot Drone","category":"equipment","cost":45,"personalBuff":false,"commanderOnly":false,"requiresRelay":false,"teamWide":false,"target":"self","modes":["cocs","cocs-coop"],"effectKind":"spot","launch":true,"coopLaunch":false,
		"effectCopy":"Mark every enemy within 20 m for 8 s (+15% damage from your team)"},
	{"id":"repair-tool","name":"Repair Tool","category":"equipment","cost":30,"personalBuff":false,"commanderOnly":false,"requiresRelay":false,"teamWide":false,"target":"cut-link","modes":["cocs","cocs-coop"],"effectKind":"repair-link","launch":true,"coopLaunch":false,
		"effectCopy":"Restore one friendly cut link within reach (nearest wins)"},
	{"id":"puma","name":"Puma Light Transport","category":"vehicle","cost":150,"personalBuff":false,"commanderOnly":false,"requiresRelay":false,"teamWide":false,"target":"depot","modes":["cocs-coop"],"effectKind":"vehicle","launch":false,"coopLaunch":true,
		"effectCopy":"Spawn the depot loaner Puma at an owned depot"},
]
## <<< END GENERATED REQ ITEMS

## Canonical wire mode id (`cocs` | `cocs-coop`), or "" when unknown. Aliases
## mirror `reqModeKey` in the source so a caller cannot guess wrong.
static func mode_key(mode: Variant) -> String:
	if not mode is String: return ""
	match mode.strip_edges().to_lower():
		"cocs", "cocs-pvp", "pvp", "pvpve": return "cocs"
		"cocs-coop", "coop", "operations": return "cocs-coop"
	return ""

## Deep copy of one catalogue row, or `{}` when the id is not offered.
static func item(id: String) -> Dictionary:
	for entry: Dictionary in ITEMS:
		if entry.get("id") == id: return entry.duplicate(true)
	return {}

## True when this mirror carries an effect kind the native gate understands. A
## generated row with an unknown kind (possible only if the exporter allowlist
## was bypassed) stays refused instead of becoming payable.
static func effect_supported(entry: Dictionary) -> bool:
	return KNOWN_EFFECT_KINDS.has(str(entry.get("effectKind", "")))

## The active personal-buff id, or "" when the observed slot is empty/not a
## buff. Mirrors `reqItem(a.reqBuff)?.personalBuff === true` in the source: a
## vehicle/legacy id stamped on the slot never blocks a personal buff.
static func active_buff_id(value: Variant) -> String:
	if not value is String: return ""
	for entry: Dictionary in ITEMS:
		if entry.get("id") == value and entry.get("personalBuff") == true: return str(value)
	return ""

## Depot ids this team owns in the recipient-observed traversal list. Missing or
## malformed entries are skipped, never assumed owned. Sorted, pure.
static func owned_depot_ids(depots: Variant, team: int) -> Array[String]:
	var out: Array[String] = []
	if not depots is Array: return out
	for depot: Variant in depots:
		if not depot is Dictionary: continue
		var id: Variant = depot.get("id")
		if not id is String: continue
		var owner: Variant = depot.get("owner")
		if not _finite(owner): continue
		if int(owner) != team: continue
		if not out.has(str(id)): out.append(str(id))
	out.sort()
	return out

## Pure per-row refusal reason for one catalogue `entry` and recipient `ctx`.
## Exposed separately so the commander/relay/puma gates are unit-testable even
## when the shipped table has no such row. Precedence mirrors
## `reqPurchaseOptions`: wrong-mode -> puma depot -> unsupported effect ->
## commander-only -> one-active-buff -> requires-relay -> balance.
static func entry_reason(entry: Dictionary, ctx: Dictionary) -> String:
	var key := mode_key(ctx.get("mode"))
	var modes: Array = entry.get("modes", [])
	if key.is_empty() or not modes.has(key): return "wrong-mode"
	var id := str(entry.get("id"))
	if id == "puma":
		if ctx.get("depotsKnown") != true: return "depot-unknown"
		if owned_depot_ids(ctx.get("depots"), _team(ctx)).is_empty(): return "requires-depot"
	if not effect_supported(entry): return "unsupported-effect"
	if entry.get("commanderOnly") == true and ctx.get("isCommander") != true: return "commander-only"
	var active := active_buff_id(ctx.get("activeBuff"))
	if entry.get("personalBuff") == true and not active.is_empty() and active != id: return "one-active-buff"
	if entry.get("requiresRelay") == true and ctx.get("relayOwned") != true: return "requires-relay"
	if not _finite(ctx.get("req")): return REASON_REQ_UNKNOWN
	if float(ctx.get("req")) < float(int(entry.get("cost"))): return "insufficient-req"
	return ""

## One pure, deterministic option list for a recipient. `ctx` keys:
##   mode         String    wire mode (aliases accepted)
##   team         number    recipient team
##   req          number   recipient-observed REQ balance, or null when unknown
##   activeBuff   String?   recipient-observed `actor.reqBuff`
##   depots       Array     recipient-observed traversal depots
##   depotsKnown  bool      true only when the wire carried a depot list
##   isCommander  bool      recipient-observed command seat for this actor
##   relayOwned   bool      recipient-observed own-team relay node
##
## The native `req-unknown` reason replaces `insufficient-req` when the balance
## is absent, so a gap is never rendered as an unaffordable zero. A missing
## commander/relay observation stays false and refuses, never assumed.
static func options(ctx: Dictionary) -> Array[Dictionary]:
	var balance_known := _finite(ctx.get("req"))
	var balance := float(ctx.get("req")) if balance_known else 0.0
	var out: Array[Dictionary] = []
	for entry: Dictionary in ITEMS:
		var reason := entry_reason(entry, ctx)
		var cost := int(entry.get("cost"))
		var modes: Array = entry.get("modes", [])
		out.append({
			"id":str(entry.get("id")), "name":str(entry.get("name")), "category":str(entry.get("category")),
			"cost":cost, "target":str(entry.get("target", "self")), "modes":modes.duplicate(),
			"effectCopy":str(entry.get("effectCopy")), "personalBuff":entry.get("personalBuff") == true,
			"affordable":balance_known and balance >= float(cost),
			"enabled":reason.is_empty(), "disabledReason":reason,
		})
	return out

## Player-facing copy for a native disabled reason. Unknown reasons degrade to a
## generic refusal rather than a false specific claim.
static func reason_text(reason: String) -> String:
	match reason:
		"wrong-mode": return "Not available in this mode"
		"depot-unknown": return "Depot ownership unknown; purchase disabled"
		"requires-depot": return "Requires an owned depot"
		"unsupported-effect": return "Item effect not implemented in the native client; purchase disabled"
		"commander-only": return "Commander seat required"
		"one-active-buff": return "Another personal buff is already active"
		"requires-relay": return "Requires an owned relay"
		"req-unknown": return "Own REQ unknown; purchase disabled"
		"insufficient-req": return "Insufficient REQ"
	return "REQ purchase unavailable"

static func _team(ctx: Dictionary) -> int:
	if _finite(ctx.get("team")): return int(ctx.get("team"))
	return -1

static func _finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
