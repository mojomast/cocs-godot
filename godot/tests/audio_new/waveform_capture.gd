extends SceneTree
## Audible-mix probe, NOT a Dummy-driver lifecycle test. Requires an actual
## Godot audio output driver; writes WAV to an isolated absolute capture path.
const Music = preload("res://audio/music_service.gd")
const Motifs = preload("res://audio/objective_motifs.gd")
const Buses = preload("res://audio/buses.gd")
const MIN_PEAK := 0.00005
var capture: AudioEffectCapture
var music
var motifs
var master := -1
var effect_index := -1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("COCS_AUDIO_CAPTURE_PATH").is_empty():
		fail("Set COCS_AUDIO_CAPTURE_PATH to an isolated absolute .wav path")
		return
	var path := OS.get_environment("COCS_AUDIO_CAPTURE_PATH")
	if not path.is_absolute_path() or not path.ends_with(".wav"):
		fail("Capture path must be absolute and .wav")
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
	# Actual Ogg instrument articulation, one existing speech WAV, and an
	# objective earcon must pass the same captured Master output.
	music.tick(0.25)
	music.cue("objective")
	motifs.event_plan({"type":"director-phase"})
	var pcm := PackedVector2Array()
	for frame in 90:
		await process_frame
		var n := mini(capture.get_frames_available(), 4096)
		if n > 0: pcm.append_array(capture.get_buffer(n))
	var peak := 0.0
	var energy := 0.0
	for sample: Vector2 in pcm:
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		energy += sample.length_squared()
	if pcm.size() < 2205 or peak <= MIN_PEAK or energy <= 0.0001:
		fail("No audible mix frames; Dummy/headless lifecycle alone is not audio evidence (frames=%d, peak=%f)" % [pcm.size(), peak])
		return
	var bytes := PackedByteArray()
	bytes.resize(pcm.size() * 4)
	for i in pcm.size():
		bytes.encode_s16(i * 4, roundi(clampf(pcm[i].x, -1.0, 1.0) * 32767.0))
		bytes.encode_s16(i * 4 + 2, roundi(clampf(pcm[i].y, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = AudioServer.get_mix_rate()
	stream.stereo = true
	stream.data = bytes
	var result := stream.save_to_wav(path)
	if result != OK:
		fail("Cannot save actual Master bus capture: %d" % result)
		return
	print("AUDIO_WAVEFORM_OK frames=",pcm.size()," peak=",peak," energy=",energy," streams=",music.status().loaded_streams," file=",path)
	cleanup()
	quit(0)

func fail(message: String) -> void:
	push_error(message)
	cleanup()
	quit(1)

func cleanup() -> void:
	if music != null and is_instance_valid(music): music.free()
	if motifs != null and is_instance_valid(motifs): motifs.free()
	if master >= 0 and effect_index >= 0 and effect_index < AudioServer.get_bus_effect_count(master): AudioServer.remove_bus_effect(master, effect_index)
