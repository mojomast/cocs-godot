extends SceneTree
const Simulation = preload("res://fighting/core/simulation.gd")
const F = preload("res://tests/fighting/core/fixtures.gd")
const IntegerMath = preload("res://fighting/core/integer_math.gd")
const Codec = preload("res://fighting/core/state_codec.gd")
var failures: Array = []
var checks := 0

func _initialize() -> void:
	for value in range(-999, 1000):
		check(IntegerMath.mul_div(value, 85, 100) == -IntegerMath.mul_div(-value, 85, 100), "signed truncation symmetry")
	var roster: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/roster.json"))
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/rules.json"))
	for left in range(roster.operators.size()):
		for right in range(left, roster.operators.size()):
			_pairing(roster, rules, roster.operators[left].id, roster.operators[right].id)
	print(JSON.stringify({"suite": "fighting-invariants", "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 100:
		failures.append(label)

func _pairing(roster: Dictionary, rules: Dictionary, left: String, right: String) -> void:
	var a = Simulation.new()
	var b = Simulation.new()
	a.configure(roster, rules)
	b.configure(roster, rules)
	check(a.last_error.is_empty(), left + "/" + right + " schema")
	if not a.last_error.is_empty():
		return
	a.start_match({"operators": [left, right], "stage_id": "invariant", "seed": 33, "training": true})
	b.start_match({"operators": [right, left], "stage_id": "invariant", "seed": 33, "training": true})
	a.training_reset({"fighters": [{"x": -450}, {"x": 450}]})
	b.training_reset({"fighters": [{"x": -450}, {"x": 450}]})
	var saved: Dictionary = {}
	var replay: Array = []
	var inputs_log: Array = []
	var last_event := 0
	for tick in range(420):
		var commands := [F.input(), F.input()]
		for id in range(2):
			var n: int = (tick * 17 + id * 29) % 131
			var button: int = [0, 1, 2, 4, 8, 16, 32, 40, 64, 128][n % 10] if tick % 11 == 0 else 0
			commands[id] = F.input(button, (1 if id == 0 else -1) if n < 60 else 0, -1 if n > 100 else (1 if n < 5 else 0), 511)
		var mirrored := [commands[1].duplicate(), commands[0].duplicate()]
		for command in mirrored:
			command.axis_x = -int(command.axis_x)
		if tick == 75:
			saved = a.save_state()
		var av: Dictionary = a.step(commands)
		var bv: Dictionary = b.step(mirrored)
		if tick >= 75:
			inputs_log.append(commands)
			replay.append(av)
		check(Codec.valid_tree(av), left + "/" + right + " integral bounded tree")
		for id in range(2):
			var af: Dictionary = av.fighters[id]
			var bf: Dictionary = bv.fighters[1 - id]
			check(af.x == -int(bf.x) and af.vx == -int(bf.vx) and af.y == bf.y and af.hp == bf.hp and af.meter == bf.meter, left + "/" + right + " mirror tick " + str(tick))
			check(af.hp >= 0 and af.meter >= 0 and af.meter <= 1000 and af.combo_hits <= 12 and af.y >= 0 and absi(int(af.x)) <= int(rules.stage_half_width), "bounded combat")
		for event in av.events:
			check(event.id > last_event, "event IDs strictly monotonic")
			last_event = event.id
	a.load_state(JSON.parse_string(JSON.stringify(saved)))
	check(a.last_error.is_empty(), "JSON codec accepted")
	for index in range(inputs_log.size()):
		check(a.step(inputs_log[index]) == replay[index], left + "/" + right + " replay " + str(index))
