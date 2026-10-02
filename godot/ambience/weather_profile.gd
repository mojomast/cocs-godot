extends RefCounted
## Cosmetic port of game/environment.mjs:511-653. Never mutates source maps.
const KINDS := {
	"clear": {"particles": 0, "mood": "default", "wind": 1.0},
	"overcast": {"particles": 0, "mood": "storm", "wind": 1.25},
	"rain": {"particles": 90, "mood": "storm", "wind": 1.5, "color": "aebccb", "size": 0.028, "life": 1.15, "fall": 19.0, "drift": 0.25, "streakRatio": 1.3},
	"snow": {"particles": 72, "mood": "cold", "wind": 1.1, "color": "eef6ff", "size": 0.045, "life": 3.4, "fall": 2.4, "drift": 1.0, "streakRatio": 0.4},
	"ash": {"particles": 64, "mood": "hot", "wind": 1.2, "color": "8f8880", "size": 0.035, "life": 3.8, "fall": 0.9, "drift": 0.8, "streakRatio": 0.4},
	"storm": {"particles": 130, "mood": "storm", "wind": 2.0, "color": "9fb0c2", "size": 0.03, "life": 1.4, "fall": 15.0, "drift": 0.7, "streakRatio": 1.15},
}
## game/environment.mjs WEATHER_PRESETS: density, exposure, tint, wet, dark.
const LOOKS := {
	"clear": [1.0, 1.0, "000000", 0.0, 0.0],
	"overcast": [1.08, 0.88, "39404a", 0.04, 0.06],
	"rain": [1.35, 0.8, "28323d", 0.16, 0.1],
	"snow": [1.2, 1.04, "c3d1de", 0.05, 0.0],
	"ash": [1.25, 0.85, "3a3129", 0.0, 0.12],
	"storm": [1.6, 0.7, "1e2833", 0.22, 0.16],
}

static func wet_sheen(wetness: float) -> Dictionary:
	var w := clampf(wetness if is_finite(wetness) else 0.0, 0.0, 1.0)
	return {"wetness": w, "roughness": 1.0 - w * 0.55, "metalness": minf(0.35, w * 0.3), "sheen": w * 0.5, "reflection": w}

static func wet_step(current: float, target: float, delta: float) -> float:
	if not is_finite(delta) or delta <= 0.0: return current
	return current + (target - current) * (1.0 - exp(-0.7 * clampf(delta, 0.0, 0.25)))
const BIOMES := {
	"canyon": {"mood": "hot", "tint": "#8a6a44", "particles": "dust"},
	"forest": {"mood": "default", "tint": "#4f7a44", "particles": "leaf"},
	"snow": {"mood": "cold", "tint": "#c7dbe8", "particles": "snow"},
	"volcanic": {"mood": "hot", "tint": "#7a3a24", "particles": "ember"},
	"urban": {"mood": "default", "tint": "#6d747b", "particles": "dust"},
	"ruins": {"mood": "default", "tint": "#9a8258", "particles": "ash"},
	"cavern": {"mood": "night", "tint": "#4a4550", "particles": "dust"},
}
const NIGHT_IDS := ["exchange", "launchpad", "crosswire", "derelict-station", "skybreak", "aether", "neon-vertical", "substation", "skyfall-basin", "signal-ridge", "catwalk-breach", "ironfall-megastructure", "puma-circuit", "puma-pitch", "colosseum", "frost-gate", "sunken-hill", "catacombs", "titan-valley", "convoy-line", "proving-grounds", "atrium"]

static func u32(value: int) -> int:
	return value & 0xffffffff

static func hash_unit(seed: int, salt: int = 0) -> float:
	# JS Math.imul wraps at 32 bits; >>>0 preserves unsigned representation.
	var h := u32(u32((seed if u32(seed) != 0 else 1) * 2654435761) ^ u32(u32(salt + 2246822519) * 3266489917))
	h = u32(u32(h ^ (h >> 15)) * 1274126177)
	h = u32(h ^ (h >> 13))
	h = u32(h ^ (h >> 16))
	return float(h) / 4294967295.0

