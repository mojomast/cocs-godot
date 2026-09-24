class_name PortAudioFeedback
extends Node

# Original, short procedural cues. Feed only deduplicated authoritative events.
# Non-positional/local feedback; Master bus volume/mute still applies.
#
# Weapon-oomph layering: every local shot/launch is synthesized for its own
# weapon with the source `feel` hints (frequency, waveform, duration, gain) as
# the basis: a noise crack, a filtered body, a tonal report, a sub-bass thump, one
# family layer and a short tail. Confirmed damage uses the last local weapon's
# impact voice. Everything is generated once from a local deterministic seed and
# cached; playback never regenerates samples or allocates nodes.
const MAX_VOICES: int = 8
const SAMPLE_RATE: int = 22050
const DEFAULT_VOLUME_DB: float = -16.0
const CUE_SECONDS: Dictionary = {"hurt": 0.18, "pickup": 0.22}
const PROJECTILE_SECONDS: Dictionary = {"launch": 0.34, "explosion": 0.42}
const INTERVAL_USEC: Dictionary = {"shot": 65000, "hit": 80000, "hurt": 140000, "pickup": 180000, "launch": 120000, "explosion": 180000}
const WEAPON_CUES: Array[String] = ["shot", "launch", "hit"]
const Projectiles = preload("res://world/projectiles.gd")
const TABLE_SIZE := 1024
const NOISE_SECONDS := 0.6
const PEAK_CEILING := 0.65

## Source feel hints, transcribed from the read-only source tables
## (`game/data.mjs` feel triples and `game/sfx-design.mjs` GUN_STYLES /
## REPORT_STYLES). The locked source is never read or mutated at runtime; this is
## a presentation copy inside the audio module only. `kick` is only used to
## decide how heavy a weapon's voice is.
const FEEL := [
	{"style":"rifle",  "kick":[0.045,0.030,16], "shot":[320.0,0.075,"square",65.0],   "launch":[320.0,0.075,"square",65.0],   "impact":[1050.0,0.045,"sine",1600.0]},
	{"style":"heavy",  "kick":[0.105,0.082,10], "shot":[86.0,0.16,"sawtooth",28.0],   "launch":[62.0,0.24,"sawtooth",24.0],   "impact":[58.0,0.3,"sawtooth",22.0]},
	{"style":"zap",    "kick":[0.075,0.070,13], "shot":[1500.0,0.16,"sine",180.0],   "launch":[1500.0,0.16,"sine",180.0],    "impact":[1900.0,0.1,"sine",2600.0]},
	{"style":"burst",  "kick":[0.12,0.085,12],  "shot":[180.0,0.13,"triangle",35.0],  "launch":[180.0,0.13,"triangle",35.0],  "impact":[120.0,0.12,"square",55.0]},
	{"style":"plasma", "kick":[0.03,0.025,20],  "shot":[620.0,0.09,"triangle",250.0], "launch":[410.0,0.12,"triangle",140.0], "impact":[260.0,0.16,"sine",80.0]},
	{"style":"heavy",  "kick":[0.095,0.075,10], "shot":[210.0,0.18,"sawtooth",45.0],  "launch":[130.0,0.2,"sawtooth",32.0],   "impact":[72.0,0.28,"sawtooth",25.0]},
	{"style":"zap",    "kick":[0.055,0.045,16], "shot":[480.0,0.1,"square",1100.0],   "launch":[480.0,0.1,"square",1100.0],   "impact":[900.0,0.08,"square",1500.0]},
	{"style":"burst",  "kick":[0.115,0.09,11],  "shot":[95.0,0.22,"triangle",30.0],   "launch":[95.0,0.22,"triangle",30.0],   "impact":[80.0,0.2,"triangle",25.0]},
	{"style":"sharp",  "kick":[0.05,0.045,14],  "shot":[700.0,0.09,"square",420.0],   "launch":[700.0,0.09,"square",420.0],   "impact":[1250.0,0.06,"sine",1850.0]},
	{"style":"rapid",  "kick":[0.022,0.02,22],  "shot":[540.0,0.06,"square",180.0],   "launch":[540.0,0.06,"square",180.0],   "impact":[900.0,0.04,"sine",1200.0]},
]
const SHAPES := {
	"rifle":{"transient":1.00,"body":0.90,"sub":0.16,"tail":0.55,"tail_freq":1100.0,"layer":"supersonic"},
	"heavy":{"transient":1.15,"body":1.25,"sub":0.34,"tail":1.05,"tail_freq":300.0,"layer":"double"},
	"zap":{"transient":0.80,"body":0.70,"sub":0.12,"tail":0.70,"tail_freq":2200.0,"layer":"sizzle"},
	"burst":{"transient":0.95,"body":1.00,"sub":0.20,"tail":0.90,"tail_freq":700.0,"layer":"bloom"},
	"plasma":{"transient":0.90,"body":1.05,"sub":0.26,"tail":0.80,"tail_freq":1500.0,"layer":"bloom"},
	"sharp":{"transient":1.20,"body":0.85,"sub":0.14,"tail":0.35,"tail_freq":2600.0,"layer":"crack"},
	"rapid":{"transient":0.85,"body":0.75,"sub":0.10,"tail":0.30,"tail_freq":1800.0,"layer":"tight"},
}

