extends RefCounted
const Codec = preload("res://fighting/core/state_codec.gd")
const Recognizer = preload("res://fighting/core/recognizer.gd")
## Delayed public observation -> ordinary commands. No simulation reference.
var last_error := ""
var _rng := 1
var _difficulty := 1
var _clock := 0
var _next_decision := 0
var _observations: Array = []
var _held := 0
var _plan: Dictionary = {"axis_x": 0, "axis_y": 0, "held": 0, "pressed": 0}

func configure(seed: int, difficulty: int) -> void:
	_rng = seed & 0x7fffffff
	_difficulty = clampi(difficulty, 0, 3)
	_clock = 0
	_next_decision = 0
	_observations = []
	_held = 0
	_plan = {"axis_x": 0, "axis_y": 0, "held": 0, "pressed": 0}

func command(state: Dictionary, actor: int) -> Dictionary:
	last_error = ""
	var neutral := {"axis_x": 0, "axis_y": 0, "held": 0, "pressed": 0}
	if not actor in [0, 1] or not state.get("fighters") is Array or state.fighters.size() != 2:
		last_error = "invalid AI observation"
		return neutral
	for f in state.fighters:
		if not f is Dictionary:
			last_error = "invalid AI fighter"
			return neutral
		for key in ["x", "y", "facing", "state", "move_id", "meter"]:
			if not f.has(key):
				last_error = "incomplete AI observation"
				return neutral
		for key in ["x", "y", "facing", "meter"]:
			if not Recognizer.integral(f[key]) or absi(int(f[key])) > 100000:
				last_error = "invalid AI numeric observation"
				return neutral
		if not f.state is String or not f.move_id is String:
			last_error = "invalid AI state observation"
			return neutral
	if state.get("phase", "") != "fight":
		_held = 0
		return neutral
	_clock += 1
	# Deliberately strip input/history, HP and all hidden authority fields.
	var observation := {"fighters": []}
	for f in state.fighters:
		observation.fighters.append({"x": f.x, "y": f.y, "facing": f.facing,
			"state": f.state, "move_id": f.move_id, "meter": f.meter})
	_observations.append(observation)
	var delay: int = [30, 22, 15, 10][_difficulty]
	if _observations.size() <= delay:
		return neutral
	var delayed: Dictionary = _observations.pop_front()
	if _clock >= _next_decision:
		_next_decision = _clock + [20, 15, 11, 8][_difficulty] + _random(7)
		var me: Dictionary = delayed.fighters[actor]
		var enemy: Dictionary = delayed.fighters[1 - actor]
		var direction := 1 if enemy.x > me.x else -1
		var distance := absi(int(enemy.x) - int(me.x))
		var choice := _random(100)
		_plan = neutral.duplicate()
		if enemy.state == "attack" and choice < 25 + _difficulty * 8:
			_plan.held = 64
			_plan.axis_y = -1 if enemy.move_id.begins_with("crouch") else 0
		elif me.state == "thrown" and choice < 20 + _difficulty * 15:
			_plan.held = 32
		elif distance > 1900:
			_plan.axis_x = direction
			if choice < 25:
				_plan.held = 8
			elif choice < 37:
				_plan.axis_y = 1
			elif choice > 90:
				_plan.held = 128
		else:
			if me.meter >= 1000 and choice < 20:
				_plan.held = 256
			elif distance < 900 and choice < 25:
				_plan.held = 32 if choice % 2 == 0 else 40
			elif choice < 65:
				_plan.held = [1, 2, 4][_random(3)]
				_plan.axis_y = -1 if _random(3) == 0 else 0
			elif choice < 80:
				_plan.held = 8
			elif choice < 90:
				_plan.axis_y = 1
				_plan.axis_x = direction
			else:
				_plan.held = 16
	var result := _plan.duplicate()
	result.pressed = int(result.held) & ~_held
	_held = int(result.held)
	# Attack buttons pulse, guard remains held. Pulsing allows later decisions to edge.
	if int(_plan.held) != 64:
		_plan.held = 0
	return result

func save_state() -> Dictionary:
	return {"version": 1, "rng": _rng, "difficulty": _difficulty, "clock": _clock,
		"next_decision": _next_decision, "observations": _observations.duplicate(true),
		"held": _held, "plan": _plan.duplicate(true)}

func load_state(saved: Dictionary) -> void:
	last_error = ""
	if not Codec.valid_tree(saved):
		last_error = "nonintegral AI save"
		return
	if saved.get("version") != 1 or not saved.get("observations") is Array or not saved.get("plan") is Dictionary:
		last_error = "invalid AI save"
		return
	for key in ["rng", "difficulty", "clock", "next_decision", "held"]:
		if not saved.has(key) or not (saved[key] is int or saved[key] is float):
			last_error = "invalid AI save scalar"
			return
	if not Recognizer.valid(saved.plan) or saved.difficulty < 0 or saved.difficulty > 3 or saved.rng < 0 or saved.rng > 0x7fffffff or saved.held < 0 or saved.held > 511 or saved.observations.size() > 30 or saved.clock < 0 or saved.next_decision < 0:
		last_error = "AI save outside bounds"
		return
	for observation in saved.observations:
		if not observation is Dictionary or not observation.get("fighters") is Array or observation.fighters.size() != 2:
			last_error = "invalid delayed AI observation"
			return
		for fighter in observation.fighters:
			if not fighter is Dictionary:
				last_error = "invalid delayed fighter"
				return
			for key in ["x", "y", "facing", "meter"]:
				if not Recognizer.integral(fighter.get(key)):
					last_error = "invalid delayed numeric field"
					return
			if not fighter.get("state") is String or not fighter.get("move_id") is String:
				last_error = "invalid delayed state field"
				return
	_rng = int(saved.rng)
	_difficulty = clampi(int(saved.difficulty), 0, 3)
	_clock = int(saved.clock)
	_next_decision = int(saved.next_decision)
	_observations = Codec.decode(saved.observations)
	_held = int(saved.held)
	_plan = Codec.decode(saved.plan)

func _random(bound: int) -> int:
	_rng = (_rng * 1103515245 + 12345) & 0x7fffffff
	return (_rng >> 8) % bound