static func seed_for(arena: Dictionary) -> int:
	var hash := 7
	var id := str(arena.get("id", ""))
	var units := (id if not id.is_empty() else "arena").to_utf16_buffer()
	for index in range(0, units.size(), 2):
		hash = u32(hash * 31 + units[index] + units[index + 1] * 256)
	return hash

static func biome(arena: Dictionary) -> Dictionary:
	var declared := str(arena.get("biome", "")).to_lower()
	var id := str(arena.get("id", "")).to_lower()
	var name := declared if BIOMES.has(declared) else "canyon"
	if not BIOMES.has(declared):
		for pair: Array in [
			[["frost", "snow", "ice", "glacier", "tundra"], "snow"],
			[["lava", "forge", "slag", "foundry", "ember", "sunscar", "gauntlet", "magma", "ashen"], "volcanic"],
			[["warfront", "trench", "ash", "derelict", "exchange", "substation", "signal", "ironfall"], "ruins"],
			[["gulch", "river", "titan", "sunken", "proving", "plateau", "colosseum", "catacomb", "atrium", "throne", "citadel", "fortress", "longreach"], "forest"],
			[["neon", "aether", "skybreak", "skyfall"], "urban"],
			[["canyon", "sunscar", "dune"], "canyon"]]:
			var found := false
			for token: String in pair[0]:
				if token in id: found = true
			if found:
				name = pair[1]
				break
	var result: Dictionary = BIOMES[name].duplicate()
	result["biome"] = name
	return result

static func _matches(id: String, tokens: Array) -> bool:
	for token: String in tokens:
		if token in id: return true
	return false

static func select(arena: Dictionary, time: Dictionary, seed: int = 1, reduced: bool = false) -> String:
	if reduced or arena.get("reducedMotion", false) == true: return "clear"
	var id := str(arena.get("id", "")).to_lower()
	var declared := str(arena.get("biome", "")).to_lower()
	var wet := str(biome(arena).mood)
	var t: float = float(time.get("t", 0.0))
	var roll := hash_unit(seed, roundi(t) if is_finite(t) else 0)
	match declared:
		"snow": return "snow" if roll < 0.55 else "clear"
		"volcanic": return "ash" if roll < 0.36 else "clear"
		"canyon", "forest": return "overcast" if roll < 0.3 else "clear"
		"cavern": return "overcast" if roll < 0.25 else "clear"
		"ruins": return "ash" if roll < 0.42 else "clear"
	if _matches(id, ["snow", "frost", "ice", "glacier", "tundra"]): return "snow" if roll < 0.55 else "clear"
	if _matches(id, ["lava", "forge", "slag", "foundry", "ember", "sunscar", "ashen", "gauntlet", "magma"]): return "ash" if roll < 0.36 else "clear"
	if _matches(id, ["gulch", "river", "titan", "sunken", "proving", "plateau", "atrium"]): return "overcast" if roll < 0.3 else "clear"
	if _matches(id, ["neon", "aether", "skybreak", "skyfall", "storm"]): return "storm" if roll < 0.22 else ("rain" if roll < 0.5 else ("overcast" if roll < 0.72 else "clear"))
	if _matches(id, ["warfront", "derelict", "exchange", "substation", "signal", "ironfall", "ruins", "trench"]): return "ash" if roll < 0.42 else "clear"
	if wet == "cold" and roll < 0.4: return "snow"
	if wet == "hot" and roll < 0.28: return "ash"
	return "rain" if roll < 0.16 else ("overcast" if roll < 0.32 else "clear")

