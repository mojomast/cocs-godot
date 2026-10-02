extends SceneTree
## Grant-gated native authority proof. Reports every trace, including failures.
const Simulation = preload("res://fighting/core/simulation.gd")
const F = preload("res://tests/fighting/core/fixtures.gd")
var results: Array = []

func _initialize() -> void:
	var roster: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/roster.json"))
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/rules.json"))
	var failures := 0
	for operator in roster.operators:
		for combo in operator.combos:
			for facing in [1, -1]:
				var result := run_combo(roster, rules, operator, combo, facing)
				results.append(result)
				if not result.passed:
					failures += 1
	var report := {"suite": "actual-content-combos", "cases": results.size(), "failures": failures, "results": results}
	var output := JSON.stringify(report)
	print(output)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file := FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			if file != null:
				file.store_string(output + "\n")
	quit(0 if failures == 0 else 1)

func run_combo(roster: Dictionary, rules: Dictionary, operator: Dictionary, combo: Dictionary, facing: int) -> Dictionary:
	var s = Simulation.new()
	s.configure(roster, rules)
	if not s.last_error.is_empty():
		return {"operator": operator.id, "name": combo.name, "facing": facing, "passed": false, "error": s.last_error}
	var attacker := 0 if facing == 1 else 1
	var defender := 1 - attacker
	var ids: Array = [operator.id, operator.id]
	s.start_match({"operators": ids, "stage_id": "combo-fixture", "seed": 11, "training": true})
	var condition: Dictionary = combo.preconditions
	var distance := int(condition.distance)
	var defender_x := (int(rules.stage_half_width) - 350) * facing if condition.corner else distance * facing
	var attacker_x := defender_x - distance * facing
	var placements := [{}, {}]
	placements[attacker] = {"x": attacker_x, "y": int(condition.attacker_y), "meter": int(condition.meter)}
	placements[defender] = {"x": defender_x, "y": int(condition.defender_y), "meter": 0}
	s.training_reset({"fighters": placements})
	var samples: Array = combo.get("setup_inputs", []).duplicate(true)
	samples.append_array(combo.inputs)
	var contacts: Array = []
	var trace: Array = []
	var replay_inputs: Array = []
	var checkpoint: Dictionary = {}
	var expected: Array = []
	var last_tick := 0
	for sample in samples:
		last_tick = maxi(last_tick, int(sample.tick) + int(sample.get("duration", 1)))
	for tick in range(last_tick + 100):
		var command: Dictionary = F.input()
		for sample in samples:
			if tick >= int(sample.tick) and tick < int(sample.tick) + int(sample.get("duration", 1)):
				command = F.input(int(sample.held), int(sample.axis_x) * facing, int(sample.axis_y), int(sample.pressed))
		var inputs := [F.input(), F.input()]
		inputs[attacker] = command
		for sample in combo.get("defender_setup_inputs", []):
			if tick >= int(sample.tick) and tick < int(sample.tick) + int(sample.get("duration", 1)):
				inputs[defender] = F.input(int(sample.held), int(sample.axis_x) * facing, int(sample.axis_y), int(sample.pressed))
		if tick == 5:
			checkpoint = s.save_state()
		var view: Dictionary = s.step(inputs)
		if tick >= 5:
			replay_inputs.append(inputs.duplicate(true))
			expected.append(view)
		trace.append({"tick": tick, "fighters": view.fighters, "events": view.events})
		for event in view.events:
			if event.actor == attacker and event.target == defender and event.type in ["hit", "throw_hit"]:
				contacts.append({"tick": tick, "move": event.move_id, "combo_hits": view.fighters[defender].combo_hits, "damage": event.damage})
	var continuous := contacts.size() == combo.route.size()
	for index in range(mini(contacts.size(), combo.route.size())):
		continuous = continuous and contacts[index].move == combo.route[index] and contacts[index].combo_hits == index + 1
	s.load_state(JSON.parse_string(JSON.stringify(checkpoint)))
	var replay_equal: bool = s.last_error.is_empty()
	for index in range(replay_inputs.size()):
		var replayed: Dictionary = s.step(replay_inputs[index])
		replay_equal = replay_equal and replayed == expected[index]
	return {"operator": operator.id, "name": combo.name, "facing": facing,
		"passed": continuous and replay_equal, "continuous": continuous,
		"replay_equal": replay_equal, "contacts": contacts, "trace": trace}
