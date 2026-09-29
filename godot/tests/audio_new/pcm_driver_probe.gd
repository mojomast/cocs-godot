extends SceneTree
## Driver probe only: reports the active Godot audio output and whether the
## Master bus actually mixes PCM that AudioEffectCapture can observe. A Dummy
## driver lifecycle is explicitly not treated as audio evidence.
##
## Usage: godot --path godot --script res://tests/audio_new/pcm_driver_probe.gd

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var info := {
		"mix_rate": AudioServer.get_mix_rate(),
		"output_device": AudioServer.get_output_device(),
		"speaker_mode": AudioServer.get_speaker_mode(),
		"bus_count": AudioServer.bus_count,
		"device_count": AudioServer.get_output_device_list().size(),
	}
	info["has_driver_name"] = AudioServer.has_method("get_driver_name")
	if info["has_driver_name"]:
		info["driver_name"] = AudioServer.get_driver_name()
	print("PCM_PROBE_INFO ", JSON.stringify(info))
	var master := AudioServer.get_bus_index("Master")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 3.0
	AudioServer.add_bus_effect(master, capture, AudioServer.get_bus_effect_count(master))
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = float(AudioServer.get_mix_rate())
	gen.buffer_length = 0.5
	var player := AudioStreamPlayer.new()
	player.stream = gen
	player.bus = &"Master"
	player.volume_db = 0.0
	root.add_child(player)
	player.play()
	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var pushed := 0
	if playback != null:
		for i in 22050:
			if playback.get_frames_available() <= 0:
				break
			playback.push_frame(Vector2(sin(TAU * 440.0 * float(i) / 44100.0) * 0.5, 0.0))
			pushed += 1
	var peak := 0.0
	var count := 0
	for frame in 120:
		await process_frame
		var available := mini(capture.get_frames_available(), 4096)
		if available <= 0:
			continue
		var buf: PackedVector2Array = capture.get_buffer(available)
		count += buf.size()
		for sample: Vector2 in buf:
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	print("PCM_PROBE_RESULT pushed=", pushed, " frames=", count, " peak=", peak,
		" captured=", count > 0 and peak > 0.00005)
	quit(0)