var _muted: bool = false
var _sounds: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _last_play_usec: Dictionary = {}
var _last_weapon: int = 0
var _noise_low := PackedFloat32Array()
var _noise_mid := PackedFloat32Array()
var _sine := PackedFloat32Array()
var synth_usec := 0

func _ready() -> void:
	_initialize_audio()

func _initialize_audio() -> void:
	if not _sounds.is_empty(): return
	var started := Time.get_ticks_usec()
	_build_tables()
	for cue: String in CUE_SECONDS:
		_sounds[cue] = _make_sound(cue, float(CUE_SECONDS[cue]))
	for index: int in range(MAX_VOICES):
		var voice := AudioStreamPlayer.new()
		voice.name = "CueVoice%d" % index
		voice.volume_db = DEFAULT_VOLUME_DB
		voice.bus = &"Master"
		add_child(voice)
		_voices.append(voice)
	synth_usec = Time.get_ticks_usec() - started

## Shared deterministic noise banks and sine table: one generation for all cues.
func _build_tables() -> void:
	if not _noise_mid.is_empty(): return
	var count := int(SAMPLE_RATE * NOISE_SECONDS)
	_noise_mid.resize(count)
	_noise_low.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 16381 # Local deterministic noise; does not touch gameplay RNG.
	var low := 0.0
	var mid := 0.0
	for index: int in count:
		var white := rng.randf_range(-1.0, 1.0)
		low += (white - low) * 0.0627   # ~220 Hz rumble
		mid += (white - mid) * 0.399    # ~1.4 kHz body
		_noise_low[index] = low * 3.2
		_noise_mid[index] = mid * 1.6
	_sine.resize(TABLE_SIZE)
	for index: int in TABLE_SIZE:
		_sine[index] = sin(TAU * float(index) / float(TABLE_SIZE))

static func _cue_index(cue: String) -> int:
	match cue:
		"shot": return 0
		"launch": return 1
		"hit": return 2
		"explosion": return 3
	return 4

## The port's confirmed-damage voice is the source feel `impact` hint.
static func _hint_key(cue: String) -> String:
	return "impact" if cue == "hit" else cue

func _cue_key(cue: String, weapon: int) -> String:
	if weapon >= 0 and weapon < FEEL.size() and cue in WEAPON_CUES: return "%s/%d" % [cue, weapon]
	return cue

