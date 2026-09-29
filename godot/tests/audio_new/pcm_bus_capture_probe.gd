extends SceneTree
## Bus-send capture probe: tests whether an AudioEffectCapture on Master sees
## audio produced by a child bus that sends to Master, versus a player placed
## directly on Master. Diagnostic only; no lifecycle claim.

func _initialize() -> void:
	call_deferred("run")

func _generator_player(bus: String) -> AudioStreamPlayer:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = float(AudioServer.get_mix_rate())
	gen.buffer_length = 0.75
	var player := AudioStreamPlayer.new()
	player.stream = gen
	player.bus = bus
	player.volume_db = 0.0
	root.add_child(player)
	player.play()
	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	for i in 32768:
		if playback != null and playback.get_frames_available() > 0:
			playback.push_frame(Vector2(sin(TAU * 440.0 * float(i) / 44100.0) * 0.5, 0.0))
	return player

func _peak(capture: AudioEffectCapture, frames: int) -> Dictionary:
	var count := 0
	var peak := 0.0
	for frame in frames:
		await process_frame
		var available := mini(capture.get_frames_available(), 4096)
		if available <= 0:
			continue
		var buf: PackedVector2Array = capture.get_buffer(available)
		count += buf.size()
		for sample: Vector2 in buf:
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	return {"frames": count, "peak": peak}

func run() -> void:
	# Child bus that sends to Master.
	var child := AudioServer.bus_count
	AudioServer.add_bus(child)
	AudioServer.set_bus_name(child, "ProbeChild")
	AudioServer.set_bus_send(child, "Master")
	var master_capture := AudioEffectCapture.new()
	master_capture.buffer_length = 3.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), master_capture, 0)
	var child_capture := AudioEffectCapture.new()
	child_capture.buffer_length = 3.0
	AudioServer.add_bus_effect(child, child_capture, 0)
	var child_player := _generator_player("ProbeChild")
	var child_result: Dictionary = await _peak(child_capture, 60)
	child_player.stop()
	var master_child_result: Dictionary = await _peak(master_capture, 10)
	master_capture.clear_buffer()
	var master_player := _generator_player("Master")
	var master_direct_result: Dictionary = await _peak(master_capture, 60)
	print("PCM_BUS_PROBE child_capture=", JSON.stringify(child_result),
		" master_seen_from_child=", JSON.stringify(master_child_result),
		" master_direct=", JSON.stringify(master_direct_result))
	quit(0)
