extends RefCounted
## Read-only training/learning feedback. Consumes only the official snapshot,
## the two routed commands and the authored roster. It never mutates combat
## authority, never invents a move, frame or timing, and never asserts an
## unverified combo: the roster's 27 routes stay labelled "proposed" elsewhere.
##
## What it tracks, all from real ticks/events:
##   * a readable input history (facing-relative notation plus the recognised move)
##   * the outcome of each started attack (hit / blocked / whiff / cancelled / throw / tech)
##   * the live hit chain reported by the core (opponent combo_hits / combo_damage)
##   * operator practice goals derived from that operator's authored moves
## Every value is derived; the helper exposes strings so the shell stays thin.

const HISTORY_LIMIT := 12
const RESULT_LIMIT := 6
const MAX_SEEN := 4096
const BUTTONS := ["L","M","H","Special","Mobility","Grab","Guard","Dash","Super"]
const SHORT := {"L":"L","M":"M","H":"H","Special":"Sp","Mobility":"Mo","Grab":"Gr","Guard":"Gu","Dash":"Da","Super":"Su"}
const BITS := {"L":1,"M":2,"H":4,"Special":8,"Mobility":16,"Grab":32,"Guard":64,"Dash":128,"Super":256}

var operators: Array = []
var _profiles: Array = [{},{}]
var _names: Array = [{},{}]   # move_id -> authored name
var _kinds: Array = [{},{}]   # move_id -> authored kind
var _history: Array = [[],[]]
var _pending: Array = [{},{}]
var _results: Array = [[],[]]
var _goals: Array = [[],[]]
var _tick_result: Array = ["",""]
var _seen: Dictionary = {}
var _last_tick := -1
var _last_round := -1

# --- lifecycle ---------------------------------------------------------------

func reset(operator_ids: Array, roster: Dictionary) -> void:
	operators = operator_ids.duplicate()
	_seen.clear()
	_last_tick = -1
	_last_round = -1
	for p: int in 2:
		_profiles[p] = _profile_for(str(operator_ids[p]) if p < operator_ids.size() else "", roster)
		_names[p] = {}
		_kinds[p] = {}
		var moves: Dictionary = _profiles[p].get("moves",{})
		for id: String in moves:
			_names[p][id] = str(moves[id].get("name",id))
			_kinds[p][id] = str(moves[id].get("kind",""))
		_history[p] = []
		_pending[p] = {}
		_results[p] = []
		_goals[p] = _build_goals(_profiles[p])

func reset_transient() -> void:
	# Explicit transient cleanup; round/rewind reset() clears goal progress too.
	# Recording playback restores the saved observation prefix instead.
	_seen.clear()
	_last_tick = -1
	_last_round = -1
	for p: int in 2:
		_history[p] = []
		_pending[p] = {}
		_results[p] = []
	_tick_result = ["",""]

func save_observation() -> Dictionary:
	return {"history":_history.duplicate(true),"pending":_pending.duplicate(true),
		"results":_results.duplicate(true),"goals":_goals.duplicate(true),
		"seen":_seen.duplicate(true),"tick":_last_tick,"round":_last_round}

func restore_observation(saved: Dictionary) -> void:
	_history = saved.history.duplicate(true)
	_pending = saved.pending.duplicate(true)
	_results = saved.results.duplicate(true)
	_goals = saved.goals.duplicate(true)
	_seen = saved.seen.duplicate(true)
	_last_tick = int(saved.tick)
	_last_round = int(saved.round)
	_tick_result = ["",""]

func observe(state: Dictionary, commands: Array) -> void:
	if state.is_empty():
		return
	var tick := int(state.get("tick",0))
	var round_index := int(state.get("round_index",1))
	if tick == _last_tick and round_index == _last_round: return
	if _last_tick != -1 and tick < _last_tick:
		# A rewind without an explicit saved observation has no valid future goals.
		reset(operators,{"operators":_profiles.duplicate(true)})
	elif _last_tick != -1 and round_index != _last_round:
		reset(operators,{"operators":_profiles.duplicate(true)})
	for event: Dictionary in state.get("events",[]):
		if str(event.get("type","")) in ["training_reset","training_place"]: reset_transient()
	_last_round = round_index
	if tick == _last_tick:
		return
	_last_tick = tick
	_tick_result = ["",""]
	for event: Dictionary in state.get("events",[]):
		var id := int(event.get("id",0))
		if _seen.has(id):
			continue
		_seen[id] = true
		_apply_event(event,state)
	if _seen.size() > MAX_SEEN:
		_seen.clear()
	var fighters: Array = state.get("fighters",[])
	for p: int in 2:
		var fighter: Dictionary = fighters[p] if p < fighters.size() else {}
		_track_move(p,fighter,tick)
	for p: int in 2:
		var command: Dictionary = commands[p] if p < commands.size() and commands[p] is Dictionary else {}
		_record_input(p,_facing(fighters,p),command,tick)

