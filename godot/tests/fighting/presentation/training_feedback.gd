extends SceneTree
## Native gate for the read-only training feedback/query helper.
## Prepared under the source-only grant; it performs no rendering, audio, import
## or package work and needs a later ordinary Godot engine grant to execute.
##
## It drives the helper with the real authored roster, real input-router commands
## and synthetic authority snapshots whose events mirror core emissions. It
## asserts hit/block/whiff/cancel/throw/tech/mobility tracking, operator-derived
## goals, exact reset/lifecycle behaviour and that the helper never mutates inputs.

const Feedback = preload("res://fighting/presentation/training_feedback.gd")
const Router = preload("res://fighting/presentation/input_router.gd")

var failures: Array = []
var event_serial := 0

func _initialize() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/roster.json"))
	_check(parsed is Dictionary, "real roster loads")
	if not parsed is Dictionary:
		_finish()
		return
	var roster: Dictionary = parsed
	_check(roster.get("operators",[]).size() == 9, "nine authored operators")

	# Goals are derived from each operator's own authored moves, never invented.
	for profile: Dictionary in roster.operators:
		var fb := Feedback.new()
		fb.reset([str(profile.id),str(profile.id)],roster)
		_check(fb.goals(0).size() == 7, "%s exposes seven authored goals" % profile.id)
		for goal: Dictionary in fb.goals(0):
			if str(goal.kind) in ["move_land","mobility"]:
				_check(profile.moves.has(str(goal.target)), "%s goal target %s is authored" % [profile.id,goal.target])
		_check(goal_contains(fb,str(profile.moves.special1.name)), "%s signature goal names its real move" % profile.id)
		_check(goal_contains(fb,str(profile.moves.crouch_l.name)), "%s low goal names its real move" % profile.id)
		_check(fb.goal_summary(0) == "0/7 goals", "%s starts with no completed goals" % profile.id)

	# Characterise an ordinary input through the real mapper, then feed its command.
	var fb_lifecycle := Feedback.new()
	fb_lifecycle.reset(["chatgpt","kimi"],roster)
	var router := Router.new()
	_router_key(router,KEY_D,true)
	_router_key(router,KEY_F,true)
	var command := router.command(0)
	_check(command.axis_x == 1 and command.held == 1 and command.pressed == 1, "real mapper emits forward light edge")
	var sample := _state(1,"stand_l",[])
	var before := JSON.stringify(sample)
	fb_lifecycle.observe(sample,[command,_neutral()])
	_check(JSON.stringify(sample) == before, "ordinary-input observation never mutates the snapshot")
	_check(fb_lifecycle.history_line(0,5).contains("6L!"), "readable facing-relative input history")
	_check(fb_lifecycle.history_line(0,5).contains("stand_l"), "history attaches the recognised move")

	# Full outcome matrix from real event shapes: hit, whiff, cancel, block,
	# throw, tech, mobility, super and a low hit; goal progress accumulates.
	var fb := Feedback.new()
	fb.reset(["chatgpt","mistral"],roster)
	_start(fb,2,"stand_l",[_hit(0,1,"stand_l",48)])
	_end(fb,3)
	_check(fb.last_result(0).state == "hit", "real hit finalises as hit")
	_start(fb,4,"stand_h")
	_end(fb,5)
	_check(fb.last_result(0).state == "no_contact", "missing contact does not assert whiff")
	_start(fb,6,"stand_l")
	_start(fb,7,"special1")
	_check(fb.last_result(0).state == "no_contact", "replacement alone does not assert cancel")
	_start(fb,8,"special1",[_block(0,1,"special1")])
	_feed(fb,9,"",[_block(1,0,"stand_l")])
	_check(fb.last_result(0).state == "block", "blocked contact is distinguished")
	_check(fb.goals(0).any(func(goal): return str(goal.id) == "block" and bool(goal.done)), "blocking completes the defender goal")
	_start(fb,10,"throw_f",[_throw_hit(0,1,"throw_f",130)])
	_end(fb,11)
	_check(fb.last_result(0).state == "throw", "landed throw is distinguished")
	_feed(fb,12,"",[_throw_tech(0,1)])
	_check(not fb.goals(0).any(func(goal): return str(goal.id) == "tech" and bool(goal.done)), "having a throw teched does not complete incoming-tech goal")
	_feed(fb,13,"",[_throw_tech(1,0),_mobility(0,1,"special2")])
	_start(fb,14,"super",[_hit(0,1,"super",240)],3,310)
	_end(fb,15)
	_check(fb.result_text(0).contains("chain 3"), "live hit chain comes from the core combo counters")
	_start(fb,16,"crouch_l",[_hit(0,1,"crouch_l",45)])
	_end(fb,17)
	_start(fb,18,"special1",[_hit(0,1,"special1",85)])
	_end(fb,19)
	_check(fb.goal_summary(0) == "7/7 goals", "all seven authored goals complete from real events")
	_check(fb.goals(1).any(func(goal): return str(goal.id) == "block" and bool(goal.done)), "defender block goal completes from the target side")
	_check(fb.goals(1).any(func(goal): return str(goal.id) == "tech" and bool(goal.done)), "tech goal completes for the teching defender")

	# Reset/lifecycle: transient reset clears history but keeps practice progress;
	# a full reset rebuilds another operator's goals at zero; history stays bounded.
	var completed := fb.goal_summary(0)
	for i: int in 20:
		_feed(fb,20+i,"",[])
	_check(fb.history_rows(0).size() == Feedback.HISTORY_LIMIT, "input history is bounded")
	_check(fb.last_result(0).state == "hit", "latest result survives further neutral ticks")
	fb.reset_transient()
	_check(fb.history_rows(0).is_empty() and fb.last_result(0).is_empty(), "transient reset clears live history")
	_check(fb.goal_summary(0) == completed, "transient reset keeps practice progress")
	fb.reset(["kimi","qwen"],roster)
	_check(fb.goal_summary(0) == "0/7 goals", "new match restarts goal progress")
	_check(goal_contains(fb,str(roster.operators[7].moves.super.name)), "new operator goals rebuild from its authored data")

	# Duplicate observations must be idempotent, including goal counts.
	var saved := fb.save_observation()
	var duplicate := _state(50,"special1",[_hit(0,1,"special1",85)])
	fb.observe(duplicate,[_neutral(),_neutral()])
	var once := JSON.stringify(fb.save_observation())
	fb.observe(duplicate,[_neutral(),_neutral()])
	_check(JSON.stringify(fb.save_observation()) == once,"same snapshot never awards twice")
	fb.restore_observation(saved)
	_check(JSON.stringify(fb.save_observation()) == JSON.stringify(saved),"replay restores exact observation prefix, not future goals")
	_start(fb,51,"stand_h")
	_feed(fb,52,"stand_h",[_hit(0,1,"special1",85)])
	_check(fb._pending[0].move_id == "stand_h","delayed projectile cannot rename running move")
	_check(fb.last_result(0).move_id == "special1","delayed contact keeps its event move")
	_end(fb,53)
	_check(fb.last_result(0).move_id == "stand_h" and fb.last_result(0).state == "no_contact","next move does not inherit projectile hit")
	_start(fb,54,"special1")
	var projectile := _hit(0,1,"special1",85)
	projectile.projectile_id = 7
	_feed(fb,55,"special1",[projectile])
	_check(fb._pending[0].outcome=="" and fb.last_result(0).name=="Projectile (special1)","same-ID projectile contact is not credited to a new attempt or reflected owner's move name")
	var new_round := _state(56,"",[])
	new_round.round_index = 2
	fb.observe(new_round,[_neutral(),_neutral()])
	_check(fb.goal_summary(0)=="0/7 goals" and fb.last_result(0).is_empty(),"round boundary clears prior round counts and results")
	_real_core_replay(roster)
	_finish()

