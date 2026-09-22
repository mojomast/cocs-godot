class_name PortAudioFeedback
extends Node

# Original, short procedural cues. Feed only deduplicated authoritative events.
# Non-positional/local feedback; Master bus volume/mute still applies.
const MAX_VOICES: int = 8
const SAMPLE_RATE: int = 22050
const DEFAULT_VOLUME_DB: float = -16.0
const CUE_SECONDS: Dictionary = {"shot": 0.11, "hit": 0.075, "hurt": 0.18, "pickup": 0.22}
const PROJECTILE_SECONDS: Dictionary = {"launch": 0.22, "explosion": 0.3}
const INTERVAL_USEC: Dictionary = {"shot": 65000, "hit": 80000, "hurt": 140000, "pickup": 180000, "launch": 120000, "explosion": 180000}
const Projectiles = preload("res://world/projectiles.gd")

var _muted: bool = false
var _sounds: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _last_play_usec: Dictionary = {}

func _ready() -> void:
	_initialize_audio()

func _initialize_audio() -> void:
	if not _sounds.is_empty(): return
	for cue: String in CUE_SECONDS:
		_sounds[cue] = _make_sound(cue, float(CUE_SECONDS[cue]))
	for index: int in range(MAX_VOICES):
		var voice := AudioStreamPlayer.new()
		voice.name = "CueVoice%d" % index
		voice.volume_db = DEFAULT_VOLUME_DB
		voice.bus = &"Master"
		add_child(voice)
		_voices.append(voice)

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
		match item.get("type", ""):
			"launch":
				if actor == local_id and _identity(item.get("weapon")) >= 0 and Projectiles.point(item.get("pos")) != null: _play_cue("launch")
			"shot":
				if actor == local_id: _play_cue("shot")
			"damage":
				var amount: Variant = item.get("amount")
				if not (amount is int or amount is float): continue
				if not is_finite(float(amount)) or float(amount) <= 0.0: continue
				if actor == local_id:
					_play_cue("hurt")
				elif _identity(item.get("source")) == local_id:
					_play_cue("hit")
			"pickup":
				if actor == local_id: _play_cue("pickup")

func _identity(value: Variant) -> int:
	# JSON numbers are floats; null, booleans and strings must never become actor 0.
	if not (value is int or value is float): return -1
	var number: float = float(value)
	if not is_finite(number) or number < 0.0 or number > 2147483647.0: return -1
	if number != floor(number): return -1
	return int(number)

func _play_cue(cue: String) -> void:
	# Cache the extra cues only when projectile combat first needs them.
	if not _sounds.has(cue): _sounds[cue] = _make_sound(cue, float(PROJECTILE_SECONDS[cue]))
	var now: int = Time.get_ticks_usec()
	if _last_play_usec.has(cue) and now - int(_last_play_usec[cue]) < int(INTERVAL_USEC[cue]): return
	for voice: AudioStreamPlayer in _voices:
		if voice.playing: continue
		voice.stream = _sounds[cue]
		voice.play()
		_last_play_usec[cue] = now
		return
	# Pool full: drop new cues rather than allocate or interrupt existing tails.

func set_muted(value: bool) -> void:
	_muted = value
	if _muted: clear_round()

func clear_round() -> void:
	for voice: AudioStreamPlayer in _voices:
		voice.stop()
		voice.stream = null
	_last_play_usec.clear()

func _exit_tree() -> void:
	clear_round()

func _make_sound(cue: String, duration: float) -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * duration)
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 16381 # Local deterministic noise; does not touch gameplay RNG.
	var phase: float = 0.0
	var smooth_noise: float = 0.0
	for index: int in range(count):
		var t: float = float(index) / SAMPLE_RATE
		var progress: float = float(index) / float(count - 1)
		var sample: float = 0.0
		match cue:
			"launch":
				phase += TAU * lerpf(130.0, 55.0, progress) / SAMPLE_RATE
				smooth_noise = lerpf(smooth_noise, rng.randf_range(-1.0, 1.0), 0.4)
				sample = (0.5 * smooth_noise + 0.4 * sin(phase)) * exp(-10.0 * t)
			"explosion":
				phase += TAU * lerpf(75.0, 30.0, progress) / SAMPLE_RATE
				smooth_noise = lerpf(smooth_noise, rng.randf_range(-1.0, 1.0), 0.25)
				sample = (0.35 * smooth_noise + 0.25 * sin(phase)) * exp(-12.0 * t)
			"shot":
				phase += TAU * lerpf(190.0, 65.0, progress) / SAMPLE_RATE
				smooth_noise = lerpf(smooth_noise, rng.randf_range(-1.0, 1.0), 0.65)
				sample = (0.72 * smooth_noise + 0.28 * sin(phase)) * exp(-20.0 * t)
			"hit":
				sample = (0.65 * sin(TAU * 1350.0 * t) + 0.35 * sin(TAU * 1950.0 * t)) * exp(-28.0 * t)
			"hurt":
				phase += TAU * lerpf(155.0, 70.0, progress) / SAMPLE_RATE
				sample = (0.8 * sin(phase) + 0.2 * sin(phase * 2.0)) * exp(-12.0 * t)
			"pickup":
				phase += TAU * lerpf(660.0, 1320.0, progress) / SAMPLE_RATE
				sample = (0.75 * sin(phase) + 0.25 * sin(phase * 1.5)) * exp(-7.0 * t)
		# 3ms attack and 18ms release reach zero at both endpoints (no hard edges).
		var envelope: float = minf(1.0, t / 0.003) * minf(1.0, (float(count - 1 - index) / SAMPLE_RATE) / 0.018)
		# Peak <= 0.65; even eight coherent voices at -16dB remain below full scale.
		var signed_sample: int = roundi(sample * envelope * 0.65 * 32767.0)
		pcm.encode_s16(index * 2, signed_sample)
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = SAMPLE_RATE
	sound.stereo = false
	sound.loop_mode = AudioStreamWAV.LOOP_DISABLED
	sound.data = pcm
	return sound