# --- event + move lifecycle --------------------------------------------------

func _apply_event(event: Dictionary, state: Dictionary) -> void:
	var type := str(event.get("type",""))
	var actor := int(event.get("actor",-1))
	var target := int(event.get("target",-1))
	var move_id := str(event.get("move_id",""))
	match type:
		"move_start":
			if actor in [0,1]:
				if not _pending[actor].is_empty(): _finalize(actor,move_id,_last_tick)
				_pending[actor] = {}
		"hit":
			if actor in [0,1]:
				_mark_result(actor,"hit",move_id,int(event.get("damage",0)),state,int(event.get("projectile_id",-1))>=0)
				if _owns_move_event(actor,event): _complete(actor,"move_land",move_id)
				_tick_result[actor] = "HIT"
		"block":
			if actor in [0,1]:
				_mark_result(actor,"block",move_id,0,state,int(event.get("projectile_id",-1))>=0)
				_tick_result[actor] = "BLK"
			if target in [0,1]:
				_complete(target,"block_incoming","")
		"throw_hit":
			if actor in [0,1]:
				_mark_result(actor,"throw",move_id,int(event.get("damage",0)),state)
				_complete(actor,"throw_land",move_id)
				_tick_result[actor] = "THROW"
		"throw_tech":
			for p: int in [actor,target]:
				if p in [0,1]:
					_mark_result(p,"tech","",0,state)
					if p == target: _complete(p,"tech","")
					_tick_result[p] = "TECH"
		"counter":
			if actor in [0,1]:
				_mark_result(actor,"counter",move_id,0,state)
				_complete(actor,"counter",move_id)
				_tick_result[actor] = "CNTR"
		"mobility":
			if actor in [0,1]:
				_mark_result(actor,"mobility",move_id,0,state)
				_complete(actor,"mobility",move_id)
				if move_id == "special2":
					_tick_result[actor] = "MOVE"

func _owns_move_event(p: int, event: Dictionary) -> bool:
	if int(event.get("projectile_id",-1)) < 0: return true
	var move: Dictionary = _profiles[p].get("moves",{}).get(str(event.get("move_id","")),{})
	# Core emits the authored effect identity even after a reflection.
	return not move.is_empty() and str(event.get("effect","")) == str(move.get("effect","missing"))

func _mark_result(p: int, outcome: String, move_id: String, damage: int, state: Dictionary, projectile: bool = false) -> void:
	# A projectile can land after recovery while a different move is running.
	# Record that contact separately; never rename the current pending attack.
	if projectile or (not _pending[p].is_empty() and str(_pending[p].get("move_id","")) != move_id):
		var current: Dictionary = _pending[p]
		_pending[p] = {}
		_mark_result(p,outcome,move_id,damage,state)
		_finalize(p,"",_last_tick)
		# Reflection changes the credited actor, not the projectile's authored
		# move. Its ID is factual; the new owner's roster name may be unrelated.
		if projectile: _results[p][-1].name = "Projectile (%s)" % move_id
		_pending[p] = current
		return
	if _pending[p].is_empty():
		_pending[p] = {"move_id":move_id,"kind":str(_kinds[p].get(move_id,"")),"start_tick":_last_tick,
			"outcome":"","damage":0,"chain":0,"chain_damage":0}
	if not move_id.is_empty():
		_pending[p]["move_id"] = move_id
	_pending[p]["outcome"] = outcome
	_pending[p]["damage"] = damage
	var fighters: Array = state.get("fighters",[])
	var opponent: Dictionary = fighters[1-p] if 1-p < fighters.size() else {}
	# combo_hits/combo_damage describe the chain the victim is currently taking.
	_pending[p]["chain"] = int(opponent.get("combo_hits",0))
	_pending[p]["chain_damage"] = int(opponent.get("combo_damage",0))

func _track_move(p: int, fighter: Dictionary, tick: int) -> void:
	var mid := str(fighter.get("move_id",""))
	var pending: Dictionary = _pending[p]
	if pending.is_empty():
		if not mid.is_empty():
			_pending[p] = {"move_id":mid,"kind":str(_kinds[p].get(mid,"")),"start_tick":tick,
				"outcome":"","damage":0,"chain":0,"chain_damage":0}
		return
	var previous := str(pending.get("move_id",""))
	if mid == previous and not mid.is_empty():
		return
	_finalize(p,mid,tick)
	if mid.is_empty():
		_pending[p] = {}
	else:
		_pending[p] = {"move_id":mid,"kind":str(_kinds[p].get(mid,"")),"start_tick":tick,
			"outcome":"","damage":0,"chain":0,"chain_damage":0}