func _real_core_replay(roster: Dictionary) -> void:
	var core := preload("res://fighting/core/simulation.gd").new()
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/rules.json"))
	core.configure(roster,rules)
	core.start_match({"operators":["chatgpt","mistral"],"stage_id":"test","seed":17,"training":true,"simple_specials":true})
	_check(core.last_error.is_empty(),"real core configured")
	var fb := Feedback.new()
	fb.reset(["chatgpt","mistral"],roster)
	var prefix: Dictionary
	var observed_prefix: Dictionary
	var inputs: Array = []
	var contacts := 0
	for tick in 480:
		if tick == 160:
			prefix = core.save_state()
			observed_prefix = fb.save_observation()
		var command := {"axis_x":1 if tick < 150 else 0,"axis_y":0,"held":1 if tick%40==0 else 0,"pressed":1 if tick%40==0 else 0}
		var commands := [command,_neutral()]
		if tick >= 160: inputs.append(commands.duplicate(true))
		var snapshot: Dictionary = core.step(commands)
		var before := JSON.stringify(snapshot)
		fb.observe(snapshot,commands)
		_check(JSON.stringify(snapshot)==before,"observer leaves real snapshot untouched")
		for event: Dictionary in snapshot.events:
			if event.type=="hit": contacts += 1
	_check(contacts>0,"ordinary-input real core produced contact")
	var expected := JSON.stringify(fb.save_observation())
	core.load_state(prefix)
	fb.restore_observation(observed_prefix)
	for commands: Array in inputs: fb.observe(core.step(commands),commands)
	_check(JSON.stringify(fb.save_observation())==expected,"real core replay yields identical feedback and counts")

