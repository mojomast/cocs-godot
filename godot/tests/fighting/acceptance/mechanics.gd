extends "res://tests/fighting/acceptance/journeys.gd"
## Authored-data outcomes, distinct from core unit tests. Every scenario owns one
## initial fixture. After that: step(InputCommand) only, including charge/setup.

const FAMILIES := ["stand_l", "stand_m", "stand_h", "crouch_l", "crouch_m", "crouch_h", "air_l", "air_m", "air_h", "throw_f", "throw_b", "special1", "special2", "special3", "super"]

func fixture_sim(oid: String, actor: int, distance: int = 700, height: int = 0, meter: int = 0) -> Variant:
	var sim: Variant = fresh([oid, oid])
	if not fight(sim):
		return null
	var saved: Dictionary = sim.save_state()
	if not saved.has("fighters"):
		unrun.append("core saved-state fighters fixture inventory absent")
		return null
	var facing := 1 if actor == 0 else -1
	saved.fighters[actor].x = -int(distance / 2) * facing
	saved.fighters[1 - actor].x = int(distance / 2) * facing
	saved.fighters[actor].y = height
	saved.fighters[1 - actor].y = height
	saved.fighters[actor].meter = meter
	sim.load_state(saved)
	return sim

func charge(sim: Variant, actor: int, move: Dictionary) -> void:
	var metadata: Dictionary = move.get("input", {})
	var frames := int(metadata.get("charge_frames", 0))
	for _tick in frames:
		var inputs := [neutral(), neutral()]
		if metadata.get("charge_axis") == "back":
			var direction := -int(sim.snapshot().fighters[actor].facing)
			inputs[actor] = command(direction)
			inputs[1 - actor] = command(direction)
		else:
			inputs[actor] = command(0, -1)
		sim.step(inputs)

func family_outcomes() -> void:
	for operator in roster.operators:
		for actor in 2:
			for mid in FAMILIES:
				var move: Dictionary = operator.moves[mid]
				var movement: Dictionary = move.get("movement", {})
				var height := 1000 if mid.begins_with("air_") or movement.get("air_only", false) else 0
				var sim: Variant = fixture_sim(operator.id, actor, 700, height, 1000 if mid == "super" else 0)
				if sim == null:
					return
				charge(sim, actor, move)
				var initial: Dictionary = sim.snapshot()
				var victim := 1 - actor
				var label: String = operator.id + ":" + mid + " side=" + str(actor)
				var started := false
				var damaged := 0
				var damage_frames := 0
				var spawned := false
				var first_damage_tick := -1
				var seen := {}
				var prior: Dictionary = initial
				var max_travel := 0
				var max_height := height
				var final: Dictionary = initial
				var trace: Array = []
				for tick in 360:
					var inputs := [neutral(), neutral()]
					if tick == 0:
						inputs[actor] = move_command(mid, int(initial.fighters[actor].facing))
					# Claude's strike counter needs an actual opposing strike in its window.
					if move.kind == "counter":
						var counter: Dictionary = move.counter
						var attack_tick := maxi(0, int(counter.from) + 1 - int(operator.moves.stand_l.startup))
						if tick == attack_tick:
							inputs[victim] = move_command("stand_l", int(initial.fighters[victim].facing))
					final = sim.step(inputs)
					started = started or final.fighters[actor].move_id == mid
					spawned = spawned or not final.projectiles.is_empty()
					max_travel = maxi(max_travel, abs(int(final.fighters[actor].x - initial.fighters[actor].x)))
					max_height = maxi(max_height, int(final.fighters[actor].y))
					var loss := int(prior.fighters[victim].hp - final.fighters[victim].hp)
					if loss > 0:
						if first_damage_tick < 0:
							first_damage_tick = tick
						damaged += loss
						damage_frames += 1
					for event in final.events:
						if not seen.has(event.id):
							seen[event.id] = event
					trace.append({"tick": tick, "inputs": inputs, "fighters": final.fighters, "projectiles": final.projectiles, "events": final.events})
					prior = final
				expect(started, label + " ordinary command selects authored family")
				if move.kind in ["strike", "projectile", "throw", "super"] and move.damage > 0:
					expect(damage_frames == 1 and damaged == move.damage, label + " exactly one authored unscaled first hit")
					expect(first_damage_tick >= int(move.startup) - 1, label + " no damage before startup")
				if move.kind == "counter":
					expect(damage_frames == 1 and damaged > 0, label + " actual strike counter-grab damages once")
				if move.kind == "projectile":
					expect(spawned, label + " actual projectile entity")
					expect(final.projectiles.is_empty(), label + " projectile expiry/contact finite")
				if move.kind == "mobility":
					var kind := str(movement.get("type", ""))
					if kind in ["rush", "reel", "blink", "air_dash"]:
						expect(max_travel > 0, label + " actual authored travel")
					elif kind in ["super_jump", "double_jump"]:
						expect(max_height > height, label + " actual upward movement")
					elif kind == "anchor":
						# Anchor representation is optional API; inspect real snapshots after merge.
						unrun.append(label + " anchor entity/one-trigger observable fixture pending")
					else:
						unrun.append(label + " mobility trajectory oracle pending: " + kind)
				if mid == "super":
					expect(final.fighters[actor].meter < 1000, label + " meter spent, no repeated super")
				checks.append({"id": label, "selected": started, "damage": damaged, "damage_frames": damage_frames, "projectile": spawned, "travel": max_travel, "peak_y": max_height})
				if failures.size() >= 100:
					return