func _finalize(p: int, _next_id: String, tick: int) -> void:
	var pending: Dictionary = _pending[p]
	var move_id := str(pending.get("move_id",""))
	var outcome := str(pending.get("outcome",""))
	var result := {"move_id":move_id,"name":str(_names[p].get(move_id,move_id)),
		"kind":str(pending.get("kind","")),"damage":int(pending.get("damage",0)),
		"chain":int(pending.get("chain",0)),"chain_damage":int(pending.get("chain_damage",0)),
		"tick":tick,"next":""}
	if move_id.is_empty(): result.name = "Throw tech" if outcome == "tech" else "Contact"
	if outcome == "hit":
		result.state = "hit"
	elif outcome == "block":
		result.state = "block"
	elif outcome == "throw":
		result.state = "throw"
	elif outcome == "counter":
		result.state = "counter"
	elif outcome == "tech":
		result.state = "tech"
	elif outcome == "mobility":
		result.state = "mobility"
	else:
		# End/replacement alone cannot prove a whiff or cancel (projectiles,
		# interruption, round end and mobility can all clear move_id).
		result.state = "no_contact"
	_results[p].append(result)
	if _results[p].size() > RESULT_LIMIT:
		_results[p].pop_front()

# --- input history -----------------------------------------------------------

func _record_input(p: int, facing: int, command: Dictionary, tick: int) -> void:
	var row := {"tick":tick,
		"direction":_direction(int(command.get("axis_x",0)),int(command.get("axis_y",0)),facing),
		"buttons":_buttons(int(command.get("held",0)),int(command.get("pressed",0))),
		"move_id":"","result":_tick_result[p]}
	if not _pending[p].is_empty() and int(_pending[p].get("start_tick",-1)) == tick:
		row.move_id = str(_pending[p].get("move_id",""))
	_history[p].append(row)
	if _history[p].size() > HISTORY_LIMIT:
		_history[p].pop_front()

func _direction(axis_x: int, axis_y: int, facing: int) -> String:
	var h := axis_x * (1 if facing >= 0 else -1)
	if axis_y > 0:
		return "9" if h > 0 else ("7" if h < 0 else "8")
	if axis_y < 0:
		return "3" if h > 0 else ("1" if h < 0 else "2")
	return "6" if h > 0 else ("4" if h < 0 else "5")

func _buttons(held: int, pressed: int) -> String:
	var tokens: Array = []
	for action: String in BUTTONS:
		var bit := int(BITS[action])
		if pressed & bit:
			tokens.append(str(SHORT[action]) + "!")
		elif held & bit:
			tokens.append(str(SHORT[action]))
	return " ".join(PackedStringArray(tokens))

# --- public read-only views --------------------------------------------------

func history_rows(p: int) -> Array:
	return _history[p]

func history_detail(p: int) -> Array:
	var lines: Array = []
	for row: Dictionary in _history[p]:
		var line := "t%d  %s" % [int(row.tick),str(row.direction)]
		if not str(row.buttons).is_empty():
			line += " " + str(row.buttons)
		if not str(row.move_id).is_empty():
			line += "  → " + str(_names[p].get(row.move_id,row.move_id))
		if not str(row.result).is_empty():
			line += "  [" + str(row.result) + "]"
		lines.append(line)
	return lines

func history_line(p: int, limit: int = 6) -> String:
	var rows: Array = _history[p]
	var start: int = maxi(0,rows.size()-limit)
	var pieces: Array = []
	for i: int in range(start,rows.size()):
		var row: Dictionary = rows[i]
		var piece := str(row.direction) + str(row.buttons)
		if not str(row.move_id).is_empty():
			piece += "→" + str(row.move_id)
		if not str(row.result).is_empty():
			piece += "[" + str(row.result) + "]"
		pieces.append(piece)
	return " ".join(PackedStringArray(pieces))

func last_result(p: int) -> Dictionary:
	if not _results[p].is_empty():
		return _results[p][-1]
	return {}

