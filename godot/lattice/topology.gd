extends RefCounted
## Authored LATTICE link topology and recipient-visible connection cues.
##
## The graph is static authored data (`source_map.nodes` + `source_map.lattice`,
## the same `arena.nodes`/`arena.lattice` the simulation reads) filtered by what
## the recipient can already see. The ownership/supply rules mirror the source:
## `connectedToHq`/`ownedSupplyNodes` (a node only pays while a same-team path
## links it back to a same-team HQ, and a cut breaks the chain behind it) and
## `capturableBy` (adjacency to owned ground plus a live node; ARRAY anchors
## stay outside this slice). Everything here is advisory: the Node authority
## decides every order, and a legal HOLD on owned ground is never re-judged by
## capture adjacency. No node, link, owner or cut is invented.
const CAPTURABLE := ["front", "economy", "relay"]
const ANCHORS := ["hq", "array"]
const MAX_NODES := 64
const MAX_EDGES := 128
const MAX_VISIBLE := 128
const MAX_CUTS := 64

var authored := false
var error := ""
var nodes: Dictionary = {}
var edges: Array = []
var adjacency: Dictionary = {}

func clear() -> void:
	authored = false
	error = ""
	nodes.clear()
	edges.clear()
	adjacency.clear()

func finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

## Parse an authored map. Invalid identity or unusable data refuses the whole
## map rather than drawing a partial guess.
func set_authored(source_map: Variant) -> bool:
	clear()
	if not source_map is Dictionary:
		error = "No authored map data"
		return false
	var raw_nodes: Variant = source_map.get("nodes")
	if not raw_nodes is Array or raw_nodes.is_empty():
		error = "Map authors no lattice nodes"
		return false
	for value: Variant in raw_nodes:
		if nodes.size() >= MAX_NODES: break
		if not value is Dictionary: continue
		var id: Variant = value.get("id")
		if not id is String or id.is_empty() or nodes.has(id): continue
		var archetype: Variant = value.get("archetype")
		var label: Variant = value.get("label")
		nodes[id] = {
			"id": id,
			"archetype": archetype if archetype is String and archetype in CAPTURABLE + ANCHORS else "",
			"label": label if label is String else "",
			"r": float(value.get("r")) if finite_number(value.get("r")) and float(value.get("r")) > 0.0 else 0.0,
			"x": float(value.get("x")) if finite_number(value.get("x")) else null,
			"z": float(value.get("z")) if finite_number(value.get("z")) else null,
		}
	if nodes.is_empty():
		error = "Map authors no usable lattice node"
		return false
	var seen := {}
	for raw: Variant in _edge_source(source_map):
		if edges.size() >= MAX_EDGES: break
		var pair := _edge_pair(raw)
		if pair.is_empty(): continue
		var a: String = pair[0]
		var b: String = pair[1]
		if a == b or not nodes.has(a) or not nodes.has(b): continue
		var key: String = a + "|" + b if a < b else b + "|" + a
		if seen.has(key): continue
		seen[key] = true
		edges.append([a, b] if a < b else [b, a])
	for id: String in nodes:
		adjacency[id] = []
	for link: Array in edges:
		(adjacency[link[0]] as Array).append(link[1])
		(adjacency[link[1]] as Array).append(link[0])
	authored = true
	return true

## `map.lattice` (bare or nested `edges`) with the authored `map.edges` spelling.
func _edge_source(source_map: Dictionary) -> Array:
	var lattice: Variant = source_map.get("lattice")
	if lattice is Array: return lattice
	if lattice is Dictionary and lattice.get("edges") is Array: return lattice.edges
	if source_map.get("edges") is Array: return source_map.edges
	return []

func _edge_pair(raw: Variant) -> Array:
	if raw is Array:
		if raw.size() != 2 or not raw[0] is String or not raw[1] is String: return []
		return [raw[0], raw[1]]
	if raw is Dictionary:
		if not raw.get("a") is String or not raw.get("b") is String: return []
		return [raw.a, raw.b]
	return []

func has_topology() -> bool:
	return authored and not edges.is_empty()

func topology_nodes() -> Array:
	var out: Array = nodes.keys()
	out.sort()
	return out