func apply_events(items: Array, local_id: int) -> void:
	if _muted or local_id < 0 or not is_inside_tree(): return
	_initialize_audio()
	for value: Variant in items:
		if not value is Dictionary: continue
		var item: Dictionary = value
		# Primary explosions have no actor/owner. Quiet event cue, not hit feedback.
		if item.get("type") == "explosion":
			if Projectiles.point(item.get("pos")) != null: _play_cue("explosion")
			continue
		var actor: int = _identity(item.get("actor"))
		if actor < 0: continue
		var weapon: int = _identity(item.get("weapon"))
		if weapon < 0 or weapon >= FEEL.size(): weapon = _last_weapon if _last_weapon >= 0 else 0
		match item.get("type", ""):
			"launch":
				if actor == local_id and _identity(item.get("weapon")) >= 0 and Projectiles.point(item.get("pos")) != null:
					_last_weapon = weapon
					_play_cue("launch", weapon)
			"shot":
				if actor == local_id:
					_last_weapon = weapon
					_play_cue("shot", weapon)
			"damage":
				var amount: Variant = item.get("amount")
				if not (amount is int or amount is float): continue
				if not is_finite(float(amount)) or float(amount) <= 0.0: continue
				if actor == local_id:
					_play_cue("hurt")
				elif _identity(item.get("source")) == local_id:
					# Damage events carry no weapon; confirm with the last local
					# weapon's impact voice (presentation only).
					_play_cue("hit", _last_weapon)
			"pickup":
				if actor == local_id: _play_cue("pickup")

func _identity(value: Variant) -> int:
	# JSON numbers are floats; null, booleans and strings must never become actor 0.
	if not (value is int or value is float): return -1
	var number: float = float(value)
	if not is_finite(number) or number < 0.0 or number > 2147483647.0: return -1
	if number != floor(number): return -1
	return int(number)

func _play_cue(cue: String, weapon: int = -1) -> void:
	# Cache per-weapon voices only when projectile/weapon combat first needs them.
	var key := _cue_key(cue, weapon)
	if not _sounds.has(key):
		var started := Time.get_ticks_usec()
		_sounds[key] = _make_sound(cue, _cue_seconds(cue, weapon), weapon)
		synth_usec += Time.get_ticks_usec() - started
	var now: int = Time.get_ticks_usec()
	if _last_play_usec.has(cue) and now - int(_last_play_usec[cue]) < int(INTERVAL_USEC[cue]): return
	for voice: AudioStreamPlayer in _voices:
		if voice.playing: continue
		voice.stream = _sounds[key]
		voice.play()
		_last_play_usec[cue] = now
		return
	# Pool full: drop new cues rather than allocate or interrupt existing tails.

func _cue_seconds(cue: String, weapon: int) -> float:
	if cue in WEAPON_CUES and weapon >= 0 and weapon < FEEL.size():
		var hint: Array = FEEL[weapon][_hint_key(cue)]
		var shape: Dictionary = SHAPES[FEEL[weapon].style]
		if cue == "hit":
			# Confirmation is a short material tick, never a full report.
			return clampf(float(hint[1]) * 0.6, 0.05, 0.18) + 0.05
		var body := clampf(float(hint[1]) * 1.5, 0.06, 0.34)
		var tail: float = maxf(0.05, float(shape.tail) * 0.22)
		return minf(0.5, body + tail)
	return float(CUE_SECONDS.get(cue, PROJECTILE_SECONDS.get(cue, 0.3)))

func set_muted(value: bool) -> void:
	_muted = value
	if _muted: clear_round()

func clear_round() -> void:
	for voice: AudioStreamPlayer in _voices:
		voice.stop()
		voice.stream = null
	_last_play_usec.clear()
	_last_weapon = 0

func _exit_tree() -> void:
	clear_round()

