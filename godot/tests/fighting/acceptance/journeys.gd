extends SceneTree
## Independent public-API journeys. Never assigns health/position or calls core internals.

const IDS := ["chatgpt", "claude", "grok", "meta", "gemini", "deepseek", "mistral", "kimi", "qwen"]
const REQUIRED_FIGHTER := ["id", "operator_id", "x", "y", "vx", "vy", "facing", "hp", "meter", "state", "move_id", "move_frame", "animation", "animation_frame", "hitstop", "stun", "combo_hits", "combo_damage", "resources"]
var failures: Array = []
var checks: Array = []
var unrun: Array = []
var roster: Dictionary
var rules: Dictionary
var simulation_script: Variant
var ai_script: Variant
var success_marker := "FIGHTING_ACCEPTANCE_JOURNEYS_OK"
var report_scope := "public API journeys only; extended mechanics/native art/UI gates separate"
var observed := {"hitstop": false, "airborne": false, "projectiles": false, "paired_throws": false}
var replay_checkpoints := {"hitstop": 0, "airborne": 0, "projectiles": 0, "paired_throws": 0}
var saved_inventory := {}

func _initialize() -> void:
	call_deferred("_run")

func expect(condition: bool, label: String) -> bool:
	if not condition:
		if failures.size() < 100:
			failures.append(label)
	return condition

func neutral() -> Dictionary:
	return {"axis_x": 0, "axis_y": 0, "held": 0, "pressed": 0}

func command(x: int = 0, y: int = 0, buttons: int = 0, edge: bool = true) -> Dictionary:
	return {"axis_x": x, "axis_y": y, "held": buttons, "pressed": buttons if edge else 0}