func archetype_of(id: String) -> String:
	return str(nodes[id].archetype) if nodes.has(id) else ""

func label_for(id: String, fallback: String = "") -> String:
	if nodes.has(id) and not str(nodes[id].label).is_empty(): return str(nodes[id].label)
	return fallback if not fallback.is_empty() else id

func neighbors_of(id: String) -> Array:
	var list: Variant = adjacency.get(id)
	return list if list is Array else []

## Authored links whose BOTH endpoints the recipient can currently see.
func visible_edges(visible_ids: Array) -> Array:
	var lookup := {}
	for value: Variant in visible_ids:
		if value is String and not lookup.has(value): lookup[value] = true
	var out: Array = []
	for link: Array in edges:
		if lookup.has(link[0]) and lookup.has(link[1]): out.append([link[0], link[1]])
	return out

func label_of(raw: Dictionary, id: String) -> String:
	var wire: Variant = raw.get("label")
	return label_for(id, wire if wire is String else "")

## A wire boolean is only true when it is exactly `true`: a mistyped field
## ("yes", 1, "0") stays false instead of aborting the projection.
func _flag(raw: Dictionary, key: String) -> bool:
	var value: Variant = raw.get(key)
	return value is bool and value == true

## Recipient-visible link/supply model. `team` is the recipient's own team
## (null/unknown leaves everything uncertified), `cuts` are the team-visible
## supply cuts the recipient already received. Only display fields survive.
func model(visible_nodes: Array, team: Variant = null, cuts: Array = []) -> Dictionary:
	var viewer: Variant = null
	if (team is int or team is float) and is_finite(float(team)) and (float(team) == 0.0 or float(team) == 1.0):
		viewer = int(float(team))
	var applied: Array = []
	var cut_set := {}
	for value: Variant in cuts:
		if applied.size() >= MAX_CUTS: break
		if not value is String or value.is_empty() or cut_set.has(value): continue
		cut_set[value] = true
		applied.append(value)
	var entries: Array = []
	var by_id := {}
	for value: Variant in visible_nodes:
		if entries.size() >= MAX_VISIBLE: break
		if not value is Dictionary: continue
		var id: Variant = value.get("id")
		if not id is String or id.is_empty() or by_id.has(id): continue
		var entry := _entry(id, value, viewer)
		by_id[id] = entry
		entries.append(entry)
	var complete: bool = authored
	if complete:
		for id: String in nodes:
			if not by_id.has(id): complete = false; break
	for entry: Dictionary in entries:
		var known: bool = nodes.has(entry.id)
		var has_owned := false
		var hidden := not known
		if known:
			for next: String in neighbors_of(entry.id):
				if not by_id.has(next): hidden = true
				elif by_id[next].mine: has_owned = true
		entry.reach = true if has_owned else (null if hidden else false)
		_certify(entry, viewer)
	# A visible owned HQ is the only proof of where supply comes from. Cutting
	# the HQ itself (or never seeing a friendly HQ) leaves the home line
	# unknowable, so it is reported unknown instead of a fabricated CUT OFF.
	var home_known: bool = not _owned_homes(by_id, viewer, cut_set).is_empty()
	var connected: Dictionary = _connected_owned(by_id, viewer, cut_set)
	# The connected set only proves a cut when it is authoritative: a complete
	# recipient view whose home line is certified by a visible uncut owned HQ.
	# Otherwise an own link is unknown, never a fabricated known cut.
	var certified: bool = complete and home_known
	var owned := 0
	var linked := 0
	var cut := 0
	for entry: Dictionary in entries:
		var staging := false
		if entry.mine:
			staging = connected.has(entry.id)
			owned += 1
			if staging: linked += 1
			elif certified: cut += 1
		elif entry.capture_legal and entry.reach == true:
			for next: String in neighbors_of(entry.id):
				if by_id.has(next) and by_id[next].mine and connected.has(next): staging = true
		entry.connected = staging
		if entry.archetype.is_empty(): entry.supply = "UNKNOWN"
		elif not entry.capturable: entry.supply = ""
		elif viewer == null: entry.supply = "UNKNOWN"
		elif entry.mine or entry.capture_legal: entry.supply = "LINKED" if staging else ("CUT OFF" if certified else "UNKNOWN")
		else: entry.supply = "BLOCKED"
	var link_entries: Array = []
	for link: Array in visible_edges(by_id.keys()):
		var first: Dictionary = by_id[link[0]]
		var second: Dictionary = by_id[link[1]]
		link_entries.append({"a": link[0], "b": link[1], "state": _edge_state(first, second, viewer, certified)})
	var next: Dictionary = {}
	for entry: Dictionary in entries:
		if not entry.capture_legal: continue
		if next.is_empty() or _better(entry, next): next = entry
	var hold: Dictionary = {}
	for entry: Dictionary in entries:
		if not entry.mine: continue
		if hold.is_empty() or (entry.connected and not hold.connected) or (entry.connected == hold.connected and entry.id < hold.id): hold = entry
	return {"authored": authored, "complete": complete, "team": viewer, "nodes": entries, "by_id": by_id,
		"edges": link_entries, "owned": owned, "linked": linked, "cut": cut, "cuts": applied,
		"next": next, "hold": hold, "source": "authored" if authored else "none"}

