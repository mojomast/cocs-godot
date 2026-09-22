extends RefCounted
## Scripted, wall-clock benchmark plan. Every function here is a pure function of
## elapsed seconds, so the same second of the same phase always asks for the same
## intent: two runs with the same map, bot count, resolution and quality level are
## comparable, and no run depends on randomness, frame rate or gameplay authority.
##
## The plan issues only ordinary player intent (held keys, fire, scripted look).
## It never writes actor state, never predicts combat and never talks to the
## authority directly: the driver feeds these intents through the same shared
## input path a human press travels.
const SCHEMA := 1
const VERSION := "1.0.0"

## Ordered phases. `measured` marks the phases that feed the reported aggregate;
## warm-up is still measured per phase, so its cost stays visible.
const PHASES := [
	{"name": "warmup", "seconds": 5.0, "measured": false, "fire": false,
		"note": "settle interpolation, shader compilation and pool allocation; excluded from the aggregate"},
	{"name": "combat", "seconds": 12.0, "measured": true, "fire": true,
		"note": "steady bot combat with the infinite-ammo Pulse Rifle plus scripted movement"},
	{"name": "burst", "seconds": 6.0, "measured": true, "fire": true,
		"note": "grenade burst and weapon-switch demand; launchers fire only when a pickup granted ammo"},
	{"name": "sustained", "seconds": 10.0, "measured": true, "fire": true,
		"note": "sustained fire, grenade and movement load at the measured quality level"},
]

## Pulse windows are seconds wide so a low frame rate cannot silently swallow a
## scripted press; the plan still never repeats an edge (the driver presses once
## and releases when the window ends).
const PULSE_WINDOW := 0.3
const SWITCH_WINDOW := 0.6
const JUMP_WINDOW := 0.2

static func phase_count() -> int:
	return PHASES.size()

static func phase_names() -> PackedStringArray:
	var names := PackedStringArray()
	for phase: Dictionary in PHASES:
		names.append(str(phase.name))
	return names

static func total_seconds() -> float:
	var total := 0.0
	for phase: Dictionary in PHASES:
		total += float(phase.seconds)
	return total

static func measured_seconds() -> float:
	var total := 0.0
	for phase: Dictionary in PHASES:
		if bool(phase.measured): total += float(phase.seconds)
	return total

static func phase_start(index: int) -> float:
	var start := 0.0
	for i in range(clampi(index, 0, PHASES.size() - 1)):
		start += float(PHASES[i].seconds)
	return start

static func phase_index(elapsed: float) -> int:
	var remaining := maxf(elapsed, 0.0)
	for i in range(PHASES.size()):
		remaining -= float(PHASES[i].seconds)
		if remaining < 0.0: return i
	return PHASES.size() - 1

static func local_seconds(elapsed: float) -> float:
	var index := phase_index(elapsed)
	return clampf(maxf(elapsed, 0.0) - phase_start(index), 0.0, float(PHASES[index].seconds))

## Weapon key codes follow the source 1..9/0 order used by weapon_selection.gd.
static func weapon_key(index: int) -> int:
	if index < 0 or index > 9: return 0
	return KEY_0 if index == 9 else KEY_1 + index

## Smooth look target in mouse-motion pixels. The driver differentiates it, so the
## swept view depends on wall-clock time rather than on the frame rate.
static func look_target(elapsed: float) -> Vector2:
	var index := phase_index(elapsed)
	var local := local_seconds(elapsed)
	match str(PHASES[index].name):
		"warmup":
			return Vector2(45.0 * sin(local * 0.7), 8.0 * sin(local * 0.5))
		"combat":
			return Vector2(150.0 * sin(local * 0.5), 40.0 * sin(local * 0.27))
		"burst":
			return Vector2(190.0 * sin(local * 0.8), 55.0 * sin(local * 0.4))
		_:
			return Vector2(170.0 * sin(local * 0.6), 70.0 * sin(local * 0.33))

static func _window(local: float, period: float, width: float) -> bool:
	if period <= 0.0: return false
	var phase := fmod(maxf(local, 0.0), period)
	return phase < width

## The keys that should be physically held at this instant. The driver diffs this
## set against the previous frame and emits exactly those press/release events.
static func held_keys(elapsed: float) -> Array:
	var index := phase_index(elapsed)
	var local := local_seconds(elapsed)
	var keys: Array = []
	match str(PHASES[index].name):
		"warmup":
			pass
		"combat":
			keys.append(KEY_W if int(local / 3.0) % 2 == 0 else KEY_S)
			keys.append(KEY_D if int(local / 1.25) % 2 == 0 else KEY_A)
			if _window(local, 4.0, JUMP_WINDOW): keys.append(KEY_SPACE)
			if _window(local, 5.0, PULSE_WINDOW): keys.append(KEY_R)
			# Repeats are no-ops while the rifle is already held, so a respawn
			# that drained selection simply re-requests it.
			if local < SWITCH_WINDOW or _window(local, 6.0, SWITCH_WINDOW): keys.append(weapon_key(0))
		"burst":
			# Requested once per phase: a launcher fires only when the actor
			# actually carries launcher ammo; otherwise the rifle stays equipped.
			if local < SWITCH_WINDOW: keys.append(weapon_key(1))
			keys.append(KEY_W if int(local / 2.5) % 2 == 0 else KEY_S)
			keys.append(KEY_A if int(local / 1.25) % 2 == 0 else KEY_D)
			if _window(local, 1.5, PULSE_WINDOW): keys.append(KEY_G)
			if _window(local, 2.5, PULSE_WINDOW): keys.append(KEY_R)
		"sustained":
			if local < SWITCH_WINDOW:
				keys.append(weapon_key(1))
			elif local >= 4.0 and local < 4.0 + SWITCH_WINDOW:
				keys.append(weapon_key(9))
			keys.append(KEY_W)
			keys.append(KEY_D if int(local / 2.0) % 2 == 0 else KEY_A)
			if _window(local, 1.5, PULSE_WINDOW): keys.append(KEY_G)
			if _window(local, 2.0, PULSE_WINDOW): keys.append(KEY_R)
			if _window(local, 5.0, JUMP_WINDOW): keys.append(KEY_SPACE)
	return keys

static func fires(elapsed: float) -> bool:
	return bool(PHASES[phase_index(elapsed)].fire)

static func phase_note(index: int) -> String:
	return str(PHASES[clampi(index, 0, PHASES.size() - 1)].note)

static func is_measured(index: int) -> bool:
	return bool(PHASES[clampi(index, 0, PHASES.size() - 1)].measured)

## Everything the driver needs for one frame. Tests assert this stays pure.
static func intent(elapsed: float) -> Dictionary:
	var index := phase_index(elapsed)
	return {
		"schema": SCHEMA,
		"index": index,
		"phase": str(PHASES[index].name),
		"local": local_seconds(elapsed),
		"measured": is_measured(index),
		"note": phase_note(index),
		"keys": held_keys(elapsed),
		"fire": fires(elapsed),
		"look": look_target(elapsed),
	}
