extends RefCounted
## JSON numbers become floats. Validate the entire tree before exact conversion.
## All authority numbers are integral; no vectors, objects, NaN or fractions.
const MAX_EXACT := 1000000000000
const FIGHTER_INTS := ["id", "x", "y", "vx", "vy", "facing", "hp", "meter", "move_frame", "animation_frame", "hitstop", "stun", "combo_hits", "combo_damage", "previous_held", "previous_y", "move_serial", "invuln", "throw_invuln", "down", "juggle", "wall_bounces", "ground_bounces", "otg", "armor_used", "stance_left", "anchor_left", "anchor_x", "mobility_left", "charge_back", "heat_idle", "dash_left", "knockdown_pending", "charge_down", "back_release", "down_release", "ground_regen", "jump_start", "landing_left", "mobility_distance", "mobility_cap", "mobility_vx", "mobility_vy", "anchor_range", "anchor_pull", "pull_left", "pull_speed", "pull_target", "pull_budget"]

static func fields(value: Dictionary, keys: Array, type: int) -> bool:
	for key in keys:
		if not value.has(key) or typeof(value[key]) != type:
			return false
	return true

static func valid_state(s: Dictionary) -> bool:
	if not fields(s, ["version", "tick", "round_index", "round_ticks_left", "winner", "rng", "next_event", "next_projectile", "next_move", "freeze", "phase_ticks"], TYPE_INT):
		return false
	if not fields(s, ["phase", "stage_id"], TYPE_STRING) or not fields(s, ["config", "pair"], TYPE_DICTIONARY) or not fields(s, ["fighters", "projectiles", "events", "wins"], TYPE_ARRAY):
		return false
	if not fields(s.config, ["operators"], TYPE_ARRAY) or not fields(s.config, ["stage_id"], TYPE_STRING) or not fields(s.config, ["training"], TYPE_BOOL) or not fields(s.config, ["seed"], TYPE_INT):
		return false
	if s.wins.size() != 2 or s.config.operators.size() != 2:
		return false
	for win in s.wins:
		if not win is int or win < 0:
			return false
	for f in s.fighters:
		if not f is Dictionary or not fields(f, FIGHTER_INTS, TYPE_INT):
			return false
		if not fields(f, ["operator_id", "state", "move_id", "animation", "contact", "mobility_type"], TYPE_STRING) or not fields(f, ["jump_edge", "air_dash_used", "double_jump_used"], TYPE_BOOL):
			return false
		if not fields(f, ["resources", "buffer", "input", "cooldowns"], TYPE_DICTIONARY) or not fields(f, ["history", "hit_ledger"], TYPE_ARRAY):
			return false
		for dictionary in [f.resources, f.cooldowns]:
			for value in dictionary.values():
				if not value is int or value < 0:
					return false
		if not f.buffer.is_empty() and (not fields(f.buffer, ["move"], TYPE_STRING) or not fields(f.buffer, ["expires"], TYPE_INT)):
			return false
		for entry in f.history:
			if not entry is Dictionary or not fields(entry, ["tick", "x", "y", "pressed"], TYPE_INT):
				return false
		for target in f.hit_ledger:
			if target not in [0, 1]:
				return false
	for p in s.projectiles:
		if not p is Dictionary or not fields(p, ["id", "owner", "x", "previous_x", "y", "previous_y", "vx", "vy", "gravity", "life", "range", "travel", "width", "height", "clash", "reflections", "max_reflections"], TYPE_INT):
			return false
		if not fields(p, ["move_id"], TYPE_STRING) or not fields(p, ["move"], TYPE_DICTIONARY) or not fields(p, ["hit_ledger"], TYPE_ARRAY) or not fields(p, ["reflectable", "pierce", "dead"], TYPE_BOOL):
			return false
		if p.owner not in [0, 1] or p.width <= 0 or p.height <= 0:
			return false
	if not s.pair.is_empty():
		if not fields(s.pair, ["actor", "target", "frame", "elapsed", "damage_frame", "duration", "facing", "origin_x", "caught_move_frame", "end_frame"], TYPE_INT) or not fields(s.pair, ["move_id"], TYPE_STRING) or not fields(s.pair, ["move"], TYPE_DICTIONARY) or not fields(s.pair, ["damage_done", "techable", "side_swap"], TYPE_BOOL):
			return false
		if s.pair.actor not in [0, 1] or s.pair.target != 1 - s.pair.actor:
			return false
	for event in s.events:
		if not event is Dictionary or not fields(event, ["id", "tick", "actor", "target", "x", "y"], TYPE_INT) or not fields(event, ["type", "move_id", "effect"], TYPE_STRING):
			return false
	return true

static func valid_tree(value: Variant, depth: int = 0) -> bool:
	if depth > 32:
		return false
	if value is int:
		return value >= -MAX_EXACT and value <= MAX_EXACT
	if value is float:
		return is_finite(value) and value >= -MAX_EXACT and value <= MAX_EXACT and value == floor(value)
	if value is String or value is bool:
		return true
	if value is Dictionary:
		for key in value:
			if not (key is String or key is StringName) or not valid_tree(value[key], depth + 1):
				return false
		return true
	if value is Array:
		for item in value:
			if not valid_tree(item, depth + 1):
				return false
		return true
	return false

static func decode(value: Variant) -> Variant:
	# Caller must validate first; no lossy casts or fallback values.
	if value is Dictionary:
		var result := {}
		for key in value:
			result[str(key)] = decode(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(decode(item))
		return result
	if value is float:
		return int(value)
	return value
