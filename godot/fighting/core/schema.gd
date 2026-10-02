extends RefCounted

const Recognizer = preload("res://fighting/core/recognizer.gd")
const REQUIRED_MOVES := ["stand_l", "stand_m", "stand_h", "crouch_l", "crouch_m", "crouch_h", "air_l", "air_m", "air_h", "throw_f", "throw_b", "special1", "special2", "special3", "super"]
const OPTIONAL := {
	"projectile": ["speed", "vy", "gravity", "life", "range", "width", "height", "spawn_x", "spawn_y", "max_count", "clash", "reflectable", "max_reflections", "spawn_frame", "pierce"],
	"movement": ["type", "speed", "distance", "duration", "jump_velocity", "cooldown", "from", "to", "vx", "vy", "air_only", "ground_only", "invulnerable_from", "invulnerable_to", "pull_speed", "on", "air_uses", "reset_on_land", "anchor_life", "trigger_range", "max_count"],
	"throw": ["range", "techable", "damage_frame", "duration", "victim_x", "victim_y", "side_swap", "knockdown", "tech_frames", "command", "ground_only"],
	"resource_effect": ["resource", "cost", "gain", "on_hit", "on_block", "on", "reset_on_land"],
	"armor": ["from", "until", "hits", "damage_percent", "reflect"],
	"stance": ["set", "duration", "requires", "variants", "resource"],
	"counter": ["from", "to", "reflect", "strike", "range", "damage_frame", "release_frame"]
}
const MOVEMENTS := ["dash", "grapple", "glide", "super_jump", "brace_slam", "double_jump", "hover", "air_dash", "blink", "tether"]

static func validate(roster: Dictionary, rules: Dictionary) -> String:
	if roster.get("version") != 1 or not roster.get("operators") is Array or roster.operators.is_empty():
		return "roster version/operators invalid"
	for key in ["version", "tick_rate", "units_per_meter", "round_seconds", "rounds_to_win", "stage_half_width"]:
		if not rules.has(key) or not Recognizer.integral(rules[key]) or rules[key] <= 0:
			return "invalid rule: " + key
	if rules.version != 1 or rules.tick_rate != 60 or rules.units_per_meter != 1000:
		return "unsupported simulation units/version"
	var rule_error := validate_rules(rules)
	if not rule_error.is_empty():
		return rule_error
	var seen := {}
	for operator in roster.operators:
		if not operator is Dictionary or not operator.get("id") is String or operator.id.is_empty() or seen.has(operator.id):
			return "invalid/duplicate operator"
		seen[operator.id] = true
		for key in operator:
			if key not in ["id", "name", "archetype", "stats", "resource", "moves", "combos"]:
				return "unknown operator field " + str(key)
		if not operator.get("name") is String or not operator.get("archetype") is String or not operator.get("combos") is Array:
			return "missing operator metadata"
		if not operator.get("stats") is Dictionary or not operator.get("moves") is Dictionary or not operator.get("resource") is Dictionary:
			return "missing stats/moves/resource"
		for key in operator.stats:
			if key not in ["hp", "walk_speed", "weight", "jump_velocity", "height"]:
				return "unknown stat " + str(key)
		for key in operator.resource:
			if key not in ["id", "name", "description", "min", "max", "initial", "regen_ground_per_tick", "regen_interval", "reset_on_round", "hover_fuel", "anchor_duration", "heat_damage_percent", "decay", "decay_delay", "brace_push_percent"]:
				return "unknown resource policy " + str(key)
		for key in ["hp", "walk_speed", "weight", "jump_velocity"]:
			if not Recognizer.integral(operator.stats.get(key)) or operator.stats[key] <= 0 or operator.stats[key] > (100000 if key == "hp" else 1000):
				return "invalid stat " + key
		for key in ["min", "max", "initial", "regen_ground_per_tick", "regen_interval"]:
			if operator.resource.has(key) and (not Recognizer.integral(operator.resource[key]) or operator.resource[key] < 0):
				return "invalid resource policy " + key
		if operator.resource.get("initial", 0) > operator.resource.get("max", 100) or operator.resource.get("min", 0) > operator.resource.get("max", 100):
			return "resource outside bounds"
		if operator.resource.get("initial", 0) < operator.resource.get("min", 0) or operator.resource.get("max", 100) > 1000:
			return "resource outside bounds"
		if not operator.resource.get("reset_on_round", true):
			return "resources must reset each round"
		for key in REQUIRED_MOVES:
			if not operator.moves.has(key):
				return "missing move " + key
		for key in operator.moves:
			var error := validate_move(normalize_move(operator.moves[key]), operator.moves)
			if not error.is_empty():
				return str(operator.id, "/", key, ": ", error)
	return ""

