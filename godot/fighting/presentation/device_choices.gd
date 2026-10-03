extends RefCounted
## Pure menu projection. No Input singleton, assignments, focus or scene writes.
## A missing current ID remains a visible last entry; its next choice is Keyboard.
static func model(assignments: Array, player: int, connected: Array) -> Dictionary:
	if player < 0 or player > 1 or assignments.size() != 2: return {}
	var current: int = int(assignments[player])
	var other: int = int(assignments[1-player])
	var choices: Array = [-1]
	var ordered: Array = connected.duplicate()
	ordered.sort()
	for device: int in ordered:
		if device >= 0 and device != other and not choices.has(device): choices.append(device)
	if not choices.has(current): choices.append(current)
	var selected: int = choices.find(current)
	return {"current":current,"choices":choices,"selected":selected,"next":choices[(selected+1)%choices.size()],"missing":current >= 0 and not connected.has(current),"occupied":current >= 0 and current == other}

static func caption(model: Dictionary, player: int, names: Dictionary) -> String:
	var current: int = int(model["current"])
	if current == -1: return "Keyboard %d" % (player+1)
	if model["missing"]: return "Pad %d · disconnected" % current
	if model["occupied"]: return "Pad %d · unavailable" % current
	return "Pad %d" % current + " · " + str(names.get(current,"Controller"))
