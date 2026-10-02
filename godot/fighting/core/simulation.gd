extends RefCounted
## Integer, local fixed-tick authority. Every mutable gameplay value lives in _state.
const Recognizer = preload("res://fighting/core/recognizer.gd")
const Schema = preload("res://fighting/core/schema.gd")
const IntegerMath = preload("res://fighting/core/integer_math.gd")
const Codec = preload("res://fighting/core/state_codec.gd")
var last_error := ""
var _catalog: Dictionary = {}
var _roster: Dictionary = {}
var _rules: Dictionary = {}
var _state: Dictionary = {}

func configure(roster: Dictionary, rules: Dictionary) -> void:
	if not Codec.valid_tree(roster) or not Codec.valid_tree(rules):
		last_error = "configuration must be a finite integral JSON tree"
		return
	last_error = Schema.validate(roster, rules)
	if not last_error.is_empty():
		return
	_roster = Codec.decode(roster)
	_rules = Codec.decode(rules)
	_catalog = {}
	for operator in _roster.operators:
		_catalog[operator.id] = operator.duplicate(true)
		for key in operator.moves:
			_catalog[operator.id].moves[key] = Schema.normalize_move(operator.moves[key])
	_state = {}

func start_match(config: Dictionary) -> void:
	last_error = ""
	if not Codec.valid_tree(config):
		last_error = "invalid match value type"
		return
	if _catalog.is_empty() or not config.get("operators") is Array or config.operators.size() != 2 or not config.get("stage_id") is String or not Recognizer.integral(config.get("seed")) or not config.get("training") is bool:
		last_error = "invalid match configuration"
		return
	if config.stage_id.is_empty() or absi(int(config.seed)) > 0x7fffffff:
		last_error = "invalid stage/seed"
		return
	if config.has("simple_specials") and not config.simple_specials is bool:
		last_error = "simple_specials must be boolean"
		return
	for id in config.operators:
		if not _catalog.has(id):
			last_error = "unknown operator"
			return
	_state = {"version": 1, "tick": 0, "phase": "intro", "round_index": 1,
		"round_ticks_left": int(_rules.round_seconds) * 60, "wins": [0, 0],
		"winner": -1, "stage_id": config.stage_id, "config": config.duplicate(true),
		"fighters": [], "projectiles": [], "events": [], "pair": {}, "rng": int(config.seed),
		"next_event": 1, "next_projectile": 1, "next_move": 1, "freeze": 0,
		"phase_ticks": int(_rules.get("round_intro_frames", _rules.get("intro_frames", 60)))}
	_reset_round()

func _reset_round() -> void:
	_state.fighters = []
	_state.projectiles = []
	_state.pair = {}
	_state.freeze = 0
	_state.round_ticks_left = int(_rules.round_seconds) * 60
	_state.phase = "intro"
	_state.phase_ticks = int(_rules.get("round_intro_frames", _rules.get("intro_frames", 60)))
	for id in range(2):
		var op: Dictionary = _catalog[_state.config.operators[id]]
		var resource: Dictionary = op.resource
		var gauges := {"heat": 0, "ward": 0, "brace": 0, "charge": 0,
			"fuel": int(resource.get("hover_fuel", 90)), "stance": 0,
			"anchor": 0, "blink": 0, "adaptive": 0, "tempo": 0, "context": 0, "tool": 0}
		var gauge_id: String = resource.get("id", "")
		if not gauge_id.is_empty():
			gauges[gauge_id] = clampi(int(resource.get("initial", 0)), 0, int(resource.get("max", 100)))
		_state.fighters.append({"id": id, "operator_id": op.id,
			"x": (-1 if id == 0 else 1) * int(_rules.get("spawn_distance", 2400)),
			"y": 0, "vx": 0, "vy": 0, "facing": 1 if id == 0 else -1,
			"hp": int(op.stats.hp), "meter": 0, "state": "idle", "move_id": "",
			"move_frame": 0, "animation": "idle", "animation_frame": 0,
			"hitstop": 0, "stun": 0, "combo_hits": 0, "combo_damage": 0,
			"resources": gauges, "history": [], "buffer": {}, "previous_held": 0,
			"previous_y": 0, "jump_edge": false, "input": _neutral(),
			"cooldowns": {}, "move_serial": 0, "hit_ledger": [], "contact": "whiff",
			"invuln": 0, "throw_invuln": 0, "down": 0, "juggle": 0,
			"wall_bounces": 0, "ground_bounces": 0, "otg": 0,
			"armor_used": 0, "air_dash_used": false, "double_jump_used": false,
			"stance_left": 0, "anchor_left": 0, "anchor_x": 0,
			"mobility_left": 0, "mobility_type": "", "charge_back": 0,
			"heat_idle": 0, "dash_left": 0, "knockdown_pending": 0,
			"charge_down": 0, "back_release": 0, "down_release": 0,
			"ground_regen": 0, "jump_start": 0, "landing_left": 0,
			"mobility_distance": 0, "mobility_cap": 0, "mobility_vx": 0,
			"mobility_vy": 0, "anchor_range": 0, "anchor_pull": 0,
			"pull_left": 0, "pull_speed": 0, "pull_target": 0, "pull_budget": 0})
	_emit("round_start", -1, -1)

func step(inputs: Array) -> Dictionary:
	last_error = ""
	if _state.is_empty() or inputs.size() != 2 or not Recognizer.valid(inputs[0]) or not Recognizer.valid(inputs[1]):
		last_error = "step requires active match and two valid commands"
		return snapshot()
	_state.tick += 1
	_state.events = []
	for id in range(2):
		Recognizer.ingest(_state.fighters[id], inputs[id], int(_state.tick), mini(6, int(_rules.get("buffer_frames", 6))), bool(_state.config.get("simple_specials", true)), _catalog[_state.fighters[id].operator_id].moves)
	if _state.phase != "fight":
		_phase_step()
		return snapshot()
	if _state.freeze > 0:
		_state.freeze -= 1
		for f in _state.fighters:
			f.hitstop = _state.freeze
		return snapshot()
	if not _state.config.training:
		_state.round_ticks_left = maxi(0, int(_state.round_ticks_left) - 1)
	if not _state.pair.is_empty():
		_pair_step()
	else:
		# Both actors advance before any contact is resolved.
		# Neutral facing samples the same pre-movement pair for both actors.
		for id in range(2):
			var f: Dictionary = _state.fighters[id]
			if f.move_id.is_empty() and f.stun == 0 and f.down == 0:
				f.facing = 1 if _state.fighters[1 - id].x >= f.x else -1
		for id in range(2):
			_advance(_state.fighters[id], _state.fighters[1 - id])
		_anchors()
		_push()
		_projectiles_advance()
		var contacts: Array = _collect_contacts()
		_resolve_contacts(contacts)
		for f in _state.fighters:
			f.x = clampi(int(f.x), -int(_rules.stage_half_width) + 350, int(_rules.stage_half_width) - 350)
		_projectiles_cleanup()
	_round_result()
	return snapshot()