static func validate_move(move: Variant, moves: Dictionary) -> String:
	if not move is Dictionary:
		return "move must be dictionary"
	for key in ["name", "kind", "level", "animation", "effect"]:
		if not move.get(key) is String:
			return "missing string " + key
	if not move.kind in ["strike", "projectile", "mobility", "throw", "counter", "super"] or not move.level in ["mid", "low", "overhead", "unblockable"]:
		return "unknown kind/level"
	var scalar_keys := ["name", "kind", "level", "animation", "effect", "startup", "active", "recovery", "damage", "hitstun", "blockstun", "hitstop", "meter_cost", "hitboxes", "cancels", "chip", "pushback", "launch", "knockdown", "juggle_cost", "wall_bounce", "ground_bounce", "otg", "cooldown", "charge_frames", "charge_axis", "meter_gain", "air_ok", "ground_ok", "input", "description", "counterplay"]
	for key in move:
		if not key in scalar_keys and not OPTIONAL.has(key):
			return "unknown move field " + str(key)
	for key in ["startup", "active", "recovery", "damage", "hitstun", "blockstun", "hitstop", "meter_cost"]:
		if not Recognizer.integral(move.get(key)) or move[key] < 0 or move[key] > 10000:
			return "invalid integer " + key
	if move.startup < 1 or move.active < 1 or move.hitstop > 30 or move.meter_cost > 1000 or move.startup + move.active + move.recovery > 600:
		return "frame/cost bounds"
	if not move.get("hitboxes") is Array or not move.get("cancels") is Array:
		return "missing boxes/cancels"
	for box in move.hitboxes:
		if not box is Dictionary:
			return "invalid box"
		for key in ["from", "to", "x", "y", "w", "h"]:
			if not Recognizer.integral(box.get(key)):
				return "invalid box field"
			if absi(int(box[key])) > 32000:
				return "unbounded box"
		if box.w <= 0 or box.h <= 0 or box.from < move.startup or box.to < box.from or box.to >= move.startup + move.active:
			return "box outside active interval"
	for cancel in move.cancels:
		if not cancel is Dictionary or not moves.has(cancel.get("to", "")) or not Recognizer.integral(cancel.get("from")) or not Recognizer.integral(cancel.get("until")) or not cancel.get("on") is Array:
			return "invalid cancel"
		for condition in cancel.on:
			if not condition in ["hit", "block", "whiff"]:
				return "unknown cancel condition"
		if cancel.from < 0 or cancel.until < cancel.from or cancel.until >= move.startup + move.active + move.recovery:
			return "cancel window outside timeline"
	for key in OPTIONAL:
		if not move.has(key):
			continue
		if not move[key] is Dictionary:
			return "invalid optional dictionary " + key
		for field in move[key]:
			if not field in OPTIONAL[key]:
				return "unknown mechanic " + key + "." + field
			var value: Variant = move[key][field]
			if field in ["type", "resource", "on"]:
				if not value is String:
					return "mechanic string required"
			elif field == "variants":
				if not value is Dictionary:
					return "variants dictionary required"
				for base in value:
					if not moves.has(base) or not moves.has(value[base]):
						return "unknown stance variant"
			elif field in ["reflectable", "pierce", "air_only", "ground_only", "reset_on_land", "side_swap", "command", "techable", "reflect", "strike"]:
				if not value is bool:
					return "mechanic boolean required"
			elif not Recognizer.integral(value):
				return "mechanic integer required"
			elif absi(int(value)) > 32000:
				return "unbounded mechanic integer"
	if move.has("movement") and not move.movement.get("type", "") in MOVEMENTS:
		return "unknown movement type"
	if move.has("movement"):
		var m: Dictionary = move.movement
		if m.get("air_uses", 1) != 1 or not m.get("reset_on_land", true) or m.get("max_count", 1) != 1:
			return "only one reset-on-land air use and one anchor supported"
		if m.get("on", "hit") != "hit" or (m.type == "blink" and m.get("invulnerable_from", -1) >= 0):
			return "unsupported movement contact/invulnerability policy"
		if m.get("distance", 2200) < 0 or m.get("distance", 2200) > 4000 or m.get("duration", 18) <= 0 or m.get("duration", 18) > 180:
			return "unbounded movement"
		if m.get("from", move.startup) < 0 or m.get("to", move.startup) < m.get("from", move.startup) or m.get("to", move.startup) >= move.startup + move.active + move.recovery:
			return "movement outside timeline"
		if m.get("air_only", false) and m.get("ground_only", false):
			return "incompatible movement restrictions"
		if (m.get("invulnerable_from", -1) < 0) != (m.get("invulnerable_to", -1) < 0) or m.get("invulnerable_to", -1) < m.get("invulnerable_from", -1):
			return "invalid movement invulnerability interval"
		if m.type in ["blink", "tether", "grapple"] and (m.get("vx", 0) != 0 or m.get("vy", 0) != 0):
			return "teleport/anchor/reel do not apply attacker velocity"
		if m.type in ["blink", "tether", "super_jump", "double_jump"] and m.get("to", move.startup) != m.get("from", move.startup):
			return "impulse/deployment requires one activation frame"
	if move.has("resource_effect") and not move.resource_effect.get("on", "start") in ["start", "hit"]:
		return "unknown resource trigger"
	if move.has("resource_effect") and (move.resource_effect.get("cost", 0) < 0 or move.resource_effect.get("gain", 0) < 0):
		return "resource cost/gain must be nonnegative"
	if move.has("projectile"):
		var p: Dictionary = move.projectile
		if p.get("speed", 180) < 1 or p.get("speed", 180) > 2000 or p.get("life", 90) < 1 or p.get("life", 90) > 240 or p.get("range", 10000) < 1 or p.get("range", 10000) > 16000 or p.get("max_count", 2) < 1 or p.get("max_count", 2) > 4 or p.get("width", 400) <= 0 or p.get("height", 400) <= 0:
			return "projectile bounds"
		if p.get("spawn_frame", move.startup) < move.startup or p.get("spawn_frame", move.startup) >= move.startup + move.active:
			return "projectile spawn outside active interval"
	if move.has("counter"):
		var c: Dictionary = move.counter
		if c.get("from", -1) < 0 or c.get("to", -1) < c.get("from", 0) or c.get("to", 0) >= move.startup + move.active + move.recovery or c.get("range", 0) < 0:
			return "counter bounds"
	if move.has("armor"):
		var armor: Dictionary = move.armor
		if armor.get("from", 0) < 0 or armor.get("until", 0) < armor.get("from", 0) or armor.get("hits", 1) < 1 or armor.get("hits", 1) > 8 or armor.get("damage_percent", 50) < 0 or armor.get("damage_percent", 50) > 100:
			return "armor bounds"
	if move.has("throw"):
		var data: Dictionary = move.throw
		if not data.get("ground_only", true) or data.get("range", 900) < 1 or data.get("range", 900) > 2000 or data.get("damage_frame", 14) < 0 or data.get("duration", 30) <= data.get("damage_frame", 14):
			return "throw bounds/ground policy"
	if move.has("stance") and (move.stance.get("set", 0) not in [0, 1] or move.stance.get("duration", 180) < 1 or move.stance.get("duration", 180) > 600):
		return "stance bounds"
	for key in ["chip", "pushback", "launch", "knockdown", "juggle_cost", "cooldown", "charge_frames", "meter_gain"]:
		if move.has(key) and (not Recognizer.integral(move[key]) or move[key] < 0 or move[key] > 10000):
			return "invalid move scalar " + key
	for key in ["air_ok", "ground_ok", "wall_bounce", "ground_bounce", "otg"]:
		if move.has(key) and not move[key] is bool:
			return "invalid move boolean " + key
	if move.has("throw") and move.throw.get("tech_frames", 10 if move.throw.get("techable", true) else 0) != (10 if move.throw.get("techable", true) else 0):
		return "normal tech window must be ten, command zero"
	if move.has("input"):
		if not move.input is Dictionary or not move.input.get("motion", "") in ["5", "2", "j.", "Grab", "4+Grab", "236", "22", "63214", "236236", "[2]8", "[4]6", "palm stance"]:
			return "unknown command motion"
		for key in move.input:
			if not key in ["simple", "motion", "charge_frames", "charge_axis"]:
				return "unknown input metadata"
		if move.input.has("charge_axis") and not move.input.charge_axis in ["back", "down"]:
			return "unknown charge axis"
	for key in ["mechanic", "mechanics"]:
		if move.has(key):
			return "use documented typed mechanics, not " + key
	return ""

