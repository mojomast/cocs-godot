extends SceneTree
## Actual Godot AudioServer DSP capture from the Master bus — NOT a Dummy-driver
## lifecycle test. Requires a real audio output driver (on this host: ALSA via a
## private userspace `null` default, so no hardware and no listening claim).
##
## The ALSA `null` PCM does not pace in real time: it runs many times faster
## than realtime, so a frame-per-process-frame read loop lets the capture ring
## wrap past the note before its first read. This probe instead drains in a
## tight loop (no await), skips leading silence to the note onset, and stores a
## bounded window. Every window is bounded by frames and wall-clock timeout.
##
## Usage:
##   COCS_AUDIO_CAPTURE_PATH=/abs/isolated.wav \
##     godot --path godot --display-driver headless --audio-driver ALSA \
##       --script res://tests/audio_new/waveform_capture.gd
##
## Writes <path> for the Master mix plus <path-basename>-seed42/-seed137.wav for
## the two seeded variation takes.

const Music = preload("res://audio/music_service.gd")
const Motifs = preload("res://audio/objective_motifs.gd")
const Buses = preload("res://audio/buses.gd")

const MIN_PEAK := 0.00005
const MIN_ENERGY := 0.0001
const MIN_FRAMES := 2205           # 50 ms at 44.1 kHz
const WINDOW_SECONDS := 1.0        # bounded DSP window stored per capture
const DRAIN_TIMEOUT_MS := 5000     # hard wall-clock bound; silence cannot hang
const ONSET_THRESHOLD := 0.00005

var capture: AudioEffectCapture
var music
var motifs
var master := -1
var effect_index := -1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var path := OS.get_environment("COCS_AUDIO_CAPTURE_PATH")
	if path.is_empty() or not path.is_absolute_path() or not path.ends_with(".wav"):
		fail("Set COCS_AUDIO_CAPTURE_PATH to an isolated absolute .wav path")
		return
	var driver := AudioServer.get_driver_name()
	if driver.to_lower() == "dummy":
		fail("Dummy driver is not DSP evidence; pass a real --audio-driver")
		return
	master = AudioServer.get_bus_index("Master")
	Buses.ensure()
	Buses.apply({"music_enabled":true,"announcer_enabled":true,"ambience_enabled":true,"mute":false})
	capture = AudioEffectCapture.new()
	capture.buffer_length = 3.0
	effect_index = AudioServer.get_bus_effect_count(master)
	AudioServer.add_bus_effect(master, capture, effect_index)
	music = Music.new()
	root.add_child(music)
	motifs = Motifs.new()
	root.add_child(motifs)
	music.set_settings({"music_volume":100,"announcer_volume":100,"music_enabled":true,"announcer_enabled":true,"mute":false})
	motifs.apply_settings({"effects_volume":100,"mute":false})
	music.set_scene("combat")
	music.set_seed(42)
	music.set_variation(137)
	music.start()
	# One bounded Master mix window: Ogg score plus a speech WAV cue plus an
	# objective earcon WAV must all pass the same captured Master output. The
	# trigger runs inside the drain so the onset cannot pass before reading.
	var main: Dictionary = capture_window(func() -> Variant:
		music.tick(0.25)
		music.cue("objective")
		motifs.event_plan({"type":"director-phase"})
		return null)
	if not sounded(main):
		fail("No audible Master mix frames on %s (frames=%d peak=%f energy=%f timed_out=%s)" %
			[driver, main.frames, main.peak, main.energy, str(main.timed_out)])
		return
	var saved := save_wav(path, main.samples)
	if saved != OK:
		fail("Cannot save actual Master bus capture: %d" % saved)
		return
	# Two bar-11 lead ornaments differ by a seeded semitone choice. Capture the
	# actual mix for both takes and record the player pitch plans as the
	# deterministic explanation of the waveform difference.
	var first: Dictionary = variation_take(42)
	var second: Dictionary = variation_take(137)
	if not sounded(first) or not sounded(second):
		fail("Seeded variation produced no mixed frames: take42(frames=%d peak=%f zcr=%f) take137(frames=%d peak=%f zcr=%f)" %
			[first.frames, first.peak, first.zcr, second.frames, second.peak, second.zcr])
		return
	if first.pitches == second.pitches:
		fail("Music variation produced identical seeded pitch plans: %s vs %s" %
			[str(first.pitches), str(second.pitches)])
		return
	if absf(first.zcr - second.zcr) <= 0.001:
		fail("Seeded pitch plans differ but captured PCM zero-crossing rates do not: %f vs %f" %
			[first.zcr, second.zcr])
		return
	var base := path.get_basename()
	var result_a := save_wav(base + "-seed42.wav", first.samples)
	var result_b := save_wav(base + "-seed137.wav", second.samples)
	if result_a != OK or result_b != OK:
		fail("Cannot save seeded variation captures: %d, %d" % [result_a, result_b])
		return
	print("AUDIO_WAVEFORM_OK driver=", driver,
		" frames=", main.frames, " peak=", main.peak, " energy=", main.energy,
		" streams=", music.status().loaded_streams,
		" variation_frames=", first.frames, ",", second.frames,
		" variation_peaks=", first.peak, ",", second.peak,
		" variation_zcr=", first.zcr, ",", second.zcr,
		" pitch_plans=", first.pitches, ",", second.pitches,
		" variation_pcm_equal=", first.fingerprint == second.fingerprint,
		" file=", path, " sha256=", FileAccess.get_sha256(path))
	cleanup()
	quit(0)