static func time_at(arena: Dictionary, elapsed: float, mode: String = "playing") -> Dictionary:
	var authored := str(arena.get("sky", ""))
	if not authored in ["day", "dusk", "night"]:
		if str(arena.get("id", "")) in NIGHT_IDS:
			authored = "night"
		else:
			var background := Color(str(arena.get("background", "#090f17"))).srgb_to_linear()
			var luminance := background.r * 0.2126 + background.g * 0.7152 + background.b * 0.0722
			authored = "night" if luminance < 0.06 else ("dusk" if luminance < 0.18 else "day")
	if arena.get("reducedMotion", false) == true or arena.get("timeOfDay", true) == false or arena.get("timeOfDayOverride", true) == false:
		return {"phase": authored, "cycle": authored, "t": 0.0}
	var period := 90.0 if mode in ["selection", "theater", "progression"] else 600.0
	var speed := period * (1.0 + (float(seed_for(arena) % 7) - 3.0) * 0.05)
	var t := (maxf(0.0, elapsed) if is_finite(elapsed) else 0.0) / maxf(30.0, speed)
	var u := t - floorf(t)
	var order := ["day", "dusk", "night", "dusk"]
	var index := mini(3, floori(u * 4.0))
	var local := u * 4.0 - index
	return {"phase": order[mini(3, index + 1)] if local >= 0.5 else order[index], "from": order[index], "to": order[mini(3, index + 1)], "blend": local, "cycle": order[index], "t": t}

static func gust(time: float, seed: int = 1, strength: float = 1.0) -> float:
	var s := u32(seed) if u32(seed) != 0 else 1
	var t := time if is_finite(time) else 0.0
	var raw := 0.5 + 0.5 * sin(t * 0.21 + hash_unit(s, 1) * TAU) + 0.28 * sin(t * 0.53 + hash_unit(s, 2) * TAU) + 0.14 * sin(t * 1.07 + hash_unit(s, 3) * TAU)
	var norm := clampf(raw / 1.92, 0.0, 1.0)
	return clampf(1.0 + (norm - 0.5) * clampf(strength if is_finite(strength) else 1.0, 0.0, 2.0) * 1.3, 0.4, 1.7)

static func lightning(seed: int, window: float = 60.0, count: int = 4, kind: String = "storm") -> Array[Dictionary]:
	if not kind in ["storm", "rain", "overcast"]: return []
	var chance := 1.0 if kind == "storm" else (0.22 if kind == "rain" else 0.12)
	var gaps := [2.2, 5.5] if kind == "storm" else ([4.0, 9.0] if kind == "rain" else [5.0, 11.0])
	var thunder := [0.5, 1.6] if kind == "storm" else ([0.7, 2.0] if kind == "rain" else [0.9, 2.4])
	var state := u32(seed) if u32(seed) != 0 else 1
	state = u32(state * 1664525 + 1013904223)
	if float(state) / 4294967296.0 > chance: return []
	var strikes: Array[Dictionary] = []
	state = u32(state * 1664525 + 1013904223)
	var t := float(state) / 4294967296.0 * maxf(0.2, gaps[0])
	for i in range(clampi(count, 0, 24)):
		if t >= (window if is_finite(window) and window > 0 else 60.0): break
		state = u32(state * 1664525 + 1013904223)
		var distance: float = 0.35 + float(state) / 4294967296.0 * 0.65
		state = u32(state * 1664525 + 1013904223)
		var intensity := 0.5 + float(state) / 4294967296.0 * 0.5
		state = u32(state * 1664525 + 1013904223)
		var thunder_gain: float = thunder[0] + float(state) / 4294967296.0 * (thunder[1] - thunder[0])
		state = u32(state * 1664525 + 1013904223)
		var pan := float(state) / 4294967296.0 * 2.0 - 1.0
		strikes.append({"time": t, "distance": distance, "intensity": intensity, "thunderGain": thunder_gain, "thunderDelay": 0.12 + distance * 1.7, "pan": pan})
		state = u32(state * 1664525 + 1013904223)
		t += maxf(0.2, gaps[0]) + float(state) / 4294967296.0 * maxf(0.0, gaps[1] - gaps[0])
	return strikes
