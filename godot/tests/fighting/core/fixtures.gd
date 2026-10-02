extends RefCounted
## Synthetic data exclusively for functional core tests; never production fallback.
const IDS := ["chatgpt", "claude", "grok", "meta", "gemini", "deepseek", "mistral", "kimi", "qwen"]

static func rules() -> Dictionary:
	return {"version": 1, "tick_rate": 60, "units_per_meter": 1000,
		"round_seconds": 8, "rounds_to_win": 2, "stage_half_width": 8000,
		"intro_frames": 1, "round_over_frames": 2, "spawn_distance": 420,
		"combo_limits": {"max_hits": 8, "juggle": 6}}

static func roster() -> Dictionary:
	var operators: Array = []
	for id in IDS:
		var moves := {}
		for prefix in ["stand_", "crouch_", "air_"]:
			for button in ["l", "m", "h"]:
				var key: String = prefix + button
				moves[key] = strike(key)
				moves[key].level = "low" if prefix == "crouch_" else ("overhead" if prefix == "air_" else "mid")
				if button == "l":
					moves[key].cancels = [{"to": "stand_m", "from": 3, "until": 9, "on": ["hit", "block"]}]
		for key in ["throw_f", "throw_b", "special1", "special2", "special3", "super"]:
			moves[key] = strike(key)
		for key in ["throw_f", "throw_b", "special3"]:
			moves[key].kind = "throw"
			moves[key].damage = 140
			moves[key]["throw"] = {"techable": key != "special3", "range": 950, "damage_frame": 14, "duration": 22}
		moves.special1.kind = "projectile"
		moves.special1.projectile = {"speed": 180, "life": 60, "spawn_x": 500}
		moves.super.meter_cost = 1000
		moves.super.damage = 250
		moves.special2.kind = "mobility"
		var movement: String = {"chatgpt": "grapple", "claude": "glide", "grok": "super_jump", "meta": "brace_slam", "gemini": "double_jump", "deepseek": "hover", "mistral": "air_dash", "kimi": "blink", "qwen": "tether"}[id]
		moves.special2.movement = {"type": movement, "distance": 2000, "duration": 12, "cooldown": 30}
		if id == "gemini":
			moves.special2.stance = {"set": 1, "duration": 180}
		if id == "deepseek":
			moves.special2.resource_effect = {"resource": "fuel", "cost": 10, "gain": 0, "on": "start"}
		if id == "claude":
			moves.special3.kind = "counter"
			moves.special3.counter = {"from": 1, "to": 8, "reflect": true, "strike": true, "range": 1000, "damage_frame": 14, "release_frame": 24}
			moves.special3.armor = {"from": 1, "until": 8, "reflect": true, "hits": 1}
		if id == "meta":
			moves.special1.kind = "strike"
			moves.special1.erase("projectile")
			moves.special1.armor = {"from": 1, "until": 8, "hits": 2}
		if id == "deepseek":
			moves.special1.charge_frames = 20
		operators.append({"id": id, "name": id, "archetype": "test",
			"stats": {"hp": 500, "walk_speed": 60, "weight": 100, "jump_velocity": 240},
			"resource": {"id": "brace" if id == "meta" else "fuel", "initial": 30, "max": 100, "hover_fuel": 30, "anchor_duration": 20},
			"moves": moves, "combos": []})
	return {"version": 1, "operators": operators}

static func strike(key: String) -> Dictionary:
	return {"name": key, "kind": "strike", "startup": 2, "active": 2,
		"recovery": 8, "damage": 60, "hitstun": 18, "blockstun": 10,
		"hitstop": 3, "level": "mid", "animation": key, "effect": key,
		"meter_cost": 0, "hitboxes": [{"from": 2, "to": 3, "x": 0, "y": 200, "w": 1250, "h": 1300}], "cancels": []}

static func input(button: int = 0, x: int = 0, y: int = 0, pressed: int = -1) -> Dictionary:
	return {"axis_x": x, "axis_y": y, "held": button, "pressed": button if pressed < 0 else pressed}