func snapshot() -> Dictionary:
	if _state.is_empty():
		return {}
	var result := _state.duplicate(true)
	for key in ["config", "rng", "next_event", "next_projectile", "next_move"]:
		result.erase(key)
	for f in result.fighters:
		for key in ["previous_held", "previous_y", "hit_ledger", "cooldowns", "buffer"]:
			f.erase(key)
		f["boxes"] = {"hurt": _hurt(f), "push": _pushbox(f), "hit": _hitboxes(f)}
		f["pair_phase"] = {}
		if not _state.pair.is_empty():
			var pair: Dictionary = _state.pair
			f.pair_phase = {"actor": pair.actor, "target": pair.target,
				"caught_move_frame": pair.caught_move_frame, "elapsed": pair.elapsed,
				"damage_frame": pair.damage_frame, "release_frame": pair.duration,
				"end_frame": pair.end_frame, "frame": pair.frame, "move_id": pair.move_id}
	return result

func training_reset(setup: Dictionary = {}) -> void:
	_training_apply(setup, true)

func training_place(setup: Dictionary) -> void:
	_training_apply(setup, false)

func _training_apply(setup: Dictionary, reset: bool) -> void:
	last_error = ""
	if _state.is_empty() or not _state.config.training:
		last_error = "training_reset is training-only"
		return
	var fighters: Variant = setup.get("fighters", [])
	if not fighters is Array or fighters.size() not in [0, 2]:
		last_error = "training setup needs two placements"
		return
	for f in fighters:
		if not f is Dictionary:
			last_error = "invalid training placement"
			return
		for key in f:
			if not key in ["x", "y", "meter"] or not Recognizer.integral(f[key]):
				last_error = "unknown/invalid training field"
				return
		if absi(int(f.get("x", 0))) > int(_rules.stage_half_width) - 350 or int(f.get("y", 0)) not in range(0, 6001) or int(f.get("meter", 0)) not in range(0, 1001):
			last_error = "training placement outside bounds"
			return
	_state.events = []
	if reset:
		_reset_round()
	_state.phase = "fight"
	for id in range(fighters.size()):
		for key in fighters[id]:
			_state.fighters[id][key] = int(fighters[id][key])
	for id in range(2):
		_state.fighters[id].facing = 1 if _state.fighters[id].x < _state.fighters[1 - id].x else -1
	_emit("training_reset" if reset else "training_place", -1, -1)

func save_state() -> Dictionary:
	if _state.is_empty():
		return {}
	return {"version": 1, "roster": _roster.duplicate(true), "rules": _rules.duplicate(true), "state": _state.duplicate(true), "checksum": JSON.stringify(_state).sha256_text()}

func load_state(saved: Dictionary) -> void:
	last_error = ""
	if not Codec.valid_tree(saved):
		last_error = "save contains nonintegral/nonfinite/non-JSON value"
		return
	if saved.get("version") != 1 or saved.get("roster") != _roster or saved.get("rules") != _rules or not saved.get("state") is Dictionary:
		last_error = "saved configuration/version mismatch"
		return
	var candidate: Dictionary = Codec.decode(saved.state)
	if saved.get("checksum", "") != JSON.stringify(candidate).sha256_text():
		last_error = "saved state checksum mismatch"
		return
	if not _valid_saved(candidate):
		last_error = "invalid saved state"
		return
	_state = candidate

func _valid_saved(s: Dictionary) -> bool:
	if not Codec.valid_state(s):
		return false
	for key in ["version", "tick", "phase", "round_index", "round_ticks_left", "wins", "winner", "stage_id", "config", "fighters", "projectiles", "events", "pair", "rng", "next_event", "next_projectile", "next_move", "freeze", "phase_ticks"]:
		if not s.has(key):
			return false
	if not s.fighters is Array or not s.projectiles is Array or not s.pair is Dictionary or not s.config is Dictionary:
		return false
	if s.fighters.size() != 2 or not s.phase in ["intro", "fight", "round_over", "match_over"] or s.tick < 0 or s.freeze < 0 or s.freeze > 30:
		return false
	for id in range(2):
		if not s.fighters[id] is Dictionary:
			return false
		var f: Dictionary = s.fighters[id]
		for key in ["id", "operator_id", "x", "y", "vx", "vy", "facing", "hp", "meter", "state", "move_id", "move_frame", "animation", "animation_frame", "hitstop", "stun", "combo_hits", "combo_damage", "resources", "history", "buffer", "previous_held", "previous_y", "jump_edge", "input", "cooldowns", "move_serial", "hit_ledger", "contact", "invuln", "throw_invuln", "down", "juggle", "wall_bounces", "ground_bounces", "otg", "armor_used", "air_dash_used", "double_jump_used", "stance_left", "anchor_left", "anchor_x", "mobility_left", "mobility_type", "charge_back", "heat_idle", "dash_left", "knockdown_pending"]:
			if not f.has(key):
				return false
		if f.id != id or not _catalog.has(f.operator_id) or f.hp < 0 or f.meter < 0 or f.meter > 1000 or not f.facing in [-1, 1]:
			return false
		if not f.move_id.is_empty() and not _catalog[f.operator_id].moves.has(f.move_id):
			return false
		if not Recognizer.valid(f.input):
			return false
	return true

func _phase_step() -> void:
	if _state.phase == "match_over":
		return
	_state.phase_ticks -= 1
	if _state.phase_ticks > 0:
		return
	if _state.phase == "intro":
		_state.phase = "fight"
		for f in _state.fighters:
			f.buffer = {}
		_emit("fight", -1, -1)
	elif _state.phase == "round_over":
		if _state.wins[0] >= _rules.rounds_to_win or _state.wins[1] >= _rules.rounds_to_win:
			_state.phase = "match_over"
			_emit("match_over", int(_state.winner), -1)
		else:
			_state.round_index += 1
			_reset_round()

