extends Resource
class_name WeaponPresentationProfile
## One inspectable first-person presentation profile per source weapon (F05).
##
## Presentation only. Nothing here is authoritative: no aim, spread, ammunition,
## damage, reload window or reload timing is read from or written to this
## resource. The source (`game/data.mjs` `WEAPONS`) stays authoritative and the
## generated catalog (`first_person/generated/catalog.gd`) is its read-only
## transcription; the recoil channels below are *derived from the source manifest
## kick triple*, never hand-copied source balance.
##
## Identity: `weapon_id` is the source weapon name and `source_index` its
## position in `game/data.mjs` `WEAPONS`, which is the stable source identity the
## rig already selects on. `for_weapon()` accepts a name or that index.
##
## Shared and immutable: `for_weapon()` and `default_for_weapon()` hand out one
## sealed instance per weapon and every exported field refuses writes once
## sealed (a refused write warns and is counted by `rejections()`). The tables
## themselves are enforced by the engine rather than by a guard a caller could
## route around: each profile's merged copy is *deep-frozen* with Godot's
## `Dictionary`/`Array` `make_read_only()` at construction, so an in-place write
## at any nesting depth -- `pose["hip_offset"]`, `impulses["lateral"]["roll"]`,
## or the sub-table `impulse("lateral")` returns -- is refused, not just a
## property setter. The freeze runs once per profile after every authored value
## is merged, so the per-frame accessors still hand out the frozen table by
## reference and allocate nothing. Runtime state (recoil age, heat, reload
## progress, spring values, kick age) never lives here; it stays on the
## per-instance rig, handling and inertia helpers.
##
## `first_person/rig.gd` remains the sole final pose compositor. Every value here
## is a bound that compositor and its helpers read, not a transform any of them
## own.

const Catalog = preload("res://first_person/generated/catalog.gd")

## --- Authored constants shared by every profile -----------------------------
## The heft band normalises the source kick triple into 0..1 (light automatic ->
## heavy break-action). It is the same band `world/audio_feedback.gd` uses to
## weight a voice, so the pose and the report cannot disagree about heft.
const HEFT_LOW := 0.042
const HEFT_HIGH := 0.205
const RECOIL_SCALE_LOW := 1.6
const RECOIL_SCALE_HIGH := 2.2
const PITCH_HOLD_LOW := 1.12
const PITCH_HOLD_HIGH := 1.22
const RECOVER_SCALE := 0.78
const PUNCH_PITCH_LOW := 0.30
const PUNCH_PITCH_HIGH := 0.50
const PUNCH_ROLL_LOW := 0.85
const PUNCH_ROLL_HIGH := 1.60
const PUNCH_BACK_LOW := 0.35
const PUNCH_BACK_HIGH := 0.60
const PUNCH_RATE_LIGHT := 34.0
const PUNCH_RATE_HEAVY := 24.0
const CHARGE_TIME := 0.28
const PUFF_LIFE := 0.40
const PUFF_POOL := 3
const HAZE_SIZE := 0.026
const HAZE_GROWTH := 0.026
const HAZE_REDUCED_SCALE := 0.5
const SPRINT_FOV_DEGREES := 3.0
const SPRINT_FOV_RATE := 9.0