func live_result(p: int) -> Dictionary:
	if not _pending[p].is_empty() and not str(_pending[p].get("outcome","")).is_empty():
		var pending: Dictionary = _pending[p]
		var move_id := str(pending.get("move_id",""))
		return {"move_id":move_id,"name":str(_names[p].get(move_id,move_id)),"kind":str(pending.get("kind","")),
			"state":str(pending.get("outcome","")),"damage":int(pending.get("damage",0)),
			"chain":int(pending.get("chain",0)),"chain_damage":int(pending.get("chain_damage",0)),
			"tick":_last_tick,"next":""}
	return last_result(p)

func result_text(p: int) -> String:
	var result := live_result(p)
	if result.is_empty():
		return "P%d no attack yet" % (p+1)
	var text := str(result.name)
	match str(result.state):
		"hit":
			text += " HIT %d" % int(result.damage)
			if int(result.chain) > 1:
				text += " · chain %d (%d dmg)" % [int(result.chain),int(result.chain_damage)]
		"block":
			text += " BLOCKED"
		"throw":
			text += " THROW %d" % int(result.damage)
		"counter":
			text += " COUNTER"
		"tech":
			text += " TEC"
		"mobility":
			text += " USED"
		_:
			text += " · no contact observed"
	return text

func goals(p: int) -> Array:
	return _goals[p]

func goal_summary(p: int) -> String:
	var done := 0
	for goal: Dictionary in _goals[p]:
		if bool(goal.done):
			done += 1
	return "%d/%d goals" % [done,_goals[p].size()]

func goal_lines(p: int) -> Array:
	var lines: Array = []
	for goal: Dictionary in _goals[p]:
		lines.append(("[x] " if bool(goal.done) else "[ ] ") + str(goal.label))
	return lines

# --- goals from authored move data -------------------------------------------

func _build_goals(profile: Dictionary) -> Array:
	var moves: Dictionary = profile.get("moves",{})
	var goals: Array = []
	var low_id := _first_id(moves,["crouch_l","crouch_m","crouch_h"])
	if not low_id.is_empty():
		var low: Dictionary = moves[low_id]
		goals.append(_goal("low","move_land","Land %s (%s) - a low hit" % [str(low.name),_notation(low)],low_id))
	var special1: Dictionary = moves.get("special1",{})
	if not special1.is_empty():
		if str(special1.get("kind","")) == "counter":
			goals.append(_goal("signature_counter","counter","Counter with %s (%s)" % [str(special1.name),_notation(special1)],"special1"))
		else:
			goals.append(_goal("signature","move_land","Land %s (%s) - signature 1" % [str(special1.name),_notation(special1)],"special1"))
	var special2: Dictionary = moves.get("special2",{})
	if not special2.is_empty():
		goals.append(_goal("mobility","mobility","Use %s (%s) - signature 2" % [str(special2.name),_notation(special2)],"special2"))
	var throw_f: Dictionary = moves.get("throw_f",{})
	if not throw_f.is_empty():
		goals.append(_goal("throw","throw_land","Land %s (%s)" % [str(throw_f.name),_notation(throw_f)],"throw_f"))
	goals.append(_goal("tech","tech","Tech an incoming throw (press Grab as it lands)",""))
	var super_move: Dictionary = moves.get("super",{})
	if not super_move.is_empty():
		goals.append(_goal("super","move_land","Land %s at 1000 meter (%s)" % [str(super_move.name),_notation(super_move)],"super"))
	goals.append(_goal("block","block_incoming","Block an incoming strike with Guard",""))
	return goals

func _goal(id: String, kind: String, label: String, target: String) -> Dictionary:
	return {"id":id,"kind":kind,"label":label,"target":target,"done":false,"count":0}

func _complete(p: int, kind: String, target: String) -> void:
	for goal: Dictionary in _goals[p]:
		if str(goal.kind) != kind:
			continue
		if not str(goal.target).is_empty() and str(goal.target) != target:
			continue
		goal.count = int(goal.count) + 1
		goal.done = true

func _notation(move: Dictionary) -> String:
	var input: Dictionary = move.get("input",{})
	var simple := str(input.get("simple",""))
	var motion := str(input.get("motion",""))
	if simple.is_empty():
		return motion
	if motion.is_empty():
		return simple
	return "%s · %s" % [simple,motion]

func _first_id(moves: Dictionary, ids: Array) -> String:
	for id: String in ids:
		if moves.has(id):
			return id
	return ""

func _profile_for(id: String, roster: Dictionary) -> Dictionary:
	for profile: Dictionary in roster.get("operators",[]):
		if str(profile.get("id","")) == id:
			return profile
	return {}

func _facing(fighters: Array, p: int) -> int:
	if p < fighters.size() and fighters[p] is Dictionary:
		return int(fighters[p].get("facing",1))
	return 1