func _round_result() -> void:
	var a: Dictionary = _state.fighters[0]
	var b: Dictionary = _state.fighters[1]
	if a.hp > 0 and b.hp > 0 and _state.round_ticks_left > 0:
		return
	_state.winner = -1 if a.hp == b.hp else (0 if a.hp > b.hp else 1)
	if _state.winner >= 0:
		_state.wins[_state.winner] += 1
	_state.phase = "round_over"
	_state.phase_ticks = int(_rules.get("round_over_frames", 120))
	_state.pair = {}
	_state.projectiles = []
	for f in _state.fighters:
		f.move_id = ""
		f.state = "win" if f.id == _state.winner else "lose"
		f.animation = f.state
	_emit("round_over", int(_state.winner), -1)

func _advance(f: Dictionary, enemy: Dictionary) -> void:
	f.animation_frame += 1
	f.invuln = maxi(0, int(f.invuln) - 1)
	f.throw_invuln = maxi(0, int(f.throw_invuln) - 1)
	for key in f.cooldowns.keys():
		f.cooldowns[key] = maxi(0, int(f.cooldowns[key]) - 1)
	_resources(f)
	if f.down > 0:
		f.down -= 1
		f.state = "knockdown"
		f.animation = "knockdown"
		if f.down == 0:
			f.invuln = int(_rules.get("wakeup_invulnerability_frames", _rules.get("wakeup_invuln", 12)))
			f.throw_invuln = int(_rules.get("throw_invulnerability_frames", _rules.get("throw_invuln", 20)))
			f.animation = "wakeup"
			_reset_combo(f)
		return
	if f.stun > 0:
		f.stun -= 1
		f.throw_invuln = maxi(int(f.throw_invuln), 2)
		_physics(f)
		if f.stun == 0 and f.y == 0 and f.knockdown_pending > 0:
			f.down = f.knockdown_pending
			f.knockdown_pending = 0
		return
	if f.y == 0:
		_reset_combo(f)
	_try_move(f)
	if not f.move_id.is_empty():
		var move := _move(f)
		f.move_frame += 1
		f.animation_frame = f.move_frame
		if f.move_frame == int(move.get("projectile", {}).get("spawn_frame", move.startup)) and (move.has("projectile") or move.kind == "projectile"):
			_spawn_projectile(f, move)
		if f.move_frame == int(move.startup):
			_set_stance(f, move)
		if move.has("movement") and f.move_frame == int(move.movement.get("from", move.startup)):
			_activate(f, enemy, move)
		if f.move_frame >= int(move.startup) + int(move.active) + int(move.recovery) - 1:
			f.move_id = ""
			f.move_frame = 0
			f.state = "idle"
	else:
		_locomotion(f)
	_physics(f)

func _try_move(f: Dictionary) -> void:
	if f.buffer.is_empty() or f.dash_left > 0 or f.jump_start > 0 or f.landing_left > 0:
		return
	var key: String = f.buffer.move
	var moves: Dictionary = _catalog[f.operator_id].moves
	if not moves.has(key):
		return
	if f.resources.stance == 1:
		for candidate in moves.values():
			var variants: Dictionary = candidate.get("stance", {}).get("variants", {})
			if variants.has(key):
				key = variants[key]
				break
	if not moves.has(key):
		return
	var move: Dictionary = moves[key]
	if (f.y > 0 and not move.get("air_ok", true)) or (f.y == 0 and not move.get("ground_ok", true)):
		return
	if not f.move_id.is_empty():
		var allowed := false
		for cancel in _move(f).cancels:
			if cancel.to == key and f.move_frame >= cancel.from and f.move_frame <= cancel.until and f.contact in cancel.on:
				allowed = true
		if not allowed:
			return
	if f.meter < move.meter_cost or int(f.cooldowns.get(key, 0)) > 0:
		return
	if key == "super" and f.meter < 1000:
		return
	if move.get("stance", {}).has("requires") and f.resources.stance != move.stance.requires:
		return
	var charge: int = int(f.charge_down) if move.get("charge_axis", "back") == "down" else int(f.charge_back)
	if int(move.get("charge_frames", 0)) > charge:
		return
	var motion: String = move.get("movement", {}).get("type", "")
	if move.get("movement", {}).get("air_only", false) and f.y == 0 or move.get("movement", {}).get("ground_only", false) and f.y > 0:
		return
	if motion in ["air_dash", "double_jump", "hover", "glide", "brace_slam"] and f.y == 0:
		return
	if motion == "air_dash" and f.air_dash_used or motion == "double_jump" and f.double_jump_used:
		return
	if motion == "hover" and f.resources.fuel <= 0:
		return
	if move.kind == "throw" and f.y > 0:
		return
	var effect: Dictionary = move.get("resource_effect", {})
	var gauge: String = effect.get("resource", "")
	if not gauge.is_empty() and int(f.resources.get(gauge, 0)) < int(effect.get("cost", 0)):
		return
	f.meter -= 1000 if key == "super" else int(move.meter_cost)
	if not gauge.is_empty():
		_gauge(f, gauge, (int(effect.get("gain", 0)) if effect.get("on", "start") == "start" else 0) - int(effect.get("cost", 0)))
	f.move_id = key
	f.move_frame = -1
	f.move_serial = _state.next_move
	_state.next_move += 1
	f.hit_ledger = []
	f.contact = "whiff"
	f.armor_used = 0
	f.state = "attack"
	f.animation = move.animation
	f.animation_frame = 0
	f.buffer = {}
	f.vx = 0
	f.cooldowns[key] = int(move.get("cooldown", move.get("movement", {}).get("cooldown", 0)))
	if move.get("charge_frames", 0) > 0:
		f.charge_back = 0
		f.charge_down = 0
	_emit("move_start", int(f.id), -1, key)

func _locomotion(f: Dictionary) -> void:
	var input: Dictionary = f.input
	var stats: Dictionary = _catalog[f.operator_id].stats
	if f.landing_left > 0:
		f.landing_left -= 1
		f.vx = 0
		f.animation = "land"
		return
	if f.jump_start > 0:
		f.jump_start -= 1
		if f.jump_start == 0:
			f.vy = int(stats.jump_velocity)
		return
	if f.dash_left > 0:
		f.dash_left -= 1
		f.state = "dash"
		return
	if f.jump_edge and f.y == 0:
		f.jump_start = int(_rules.get("jump_startup", 0))
		if f.jump_start == 0:
			f.vy = int(stats.jump_velocity)
		f.state = "jump"
		_emit("jump", int(f.id), -1)
	if int(input.pressed) & 128 and f.y == 0:
		f.dash_left = 12
		f.vx = (int(input.axis_x) if input.axis_x != 0 else int(f.facing)) * int(stats.walk_speed) * 3
		f.animation = "dash_f" if f.vx * f.facing > 0 else "dash_b"
		return
	var guarding: bool = int(input.held) & 64 != 0
	f.vx = int(input.axis_x) * int(stats.walk_speed) if not guarding and input.axis_y >= 0 else 0
	f.state = "guard" if guarding else ("crouch" if input.axis_y < 0 and f.y == 0 else ("walk" if f.vx != 0 else "idle"))
	f.animation = ("guard_lo" if input.axis_y < 0 else "guard_hi") if guarding else ("crouch" if f.state == "crouch" else ("walk_f" if f.vx * f.facing > 0 else "walk_b") if f.vx != 0 else "idle")

