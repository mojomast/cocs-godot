extends "res://lattice/transport.gd"
## Narrow shape guard before the inherited transport emits to typed consumers.

func finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func valid_envelope(frame: Dictionary) -> bool:
	if not super.valid_envelope(frame): return false
	if frame.type not in ["snapshot", "results"]: return true
	var state: Variant = frame.get("state")
	if not state is Dictionary or not state.get("actors") is Array: return false
	if state.actors.size() > 512: return false
	var seen := {}
	for actor: Variant in state.actors:
		if not actor is Dictionary or not wire_integer(actor.get("id")) or seen.has(actor.id): return false
		seen[actor.id] = true
		for key: String in ["x", "y", "z", "yaw", "pitch", "health"]:
			if not finite_number(actor.get(key)): return false
		for key: String in ["dead", "eyeHeight", "bodyYaw", "armor", "weapon", "shots", "req"]:
			if actor.has(key) and not finite_number(actor[key]): return false
		if not wire_integer(actor.get("team")) or (actor.team != 0 and actor.team != 1): return false
		# Own-team personal buff slot. Optional because the source omits undefined
		# slots; reject an unbounded/non-string value instead of coercing.
		if actor.has("reqBuff") and actor.reqBuff != null and not (actor.reqBuff is String and actor.reqBuff.length() <= 64): return false
		if not actor.get("ammo", []) is Array: return false
	if not state.get("pickups", []) is Array: return false
	for pickup: Variant in state.get("pickups", []):
		if not pickup is Dictionary or not wire_integer(pickup.get("id")) or not pickup.get("kind") is String: return false
		for key: String in ["x", "z"]:
			if not finite_number(pickup.get(key)): return false
		for key: String in ["y", "wait"]:
			if pickup.has(key) and not finite_number(pickup[key]): return false
	# Missing projection is loss of authorization, handled by observe/session.
	if not state.has("cocs") or state.cocs == null: return true
	if not state.cocs is Dictionary: return false
	for key: String in ["cards", "req"]:
		if state.cocs.has(key) and not state.cocs[key] is Array: return false
	for wallet: Variant in state.cocs.get("req", []):
		if not wallet is Dictionary or not wire_integer(wallet.get("id")) or not finite_number(wallet.get("req")): return false
	# The contact stream is private to this recipient. Reject an unexpected
	# second team bucket rather than silently letting presentation see it.
	if state.cocs.has("contacts") and state.cocs.contacts != null:
		if not state.cocs.contacts is Dictionary: return false
		var own_team := -1
		for actor: Variant in state.actors:
			if actor.id == actor_id: own_team = int(actor.team)
		if own_team >= 0:
			var contacts: Dictionary = state.cocs.contacts
			for key: Variant in contacts.keys():
				if key != str(own_team): return false
			var entries: Variant = contacts.get(str(own_team))
			if entries != null:
				if not entries is Array or entries.size() > 128: return false
				for entry: Variant in entries:
					if not entry is Dictionary or not wire_integer(entry.get("id")) or not wire_integer(entry.get("team")) or (entry.team != 0 and entry.team != 1): return false
					if not finite_number(entry.get("x")) or not finite_number(entry.get("z")) or not entry.get("own") is bool: return false
					if entry.own != (entry.team == own_team): return false
					for flag: String in ["revealed", "spotted"]:
						if entry.has(flag) and not entry[flag] is bool: return false
	# Wave force and director label are optional, public Operations facts. Never
	# turn an omitted threat into a zero or a locally extrapolated countdown.
	if state.cocs.has("waves") and state.cocs.waves != null:
		if not state.cocs.waves is Dictionary: return false
		for key: String in ["forceAlive", "forceTotal"]:
			if state.cocs.waves.has(key) and (not wire_integer(state.cocs.waves[key]) or state.cocs.waves[key] > 512): return false
	if state.cocs.has("director") and state.cocs.director != null:
		if not state.cocs.director is Dictionary: return false
		if state.cocs.director.has("waveLabel") and state.cocs.director.waveLabel != null and (not state.cocs.director.waveLabel is String or state.cocs.director.waveLabel.length() > 64): return false
	for key: String in ["flux", "fluxSpent", "fluxIncome", "fluxUpkeep"]:
		if not state.cocs.has(key): continue
		if not state.cocs[key] is Dictionary: return false
		for value: Variant in state.cocs[key].values():
			if not finite_number(value): return false
	# These are additive recipient-public fields. Validate only their documented
	# bounded shape; absence/null stays distinct from explicit numeric zero.
	if state.cocs.has("dominance") and state.cocs.dominance != null:
		var dominance: Variant = state.cocs.dominance
		if not dominance is Dictionary: return false
		for key: String in ["progress", "target", "remaining", "count", "fastCount", "breakCount", "hold", "fastHold"]:
			if dominance.has(key) and (not finite_number(dominance[key]) or float(dominance[key]) < 0.0): return false
		for key: String in ["count", "fastCount", "breakCount"]:
			if dominance.has(key) and (not wire_integer(dominance[key]) or dominance[key] > 128): return false
		if dominance.has("team") and dominance.team != null and (not wire_integer(dominance.team) or (dominance.team != 0 and dominance.team != 1)): return false
		if dominance.has("fast") and not dominance.fast is bool: return false
		if dominance.has("counts"):
			if not dominance.counts is Dictionary: return false
			for team: String in ["0", "1"]:
				if dominance.counts.has(team) and (not wire_integer(dominance.counts[team]) or dominance.counts[team] > 128): return false
	if state.cocs.has("outcome") and state.cocs.outcome != null:
		var outcome: Variant = state.cocs.outcome
		if not outcome is Dictionary: return false
		if outcome.has("mode") and outcome.mode not in ["pvp", "operations"]: return false
		if outcome.has("waves") and outcome.waves != null:
			if not outcome.waves is Dictionary: return false
			for key: String in ["cleared", "total"]:
				if outcome.waves.has(key) and (not wire_integer(outcome.waves[key]) or outcome.waves[key] > 1000): return false
		if outcome.has("hq") and outcome.hq != null:
			if not outcome.hq is Dictionary: return false
			for key: String in ["health", "max", "percent"]:
				if outcome.hq.has(key) and (not finite_number(outcome.hq[key]) or float(outcome.hq[key]) < 0.0): return false
			if outcome.hq.has("armed") and not outcome.hq.armed is bool: return false
	# Recipient-observed traversal depots (public world truth). Only the bounded
	# id/owner pair the native REQ mirror reads is validated; absence is allowed
	# and stays unknown, it is never inferred as "no depot".
	if state.cocs.has("traversal") and state.cocs.traversal != null:
		var traversal: Variant = state.cocs.traversal
		if not traversal is Dictionary: return false
		if traversal.has("depots") and traversal.depots != null:
			if not traversal.depots is Array or traversal.depots.size() > 64: return false
			for depot: Variant in traversal.depots:
				if not depot is Dictionary or not depot.get("id") is String or depot.id.length() > 64: return false
				if depot.get("owner") != null and (not wire_integer(depot.owner) or (depot.owner != 0 and depot.owner != 1)): return false
	if not state.cocs.has("nodes"): return true
	if not state.cocs.nodes is Array or state.cocs.nodes.size() > 128: return false
	seen.clear()
	for node: Variant in state.cocs.nodes:
		if not node is Dictionary or not node.get("id") is String or seen.has(node.id): return false
		seen[node.id] = true
		for key: String in ["x", "z"]:
			if not finite_number(node.get(key)): return false
		for key: String in ["y", "r"]:
			if node.has(key) and not finite_number(node[key]): return false
		if node.get("owner") != null and (not wire_integer(node.owner) or (node.owner != 0 and node.owner != 1)): return false
		if node.has("progress"):
			if not node.progress is Array or node.progress.size() != 2: return false
			for value: Variant in node.progress:
				if not finite_number(value): return false
	return true