func _make_sound(cue: String, duration: float, weapon: int = -1) -> AudioStreamWAV:
	var count: int = maxi(16, int(SAMPLE_RATE * duration))
	var raw := PackedFloat32Array()
	raw.resize(count)
	if cue in WEAPON_CUES and weapon >= 0 and weapon < FEEL.size():
		_synth_weapon(raw, count, cue, weapon)
	else:
		_synth_base(raw, count, cue)
	# 3ms attack and 18ms release reach zero at both endpoints (no hard edges),
	# then the whole cue is normalised in one bounded pass.
	var peak := 0.0
	for index: int in count:
		var t := float(index) / SAMPLE_RATE
		var envelope: float = minf(1.0, t / 0.003) * minf(1.0, (float(count - 1 - index) / SAMPLE_RATE) / 0.018)
		var sample := raw[index] * envelope
		raw[index] = sample
		peak = maxf(peak, absf(sample))
	var gain := 1.0
	var target := PEAK_CEILING
	if cue == "shot":
		# Heavy weapons are intentionally the hottest voices; light automatic fire
		# stays a touch quieter. Every cue stays under the 0.65 contract.
		target *= lerpf(0.80, 1.0, _heft(weapon))
	elif cue == "launch":
		target *= lerpf(0.84, 1.0, _heft(weapon))
	elif cue == "hit":
		target *= lerpf(0.78, 0.96, _heft(weapon))
	if peak > 0.02:
		# Weapon voices and the rebuilt explosion normalise to their target. The
		# original hurt/pickup cues only scale down: their levels are unchanged.
		if weapon < 0 and cue != "explosion":
			gain = minf(target / peak, 1.0)
		else:
			gain = target / peak
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	for index: int in count:
		pcm.encode_s16(index * 2, roundi(raw[index] * gain * 32767.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = SAMPLE_RATE
	sound.stereo = false
	sound.loop_mode = AudioStreamWAV.LOOP_DISABLED
	sound.data = pcm
	return sound

## Normalised 0..1 heft of a source kick triple (light automatic -> heavy).
func _heft(weapon: int) -> float:
	if weapon < 0 or weapon >= FEEL.size(): return 0.0
	var kick: Array = FEEL[weapon].kick
	var total := clampf(float(kick[0]) + float(kick[1]), 0.042, 0.205)
	return (total - 0.042) / (0.205 - 0.042)

## One weapon voice: crack transient, filtered body, tonal report, sub-bass
## thump, one family layer and a short tail. `hint` supplies the source
## frequency/waveform/duration/gain; the family shape supplies the mix.
func _synth_weapon(raw: PackedFloat32Array, count: int, cue: String, weapon: int) -> void:
	var feel: Dictionary = FEEL[weapon]
	var shape: Dictionary = SHAPES[feel.style]
	var hint: Array = feel[_hint_key(cue)]
	var base: float = maxf(60.0, float(hint[0]))
	var waveform := String(hint[2])
	var tone_gain: float = minf(0.30, float(hint[3]) * 0.0032)
	var body_seconds: float = clampf(float(hint[1]) * 1.5, 0.06, 0.34)
	var style := String(feel.style)
	var heavy := style == "heavy"
	var zap := style == "zap"
	var layer := String(shape.layer)
	var transient: float = float(shape.transient)
	var body_mix: float = float(shape.body)
	var sub_mix: float = float(shape.sub)
	var tail_mix: float = float(shape.tail)
	var noise_size := _noise_mid.size()
	var noise_offset := (weapon * 977 + _cue_index(cue) * 613) % maxi(1, noise_size - count)
	# Tone sweep: heavy weapons fall, energy weapons rise into the shot.
	var tone_start := base
	var tone_end: float = base * 2.2 if zap else maxf(45.0, base * 0.55)
	var sub_start: float = maxf(42.0, base * 0.45)
	var sub_end := 48.0 if not heavy else 34.0
	# Launch voices are a deeper, slower whoomp with a longer rumble; hit voices
	# are short material ticks; shots are the full layered report.
	var crack_seconds := 0.009
	var body_scale := body_mix
	var sub_scale := sub_mix
	var tone_seconds := maxf(0.03, body_seconds * 0.6)
	var tail_seconds := maxf(0.09, body_seconds * 0.9)
	var delay := 0.0
	var extra_scale := 0.0
	var extra_seconds := 0.05
	if cue == "shot":
		match layer:
			"supersonic": delay = 0.020; extra_scale = 0.20
			"double": delay = 0.055; extra_scale = 0.30; extra_seconds = 0.09
			"sizzle": delay = 0.010; extra_scale = 0.22; extra_seconds = 0.14
			"bloom": delay = 0.020; extra_scale = 0.24; extra_seconds = 0.16
			"crack": delay = 0.005; extra_scale = 0.45; extra_seconds = 0.04
			"tight": delay = 0.012; extra_scale = 0.35; extra_seconds = 0.03
	elif cue == "launch":
		crack_seconds = 0.016
		body_scale = body_mix * 0.85
		sub_scale = minf(0.5, sub_mix * 1.7)
		tone_seconds = maxf(0.06, body_seconds * 0.85)
		tail_seconds = maxf(0.14, body_seconds * 1.2)
		if zap: delay = 0.015; extra_scale = 0.26; extra_seconds = 0.18
		else: delay = 0.045; extra_scale = 0.22; extra_seconds = 0.20
	else:
		crack_seconds = 0.006
		body_seconds = clampf(float(hint[1]) * 0.6, 0.05, 0.18)
		body_scale = body_mix * 0.45
		sub_scale = sub_mix * 0.55
		tone_seconds = maxf(0.025, body_seconds * 0.35)
		tail_seconds = maxf(0.05, body_seconds * 0.5)
		extra_scale = 0.18 if not zap else 0.30
		extra_seconds = 0.05
	var crack_decay := exp(-1.0 / (SAMPLE_RATE * crack_seconds))
	var body_decay := exp(-1.0 / (SAMPLE_RATE * maxf(0.02, body_seconds * 0.5)))
	var sub_decay := exp(-1.0 / (SAMPLE_RATE * maxf(0.05, body_seconds * 0.9)))
	var tone_decay := exp(-1.0 / (SAMPLE_RATE * tone_seconds))
	var tail_decay := exp(-1.0 / (SAMPLE_RATE * tail_seconds))
	var extra_decay := exp(-1.0 / (SAMPLE_RATE * extra_seconds)) if extra_scale > 0.0 else 0.0
	var crack_env := 1.0
	var body_env := 1.0
	var sub_env := 1.0
	var tone_env := 1.0
	var tail_env := 1.0
	var extra_env := 1.0
	var delay_frames := int(delay * SAMPLE_RATE)
	var tone_phase := 0.0
	var sub_phase := 0.0
	var ring_phase := 0.0
	var ring_gain := 0.0
	if cue == "hit" and (style == "sharp" or style == "zap"):
		ring_gain = 0.16
	for index: int in count:
		var progress := float(index) / float(maxi(1, count - 1))
		var read := (index + noise_offset) % noise_size
		var low := _noise_low[read]
		var mid := _noise_mid[read]
		var high := mid - _noise_low[read] * 0.35
		var frac := tone_phase / TAU
		frac -= floorf(frac)
		var tone := 0.0
		if waveform == "square":
			tone = 1.0 if frac < 0.5 else -1.0
		elif waveform == "sawtooth":
			tone = 2.0 * frac - 1.0
		elif waveform == "triangle":
			tone = 4.0 * absf(frac - 0.5) - 1.0
		else:
			tone = _sine[int(frac * TABLE_SIZE) & (TABLE_SIZE - 1)]
		var sub := _sine[int((sub_phase / TAU - floorf(sub_phase / TAU)) * TABLE_SIZE) & (TABLE_SIZE - 1)]
		var sample := 0.0
		if cue == "shot":
			# Heavy reports crack through the low bank with a touch of edge;
			# everyone else gets the bright high-passed transient.
			var crack := low * 0.8 + high * 0.35 if heavy else high
			sample += crack * transient * crack_env * 0.72
			sample += mid * body_scale * body_env * 0.34
			sample += tone * tone_gain * tone_env
			sample += sub * sub_scale * sub_env * 0.55
			sample += mid * tail_mix * tail_env * 0.12
		elif cue == "launch":
			sample += low * (0.42 if heavy else 0.32) * body_env
			sample += mid * body_scale * body_env * 0.18
			sample += tone * tone_gain * tone_env * 0.9
			sample += sub * sub_scale * sub_env * 0.7
			sample += mid * tail_mix * tail_env * 0.10
		else:
			sample += (mid * 0.42 + high * 0.34) * transient * crack_env
			sample += tone * tone_gain * tone_env
			sample += sub * sub_scale * sub_env * 0.3
			sample += mid * tail_mix * tail_env * 0.08
		if delay_frames > 0:
			delay_frames -= 1
		elif extra_scale > 0.0:
			var extra := high if (layer == "sizzle" or layer == "crack" or layer == "tight" or layer == "supersonic") else low
			sample += extra * extra_scale * extra_env * 0.5
			extra_env *= extra_decay
		if ring_gain > 0.0:
			sample += _sine[int((ring_phase / TAU - floorf(ring_phase / TAU)) * TABLE_SIZE) & (TABLE_SIZE - 1)] * ring_gain * tone_env * 0.5
			ring_phase += TAU * base * 1.7 / SAMPLE_RATE
		raw[index] = sample
		crack_env *= crack_decay
		body_env *= body_decay
		sub_env *= sub_decay
		tone_env *= tone_decay
		tail_env *= tail_decay
		tone_phase += TAU * lerpf(tone_start, tone_end, progress) / SAMPLE_RATE
		sub_phase += TAU * lerpf(sub_start, sub_end, progress) / SAMPLE_RATE

## Non-weapon voices: hurt, pickup, explosion. The original short procedural
## cues are kept; the explosion is rebuilt with a rumble body, sub thump and a
## decaying tail.
func _synth_base(raw: PackedFloat32Array, count: int, cue: String) -> void:
	if cue == "explosion":
		var noise_size := _noise_mid.size()
		var low_env := 1.0
		var sub_env := 1.0
		var mid_env := 1.0
		var tail_env := 1.0
		var low_decay := exp(-1.0 / (SAMPLE_RATE * 0.16))
		var sub_decay := exp(-1.0 / (SAMPLE_RATE * 0.30))
		var mid_decay := exp(-1.0 / (SAMPLE_RATE * 0.05))
		var tail_decay := exp(-1.0 / (SAMPLE_RATE * 0.24))
		var sub_phase := 0.0
		var tone_phase := 0.0
		for index: int in count:
			var progress := float(index) / float(maxi(1, count - 1))
			var read := index % noise_size
			var low := _noise_low[read]
			var mid := _noise_mid[read]
			var sub := _sine[int((sub_phase / TAU - floorf(sub_phase / TAU)) * TABLE_SIZE) & (TABLE_SIZE - 1)]
			var tone := _sine[int((tone_phase / TAU - floorf(tone_phase / TAU)) * TABLE_SIZE) & (TABLE_SIZE - 1)]
			raw[index] = low * low_env * 0.50 + mid * mid_env * 0.30 + sub * sub_env * 0.42 + tone * tail_env * 0.10
			low_env *= low_decay
			sub_env *= sub_decay
			mid_env *= mid_decay
			tail_env *= tail_decay
			sub_phase += TAU * lerpf(75.0, 30.0, progress) / SAMPLE_RATE
			tone_phase += TAU * lerpf(180.0, 60.0, progress) / SAMPLE_RATE
		return
	var phase: float = 0.0
	var smooth_noise: float = 0.0
	for index: int in count:
		var t: float = float(index) / SAMPLE_RATE
		var progress: float = float(index) / float(maxi(1, count - 1))
		var sample: float = 0.0
		match cue:
			"hurt":
				phase += TAU * lerpf(155.0, 70.0, progress) / SAMPLE_RATE
				sample = (0.8 * sin(phase) + 0.2 * sin(phase * 2.0)) * exp(-12.0 * t)
			"pickup":
				phase += TAU * lerpf(660.0, 1320.0, progress) / SAMPLE_RATE
				sample = (0.75 * sin(phase) + 0.25 * sin(phase * 1.5)) * exp(-7.0 * t)
		raw[index] = sample * 0.65