func _physics(f: Dictionary) -> void:
	if f.pull_left > 0:
		f.pull_left -= 1
		var pull := clampi(int(f.pull_target) - int(f.x), -int(f.pull_speed), int(f.pull_speed))
		pull = clampi(pull, -int(f.pull_budget), int(f.pull_budget))
		f.x += pull
		f.pull_budget -= absi(pull)
	if f.mobility_left > 0:
		f.mobility_left -= 1
		if f.mobility_type in ["hover", "air_dash"]:
			f.vy = int(f.mobility_vy)
		elif f.mobility_type == "glide":
			f.vy = maxi(int(f.vy), int(f.mobility_vy))
		f.vx = int(f.mobility_vx)
		var remaining := maxi(0, int(f.mobility_cap) - int(f.mobility_distance))
		f.vx = clampi(int(f.vx), -remaining, remaining)
		f.mobility_distance += absi(int(f.vx))
	f.x = clampi(int(f.x) + int(f.vx), -int(_rules.stage_half_width) + 350, int(_rules.stage_half_width) - 350)
	if f.mobility_left == 0 and f.mobility_type in ["dash", "air_dash", "hover", "glide"] and not f.move_id.is_empty():
		f.vx = 0
	if f.y > 0 or f.vy > 0:
		f.y = maxi(0, int(f.y) + int(f.vy))
		f.vy = maxi(-int(_rules.get("terminal_velocity", 400)), int(f.vy) - int(_rules.get("gravity", 12)) - int(f.juggle))
		if f.move_id.is_empty() and f.stun == 0:
			f.animation = "jump_rise" if f.vy > 20 else ("jump_apex" if f.vy >= -20 else "jump_fall")
		if f.y == 0:
			f.vy = 0
			f.air_dash_used = false
			f.double_jump_used = false
			f.mobility_left = 0
			f.landing_left = int(_rules.get("landing_recovery", 0))
			for move in _catalog[f.operator_id].moves.values():
				var effect: Dictionary = move.get("resource_effect", {})
				if effect.get("reset_on_land", false):
					f.resources[effect.resource] = int(_catalog[f.operator_id].resource.get("max", 100))
			if f.knockdown_pending > 0:
				f.down = f.knockdown_pending
				f.knockdown_pending = 0
			_emit("land", int(f.id), -1)
	if f.stun > 0:
		f.vx = IntegerMath.mul_div(int(f.vx), 85, 100)

func _resources(f: Dictionary) -> void:
	var policy: Dictionary = _catalog[f.operator_id].resource
	for axis in ["back", "down"]:
		var held: bool = int(f.input.axis_x) * int(f.facing) < 0 if axis == "back" else f.input.axis_y < 0
		var field := "charge_" + axis
		var release := axis + "_release"
		if held:
			f[field] = mini(180, int(f[field]) + 1)
			f[release] = 6
		elif f[release] > 0:
			f[release] -= 1
		else:
			f[field] = 0
	var gauge: String = policy.get("id", "")
	if f.y == 0 and not gauge.is_empty():
		_gauge(f, gauge, int(policy.get("regen_ground_per_tick", 0)))
		if int(policy.get("regen_interval", 0)) > 0:
			f.ground_regen += 1
			if f.ground_regen >= int(policy.regen_interval):
				f.ground_regen = 0
				_gauge(f, gauge, 1)
	if f.operator_id == "deepseek":
		f.resources.charge = f.charge_back
	if f.operator_id == "grok":
		f.heat_idle += 1
		if f.heat_idle > int(policy.get("decay_delay", 90)):
			_gauge(f, "heat", -maxi(1, int(policy.get("decay", 1))))
	if f.stance_left > 0:
		f.stance_left -= 1
		if f.stance_left == 0:
			f.resources.stance = 0
			if gauge == "band":
				f.resources.band = 0
	if f.anchor_left > 0:
		f.anchor_left -= 1
		f.resources.anchor = f.anchor_left
		if f.anchor_left == 0:
			_emit("anchor_end", int(f.id), -1, "special2")

func _anchors() -> void:
	for id in range(2):
		var f: Dictionary = _state.fighters[id]
		var enemy: Dictionary = _state.fighters[1 - id]
		if f.anchor_left <= 0 or enemy.y > 0 or enemy.stun > 0 or enemy.down > 0 or enemy.invuln > 0:
			continue
		if absi(int(enemy.x) - int(f.anchor_x)) < int(f.anchor_range):
			enemy.pull_left = 12
			enemy.pull_target = f.anchor_x
			enemy.pull_speed = f.anchor_pull
			enemy.pull_budget = mini(1000, int(f.anchor_range))
			f.anchor_left = 0
			f.resources.anchor = 0
			_emit("anchor_trigger", id, 1 - id, "special2", {"x": f.anchor_x, "y": 0})

func _set_stance(f: Dictionary, move: Dictionary) -> void:
	if move.has("stance") and move.stance.has("set"):
		f.resources.stance = int(move.stance.set)
		f.resources[move.stance.get("resource", "stance")] = int(move.stance.set)
		f.stance_left = mini(600, int(move.stance.get("duration", 180)))

