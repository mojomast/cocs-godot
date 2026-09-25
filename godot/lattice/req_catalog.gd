extends RefCounted
## Finite, source-mirrored personal REQUISITION (`REQ`) catalogue for the native
## client. This is a *mirror*, never an authority: gameplay rules stay in
## `game/cocs-economy.mjs` and `server/room.mjs`; the native UI only reads
## recipient-observed wire state to decide what it is allowed to *ask* for.
##
## Truth rule (WP1.3): only rows with a shipped simulation effect are offered.
## Every row below is `launch:true` in both wire modes, or `coopLaunch:true`
## (the OPERATIONS depot Puma). Rows without an effect (`at-mine`, `smoke`,
## `barrier`, `sentry`, `forward-depot`, `supply-drop`, `recon-pulse`,
## `fortify-doctrine`, `tier-upgrade`, `oracle-unlock`) are deliberately absent;
## `godot/tests/lattice/req_catalog_contract.gd` fails if the source launches a
## row this table does not carry.
##
## `id` / `name` / `cost` / `effectCopy` / `modes` / `personalBuff` / `target`
## are compared against `game/cocs-economy.mjs` by that native contract test.
## The native-only gate reasons (`req-unknown`) exist because a recipient wire
## snapshot can omit authority that the local sim never omits; absence stays
## unknown and disabled rather than inferred as zero or ownership.
##
## This module performs no I/O, has no clock/RNG and mutates nothing.

## Native-only reason when the recipient-observed `REQ` balance is missing. The
## source `reqPurchaseOptions` always has authoritative actor state and never
## needs it; the native client may not, and must not treat a gap as zero.
const REASON_REQ_UNKNOWN := "req-unknown"

const ITEMS: Array = [
	{"id":"field-repair","name":"Field Repair","category":"buff","cost":40,"personalBuff":true,"commanderOnly":false,"requiresRelay":false,"target":"self","modes":["cocs","cocs-coop"],
		"effectCopy":"Heal 50 health (capped at max health)"},
	{"id":"ammo-crate","name":"Ammo Crate","category":"buff","cost":25,"personalBuff":true,"commanderOnly":false,"requiresRelay":false,"target":"self","modes":["cocs","cocs-coop"],
		"effectCopy":"Refill every finite weapon magazine to capacity"},
	{"id":"haste","name":"Haste","category":"buff","cost":35,"personalBuff":true,"commanderOnly":false,"requiresRelay":false,"target":"self","modes":["cocs","cocs-coop"],
		"effectCopy":"15 s of Haste speed"},
	{"id":"overshield","name":"Overshield","category":"buff","cost":50,"personalBuff":true,"commanderOnly":false,"requiresRelay":false,"target":"self","modes":["cocs","cocs-coop"],
		"effectCopy":"50-point temporary shield"},
	{"id":"spot-drone","name":"Spot Drone","category":"equipment","cost":45,"personalBuff":false,"commanderOnly":false,"requiresRelay":false,"target":"self","modes":["cocs","cocs-coop"],
		"effectCopy":"Mark every enemy within 20 m for 8 s (+15% damage from your team)"},
	{"id":"repair-tool","name":"Repair Tool","category":"equipment","cost":30,"personalBuff":false,"commanderOnly":false,"requiresRelay":false,"target":"cut-link","modes":["cocs","cocs-coop"],
		"effectCopy":"Restore one friendly cut link within reach (nearest wins)"},
	{"id":"puma","name":"Puma Light Transport","category":"vehicle","cost":150,"personalBuff":false,"commanderOnly":false,"requiresRelay":false,"target":"depot","modes":["cocs-coop"],
		"effectCopy":"Spawn the depot loaner Puma at an owned depot"},
]

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

## One pure, deterministic option list for a recipient. `ctx` keys:
##   mode         String    wire mode (aliases accepted)
##   team         number    recipient team
##   req          number   recipient-observed REQ balance, or null when unknown
##   activeBuff   String?   recipient-observed `actor.reqBuff`
##   depots       Array     recipient-observed traversal depots
##   depotsKnown  bool      true only when the wire carried a depot list
##
## Precedence mirrors `reqPurchaseOptions`: wrong-mode -> puma depot ->
## commander-only -> one-active-buff -> requires-relay -> balance. The native
## `req-unknown` reason replaces `insufficient-req` when the balance is absent,
## so a gap is never rendered as an unaffordable zero.
static func options(ctx: Dictionary) -> Array[Dictionary]:
	var key := mode_key(ctx.get("mode"))
	var team := -1
	if _finite(ctx.get("team")): team = int(ctx.get("team"))
	var balance_known := _finite(ctx.get("req"))
	var balance := float(ctx.get("req")) if balance_known else 0.0
	var active := active_buff_id(ctx.get("activeBuff"))
	var depots_known: bool = ctx.get("depotsKnown") == true
	var owned := owned_depot_ids(ctx.get("depots"), team)
	var out: Array[Dictionary] = []
	for entry: Dictionary in ITEMS:
		var id := str(entry.get("id"))
		var cost := int(entry.get("cost"))
		var modes: Array = entry.get("modes", [])
		var reason := ""
		if key.is_empty() or not modes.has(key): reason = "wrong-mode"
		elif id == "puma" and not depots_known: reason = "depot-unknown"
		elif id == "puma" and owned.is_empty(): reason = "requires-depot"
		elif entry.get("commanderOnly") == true: reason = "commander-only"
		elif entry.get("personalBuff") == true and not active.is_empty() and active != id: reason = "one-active-buff"
		elif entry.get("requiresRelay") == true: reason = "requires-relay"
		elif not balance_known: reason = REASON_REQ_UNKNOWN
		elif balance < float(cost): reason = "insufficient-req"
		out.append({
			"id":id, "name":str(entry.get("name")), "category":str(entry.get("category")),
			"cost":cost, "target":str(entry.get("target")), "modes":modes.duplicate(),
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
		"commander-only": return "Commander seat required"
		"one-active-buff": return "Another personal buff is already active"
		"requires-relay": return "Requires an owned relay"
		"req-unknown": return "Own REQ unknown; purchase disabled"
		"insufficient-req": return "Insufficient REQ"
	return "REQ purchase unavailable"

static func _finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