static func validate_rules(rules: Dictionary) -> String:
	for key in rules:
		if key not in ["version", "tick_rate", "units_per_meter", "round_seconds", "rounds_to_win", "stage_half_width", "seed", "buffer_frames", "throw_tech_frames", "meter_max", "gravity", "terminal_velocity", "jump_startup", "landing_recovery", "spawn_distance", "round_intro_frames", "intro_frames", "round_over_frames", "guard_release_frames", "air_guard", "socd", "negative_edge", "wakeup_invulnerability_frames", "throw_invulnerability_frames", "wakeup_invuln", "throw_invuln", "combo_limits", "hurtboxes", "pushbox", "input_help"]:
			return "unknown rule " + str(key)
	if rules.round_seconds > 600 or rules.rounds_to_win > 9 or rules.stage_half_width < 2000 or rules.stage_half_width > 16000:
		return "round/stage rules outside bounds"
	for entry in [["buffer_frames", 6], ["throw_tech_frames", 10], ["meter_max", 1000], ["guard_release_frames", 0], ["air_guard", false], ["socd", "neutral_both_axes"], ["negative_edge", false]]:
		if rules.has(entry[0]) and rules[entry[0]] != entry[1]:
			return "unsupported fixed policy " + entry[0]
	for key in ["gravity", "terminal_velocity", "jump_startup", "landing_recovery", "spawn_distance", "round_intro_frames", "intro_frames", "round_over_frames", "wakeup_invulnerability_frames", "throw_invulnerability_frames", "wakeup_invuln", "throw_invuln"]:
		if rules.has(key) and (not Recognizer.integral(rules[key]) or rules[key] < 0 or rules[key] > 16000):
			return "invalid rule scalar " + key
	if rules.has("combo_limits"):
		if not rules.combo_limits is Dictionary:
			return "combo_limits dictionary required"
		for key in rules.combo_limits:
			var value: Variant = rules.combo_limits[key]
			if key == "damage_scaling_percent":
				if not value is Array or value.is_empty():
					return "nonempty damage scaling required"
				var previous := 100
				for percent in value:
					if not Recognizer.integral(percent) or percent < 1 or percent > previous:
						return "invalid damage scaling curve"
					previous = int(percent)
			elif key in ["max_hits", "juggle_budget", "juggle", "wall_bounces", "ground_bounces", "otg_hits", "otg", "damage_floor_percent", "scaling_floor", "scaling_step", "hitstun_deterioration_per_hit", "stun_decay", "min_hitstun"]:
				if not Recognizer.integral(value) or value < 0 or value > 100:
					return "invalid combo limit"
			else:
				return "unknown combo limit " + key
	for section in ["hurtboxes", "pushbox"]:
		if not rules.has(section):
			continue
		if not rules[section] is Dictionary:
			return "invalid collision rules"
		var boxes: Array = rules.hurtboxes.values() if section == "hurtboxes" else [rules.pushbox]
		for box in boxes:
			if not box is Dictionary:
				return "invalid collision rectangle"
			for key in ["x", "y", "w", "h"]:
				if not Recognizer.integral(box.get(key)) or absi(int(box[key])) > 4000:
					return "invalid collision rectangle field"
			if box.w <= 0 or box.h <= 0:
				return "empty collision rectangle"
	return ""