## --- Authored default: exactly the constants these helpers carried inline before
## the profile existed. A weapon that authors no override resolves to these
## values, i.e. current behaviour.
##
## Scalar feel numbers are stored as plain floats on purpose: a Godot `Vector2`
## is single precision, so rounding a double band through one would quietly move
## the authored response. Vectors appear only where the composed value was
## already a vector.
const DEFAULT := {
	"pose": {
		"hip_offset": Vector3(0.29, -0.26, -0.75),
		"switch_seconds": 0.22,
		"switch_drop": 0.0704,
		"slide_offset": Vector3(0.018, -0.025, 0.0),
		"slide_roll": 0.08,
		"slide_rate": 12.0,
		"reload_window": Vector3(0.22, 0.72, 1.0),
		"reload_drop": 0.045,
		"reload_roll": 0.16,
		"hand_window": Vector4(0.04, 0.22, 0.78, 0.96),
		"sight_corridor": {"rear": "SightRear", "front": "SightFront", "optic": "OpticCenter"},
		"heft_weight_low": 0.75,
		"heft_weight_high": 1.25,
		"shove_scale": 0.45,
		"lift_scale": 0.6,
		"lift_scale_reduced": 0.28,
		"punch_reduced": 0.35,
		"punch_rate_scale": 1.5,
		"punch_limit": 1.25,
		"recoil_cap": 1.5,
		"look_lag_rate": 12.0,
		"mechanism_reduced": 0.5,
	},
	"recoil": {
		"heft_low": HEFT_LOW, "heft_high": HEFT_HIGH,
		"scale_low": RECOIL_SCALE_LOW, "scale_high": RECOIL_SCALE_HIGH,
		"pitch_hold_low": PITCH_HOLD_LOW, "pitch_hold_high": PITCH_HOLD_HIGH,
		"recover_scale": RECOVER_SCALE,
		"punch_pitch_low": PUNCH_PITCH_LOW, "punch_pitch_high": PUNCH_PITCH_HIGH,
		"punch_roll_low": PUNCH_ROLL_LOW, "punch_roll_high": PUNCH_ROLL_HIGH,
		"punch_back_low": PUNCH_BACK_LOW, "punch_back_high": PUNCH_BACK_HIGH,
		"punch_rate_low": PUNCH_RATE_LIGHT, "punch_rate_high": PUNCH_RATE_HEAVY,
	},
	"springs": {
		"lateral": {"omega": 18.0, "limit": 0.018},
		"forward": {"omega": 18.0, "limit": 0.014},
		"vertical": {"omega": 22.0, "limit": 0.024},
		"sprint": {"omega": 20.0, "limit": 1.0},
		"strafe": {"omega": 12.0, "limit": 1.0},
		"look_x": {"omega": 22.0, "limit": 0.025},
		"look_y": {"omega": 22.0, "limit": 0.02},
	},
	"impulses": {
		"lateral": {"gain": 0.035, "clamp": 0.28, "limit": 0.6, "roll": 0.9},
		"forward": {"gain": 0.025, "clamp": 0.24, "limit": 0.5},
		"vertical": {"jump": -0.22, "jump_limit": 0.7, "land_gain": 0.07, "land_min": 0.12,
			"land_max": 0.65, "land_limit": 0.7, "pitch": 0.7},
		"hurt": {"lateral": 0.15, "lateral_limit": 0.6, "vertical": -0.18, "vertical_limit": 0.7},
		"strafe": {"divisor": 9.0, "position": 0.009, "roll": 0.014},
		"sprint": {"position": 0.028, "pitch": 0.055},
		"look_x": {"gain": 3.0, "limit": 0.7},
		"look_y": {"gain": 3.0, "limit": 0.6},
	},
	"handling": {
		"charge_time": CHARGE_TIME,
		"puff_life": PUFF_LIFE,
		"puff_pool": PUFF_POOL,
		"haze_size": HAZE_SIZE,
		"haze_growth": HAZE_GROWTH,
		"haze_reduced_scale": HAZE_REDUCED_SCALE,
	},
	"optics": {"sprint_fov_degrees": SPRINT_FOV_DEGREES, "sprint_fov_rate": SPRINT_FOV_RATE},
	"clips": {"reload": "", "switch": "", "pump": ""},
	"grammar": {"impact_visual": "", "impact": "", "trace": "", "arc": "", "effect_mode": -1, "effect_sheet": ""},
	"audio": {"report": "shot", "launch": "launch", "impact": "hit"},
}

