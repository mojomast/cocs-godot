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
	for key: String in ["flux", "fluxSpent", "fluxIncome", "fluxUpkeep"]:
		if not state.cocs.has(key): continue
		if not state.cocs[key] is Dictionary: return false
		for value: Variant in state.cocs[key].values():
			if not finite_number(value): return false
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