func sounded(window: Dictionary) -> bool:
	return window.frames >= MIN_FRAMES and window.peak > MIN_PEAK and window.energy > MIN_ENERGY

## Drain the Master capture in a tight loop (no await, so the fast null device
## cannot outrun the reader), skip leading silence to the onset, and store a
## bounded window. `trigger` runs immediately after the buffer is cleared, so
## the audible onset is always mixed while this loop is already draining.
func capture_window(trigger: Callable = Callable()) -> Dictionary:
	var target := int(round(WINDOW_SECONDS * AudioServer.get_mix_rate()))
	capture.clear_buffer()
	var trigger_result: Variant = trigger.call() if trigger.is_valid() else null
	var samples := PackedVector2Array()
	var peak := 0.0
	var energy := 0.0
	var zero_crossings := 0
	var previous_sign := 0.0
	var started := false
	var deadline := Time.get_ticks_msec() + DRAIN_TIMEOUT_MS
	while samples.size() < target and Time.get_ticks_msec() < deadline:
		var available := capture.get_frames_available()
		if available <= 0:
			continue
		var buffer: PackedVector2Array = capture.get_buffer(available)
		var begin := 0
		if not started:
			begin = -1
			for i in buffer.size():
				if maxf(absf(buffer[i].x), absf(buffer[i].y)) > ONSET_THRESHOLD:
					begin = i
					started = true
					break
			if begin < 0:
				continue
		var end := mini(buffer.size(), begin + (target - samples.size()))
		for i in range(begin, end):
			var sample: Vector2 = buffer[i]
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
			energy += sample.length_squared()
			var current_sign := signf(sample.x)
			if current_sign != 0.0 and previous_sign != 0.0 and current_sign != previous_sign:
				zero_crossings += 1
			if current_sign != 0.0:
				previous_sign = current_sign
		samples.append_array(buffer.slice(begin, end))
	var result := {"samples":samples,"frames":samples.size(),"peak":peak,"energy":energy,
		"zcr":float(zero_crossings) / float(maxi(1, samples.size())),
		"timed_out":samples.size() < target, "trigger":trigger_result}
	result["fingerprint"] = fingerprint(samples)
	return result

func variation_take(value: int) -> Dictionary:
	for player: AudioStreamPlayer in music.players: player.stop()
	if music.announcer_player != null: music.announcer_player.stop()
	for player: AudioStreamPlayer in motifs.players: player.stop()
	music.set_scene("combat")
	music.set_variation(value)
	music.form_bar = 11
	music.step = 12
	var window: Dictionary = capture_window(func() -> Variant:
		music._step_music()
		var plan := []
		for player: AudioStreamPlayer in music.players:
			if player.playing: plan.append(snappedf(player.pitch_scale, 0.0001))
		return plan)
	window["pitches"] = window["trigger"]
	return window

func fingerprint(samples: PackedVector2Array) -> String:
	var hash := 1469598103934665603
	for sample: Vector2 in samples:
		for value: float in [sample.x, sample.y]:
			var quantized := int(round(clampf(value, -1.0, 1.0) * 32767.0)) & 0xffff
			hash = ((hash ^ quantized) * 1099511628211) & 0x7fffffffffffffff
	return "%016x" % hash

func save_wav(path: String, samples: PackedVector2Array) -> int:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 4)
	for i in samples.size():
		bytes.encode_s16(i * 4, roundi(clampf(samples[i].x, -1.0, 1.0) * 32767.0))
		bytes.encode_s16(i * 4 + 2, roundi(clampf(samples[i].y, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(AudioServer.get_mix_rate())
	stream.stereo = true
	stream.data = bytes
	return stream.save_to_wav(path)

func fail(message: String) -> void:
	push_error(message)
	cleanup()
	quit(1)

func cleanup() -> void:
	if music != null and is_instance_valid(music): music.free()
	if motifs != null and is_instance_valid(motifs): motifs.free()
	if master >= 0 and effect_index >= 0 and effect_index < AudioServer.get_bus_effect_count(master):
		AudioServer.remove_bus_effect(master, effect_index)