func _entry(id: String, raw: Dictionary, viewer: Variant) -> Dictionary:
	var owner: Variant = raw.get("owner")
	var team: Variant = null
	if owner is int or owner is float:
		if is_finite(float(owner)) and (float(owner) == 0.0 or float(owner) == 1.0): team = int(float(owner))
	var wire: Variant = raw.get("archetype")
	var archetype: String = wire if wire is String and wire in CAPTURABLE + ANCHORS else archetype_of(id)
	var progress: Variant = null
	var captured: Variant = raw.get("progress")
	if captured is Array and captured.size() == 2 and finite_number(captured[0]) and finite_number(captured[1]):
		progress = [clampf(float(captured[0]), 0.0, 1.0), clampf(float(captured[1]), 0.0, 1.0)]
	var capturable: bool = archetype in CAPTURABLE
	var mine: bool = viewer != null and team == viewer
	var live: bool = _flag(raw, "live") or (capturable and team != null)
	return {"id": id, "label": label_of(raw, id), "archetype": archetype, "known": nodes.has(id),
		"owner": team, "mine": mine, "enemy": viewer != null and team != null and team != viewer,
		"live": live, "contested": _flag(raw, "contested"), "progress": progress,
		"my_progress": float(progress[viewer]) if progress != null and viewer != null else 0.0,
		"enemy_progress": float(progress[1 - int(viewer)]) if progress != null and viewer != null else 0.0,
		"capturable": capturable, "reach": null, "connected": false, "capture_legal": false,
		"hold_legal": mine, "supply": ""}

## Adjacency-only capture legality (ARRAY anchors are deliberately outside this
## slice). Never applied to owned ground: a HOLD stays legal regardless.
func _certify(entry: Dictionary, viewer: Variant) -> void:
	entry.capture_legal = viewer != null and entry.capturable and not entry.mine and entry.live and entry.reach == true
	entry.hold_legal = entry.mine or entry.capture_legal

## Recipient-visible owned HQs that are not team-visible supply cuts.
func _owned_homes(by_id: Dictionary, viewer: Variant, cut_set: Dictionary) -> Array:
	var homes: Array = []
	if viewer == null: return homes
	for id: String in by_id:
		var entry: Dictionary = by_id[id]
		if entry.archetype == "hq" and entry.mine and not cut_set.has(id): homes.append(id)
	return homes

## Owned nodes that trace a same-team path home to an uncut owned HQ.
func _connected_owned(by_id: Dictionary, viewer: Variant, cut_set: Dictionary) -> Dictionary:
	var seen := {}
	var queue: Array = _owned_homes(by_id, viewer, cut_set)
	for id: String in queue: seen[id] = true
	while not queue.is_empty():
		var id: String = queue.pop_front()
		for next: String in neighbors_of(id):
			if seen.has(next) or cut_set.has(next) or not by_id.has(next) or not by_id[next].mine: continue
			seen[next] = true
			queue.append(next)
	return seen