## --- Authored per-weapon overrides -----------------------------------------
## Source identity first, then only the groups that weapon actually overrides.
## Every channel below reproduces the procedural response the helpers produced
## before this profile existed; parity is asserted bit-exactly by
## `tests/first_person/presentation_profile.gd`.
##
## Only the Pulse Rifle names a reload clip: that is the sampled-animation pilot
## and it keys off this table. The other nine stay procedural ("" clip) until
## their parity is proven.
const OVERRIDES := {
	"Pulse Rifle": {
		"weapon_id": "Pulse Rifle",
		"source_index": 0,
		"recoil": {
			# Exact spellings of the current procedural response. GDScript's float
			# literal parser does not always round the shortest repr to the same
			# double, and parity here is bit-for-bit, not approximate:
			# `tests/first_person/presentation_profile.gd` asserts it for all ten
			# source weapons.
			"scale": 1.7214723926380369,
			"pitch_hold": 1.14024539877300612,
			"recover_rate": 12.48,
			"punch_pitch": 0.34049079754601225,
			"punch_roll": 1.001840490797546,
			"punch_back": 0.4006134969325153,
			"punch_rate": 31.97546012269939,
		},
		"clips": {"reload": "mechanism/reload_hardware"},
		"grammar": {"impact_visual": "", "impact": "", "trace": "", "arc": "", "effect_mode": 0, "effect_sheet": "pulse"},
	},
	"Scattergun": {
		"weapon_id": "Scattergun",
		"source_index": 3,
		"recoil": {
			"scale": 2.2,
			"pitch_hold": 1.22,
			"recover_rate": 9.36,
			"punch_pitch": 0.5,
			"punch_roll": 1.6,
			"punch_back": 0.6,
			"punch_rate": 24.0,
		},
		"grammar": {"impact_visual": "wide", "impact": "", "trace": "", "arc": "", "effect_mode": 3, "effect_sheet": ""},
	},
	"Submachine Gun": {
		"weapon_id": "Submachine Gun",
		"source_index": 9,
		"recoil": {
			"scale": 1.6,
			"pitch_hold": 1.12,
			"recover_rate": 17.16,
			"punch_pitch": 0.3,
			"punch_roll": 0.85,
			"punch_back": 0.35,
			"punch_rate": 34.0,
		},
		"grammar": {"impact_visual": "", "impact": "", "trace": "", "arc": "", "effect_mode": 9, "effect_sheet": ""},
	},
}

static var _registry: Dictionary = {}
static var _fallback: WeaponPresentationProfile = null
static var _rejections := 0

var _values: Dictionary = {}
var _sealed := false

## --- Exported authored overrides -------------------------------------------
## All authored overrides are keyed by stable source weapon id: `weapon_id` must
## match the source weapon name and `source_index` the source `WEAPONS` order.

## Stable source identity: source weapon name and `WEAPONS` order index.
@export var weapon_id: String:
	get: return String(_values.get("weapon_id", ""))
	set(value): _write("weapon_id", value)
@export var source_index: int:
	get: return int(_values.get("source_index", -1))
	set(value): _write("source_index", value)
## Pose/ADS offsets and sight corridor references, metres and radians.
@export var pose: Dictionary:
	get: return _values.get("pose", {})
	set(value): _write("pose", value)
## Cosmetic recoil/recovery scale. Endpoints are presentation; the per-weapon
## response is derived from the source `kick` triple unless a channel is
## authored directly (see `OVERRIDES`).
@export var recoil: Dictionary:
	get: return _values.get("recoil", {})
	set(value): _write("recoil", value)
## Spring/inertia limits per cosmetic channel: `omega` (rad/s) and `limit`.
@export var springs: Dictionary:
	get: return _values.get("springs", {})
	set(value): _write("springs", value)
## Observed source motion -> cosmetic offset gains, clamps and impulses.
@export var impulses: Dictionary:
	get: return _values.get("impulses", {})
	set(value): _write("impulses", value)
## Cosmetic handling/FX bounds (charge time, pool size, plume budget).
@export var handling: Dictionary:
	get: return _values.get("handling", {})
	set(value): _write("handling", value)
## Additive hip-fire optical cue. The ADS FOV stays owned by the rig/session.
@export var optics: Dictionary:
	get: return _values.get("optics", {})
	set(value): _write("optics", value)
## Mechanism clip references (`reload`/`switch`/`pump`), or "" for procedural.
@export var clips: Dictionary:
	get: return _values.get("clips", {})
	set(value): _write("clips", value)
## Muzzle/impact grammar references (source feel grammar + effect-sheet ids).
@export var grammar: Dictionary:
	get: return _values.get("grammar", {})
	set(value): _write("grammar", value)
## Audio report cue ids, as keyed by `world/audio_feedback.gd`.
@export var audio: Dictionary:
	get: return _values.get("audio", {})
	set(value): _write("audio", value)

func _write(field: String, value: Variant) -> void:
	if _sealed:
		_rejections += 1
		push_warning("WeaponPresentationProfile '%s' is shared and immutable: refused write to %s" % [weapon_id, field])
		return
	_values[field] = value

