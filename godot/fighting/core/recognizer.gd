extends RefCounted

const MASK := 511

static func valid(command: Variant) -> bool:
	if not command is Dictionary:
		return false
	for key in ["axis_x", "axis_y", "held", "pressed"]:
		if not command.has(key) or not integral(command[key]):
			return false
	return abs(int(command.axis_x)) <= 1 and abs(int(command.axis_y)) <= 1 and int(command.held) >= 0 and int(command.held) <= MASK and int(command.pressed) >= 0 and int(command.pressed) <= MASK

static func integral(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))

static func ingest(fighter: Dictionary, command: Dictionary, tick: int, buffer: int, simple: bool, moves: Dictionary = {}) -> void:
	var edge: int = int(command.held) & ~int(fighter.previous_held)
	fighter.input = {"axis_x": int(command.axis_x), "axis_y": int(command.axis_y), "held": int(command.held), "pressed": edge}
	fighter.history.append({"tick": tick, "x": int(command.axis_x) * int(fighter.facing), "y": int(command.axis_y), "pressed": edge})
	while fighter.history.size() > 40:
		fighter.history.pop_front()
	fighter.jump_edge = int(command.axis_y) == 1 and fighter.previous_y != 1
	fighter.previous_y = int(command.axis_y)
	fighter.previous_held = int(command.held)
	var move := ""
	if edge & 256:
		move = "super"
	elif (edge & 40) != 0 and (int(command.held) & 40) == 40 and simple:
		move = "special3"
	elif edge & 16:
		move = "special2"
	elif edge & 32:
		move = "throw_b" if int(command.axis_x) * int(fighter.facing) < 0 else "throw_f"
	elif edge & 8 and simple:
		move = "special1"
	elif edge & 7:
		if motion(fighter.history, [[0, -1], [1, -1], [1, 0], [0, -1], [1, -1], [1, 0]], tick):
			move = "super"
		elif motion(fighter.history, [[1, 0], [1, -1], [0, -1], [-1, -1], [-1, 0]], tick):
			move = "special3"
		elif moves.get("special1", {}).get("charge_frames", 0) > 0 and fighter.charge_back >= moves.special1.charge_frames and int(command.axis_x) * int(fighter.facing) > 0:
			move = "special1"
		elif moves.get("special2", {}).get("charge_axis", "") == "down" and fighter.charge_down >= moves.special2.get("charge_frames", 1) and command.axis_y > 0:
			move = "special2"
		elif motion(fighter.history, [[0, -1], [1, -1], [1, 0]], tick):
			move = "special1"
		elif motion(fighter.history, [[0, -1], [0, 0], [0, -1]], tick):
			move = "special2"
		else:
			var prefix := "air_" if fighter.y > 0 else ("crouch_" if command.axis_y < 0 else "stand_")
			move = prefix + ("h" if edge & 4 else ("m" if edge & 2 else "l"))
	if not move.is_empty():
		fighter.buffer = {"move": move, "expires": tick + buffer - 1}
	elif not fighter.buffer.is_empty() and int(fighter.buffer.expires) < tick:
		fighter.buffer = {}

static func motion(history: Array, sequence: Array, tick: int) -> bool:
	var index := sequence.size() - 1
	for offset in range(history.size() - 1, -1, -1):
		var entry: Dictionary = history[offset]
		if tick - int(entry.tick) > 18:
			break
		if entry.x == sequence[index][0] and entry.y == sequence[index][1]:
			index -= 1
			if index < 0:
				return true
	return false