func _better(candidate: Dictionary, current: Dictionary) -> bool:
	if candidate.connected != current.connected: return candidate.connected
	var rank := {"front": 0, "relay": 1, "economy": 2}
	var a: int = rank.get(candidate.archetype, 3)
	var b: int = rank.get(current.archetype, 3)
	if a != b: return a < b
	return candidate.id < current.id

## Three-valued own-link state: `certified` says whether the connected set is
## authoritative (complete view + certified home line). Without it two own nodes
## that are not provably linked are unknown, never a definite cut.
func _edge_state(first: Dictionary, second: Dictionary, viewer: Variant, certified: bool) -> String:
	if viewer == null: return "unknown"
	if first.mine and second.mine: return "linked" if first.connected and second.connected else ("severed" if certified else "unknown")
	if first.mine or second.mine: return "front"
	return "other"

## Advisory one-line cue for the selected objective or the next public target.
func guidance(model: Dictionary, selected_id: String = "") -> Dictionary:
	var result := {"code": "no-topology", "text": "", "target_id": "", "target_label": ""}
	if not model.get("authored", false):
		result.text = "Authored links unavailable for this map; List still shows every objective. The server decides orders."
		return result
	if model.nodes.is_empty():
		result.code = "no-nodes"
		result.text = "No positioned objectives received; nothing to link."
		return result
	if model.team == null:
		result.code = "no-team"
		result.text = "Links shown unowned until the server publishes your team; selection only."
		return result
	var by_id: Dictionary = model.by_id
	var mark := {"hq": "^", "front": "A", "relay": "O", "economy": "D"}
	# A selection the model cannot resolve (stale id, capped/malformed entry)
	# falls through to the ordinary cue instead of dereferencing an empty entry.
	var chosen: Variant = by_id.get(selected_id)
	if not selected_id.is_empty() and chosen is Dictionary and not (chosen as Dictionary).is_empty():
		var entry: Dictionary = chosen
		var symbol: String = mark.get(entry.archetype, "*")
		result.code = "selected"
		result.target_id = entry.id
		result.target_label = entry.label
		if entry.mine:
			result.text = "Selected %s %s: HOLD available - supply %s%s. Server decides." % [symbol, entry.label,
				entry.supply if not entry.supply.is_empty() else "not applicable",
				", line cut from your HQ - reconnect or fall back" if entry.supply == "CUT OFF" else ""]
		elif entry.capture_legal:
			result.text = "Selected %s %s: capture legal - %s%s. Server decides." % [symbol, entry.label,
				"linked to your HQ" if entry.supply == "LINKED" else ("staging line cut off from your HQ" if entry.supply == "CUT OFF" else "line home unconfirmed"),
				"; %d%% yours" % int(round(entry.my_progress * 100.0)) if entry.my_progress > 0.0 else ""]
		elif entry.reach == false and entry.capturable:
			result.text = "Selected %s %s: no owned link reaches it yet - hold your linked ground. Server decides." % [symbol, entry.label]
		else:
			result.text = "Selected %s %s: no author link data for a capture decision - the server decides." % [symbol, entry.label]
		return result
	var next: Dictionary = model.next
	if not next.is_empty():
		result.code = "next"
		result.target_id = next.id
		result.target_label = next.label
		result.text = "NEXT %s %s - %s. Server decides." % [mark.get(next.archetype, "*"), next.label,
			"linked push from your HQ" if next.supply == "LINKED" else ("no linked route home - reconnect the line first" if next.supply == "CUT OFF" else "line home unconfirmed - hold your linked ground")]
		return result
	var hold: Dictionary = model.hold
	if not hold.is_empty():
		result.code = "hold"
		result.target_id = hold.id
		result.target_label = hold.label
		result.text = "HOLD %s %s - your line is %s. Server decides." % [mark.get(hold.archetype, "*"), hold.label,
			"linked" if hold.connected else ("cut off from your HQ" if hold.supply == "CUT OFF" else "not confirmed linked")]
		return result
	result.code = "hold"
	result.text = "No public capture links to your ground yet; hold your own nodes. Server decides."
	return result