## Writes refused on a sealed profile since process start.
static func rejections() -> int:
	return _rejections

## --- Loader ----------------------------------------------------------------

## The shared immutable profile for `id`, which may be the source weapon name or
## its `WEAPONS` index. An unknown id resolves to the documented default, i.e.
## current behaviour. Treat the result as read-only.
static func for_weapon(id: Variant) -> WeaponPresentationProfile:
	var key := weapon_id_for(id)
	if key.is_empty(): return default_for_weapon()
	if not _registry.has(key):
		_registry[key] = _build(key, OVERRIDES.get(key, {}))
	return _registry[key]

## The documented fallback: one shared sealed instance whose values reproduce the
## constants the first-person helpers carried before this resource existed.
static func default_for_weapon() -> WeaponPresentationProfile:
	if _fallback == null:
		_fallback = _build("", {})
	return _fallback

## Source weapon name for `id` (name or `WEAPONS` index), or "" when `id` names no
## source weapon. Matching is exact: the source name is the stable identity.
static func weapon_id_for(id: Variant) -> String:
	if id is String:
		var text := String(id).strip_edges()
		for entry: Dictionary in Catalog.WEAPONS:
			if String(entry.get("name", "")) == text: return text
		return ""
	if id is int or id is float:
		if not is_finite(float(id)) or float(id) != floor(float(id)): return ""
		var index := int(id)
		if index < 0 or index >= Catalog.WEAPONS.size(): return ""
		return String(Catalog.WEAPONS[index].get("name", ""))
	return ""

## Every source weapon name in source order, i.e. the stable profile keys.
static func ids() -> Array[String]:
	var keys: Array[String] = []
	for entry: Dictionary in Catalog.WEAPONS: keys.append(String(entry.get("name", "")))
	return keys

## True when `id` names a source weapon; an unknown id resolves to the default.
static func has_weapon(id: Variant) -> bool:
	return not weapon_id_for(id).is_empty()

static func _build(key: String, override: Dictionary) -> WeaponPresentationProfile:
	var profile := WeaponPresentationProfile.new()
	var values: Dictionary = {"weapon_id": key, "source_index": -1}
	for group: String in DEFAULT:
		var merged: Dictionary = (DEFAULT[group] as Dictionary).duplicate(true)
		var authored: Variant = override.get(group)
		if authored is Dictionary:
			for field: Variant in authored: merged[field] = authored[field]
		values[group] = merged
	values["weapon_id"] = String(override.get("weapon_id", key))
	# The source name is the key, so the source order index is derived from it and
	# only ever has to be asserted, never trusted.
	var derived := -1
	for index: int in range(Catalog.WEAPONS.size()):
		if String(Catalog.WEAPONS[index].get("name", "")) == String(values["weapon_id"]): derived = index
	values["source_index"] = int(override.get("source_index", derived))
	# Freeze after every authored value is in place, so what the consumers read is
	# the same table they cannot edit. `duplicate(true)` above is deliberately a
	# writable copy; this is the step that seals it.
	_freeze_deep(values)
	profile._values = values
	profile._sealed = true
	return profile

## Recursively mark `value` and every Dictionary/Array inside it read-only, so an
## in-place write is refused by the engine at any nesting depth instead of only
## at the property setter. Scalars, vectors and packed arrays are values rather
## than containers and are already safe to hand out. Idempotent, and called once
## per profile at build time -- never on the per-frame read path, which still
## returns the frozen tables by reference and so allocates nothing.
static func _freeze_deep(value: Variant) -> void:
	if value is Dictionary:
		var table: Dictionary = value
		for field: Variant in table: _freeze_deep(table[field])
		table.make_read_only()
	elif value is Array:
		var list: Array = value
		for item: Variant in list: _freeze_deep(item)
		list.make_read_only()

## --- Pose / ADS ------------------------------------------------------------

func hip_offset() -> Vector3:
	var value: Variant = pose.get("hip_offset")
	return value if value is Vector3 else Vector3(0.29, -0.26, -0.75)

## Authored sight corridor: the exported anchor names the ADS solve reads and
## the reticle corridor is measured against.
func sight_corridor() -> Dictionary:
	var value: Variant = pose.get("sight_corridor")
	return value if value is Dictionary else {}