func _activate(f: Dictionary, enemy: Dictionary, move: Dictionary) -> void:
	if not move.has("movement"):
		return
	var m: Dictionary = move.movement
	var kind: String = m.type
	f.mobility_type = kind
	f.mobility_left = clampi(int(m.get("duration", 18)), 1, 180)
	if kind in ["dash", "glide", "hover", "air_dash", "brace_slam"] and m.has("from") and m.has("to"):
		f.mobility_left = mini(int(f.mobility_left), int(m.to) - int(m.from) + 1)
	f.mobility_distance = 0
	f.mobility_cap = int(m.get("distance", 2200))
	f.mobility_vx = int(m.get("vx", m.get("speed", 140))) * int(f.facing)
	f.mobility_vy = int(m.get("vy", 0))
	match kind:
		"dash", "air_dash":
			f.vx = f.mobility_vx
			f.vy = int(m.get("vy", 0))
			if kind == "air_dash":
				f.air_dash_used = true
				f.vy = 0
		"double_jump", "super_jump":
			f.vy = int(m.get("vy", m.get("jump_velocity", 260)))
			if kind == "double_jump":
				f.double_jump_used = true
		"brace_slam":
			f.vy = int(m.get("vy", -240))
		"blink":
			f.x = clampi(int(f.x) + int(f.facing) * mini(3500, int(m.get("distance", 2200))), -int(_rules.stage_half_width) + 350, int(_rules.stage_half_width) - 350)
			f.resources.blink = int(f.cooldowns.get(f.move_id, 0))
		"tether":
			f.anchor_x = clampi(int(f.x) + int(f.facing) * mini(4000, int(m.get("distance", 2200))), -int(_rules.stage_half_width), int(_rules.stage_half_width))
			f.anchor_left = mini(240, int(m.get("anchor_life", _catalog[f.operator_id].resource.get("anchor_duration", 150))))
			f.anchor_range = int(m.get("trigger_range", 650))
			f.anchor_pull = int(m.get("pull_speed", 55))
			f.resources.anchor = f.anchor_left
		"glide", "hover":
			f.vx = f.mobility_vx
		"grapple":
			# Contact is resolved through the move's authored hitboxes.
			f.mobility_left = 0
	_emit("mobility", int(f.id), int(enemy.id), f.move_id, {"mechanic": kind, "anchor_x": f.anchor_x})

func _push() -> void:
	var a: Dictionary = _state.fighters[0]
	var b: Dictionary = _state.fighters[1]
	var width := int(_rules.get("pushbox", {}).get("w", 700))
	var height := int(_rules.get("pushbox", {}).get("h", 1500))
	if absi(int(a.y) - int(b.y)) >= height:
		return
	var distance: int = absi(int(a.x) - int(b.x))
	if distance >= width:
		return
	var direction := 1 if a.x <= b.x else -1
	var overlap := width - distance
	# Round both outward equally; an odd overlap leaves a harmless 1 mm gap.
	var half: int = IntegerMath.mul_div(overlap + 1, 1, 2)
	var bound: int = int(_rules.stage_half_width) - 350
	a.x = clampi(int(a.x) - direction * half, -bound, bound)
	b.x = clampi(int(b.x) + direction * half, -bound, bound)
	var remaining := width - absi(int(a.x) - int(b.x))
	if remaining > 0:
		if absi(int(a.x)) == bound:
			b.x += direction * remaining
		else:
			a.x -= direction * remaining

func _pushbox(f: Dictionary) -> Array:
	var box: Dictionary = _rules.get("pushbox", {"x": -350, "y": 0, "w": 700, "h": 1500})
	return [int(f.x) + int(box.x), int(f.y) + int(box.y), int(box.w), int(box.h)]

func _hurt(f: Dictionary) -> Array:
	var key := "air" if f.y > 0 else ("crouch" if f.input.axis_y < 0 else "stand")
	if _rules.get("hurtboxes", {}).has(key):
		var box: Dictionary = _rules.hurtboxes[key]
		return [int(f.x) + int(box.x), int(f.y) + int(box.y), int(box.w), int(box.h)]
	return [int(f.x) - 330, int(f.y), 660, 1000 if f.input.axis_y < 0 and f.y == 0 else 1800]

func _hitboxes(f: Dictionary) -> Array:
	var boxes: Array = []
	if f.move_id.is_empty():
		return boxes
	for box in _move(f).hitboxes:
		if f.move_frame >= box.from and f.move_frame <= box.to:
			boxes.append([int(f.x) + int(box.x) if f.facing > 0 else int(f.x) - int(box.x) - int(box.w), int(f.y) + int(box.y), int(box.w), int(box.h)])
	return boxes

func _overlap(a: Array, b: Array) -> bool:
	return a[0] < b[0] + b[2] and a[0] + a[2] > b[0] and a[1] < b[1] + b[3] and a[1] + a[3] > b[1]

func _collect_contacts() -> Array:
	var result: Array = []
	for id in range(2):
		var f: Dictionary = _state.fighters[id]
		var target: Dictionary = _state.fighters[1 - id]
		if f.move_id.is_empty() or f.hit_ledger.has(target.id):
			continue
		var move := _move(f)
		if f.move_frame < move.startup or f.move_frame >= move.startup + move.active:
			continue
		if move.kind == "throw":
			if target.y == 0 and f.y == 0 and target.stun == 0 and target.down == 0 and target.throw_invuln == 0 and target.invuln == 0 and absi(int(f.x) - int(target.x)) <= int(move.get("throw", {}).get("range", 900)):
				result.append(_contact(f, target, move, -1))
		elif move.kind != "projectile" and move.kind != "counter":
			for box in _hitboxes(f):
				if _overlap(box, _hurt(target)):
					result.append(_contact(f, target, move, -1, box))
					break
	for p in _state.projectiles:
		if p.dead:
			continue
		var target: Dictionary = _state.fighters[1 - int(p.owner)]
		if p.hit_ledger.has(target.id):
			continue
		if _overlap(_projectile_box(p, true), _hurt(target)):
			var owner: Dictionary = _state.fighters[p.owner]
			result.append(_contact(owner, target, p.move, int(p.id), _projectile_box(p, true)))
	return result