func equal(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not equal(a[key], b[key]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for index in a.size():
			if not equal(a[index], b[index]):
				return false
		return true
	return a == b

func json_safe(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			# Godot dot-key insertion may produce StringName keys; JSON encodes
			# these as strings, as the core codec explicitly permits. Values still
			# must be JSON scalars/containers, and roundtrip equality stays required.
			if not (key is String or key is StringName) or not json_safe(value[key]):
				return false
		return true
	if value is Array:
		for item in value:
			if not json_safe(item):
				return false
		return true
	return value == null or value is String or value is bool or value is int or (value is float and is_finite(value))

func fresh(operators: Array, seed_value: int = 23017, training: bool = false) -> Variant:
	var sim: Variant = simulation_script.new()
	sim.configure(roster.duplicate(true), rules.duplicate(true))
	sim.start_match({"operators": operators, "stage_id": "basalt-reach", "seed": seed_value, "training": training})
	return sim

func fight(sim: Variant) -> bool:
	for _tick in 600:
		if sim.snapshot().get("phase") == "fight":
			return true
		sim.step([neutral(), neutral()])
	return expect(false, "intro must reach fight within 600 ticks")

func validate_snapshot(state: Dictionary, ledger: Dictionary, label: String) -> void:
	for key in ["version", "tick", "phase", "round_index", "round_ticks_left", "wins", "winner", "stage_id", "fighters", "projectiles", "events"]:
		if not expect(state.has(key), label + " snapshot missing " + key):
			return
	expect(json_safe(state), label + " JSON-safe snapshot")
	expect(state.phase in ["intro", "fight", "round_over", "match_over"], label + " legal phase")
	if not expect(state.fighters.size() == 2, label + " exactly two fighters"):
		return
	for actor in 2:
		var f: Dictionary = state.fighters[actor]
		for key in REQUIRED_FIGHTER:
			if not expect(f.has(key), label + " fighter field " + key):
				return
		expect(f.id == actor, label + " stable actor ID")
		expect(f.hp >= 0 and f.meter >= 0 and f.meter <= 1000, label + " health/meter bounds")
		expect(f.facing in [-1, 1], label + " facing")
		for key in ["x", "y", "vx", "vy", "hp", "meter", "move_frame", "animation_frame", "hitstop", "stun"]:
			expect(f[key] is int, label + " integer fixed state " + key)
		observed.hitstop = observed.hitstop or f.hitstop > 0
		observed.airborne = observed.airborne or f.y > 0
		observed.paired_throws = observed.paired_throws or str(f.animation).begins_with("victim_")
	observed.projectiles = observed.projectiles or not state.projectiles.is_empty()
	for event in state.events:
		for key in ["id", "tick", "type", "actor", "target", "move_id", "x", "y", "effect"]:
			if not expect(event.has(key), label + " event field " + key):
				return
		expect(event.id is int and event.tick is int and event.tick <= state.tick, label + " event identity")
		# A snapshot may expose an event history. Re-exposure is legal only byte-identically.
		if ledger.has(event.id):
			expect(equal(ledger[event.id], event), label + " event ID reused for different event")
		else:
			ledger[event.id] = event.duplicate(true)

func approach(sim: Variant, actor: int, separation: int = 700) -> bool:
	for _tick in 360:
		var state: Dictionary = sim.snapshot()
		if state.phase != "fight":
			return false
		if abs(state.fighters[0].x - state.fighters[1].x) <= separation:
			return true
		var inputs := [neutral(), neutral()]
		inputs[actor] = command(int(state.fighters[actor].facing))
		sim.step(inputs)
	return expect(false, "ordinary walking reaches contact range")

func detach_and_restore(sim: Variant, operators: Array) -> Variant:
	var before: Dictionary = sim.save_state().duplicate(true)
	record_inventory(before, "saved")
	var saved: Dictionary = sim.save_state()
	expect(json_safe(saved), "saved complete state JSON-safe")
	var snapshot: Dictionary = sim.snapshot()
	if snapshot.get("fighters", []).size() == 2:
		snapshot.fighters[0].resources["acceptance_detachment_probe"] = 123
		snapshot.fighters.clear()
	expect(equal(before, sim.save_state()), "snapshot deep detachment")
	saved["acceptance_detachment_probe"] = {"nested": [1, 2]}
	for key in saved:
		if saved[key] is Array and not saved[key].is_empty():
			saved[key].clear()
			break
	expect(equal(before, sim.save_state()), "saved state deep detachment")
	var restored: Variant = fresh(operators)
	var json_copy: Variant = JSON.parse_string(JSON.stringify(before))
	restored.load_state(json_copy)
	expect(equal(sim.save_state(), restored.save_state()), "JSON save/load complete state equality")
	expect(equal(sim.snapshot(), restored.snapshot()), "JSON save/load snapshot equality")
	validate_snapshot(restored.snapshot(), {}, "JSON authoritative integer restoration")
	# load_state must detach from the caller too.
	json_copy.clear()
	expect(equal(before, restored.save_state()), "load_state caller ownership")
	return restored

func record_inventory(value: Variant, path: String) -> void:
	saved_inventory[path] = type_string(typeof(value))
	if value is Dictionary:
		for key in value:
			record_inventory(value[key], path + "." + str(key))
	elif value is Array:
		for item in value:
			record_inventory(item, path + "[]")

func scripted_input(tick: int, state: Dictionary, actor: int) -> Dictionary:
	var phase_tick := tick % 150
	var facing := int(state.fighters[actor].facing)
	if phase_tick < 40:
		return command(facing)
	if phase_tick == 40:
		return command(0, 0, 1)
	if phase_tick == 49:
		return command(0, 0, 2)
	if phase_tick == 85:
		return command(0, 0, 8)
	if phase_tick == 115:
		return command(0, 1)
	if phase_tick == 125:
		return command(0, 0, 4)
	return neutral()

func matrix_replay() -> void:
	var cases := 0
	for left in IDS.size():
		for right in range(left, IDS.size()):
			for side in 2:
				var operators: Array = [IDS[left], IDS[right]] if side == 0 else [IDS[right], IDS[left]]
				var sim: Variant = fresh(operators)
				var twin: Variant = fresh(operators)
				var mirrored: Variant = fresh([operators[1], operators[0]])
				var restored := {}
				var ledger := {}
				var label := str(operators) + " side=" + str(side)
				for tick in 720:
					var state: Dictionary = sim.snapshot()
					var inputs := [scripted_input(tick, state, 0), scripted_input(tick + 30, state, 1)]
					var next: Dictionary = sim.step(inputs.duplicate(true))
					for actor in 2:
						if state.fighters[actor].hitstop > 1:
							for key in ["x", "y", "vx", "vy", "move_frame", "stun"]:
								expect(equal(state.fighters[actor][key], next.fighters[actor][key]), label + " hitstop freezes " + key)
					twin.step(inputs.duplicate(true))
					var mirror_inputs := [inputs[1].duplicate(true), inputs[0].duplicate(true)]
					for input in mirror_inputs:
						input.axis_x = -input.axis_x
					var reflected: Dictionary = mirrored.step(mirror_inputs)
					for actor in 2:
						var a: Dictionary = next.fighters[actor]
						var b: Dictionary = reflected.fighters[1 - actor]
						for key in ["operator_id", "hp", "meter", "y", "vy", "state", "move_id", "move_frame", "hitstop", "stun", "combo_hits", "combo_damage", "resources"]:
							expect(equal(a[key], b[key]), label + " mirrored actor-order parity " + key + " tick " + str(tick))
						expect(a.x == -b.x and a.vx == -b.vx and a.facing == -b.facing, label + " left/right geometry parity")
					for key in ["phase", "round_index", "round_ticks_left"]:
						expect(equal(next[key], reflected[key]), label + " mirrored " + key)
					expect(equal(sim.save_state(), twin.save_state()), label + " fresh-instance determinism tick " + str(tick))
					for category in restored:
						restored[category].step(inputs.duplicate(true))
						expect(equal(sim.save_state(), restored[category].save_state()), label + " " + category + " all later saved-state frames " + str(tick))
					# Distinct live checkpoints; every fork remains checked until journey end.
					var conditions := {"hitstop": next.fighters[0].hitstop > 0,
						"airborne": next.fighters[0].y > 0, "projectiles": not next.projectiles.is_empty()}
					for category in conditions:
						if tick > 200 and conditions[category] and not restored.has(category):
							restored[category] = detach_and_restore(sim, operators)
							replay_checkpoints[category] += 1
					validate_snapshot(next, ledger, label)
					if failures.size() >= 100:
						return
				if not expect(not restored.is_empty(), label + " exercised live save checkpoint"):
					return
				cases += 1
	checks.append({"id": "roster-matrix-replay", "cases": cases, "mirrors": 9, "distinct": 36, "actor_orders": 2, "ticks_per_case": 720})

func held_and_release() -> void:
	for oid in IDS:
		var sim: Variant = fresh([oid, oid])
		if not fight(sim):
			return
		var activations := 0
		var prior_move := ""
		for tick in 240:
			var state: Dictionary = sim.step([command(0, 0, 1, tick == 0), neutral()])
			var mid := str(state.fighters[0].move_id)
			if mid == "stand_l" and prior_move != mid:
				activations += 1
			prior_move = mid
		expect(activations == 1, oid + " held attack starts exactly once")
		for _tick in 90:
			var state: Dictionary = sim.step([neutral(), neutral()])
			expect(state.fighters[0].move_id != "stand_l", oid + " negative edge disabled")
		# Caller pressed is a hint, never authority: deliberately forge every tick.
		var forged: Variant = fresh([oid, oid])
		if not fight(forged):
			return
		activations = 0
		prior_move = ""
		for _tick in 240:
			var state: Dictionary = forged.step([command(0, 0, 1, true), neutral()])
			var mid := str(state.fighters[0].move_id)
			if mid == "stand_l" and prior_move != mid:
				activations += 1
			prior_move = mid
		expect(activations == 1, oid + " forged pressed while held cannot retrigger")
		var hintless: Variant = fresh([oid, oid])
		if not fight(hintless):
			return
		var derived: Dictionary = hintless.step([command(0, 0, 1, false), neutral()])
		expect(derived.fighters[0].move_id == "stand_l", oid + " held rising edge recognized without pressed hint")
	checks.append({"id": "held-and-negative-edge", "operators": 9})

func axis_polarity() -> void:
	for oid in IDS:
		var down: Variant = fresh([oid, oid])
		var up: Variant = fresh([oid, oid])
		if not fight(down) or not fight(up):
			return
		var peak := 0
		for tick in 30:
			var crouching: Dictionary = down.step([command(0, -1), neutral()])
			var jumping: Dictionary = up.step([command(0, 1), neutral()])
			expect(crouching.fighters[0].y == 0, oid + " down -1 never jumps")
			peak = maxi(peak, int(jumping.fighters[0].y))
		var low: Dictionary = down.step([command(0, -1, 1), neutral()])
		expect(low.fighters[0].move_id == "crouch_l", oid + " down -1 selects crouch normal")
		expect(peak > 0, oid + " up +1 produces real jump")
		checks.append({"id": "axis-polarity-" + oid, "jump_peak": peak})

func move_command(mid: String, facing: int) -> Dictionary:
	var button := 0
	if mid.ends_with("_l"):
		button = 1
	elif mid.ends_with("_m"):
		button = 2
	elif mid.ends_with("_h"):
		button = 4
	else:
		button = {"throw_f": 32, "throw_b": 32, "special1": 8, "special2": 16, "special3": 40, "super": 256}.get(mid, 0)
	return command(-facing if mid == "throw_b" else 0, -1 if mid.begins_with("crouch_") else 0, button)

func combos() -> void:
	for operator in roster.operators:
		for combo in operator.combos:
			for actor in 2:
				var sim: Variant = fresh([operator.id, operator.id])
				if not fight(sim):
					return
				var victim := 1 - actor
				var label: String = operator.id + ":" + combo.name + " actor=" + str(actor)
				var fixture: Dictionary = sim.save_state()
				if not fixture.has("fighters"):
					unrun.append(label + " saved-state fixture inventory requires core coordination")
					continue
				var pre: Dictionary = combo.preconditions
				var facing := 1 if actor == 0 else -1
				# Sole fixture mutation, before the trace. No HP edits, no further writes.
				# Defender follows charge walking through ordinary inputs during setup.
				var victim_x := (int(rules.stage_half_width) - 330) * facing if pre.corner else int(pre.distance / 2) * facing
				fixture.fighters[victim].x = victim_x
				fixture.fighters[actor].x = victim_x - int(pre.distance) * facing
				fixture.fighters[actor].y = int(pre.attacker_y)
				fixture.fighters[victim].y = int(pre.defender_y)
				fixture.fighters[actor].meter = int(pre.meter)
				sim.load_state(fixture)
				var samples: Array = combo.get("setup_inputs", []).duplicate(true)
				samples.append_array(combo.inputs)
				var first_attack := int(combo.inputs[0].tick)
				var last_input := 0
				for sample in samples:
					last_input = maxi(last_input, int(sample.tick) + int(sample.get("duration", 1)))
				var damage_ticks: Array = []
				var executed := {}
				var hit_moves: Array = []
				var seen_events := {}
				var trace: Array = []
				var gap := false
				var prior: Dictionary = sim.snapshot()
				for tick in range(last_input + 180):
					var inputs := [neutral(), neutral()]
					for sample in samples:
						if tick >= sample.tick and tick < sample.tick + sample.get("duration", 1):
							inputs[actor] = {"axis_x": int(sample.axis_x) * facing, "axis_y": int(sample.axis_y), "held": int(sample.held), "pressed": int(sample.pressed) if tick == sample.tick else 0}
					if tick < first_attack:
						inputs[victim] = command(int(inputs[actor].axis_x))
					if tick == first_attack:
						expect(abs(prior.fighters[actor].x - prior.fighters[victim].x) == pre.distance, label + " authored first-attack distance")
					var next: Dictionary = sim.step(inputs)
					var active := str(next.fighters[actor].move_id)
					if not active.is_empty():
						executed[active] = true
					for event in next.events:
						if seen_events.has(event.id):
							continue
						seen_events[event.id] = true
						if event.actor == actor and event.target == victim and event.get("damage", 0) > 0 and not event.get("blocked", false):
							hit_moves.append(event.move_id)
					if next.fighters[victim].hp < prior.fighters[victim].hp:
						if not damage_ticks.is_empty():
							expect(not gap and prior.fighters[victim].stun > 0, label + " strictly positive consecutive hitstun")
						damage_ticks.append(tick)
					if not damage_ticks.is_empty() and next.fighters[victim].stun <= 0:
						gap = true
					trace.append({"tick": tick, "inputs": inputs, "fighters": next.fighters, "events": next.events})
					prior = next
				expect(damage_ticks.size() >= combo.route.size(), label + " every proposed attack contacts")
				for mid in combo.route:
					expect(executed.has(mid), label + " intended move actually executed " + mid)
				expect(equal(hit_moves, combo.route), label + " actual damaging event sequence equals authored route")
				var directory := OS.get_environment("FIGHTING_ACCEPTANCE_EVIDENCE")
				if not directory.is_empty():
					var filename: String = operator.id + "-" + combo.name.to_snake_case() + "-" + str(actor) + ".json"
					var file := FileAccess.open(directory.path_join(filename), FileAccess.WRITE)
					if file != null:
						file.store_string(JSON.stringify({"fixture": fixture, "trace": trace}, "\t"))
				checks.append({"id": label, "damage_ticks": damage_ticks, "hit_moves": hit_moves, "executed": executed.keys()})

func ai_matches() -> void:
	for oid in IDS:
		var operators := [oid, "meta" if oid != "meta" else "mistral"]
		var sim: Variant = fresh(operators)
		var twin: Variant = fresh(operators)
		var ais := [ai_script.new(), ai_script.new()]
		var copies := [ai_script.new(), ai_script.new()]
		for actor in 2:
			ais[actor].configure(703 + actor, 2)
			copies[actor].configure(703 + actor, 2)
		var completed := false
		var hp_changed := false
		var ledger := {}
		for tick in 22000:
			var state: Dictionary = sim.snapshot()
			var before: Dictionary = state.duplicate(true)
			var inputs := [neutral(), neutral()]
			var twin_inputs := [neutral(), neutral()]
			if state.phase == "fight":
				for actor in 2:
					inputs[actor] = ais[actor].command(state, actor)
					twin_inputs[actor] = copies[actor].command(twin.snapshot(), actor)
				expect(equal(state, before), oid + " AI snapshot not mutated")
				expect(equal(inputs, twin_inputs), oid + " seeded AI commands equal")
			var next: Dictionary = sim.step(inputs)
			twin.step(twin_inputs)
			expect(equal(sim.save_state(), twin.save_state()), oid + " full AI determinism frame " + str(tick))
			validate_snapshot(next, ledger, oid + " AI")
			for actor in 2:
				hp_changed = hp_changed or next.fighters[actor].hp < state.fighters[actor].hp
			if next.phase == "match_over":
				completed = true
				break
			if failures.size() >= 100:
				return
		expect(completed and hp_changed, oid + " ordinary-input AI full match with actual damage")
		sim.start_match({"operators": operators, "stage_id": "basalt-reach", "seed": 23017, "training": false})
		var reset: Variant = fresh(operators)
		expect(equal(sim.save_state(), reset.save_state()), oid + " rematch complete reset including IDs/resources")
		checks.append({"id": "ai-match-" + oid, "completed": completed, "damage": hp_changed})

func paired_throws() -> void:
	for operator in roster.operators:
		for actor in 2:
			for mid in ["throw_f", "throw_b"]:
				var operators: Array = [operator.id, operator.id]
				var sim: Variant = fresh(operators)
				if not fight(sim) or not approach(sim, actor):
					return
				var initial: Dictionary = sim.snapshot()
				var prior: Dictionary = initial
				var victim := 1 - actor
				var damage_frames := 0
				var clone: Variant = null
				var seen_pair := false
				var inputs := [neutral(), neutral()]
				inputs[actor] = move_command(mid, int(initial.fighters[actor].facing))
				for tick in 240:
					var next: Dictionary = sim.step(inputs)
					if clone != null:
						clone.step(inputs.duplicate(true))
						expect(equal(sim.save_state(), clone.save_state()), operator.id + " paired throw replay every later frame")
					if str(next.fighters[victim].animation).begins_with("victim_"):
						seen_pair = true
						observed.paired_throws = true
						if clone == null:
							clone = detach_and_restore(sim, operators)
							replay_checkpoints.paired_throws += 1
					if next.fighters[victim].hp < prior.fighters[victim].hp:
						damage_frames += 1
					prior = next
					inputs = [neutral(), neutral()]
				var label: String = operator.id + ":" + mid + " actor=" + str(actor)
				expect(seen_pair, label + " paired victim timeline observable")
				expect(damage_frames == 1, label + " damage occurs exactly once")
				expect(initial.fighters[victim].hp - prior.fighters[victim].hp == operator.moves[mid].damage, label + " authored first-hit damage")
				expect(not str(prior.fighters[victim].animation).begins_with("victim_"), label + " pair releases both actors")
				if mid == "throw_b":
					expect(sign(initial.fighters[actor].x - initial.fighters[victim].x) == -sign(prior.fighters[actor].x - prior.fighters[victim].x), label + " actual side swap")
				checks.append({"id": label, "damage_frames": damage_frames, "seen_pair": seen_pair})

func _run() -> void:
	for path in ["res://fighting/core/simulation.gd", "res://fighting/core/ai.gd", "res://fighting/data/roster.json", "res://fighting/data/rules.json"]:
		if not FileAccess.file_exists(path):
			unrun.append("missing dependency " + path)
	if not unrun.is_empty():
		finish()
		return
	roster = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/roster.json"))
	rules = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/rules.json"))
	simulation_script = load("res://fighting/core/simulation.gd")
	ai_script = load("res://fighting/core/ai.gd")
	if not expect(simulation_script != null and ai_script != null, "native class load"):
		finish()
		return
	matrix_replay()
	if failures.size() < 100:
		held_and_release()
		axis_polarity()
		paired_throws()
		combos()
		ai_matches()
	for category in observed:
		if not observed[category]:
			unrun.append("not reached by input journeys: " + category)
		if replay_checkpoints[category] == 0:
			unrun.append("no real saved continuation checkpoint: " + category)
	finish()

func finish() -> void:
	var status := "failed" if not failures.is_empty() else "deferred" if not unrun.is_empty() else "passed"
	var report := {"status": status, "checks": checks, "failures": failures, "unrun": unrun, "observed": observed,
		"saved_inventory": saved_inventory, "replay_checkpoints": replay_checkpoints,
		"scope": report_scope}
	var path := OS.get_environment("FIGHTING_ACCEPTANCE_OUTPUT")
	if not path.is_empty():
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	if status == "passed":
		print(success_marker)
	quit(0 if status == "passed" else 1)