func switch_seconds() -> float: return _number(pose.get("switch_seconds"), 0.22)
func switch_drop() -> float: return _number(pose.get("switch_drop"), 0.0704)
func slide_offset() -> Vector3:
	var value: Variant = pose.get("slide_offset")
	return value if value is Vector3 else Vector3.ZERO
func slide_roll() -> float: return _number(pose.get("slide_roll"), 0.0)
func slide_rate() -> float: return _number(pose.get("slide_rate"), 12.0)
## Source reload progress where the procedural lift starts, where the seat
## starts, and where the authoritative window closes.
func reload_window() -> Vector3:
	var value: Variant = pose.get("reload_window")
	return value if value is Vector3 else Vector3(0.22, 0.72, 1.0)
func reload_drop() -> float: return _number(pose.get("reload_drop"), 0.045)
func reload_roll() -> float: return _number(pose.get("reload_roll"), 0.16)
## Offhand-to-feed contact window along source progress: in, in, out, out.
func hand_window() -> Vector4:
	var value: Variant = pose.get("hand_window")
	return value if value is Vector4 else Vector4(0.04, 0.22, 0.78, 0.96)
func heft_weight_low() -> float: return _number(pose.get("heft_weight_low"), 0.75)
func heft_weight_high() -> float: return _number(pose.get("heft_weight_high"), 1.25)
## Inertia/sway weight for a weapon of this source heft.
func heft_weight_for(kick: Array) -> float:
	return lerpf(heft_weight_low(), heft_weight_high(), recoil_heft(kick))
func shove_scale() -> float: return _number(pose.get("shove_scale"), 0.45)
func lift_scale() -> float: return _number(pose.get("lift_scale"), 0.6)
func lift_scale_reduced() -> float: return _number(pose.get("lift_scale_reduced"), 0.28)
func punch_reduced() -> float: return _number(pose.get("punch_reduced"), 0.35)
func punch_rate_scale() -> float: return _number(pose.get("punch_rate_scale"), 1.5)
func punch_limit() -> float: return _number(pose.get("punch_limit"), 1.25)
func recoil_cap() -> float: return _number(pose.get("recoil_cap"), 1.5)
func look_lag_rate() -> float: return _number(pose.get("look_lag_rate"), 12.0)
## Reduced-motion weight for the sampled mechanism offset.
func mechanism_reduced_scale() -> float: return _number(pose.get("mechanism_reduced"), 0.5)

## --- Cosmetic recoil / recovery -------------------------------------------
## These turn the source `feel.kick = [pitch, yaw, recover]` triple into a
## stronger first-person response: a sustained shove and pitch that settle more
## slowly than the source rate, plus a fast transient punch. The character is
## derived from the weapon's own source kick magnitude, so no second table can
## drift from the manifest. A channel authored as a number wins over the
## derivation, which is how a weapon's feel is pinned without touching source
## balance.

## Normalised 0..1 heft of a source kick triple, the band the audio module also
## weights a weapon voice by.
func recoil_heft(kick: Array) -> float:
	if kick.size() < 2: return 0.0
	var low := recoil_heft_low()
	var high := recoil_heft_high()
	var total := clampf(float(kick[0]) + float(kick[1]), low, high)
	return (total - low) / (high - low)

func recoil_heft_low() -> float: return _number(recoil.get("heft_low"), HEFT_LOW)
func recoil_heft_high() -> float: return _number(recoil.get("heft_high"), HEFT_HIGH)

## Sustained translation multiplier on the source kick.
func recoil_scale(kick: Array) -> float:
	return _channel("scale", RECOIL_SCALE_LOW, RECOIL_SCALE_HIGH, kick)
## Sustained muzzle-rise hold, kept close to the source rate on purpose: the
## rest of the per-weapon kick lives in the transient and the shove.
func pitch_hold(kick: Array) -> float:
	return _channel("pitch_hold", PITCH_HOLD_LOW, PITCH_HOLD_HIGH, kick)
## Sustained settle rate derived from the source `recover`.
func recover_rate(kick: Array) -> float:
	var authored: Variant = recoil.get("recover_rate")
	if authored is float or authored is int: return float(authored)
	var scale := _number(recoil.get("recover_scale"), RECOVER_SCALE)
	return maxf(1.0, float(kick[2]) if kick.size() > 2 else 16.0) * scale