func _contact(f: Dictionary, target: Dictionary, move: Dictionary, projectile: int, box: Array = []) -> Dictionary:
	var armor: Dictionary = _move(target).get("armor", {})
	var active_armor: bool = target.move_frame >= int(armor.get("from", 1)) and target.move_frame <= int(armor.get("until", 0))
	var counter_data: Dictionary = _move(target).get("counter", {})
	var counter_window: bool = not counter_data.is_empty() and target.move_frame >= int(counter_data.get("from", 0)) and target.move_frame <= int(counter_data.get("to", -1))
	var counter: bool = counter_window and counter_data.get("strike", false) and f.y == 0 and target.y == 0 and absi(int(f.x) - int(target.x)) <= int(counter_data.get("range", 0))
	var guarding: bool = target.y == 0 and target.move_id.is_empty() and target.dash_left == 0 and target.down == 0 and target.jump_start == 0 and (target.stun == 0 or target.state == "blockstun") and int(target.input.held) & 64 != 0
	var blocked: bool = guarding and move.level != "unblockable" and (move.level != "low" or target.input.axis_y < 0) and (move.level != "overhead" or target.input.axis_y >= 0)
	var point: Array = _contact_point(box, _hurt(target)) if not box.is_empty() else [int(target.x), int(target.y) + 900]
	return {"actor": int(f.id), "target": int(target.id), "move_id": f.move_id if projectile < 0 else "", "move": move.duplicate(true), "projectile": projectile,
		"blocked": blocked, "counter": counter, "reflect": (active_armor and bool(armor.get("reflect", false))) or (counter_window and counter_data.get("reflect", false)),
		"counter_move": _move(target).duplicate(true), "counter_id": target.move_id,
		"armored": active_armor and target.armor_used < int(armor.get("hits", 1)), "armor_percent": int(armor.get("damage_percent", 50)),
		"counter_hit": not target.move_id.is_empty() and target.move_frame < int(_move(target).get("startup", 0)),
		"invulnerable": target.invuln > 0 or _movement_invulnerable(target), "target_down": target.down > 0,
		"facing": int(f.facing), "target_corner": absi(int(target.x)) >= int(_rules.stage_half_width) - 400, "x": point[0], "y": point[1]}

func _contact_point(a: Array, b: Array) -> Array:
	return [IntegerMath.mul_div(maxi(a[0], b[0]) + mini(a[0] + a[2], b[0] + b[2]), 1, 2),
		IntegerMath.mul_div(maxi(a[1], b[1]) + mini(a[1] + a[3], b[1] + b[3]), 1, 2)]

func _resolve_contacts(contacts: Array) -> void:
	var throws: Array = []
	var strikes: Array = []
	for c in contacts:
		if c.move.kind == "throw":
			throws.append(c)
		else:
			strikes.append(c)
	# Strike contact defeats a simultaneous throw; mutual normal catches tech.
	for c in strikes:
		_apply_hit(c)
	if not strikes.is_empty():
		return
	if throws.size() == 2:
		_tech(throws[0].actor, throws[0].target)
	elif throws.size() == 1:
		_begin_pair(throws[0])

func _apply_hit(c: Dictionary) -> void:
	var a: Dictionary = _state.fighters[c.actor]
	var b: Dictionary = _state.fighters[c.target]
	var move: Dictionary = c.move
	var p: Dictionary = _find_projectile(int(c.projectile))
	if c.invulnerable:
		return
	if c.target_down and (not move.get("otg", false) or b.otg >= _limit("otg", 1)):
		return
	if b.y > 0 and int(b.juggle) + int(move.get("juggle_cost", 1)) > _limit("juggle", 8):
		return
	if c.projectile >= 0 and c.reflect and not p.is_empty() and p.reflectable and p.reflections < p.max_reflections:
		p.owner = b.id
		p.vx = -int(p.vx)
		p.reflections += 1
		p.hit_ledger = []
		p.x = int(b.x) + int(b.facing) * 750
		p.previous_x = p.x
		_emit("reflect", int(b.id), int(a.id), p.move_id, {"x": c.x, "y": c.y, "projectile_id": p.id, "owner": b.id, "effect": p.move.effect})
		_resource_on_hit(b, c.counter_move)
		return
	if c.counter and c.projectile < 0:
		var counter_move: Dictionary = c.counter_move.duplicate(true)
		counter_move["throw"] = {"techable": false, "command": true,
			"damage_frame": int(counter_move.counter.get("damage_frame", counter_move.startup + counter_move.active + 1)),
			"duration": int(counter_move.counter.get("release_frame", counter_move.startup + counter_move.active + 12)), "knockdown": 36}
		_begin_pair({"actor": b.id, "target": a.id, "move_id": c.counter_id, "move": counter_move})
		_emit("counter", int(b.id), int(a.id), c.counter_id, {"x": c.x, "y": c.y})
		return
	if not p.is_empty():
		p.hit_ledger.append(b.id)
		p.dead = not p.pierce
		c.move_id = p.move_id
	else:
		a.hit_ledger.append(b.id)
	var damage := int(move.damage)
	if c.blocked:
		damage = mini(maxi(0, int(b.hp) - 1), int(move.get("chip", 0)))
		b.stun = int(move.blockstun)
		b.state = "blockstun"
		b.animation = "block_lo" if b.input.axis_y < 0 else "block_hi"
		a.contact = "block"
	else:
		var curve: Array = _rules.get("combo_limits", {}).get("damage_scaling_percent", [])
		var scale := maxi(_limit("scaling_floor", 20), int(curve[mini(int(b.combo_hits), curve.size() - 1)]) if not curve.is_empty() else 100 - int(b.combo_hits) * _limit("scaling_step", 10))
		damage = maxi(1, IntegerMath.mul_div(damage, scale, 100))
		if c.counter_hit:
			damage = IntegerMath.mul_div(damage, 120, 100)
		if a.operator_id == "grok":
			damage += IntegerMath.mul_div(damage, mini(20, int(_catalog[a.operator_id].resource.get("heat_damage_percent", 12))) * int(a.resources.heat), 100 * maxi(1, int(_catalog[a.operator_id].resource.get("max", 6))))
		if c.armored:
			damage = IntegerMath.mul_div(damage, int(c.armor_percent), 100)
			b.armor_used += 1
		else:
			b.stun = maxi(_limit("min_hitstun", 1), int(move.hitstun) - int(b.combo_hits) * _limit("stun_decay", 2))
			b.move_id = ""
			b.dash_left = 0
			b.mobility_left = 0
			b.state = "hitstun"
			b.animation = "hit_air" if b.y > 0 else ("hit_lo" if move.level == "low" else "hit_hi")
			b.vy = maxi(int(b.vy), int(move.get("launch", 0)))
			b.knockdown_pending = int(move.get("knockdown", 0))
			if b.y > 0 or b.vy > 0:
				b.juggle += int(move.get("juggle_cost", 1))
			if c.target_down:
				b.otg += 1
				b.down = 0
		b.combo_hits += 1
		b.combo_damage += damage
		if b.combo_hits >= _limit("max_hits", 12):
			b.stun = 0
			b.down = 30
			b.invuln = 30
			b.vy = 0
			b.y = 0
		if move.get("wall_bounce", false) and absi(int(b.x)) >= int(_rules.stage_half_width) - 900 and b.wall_bounces < _limit("wall_bounces", 1):
			b.wall_bounces += 1
			b.vy = maxi(int(b.vy), 180)
			c["bounced"] = true
		if move.get("ground_bounce", false) and b.y == 0 and b.ground_bounces < _limit("ground_bounces", 1):
			b.ground_bounces += 1
			b.vy = maxi(int(b.vy), 180)
		a.contact = "hit"
		if a.operator_id == "grok":
			_gauge(a, "heat", 1)
			a.heat_idle = 0
		if move.get("movement", {}).get("type", "") == "grapple":
			b.pull_budget = mini(2500, int(move.movement.get("distance", 1800)))
			b.pull_target = int(a.x) + int(c.facing) * 850
			b.pull_speed = int(move.movement.get("pull_speed", 90))
			b.pull_left = int(move.movement.get("duration", 15))
	b.hp = maxi(0, int(b.hp) - damage)
	b.throw_invuln = maxi(int(b.throw_invuln), int(b.stun) + 6)
	a.meter = mini(1000, int(a.meter) + (0 if c.blocked else int(move.get("meter_gain", 35))))
	b.meter = mini(1000, int(b.meter) + (10 if c.blocked else 20))
	var push := IntegerMath.mul_div(int(move.get("pushback", 120)), 100, int(_catalog[b.operator_id].stats.weight))
	if b.operator_id == "meta" and b.resources.brace > 0 and b.input.axis_y < 0:
		push = IntegerMath.mul_div(push, int(_catalog[b.operator_id].resource.get("brace_push_percent", 50)), 100)
	if not c.armored:
		b.vx = int(c.facing) * push * (-1 if c.get("bounced", false) else 1)
		if c.target_corner:
			a.x -= int(c.facing) * push
	var effect: Dictionary = move.get("resource_effect", {})
	if effect.has("resource"):
		if not c.blocked:
			_resource_on_hit(a, move)
		_gauge(a, effect.resource, int(effect.get("on_block" if c.blocked else "on_hit", 0)))
	_freeze(int(move.hitstop))
	_emit("block" if c.blocked else "hit", int(a.id), int(b.id), c.move_id,
		{"damage": damage, "blocked": c.blocked, "counter_hit": c.counter_hit, "armored": c.armored, "x": c.x, "y": c.y, "projectile_id": c.projectile, "effect": move.effect})

