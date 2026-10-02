extends SceneTree
const Simulation = preload("res://fighting/core/simulation.gd")
const AI = preload("res://fighting/core/ai.gd")
const F = preload("res://tests/fighting/core/fixtures.gd")
var failures: Array = []
var checks := 0

func _initialize() -> void:
	_validation()
	_inputs_and_freeze()
	_charge_and_policy()
	_hits_and_guard()
	_throws()
	_pair_clocks()
	_replay()
	_mechanics()
	_projectiles()
	_ai_rounds()
	print(JSON.stringify({"suite": "fighting-core", "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: " + label)

func sim(a: String = "chatgpt", b: String = "grok", training: bool = true):
	var s = Simulation.new()
	s.configure(F.roster(), F.rules())
	check(s.last_error.is_empty(), "fixture schema accepted: " + s.last_error)
	s.start_match({"operators": [a, b], "stage_id": "fixture", "seed": 7, "training": training})
	s.step([F.input(), F.input()])
	return s

func idle(s, ticks: int) -> void:
	for tick in range(ticks):
		s.step([F.input(), F.input()])

func _validation() -> void:
	var s = sim()
	var before: Dictionary = s.save_state()
	s.step([F.input()])
	check(not s.last_error.is_empty() and s.save_state() == before, "invalid input atomic rejection")
	s.start_match({"operators": ["missing", "grok"], "stage_id": "x", "seed": 1, "training": false})
	check(not s.last_error.is_empty() and s.save_state() == before, "unknown roster atomic rejection")
	var detached: Dictionary = s.snapshot()
	detached.fighters[0].hp = 1
	check(s.snapshot().fighters[0].hp == 500, "snapshot detached")
	var bad: Dictionary = before.duplicate(true)
	bad.state.fighters[0].hp = -1
	s.load_state(bad)
	check(not s.last_error.is_empty() and s.save_state() == before, "tampered save rejected")
	bad = before.duplicate(true)
	bad.state.fighters[0].x = 0.5
	s.load_state(bad)
	check(not s.last_error.is_empty() and s.save_state() == before, "fractional JSON value rejected without truncation")
	bad = before.duplicate(true)
	bad.state.fighters[0].resources.fuel = NAN
	s.load_state(bad)
	check(not s.last_error.is_empty() and s.save_state() == before, "nested nonfinite gauge rejected")

func _inputs_and_freeze() -> void:
	var s = sim()
	s.step([F.input(0, 0, 0, 1), F.input()])
	check(s.snapshot().fighters[0].move_id.is_empty(), "forged pressed cannot attack")
	s.step([F.input(1, 0, 0, 0), F.input()])
	check(s.snapshot().fighters[0].move_id == "stand_l", "real held edge ignores missing hint")
	idle(s, 2)
	var before: Dictionary = s.snapshot()
	s.step([F.input(2), F.input()])
	var after: Dictionary = s.snapshot()
	check(after.tick == before.tick + 1 and after.fighters[1].stun == before.fighters[1].stun and after.fighters[1].x == before.fighters[1].x and after.round_ticks_left == before.round_ticks_left, "hitstop freezes stun movement and timer together")
	check(after.fighters[0].history[-1].pressed == 2, "input collected during hitstop")
	idle(s, 4)
	check(s.snapshot().fighters[0].move_id == "stand_m", "buffer executes legal hit cancel after freeze")

func _charge_and_policy() -> void:
	var roster: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/roster.json"))
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/rules.json"))
	var s = Simulation.new()
	s.configure(roster, rules)
	check(s.last_error.is_empty(), "actual 138-move schema accepted")
	if not s.last_error.is_empty():
		return
	s.start_match({"operators": ["deepseek", "grok"], "stage_id": "test", "seed": 1, "training": true})
	s.training_reset()
	s.step([F.input(8), F.input()])
	check(s.snapshot().fighters[0].move_id.is_empty(), "DeepSeek simple S1 rejects uncharged")
	s.training_reset()
	for tick in range(36):
		s.step([F.input(64, -1), F.input()])
	idle(s, 5)
	s.step([F.input(8, 1), F.input()])
	check(s.snapshot().fighters[0].move_id == "special1", "DeepSeek charge retained sixth release tick")
	s.training_reset()
	for tick in range(36):
		s.step([F.input(64, -1), F.input()])
	idle(s, 6)
	s.step([F.input(8, 1), F.input()])
	check(s.snapshot().fighters[0].move_id.is_empty(), "DeepSeek charge expires seventh release tick")
	s.training_reset()
	for tick in range(18):
		s.step([F.input(), F.input(0, 0, -1)])
	s.step([F.input(), F.input(16)])
	check(s.snapshot().fighters[1].move_id == "special2", "Grok requires and consumes down charge")

func _pair_clocks() -> void:
	var s = sim()
	s.step([F.input(32), F.input()])
	var release_seen := false
	for tick in range(40):
		var pose: Dictionary = s.step([F.input(), F.input()])
		var phase: Dictionary = pose.fighters[0].get("animation_pair_phase", {})
		if not phase.is_empty() and pose.pair.is_empty():
			release_seen = true
			check(phase.frame == pose.fighters[0].animation_frame and phase.elapsed == phase.frame - phase.caught_move_frame, "recovery phase uses authoritative animation clock")
			var restored = sim()
			restored.load_state(JSON.parse_string(JSON.stringify(s.save_state())))
			check(restored.last_error.is_empty() and restored.snapshot() == pose, "release/recovery JSON restore preserves phase")
	check(release_seen, "release snapshot retains attacker pair projection")
	check(not s.snapshot().fighters[0].has("animation_pair_phase"), "animation transition clears recovery phase")
	s = sim()
	s.training_place({"fighters": [{"x": -550}, {"x": 550}]})
	s.step([F.input(32), F.input()])
	idle(s, 2)
	check(s.snapshot().pair.is_empty(), "throw first active frame out of range")
	s.training_place({"fighters": [{"x": -420}, {"x": 420}]})
	s.step([F.input(), F.input()])
	var view: Dictionary = s.snapshot()
	check(view.fighters[0].pair_phase.get("caught_move_frame", -1) == 3 and view.fighters[0].animation_frame == view.fighters[1].animation_frame, "late throw catch shared actual clock")
	s = sim("chatgpt", "claude")
	s.step([F.input(), F.input(40)])
	s.step([F.input(1), F.input()])
	idle(s, 2)
	view = s.snapshot()
	check(not view.pair.is_empty() and view.fighters[0].animation_frame == view.fighters[1].animation_frame, "delayed Claude counter becomes shared pair")

func _hits_and_guard() -> void:
	var s = sim()
	s.step([F.input(1), F.input(1)])
	idle(s, 2)
	var view: Dictionary = s.snapshot()
	check(view.fighters[0].hp == view.fighters[1].hp and view.fighters[0].hp < 500, "simultaneous trade")
	var frame: int = view.fighters[0].move_frame
	var tick: int = view.tick
	idle(s, 1)
	check(s.snapshot().tick == tick + 1 and s.snapshot().fighters[0].move_frame == frame, "absolute tick during hitstop")
	s = sim()
	for t in range(6):
		s.step([F.input(1), F.input(64)])
	check(s.snapshot().fighters[1].hp == 500, "standing mid guard")
	s = sim()
	for t in range(6):
		s.step([F.input(1, 0, -1), F.input(64)])
	check(s.snapshot().fighters[1].hp < 500, "low defeats high guard")
	s = sim()
	for t in range(6):
		s.step([F.input(1, 0, -1), F.input(64, 0, -1)])
	check(s.snapshot().fighters[1].hp == 500, "crouch low guard")
	s = sim()
	for t in range(70):
		s.step([F.input(1), F.input()])
	check(s.snapshot().fighters[1].hp == 440, "held attack cannot repeat")

func _throws() -> void:
	var s = sim()
	s.step([F.input(32), F.input()])
	idle(s, 2)
	check(not s.save_state().state.pair.is_empty(), "normal throw catches")
	idle(s, 8)
	s.step([F.input(), F.input(32)])
	check(s.snapshot().fighters[1].hp == 500 and s.save_state().state.pair.is_empty(), "tech accepted final frame elapsed nine")
	s = sim()
	s.step([F.input(32), F.input()])
	idle(s, 11)
	s.step([F.input(), F.input(32)])
	idle(s, 30)
	check(s.snapshot().fighters[1].hp == 360, "tech rejected elapsed ten")
	s = sim()
	s.step([F.input(32), F.input()])
	idle(s, 40)
	check(s.snapshot().fighters[1].hp == 360, "throw damage exactly once")
	s = sim()
	s.step([F.input(40), F.input()])
	idle(s, 3)
	s.step([F.input(), F.input(32)])
	idle(s, 30)
	check(s.snapshot().fighters[1].hp == 360, "command throw not normal-techable")
	s = sim()
	s.step([F.input(40), F.input(0, 0, 1)])
	idle(s, 8)
	check(s.snapshot().fighters[1].hp == 500, "jump escapes command throw startup")

func _replay() -> void:
	var s = sim()
	s.step([F.input(32), F.input()])
	idle(s, 3)
	var saved: Dictionary = s.save_state()
	var trace: Array = []
	for t in range(90):
		trace.append(s.step([F.input(1 if t % 19 == 0 else 0), F.input(2 if t % 23 == 0 else 0)]))
	s.load_state(JSON.parse_string(JSON.stringify(saved)))
	check(s.last_error.is_empty(), "JSON save loads during paired throw")
	for t in range(90):
		check(s.step([F.input(1 if t % 19 == 0 else 0), F.input(2 if t % 23 == 0 else 0)]) == trace[t], "replay equality tick " + str(t))
	var clone = Simulation.new()
	clone.configure(F.roster(), F.rules())
	clone.load_state(saved)
	check(clone.last_error.is_empty() and clone.save_state() == saved, "load into configured fresh instance")

func _mechanics() -> void:
	for id in F.IDS:
		var s = sim(id, "chatgpt")
		if id in ["claude", "meta", "gemini", "deepseek", "mistral"]:
			s.step([F.input(0, 0, 1), F.input()])
			idle(s, 3)
		var before: Dictionary = s.snapshot().fighters[0]
		s.step([F.input(16), F.input()])
		idle(s, 2)
		var f: Dictionary = s.snapshot().fighters[0]
		match id:
			"chatgpt": check(s.snapshot().fighters[1].hp < 500, "grapple real contact")
			"claude": check(f.mobility_type == "glide", "Claude glide active")
			"grok": check(f.vy > 0, "Grok super jump")
			"meta": check(f.resources.brace > 0 and f.vy < 0, "Meta brace slam")
			"gemini": check(f.double_jump_used and f.resources.stance == 1, "Gemini jump stance")
			"deepseek": check(f.resources.fuel < before.resources.fuel, "DeepSeek fuel consumed")
			"mistral": check(f.air_dash_used and f.vx > 0, "Mistral air dash")
			"kimi": check(f.x > before.x + 1000, "Kimi bounded blink")
			"qwen": check(f.anchor_left > 0, "Qwen anchor deployed")
		idle(s, 260)
		check(s.snapshot().fighters[0].anchor_left == 0, id + " finite anchor")

func _projectiles() -> void:
	var s = sim("chatgpt", "chatgpt")
	s.step([F.input(8), F.input(8)])
	var clash := false
	for t in range(12):
		var view: Dictionary = s.step([F.input(), F.input()])
		for event in view.events:
			clash = clash or event.type == "projectile_clash"
	check(clash, "opposing projectile clash")
	s = sim("chatgpt", "claude")
	s.step([F.input(8), F.input(40)])
	var reflected := false
	for t in range(8):
		var view: Dictionary = s.step([F.input(), F.input()])
		for event in view.events:
			reflected = reflected or event.type == "reflect"
	check(reflected, "Claude real projectile reflect")
	idle(s, 250)
	check(s.snapshot().projectiles.is_empty(), "finite projectile lifecycle")

func _ai_rounds() -> void:
	var s = sim("chatgpt", "grok", false)
	var a = AI.new()
	var b = AI.new()
	a.configure(71, 2)
	b.configure(19, 2)
	var initial: Dictionary = s.snapshot()
	var ai_saved: Dictionary = a.save_state()
	var command: Dictionary = a.command(initial, 0)
	a.load_state(ai_saved)
	check(a.command(initial, 0) == command, "AI save restores decisions")
	var saw_damage := false
	for t in range(5000):
		var view: Dictionary = s.snapshot()
		if view.phase == "match_over":
			break
		s.step([a.command(view, 0), b.command(view, 1)])
		for event in s.snapshot().events:
			saw_damage = saw_damage or event.type in ["hit", "throw_hit"]
	check(saw_damage, "AI input-only damage")
	check(s.snapshot().phase == "match_over", "AI input-only full match lifecycle")