func punch_pitch(kick: Array) -> float:
	return _channel("punch_pitch", PUNCH_PITCH_LOW, PUNCH_PITCH_HIGH, kick)
func punch_roll(kick: Array) -> float:
	return _channel("punch_roll", PUNCH_ROLL_LOW, PUNCH_ROLL_HIGH, kick)
func punch_back(kick: Array) -> float:
	return _channel("punch_back", PUNCH_BACK_LOW, PUNCH_BACK_HIGH, kick)
func punch_rate(kick: Array) -> float:
	return _channel("punch_rate", PUNCH_RATE_LIGHT, PUNCH_RATE_HEAVY, kick)

## One authored channel: a number wins (a weapon pins its own feel), otherwise the
## light/heavy endpoints are interpolated by the source heft.
func _channel(name: String, low: float, high: float, kick: Array) -> float:
	var authored: Variant = recoil.get(name)
	if authored is float or authored is int: return float(authored)
	return lerpf(_number(recoil.get("%s_low" % name), low), _number(recoil.get("%s_high" % name), high), recoil_heft(kick))

## --- Spring / inertia limits -----------------------------------------------

## `omega` (rad/s) and `limit` (metres, or normalised units) for one cosmetic
## channel: lateral, forward, vertical, sprint, strafe, look_x, look_y.
func spring(channel: String) -> Dictionary:
	var value: Variant = springs.get(channel)
	if value is Dictionary: return value
	var fallback: Variant = (DEFAULT.springs as Dictionary).get(channel)
	return fallback if fallback is Dictionary else {"omega": 18.0, "limit": 0.1}

## Observed source motion -> cosmetic offset gain, clamp and spring impulse for
## one channel. Read once per bind so the hot path stays plain float math.
func impulse(channel: String) -> Dictionary:
	var value: Variant = impulses.get(channel)
	if value is Dictionary: return value
	var fallback: Variant = (DEFAULT.impulses as Dictionary).get(channel)
	return fallback if fallback is Dictionary else {}

## The whole authored impulse/composition table, for helpers that read several
## channels per frame.
func impulse_table() -> Dictionary:
	return impulses

## --- Cosmetic handling / FX bounds -----------------------------------------

func charge_time() -> float: return _number(handling.get("charge_time"), CHARGE_TIME)
func puff_life() -> float: return _number(handling.get("puff_life"), PUFF_LIFE)
func puff_pool() -> int: return maxi(1, int(_number(handling.get("puff_pool"), PUFF_POOL)))
func haze_size() -> float: return _number(handling.get("haze_size"), HAZE_SIZE)
func haze_growth() -> float: return _number(handling.get("haze_growth"), HAZE_GROWTH)
func haze_reduced_scale() -> float: return _number(handling.get("haze_reduced_scale"), HAZE_REDUCED_SCALE)

## --- Additive hip-fire optical cue -----------------------------------------

func sprint_fov_degrees() -> float: return _number(optics.get("sprint_fov_degrees"), SPRINT_FOV_DEGREES)
func sprint_fov_rate() -> float: return _number(optics.get("sprint_fov_rate"), SPRINT_FOV_RATE)

## --- Mechanism clips -------------------------------------------------------

## The authored mechanism clip for `kind` ("reload", "switch", "pump"), or ""
## when this weapon's mechanism is purely procedural. An empty name is the
## default for every weapon except the Pulse Rifle.
func clip(kind: String) -> String:
	var value: Variant = clips.get(kind)
	return String(value) if value is String else ""

## --- Muzzle / impact grammar and audio cues --------------------------------

## Grammar references only: the source `feel` impact/trace/arc words plus the
## effect ids `weapon_effects/profiles.gd` and `world/audio_feedback.gd` key their
## own tables by. No effect value is duplicated here.
func impact_grammar() -> Dictionary:
	return grammar

## The audio cue id this weapon's report uses, as keyed by
## `world/audio_feedback.gd` (`report` -> "shot", `launch` -> "launch",
## `impact` -> "hit").
func report_cue(kind: String = "report") -> String:
	var value: Variant = audio.get(kind)
	return String(value) if value is String else ""

static func _number(value: Variant, fallback: float) -> float:
	return float(value) if (value is int or value is float) and is_finite(float(value)) else fallback