func _begin_pair(c: Dictionary) -> void:
	var a: Dictionary = _state.fighters[c.actor]
	var b: Dictionary = _state.fighters[c.target]
	var data: Dictionary = c.move.get("throw", {})
	var techable: bool = bool(data.get("techable", c.move_id in ["throw_f", "throw_b"]))
	_state.pair = {"actor": a.id, "target": b.id, "move_id": c.move_id, "move": c.move,
		"frame": int(a.move_frame), "elapsed": 0, "damage_done": false, "techable": techable,
		"caught_move_frame": int(a.move_frame), "end_frame": int(c.move.startup) + int(c.move.active) + int(c.move.recovery),
		"damage_frame": maxi(int(a.move_frame) + (10 if techable else 1), int(data.get("damage_frame", 14))),
		"duration": maxi(16, int(data.get("duration", 30))), "facing": a.facing,
		"origin_x": a.x, "side_swap": bool(data.get("side_swap", c.move_id == "throw_b"))}
	_state.pair.duration = maxi(int(_state.pair.duration), int(_state.pair.damage_frame) + 1)
	_state.pair.end_frame = maxi(int(_state.pair.end_frame), int(_state.pair.duration) + 1)
	a.hit_ledger.append(b.id)
	a.state = "throw"
	b.state = "thrown"
	b.move_id = ""
	a.vx = 0
	b.vx = 0
	b.animation = "victim_" + a.operator_id + "_" + c.move_id
	_pair_place()
	_emit("throw_start", int(a.id), int(b.id), c.move_id, {"throw_phase": "catch", "techable": techable, "x": b.x, "y": int(b.y) + 900})
	if techable and int(b.input.pressed) & 32:
		_tech(int(a.id), int(b.id))

func _pair_place() -> void:
	var pair: Dictionary = _state.pair
	var a: Dictionary = _state.fighters[pair.actor]
	var b: Dictionary = _state.fighters[pair.target]
	var data: Dictionary = pair.move.get("throw", {})
	var side: int = int(pair.facing) * (-1 if pair.side_swap and pair.damage_done else 1)
	a.facing = side
	b.facing = -side
	var bound := int(_rules.stage_half_width) - 1000
	a.x = clampi(int(pair.origin_x), -bound, bound)
	b.x = int(a.x) + side * clampi(int(data.get("victim_x", 600)), 350, 900)
	b.y = clampi(int(data.get("victim_y", 0)), 0, 2000)
	a.animation_frame = pair.frame
	b.animation_frame = pair.frame
	a.move_frame = pair.frame

func _pair_step() -> void:
	var pair: Dictionary = _state.pair
	var a: Dictionary = _state.fighters[pair.actor]
	var b: Dictionary = _state.fighters[pair.target]
	pair.frame += 1
	pair.elapsed += 1
	if pair.techable and pair.elapsed < 10 and int(b.input.pressed) & 32:
		_tech(int(a.id), int(b.id))
		return
	if not pair.damage_done and pair.frame >= pair.damage_frame:
		pair.damage_done = true
		_pair_place()
		b.hp = maxi(0, int(b.hp) - int(pair.move.damage))
		a.meter = mini(1000, int(a.meter) + int(pair.move.get("meter_gain", 50)))
		_resource_on_hit(a, pair.move)
		b.meter = mini(1000, int(b.meter) + 25)
		_emit("throw_hit", int(a.id), int(b.id), pair.move_id, {"damage": int(pair.move.damage), "throw_phase": "impact", "x": b.x, "y": b.y})
	_pair_place()
	if pair.frame >= maxi(int(pair.duration), int(pair.damage_frame) + 1):
		b.down = int(pair.move.get("throw", {}).get("knockdown", 35))
		b.y = 0
		a.state = "attack"
		b.state = "knockdown"
		b.animation = "knockdown"
		_emit("throw_end", int(a.id), int(b.id), pair.move_id, {"throw_phase": "release"})
		_state.pair = {}

func _tech(actor: int, target: int) -> void:
	for id in [actor, target]:
		var f: Dictionary = _state.fighters[id]
		f.move_id = ""
		f.stun = 12
		f.throw_invuln = 30
		f.state = "throw_tech"
		f.animation = "throw_tech"
		f.vx = -int(f.facing) * 90
	_state.pair = {}
	_emit("throw_tech", actor, target, "", {"x": IntegerMath.mul_div(int(_state.fighters[actor].x) + int(_state.fighters[target].x), 1, 2), "y": 900})