func guard_lattice() -> void:
	for operator in roster.operators:
		for actor in 2:
			for mid in ["stand_l", "crouch_l", "stand_h"]:
				var move: Dictionary = operator.moves[mid]
				for crouched in [false, true]:
					var sim: Variant = fixture_sim(operator.id, actor)
					if sim == null:
						return
					var victim := 1 - actor
					var initial: Dictionary = sim.snapshot()
					var final: Dictionary = initial
					for tick in 120:
						var inputs := [neutral(), neutral()]
						inputs[victim] = command(0, -1 if crouched else 0, 64, tick == 0)
						if tick == 1:
							inputs[actor] = move_command(mid, int(initial.fighters[actor].facing))
						final = sim.step(inputs)
					var blocks: bool = move.level == "mid" or (move.level == "low" and crouched) or (move.level == "overhead" and not crouched)
					var expected_damage := int(move.get("chip", 0)) if blocks else int(move.damage)
					var actual := int(initial.fighters[victim].hp - final.fighters[victim].hp)
					var label: String = operator.id + ":" + mid + " guard_low=" + str(crouched) + " side=" + str(actor)
					expect(actual == expected_damage, label + " independently expected guard damage")
					checks.append({"id": label, "expected_damage": expected_damage, "actual_damage": actual})

func throw_tech_and_charge_negatives() -> void:
	for operator in roster.operators:
		for actor in 2:
			for delay in [0, 9, 11]:
				var sim: Variant = fixture_sim(operator.id, actor)
				if sim == null:
					return
				var initial: Dictionary = sim.snapshot()
				var victim := 1 - actor
				var contact_tick := -1
				var final: Dictionary = initial
				for tick in 180:
					var inputs := [neutral(), neutral()]
					if tick == 0:
						inputs[actor] = move_command("throw_f", int(initial.fighters[actor].facing))
					if contact_tick >= 0 and tick == contact_tick + 1 + delay:
						inputs[victim] = command(0, 0, 32)
					final = sim.step(inputs)
					if contact_tick < 0 and str(final.fighters[victim].animation).begins_with("victim_"):
						contact_tick = tick
				var damage := int(initial.fighters[victim].hp - final.fighters[victim].hp)
				var label: String = operator.id + " throw tech delay=" + str(delay) + " side=" + str(actor)
				expect(contact_tick >= 0, label + " actual throw pair")
				expect(damage == (0 if delay < 10 else int(operator.moves.throw_f.damage)), label + " ten-frame visible tech window")
				checks.append({"id": label, "contact_tick": contact_tick, "damage": damage})
	for spec in [["deepseek", "special1"], ["grok", "special2"]]:
		for operator in roster.operators:
			if operator.id != spec[0]:
				continue
			for actor in 2:
				var sim: Variant = fixture_sim(operator.id, actor)
				if sim == null:
					return
				var selected := false
				for tick in 90:
					var inputs := [neutral(), neutral()]
					if tick == 0:
						inputs[actor] = move_command(spec[1], int(sim.snapshot().fighters[actor].facing))
					var next: Dictionary = sim.step(inputs)
					selected = selected or next.fighters[actor].move_id == spec[1]
				expect(not selected, operator.id + " charge cannot be bypassed by simple input")
				checks.append({"id": operator.id + "-uncharged-negative-" + str(actor), "selected": selected})

func _run() -> void:
	success_marker = "FIGHTING_ACCEPTANCE_MECHANICS_OK"
	report_scope = "authored family/guard/throw-tech/charge conformance; unresolved critical scenarios explicitly deferred"
	for path in ["res://fighting/core/simulation.gd", "res://fighting/data/roster.json", "res://fighting/data/rules.json"]:
		if not FileAccess.file_exists(path):
			unrun.append("missing dependency " + path)
	if not unrun.is_empty():
		finish()
		return
	roster = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/roster.json"))
	rules = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/rules.json"))
	simulation_script = load("res://fighting/core/simulation.gd")
	if simulation_script == null:
		failures.append("native simulation class load")
		finish()
		return
	family_outcomes()
	guard_lattice()
	throw_tech_and_charge_negatives()
	# These cannot disappear from a passing report while merged adapters are pending.
	unrun.append_array(["buffer exact 6/7 and queued hitstop edges", "raw SOCD device adapter", "command throw trade, wakeup invulnerability and pair KO cleanup", "projectile clash, reflect ownership, swept ledger and ordering", "juggle/floor/bounce/OTG finite loops", "all operator resources and stance variants", "malformed inputs and unknown mechanic rejection"])
	finish()