static func normalize_move(source: Variant) -> Variant:
	if not source is Dictionary:
		return source
	var move: Dictionary = source.duplicate(true)
	var aliases := {"projectile": {"vx": "speed", "x": "spawn_x", "y": "spawn_y", "w": "width", "h": "height", "clash_strength": "clash"}, "armor": {"to": "until"}, "throw": {"release_frame": "duration", "knockdown_frames": "knockdown"}}
	for section in aliases:
		if not move.get(section) is Dictionary:
			continue
		for old in aliases[section]:
			if move[section].has(old):
				move[section][aliases[section][old]] = move[section][old]
				move[section].erase(old)
	for pair in [["launch_velocity", "launch"], ["knockdown_frames", "knockdown"]]:
		if move.has(pair[0]):
			move[pair[1]] = move[pair[0]]
			move.erase(pair[0])
	if move.get("movement") is Dictionary:
		var types := {"reel": "grapple", "rush": "dash", "slam": "brace_slam", "anchor": "tether"}
		move.movement.type = types.get(move.movement.get("type", ""), move.movement.get("type", ""))
	if move.get("throw") is Dictionary and move.throw.has("command"):
		move.throw.techable = not move.throw.command
	if move.get("input") is Dictionary:
		move.charge_frames = move.input.get("charge_frames", 0)
		move.charge_axis = move.input.get("charge_axis", "back")
	return move