func _spawn_projectile(f: Dictionary, move: Dictionary) -> void:
	var data: Dictionary = move.get("projectile", {})
	var count := 0
	for p in _state.projectiles:
		if p.owner == f.id:
			count += 1
	if count >= clampi(int(data.get("max_count", 2)), 1, 4):
		return
	var x := int(f.x) + int(f.facing) * int(data.get("spawn_x", 600))
	_state.projectiles.append({"id": _state.next_projectile, "owner": f.id,
		"move_id": f.move_id, "operator_id": f.operator_id, "effect": move.effect, "move": move.duplicate(true), "x": x, "previous_x": x,
		"y": int(f.y) + int(data.get("spawn_y", 900)), "previous_y": int(f.y) + int(data.get("spawn_y", 900)),
		"vx": clampi(int(data.get("speed", 180)), 1, 2000) * int(f.facing), "vy": int(data.get("vy", 0)),
		"gravity": int(data.get("gravity", 0)), "life": clampi(int(data.get("life", 90)), 1, 240),
		"range": clampi(int(data.get("range", 10000)), 1, 16000), "travel": 0,
		"width": int(data.get("width", 400)), "height": int(data.get("height", 400)),
		"clash": int(data.get("clash", 1)), "reflectable": bool(data.get("reflectable", true)),
		"reflections": 0, "max_reflections": clampi(int(data.get("max_reflections", 2)), 0, 3), "dead": false,
		"pierce": bool(data.get("pierce", false)), "hit_ledger": []})
	_state.next_projectile += 1
	_emit("projectile_spawn", int(f.id), -1, f.move_id, {"x": x, "y": int(f.y) + int(data.get("spawn_y", 900)), "projectile_id": int(_state.next_projectile) - 1, "owner": f.id})

func _projectile_box(p: Dictionary, swept: bool) -> Array:
	var x: int = mini(int(p.x), int(p.previous_x)) if swept else int(p.x)
	var y: int = mini(int(p.y), int(p.previous_y)) if swept else int(p.y)
	return [x - IntegerMath.mul_div(int(p.width), 1, 2), y - IntegerMath.mul_div(int(p.height), 1, 2),
		int(p.width) + (absi(int(p.x) - int(p.previous_x)) if swept else 0),
		int(p.height) + (absi(int(p.y) - int(p.previous_y)) if swept else 0)]

func _projectiles_advance() -> void:
	for p in _state.projectiles:
		p.previous_x = p.x
		p.previous_y = p.y
		p.x += int(p.vx)
		p.y += int(p.vy)
		p.vy -= int(p.gravity)
		p.travel += absi(int(p.vx))
		p.life -= 1
		p.dead = p.life < 0 or p.travel > p.range or p.y < 0 or absi(int(p.x)) > int(_rules.stage_half_width) + 500
	for i in range(_state.projectiles.size()):
		for j in range(i + 1, _state.projectiles.size()):
			var a: Dictionary = _state.projectiles[i]
			var b: Dictionary = _state.projectiles[j]
			if a.dead or b.dead or a.owner == b.owner:
				continue
			if _overlap(_projectile_box(a, true), _projectile_box(b, true)):
				a.dead = a.clash <= b.clash
				b.dead = b.clash <= a.clash
				var point := _contact_point(_projectile_box(a, true), _projectile_box(b, true))
				_emit("projectile_clash", int(a.owner), int(b.owner), a.move_id, {"x": point[0], "y": point[1], "projectile_id": a.id, "other_projectile_id": b.id})

func _projectiles_cleanup() -> void:
	for i in range(_state.projectiles.size() - 1, -1, -1):
		if _state.projectiles[i].dead:
			_state.projectiles.remove_at(i)

func _find_projectile(id: int) -> Dictionary:
	for p in _state.projectiles:
		if p.id == id:
			return p
	return {}

func _move(f: Dictionary) -> Dictionary:
	return _catalog[f.operator_id].moves.get(f.move_id, {})

func _movement_invulnerable(f: Dictionary) -> bool:
	var movement: Dictionary = _move(f).get("movement", {})
	return int(movement.get("invulnerable_from", -1)) >= 0 and f.move_frame >= int(movement.invulnerable_from) and f.move_frame <= int(movement.get("invulnerable_to", -1))

func _limit(key: String, default_value: int) -> int:
	var aliases := {"juggle": "juggle_budget", "scaling_floor": "damage_floor_percent", "stun_decay": "hitstun_deterioration_per_hit", "otg": "otg_hits"}
	var limits: Dictionary = _rules.get("combo_limits", {})
	return int(limits.get(aliases.get(key, key), limits.get(key, default_value)))

func _reset_combo(f: Dictionary) -> void:
	f.combo_hits = 0
	f.combo_damage = 0
	f.juggle = 0
	f.wall_bounces = 0
	f.ground_bounces = 0
	f.otg = 0

func _gauge(f: Dictionary, key: String, delta: int) -> void:
	var maximum := clampi(int(_catalog[f.operator_id].resource.get("max", 100)), 1, 1000)
	var minimum := int(_catalog[f.operator_id].resource.get("min", 0))
	f.resources[key] = clampi(int(f.resources.get(key, 0)) + delta, minimum, maximum)

func _resource_on_hit(f: Dictionary, move: Dictionary) -> void:
	var effect: Dictionary = move.get("resource_effect", {})
	if effect.get("on", "") == "hit" and effect.has("resource"):
		_gauge(f, effect.resource, int(effect.get("gain", 0)))

func _freeze(frames: int) -> void:
	_state.freeze = maxi(int(_state.freeze), clampi(frames, 0, 30))
	for f in _state.fighters:
		f.hitstop = _state.freeze

func _emit(type: String, actor: int, target: int, move_id: String = "", extra: Dictionary = {}) -> void:
	var f: Dictionary = _state.fighters[actor] if actor >= 0 and _state.fighters.size() > actor else {}
	var event := {"id": int(_state.next_event), "tick": int(_state.tick), "type": type,
		"actor": actor, "target": target, "move_id": move_id, "x": int(f.get("x", 0)),
		"y": int(f.get("y", 0)), "effect": ""}
	if not f.is_empty() and _catalog[f.operator_id].moves.has(move_id):
		event.effect = _catalog[f.operator_id].moves[move_id].effect
	event.merge(extra, true)
	_state.next_event += 1
	_state.events.append(event)

func _neutral() -> Dictionary:
	return {"axis_x": 0, "axis_y": 0, "held": 0, "pressed": 0}