func _start(fb: RefCounted, tick: int, move: String, events: Array = [], combo_hits: int = 0, combo_damage: int = 0) -> void:
	fb.observe(_state(tick,move,events,combo_hits,combo_damage),[_neutral(),_neutral()])

func _end(fb: RefCounted, tick: int) -> void:
	fb.observe(_state(tick,"",[]),[_neutral(),_neutral()])

func _feed(fb: RefCounted, tick: int, move: String, events: Array) -> void:
	fb.observe(_state(tick,move,events),[_neutral(),_neutral()])

func _state(tick: int, p0_move: String, events: Array, combo_hits: int = 0, combo_damage: int = 0) -> Dictionary:
	return {"version":1,"tick":tick,"round_index":1,"phase":"fight","events":events,
		"fighters":[{"facing":1,"move_id":p0_move,"combo_hits":0,"combo_damage":0},
			{"facing":-1,"move_id":"","combo_hits":combo_hits,"combo_damage":combo_damage}]}

func _event(type: String, actor: int, target: int, move_id: String, extra: Dictionary = {}) -> Dictionary:
	event_serial += 1
	var event := {"id":event_serial,"tick":0,"type":type,"actor":actor,"target":target,"move_id":move_id,"x":0,"y":0,"effect":""}
	event.merge(extra,true)
	return event

func _hit(actor: int, target: int, move_id: String, damage: int) -> Dictionary:
	return _event("hit",actor,target,move_id,{"damage":damage,"blocked":false})

func _block(actor: int, target: int, move_id: String) -> Dictionary:
	return _event("block",actor,target,move_id,{"damage":0,"blocked":true})

func _throw_hit(actor: int, target: int, move_id: String, damage: int) -> Dictionary:
	return _event("throw_hit",actor,target,move_id,{"damage":damage})

func _throw_tech(actor: int, target: int) -> Dictionary:
	return _event("throw_tech",actor,target,"")

func _mobility(actor: int, target: int, move_id: String) -> Dictionary:
	return _event("mobility",actor,target,move_id,{"mechanic":"glide"})

func _neutral() -> Dictionary:
	return {"axis_x":0,"axis_y":0,"held":0,"pressed":0}

func _router_key(router: RefCounted, code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	router.ingest(event)

func goal_contains(fb: RefCounted, needle: String) -> bool:
	if needle.is_empty():
		return false
	return fb.goal_lines(0).any(func(line): return str(line).contains(needle))

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _finish() -> void:
	print("FIGHTING_TRAINING_FEEDBACK ",JSON.stringify({"passed":failures.is_empty(),"failures":failures}))
	if failures.is_empty():
		print("FIGHTING_TRAINING_FEEDBACK_OK")
	quit(0 if failures.is_empty() else 1)
