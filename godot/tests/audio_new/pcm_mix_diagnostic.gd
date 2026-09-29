extends SceneTree
## Diagnostic for the waveform-capture mix: mirrors the capture setup and prints
## per-bus, per-player state so silence can be attributed precisely.
const Music = preload("res://audio/music_service.gd")
const Motifs = preload("res://audio/objective_motifs.gd")
const Buses = preload("res://audio/buses.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var master := AudioServer.get_bus_index("Master")
	Buses.ensure()
	Buses.apply({"music_enabled":true,"announcer_enabled":true,"ambience_enabled":true,"mute":false})
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 3.0
	AudioServer.add_bus_effect(master, capture, AudioServer.get_bus_effect_count(master))
	var music := Music.new()
	root.add_child(music)
	var motifs := Motifs.new()
	root.add_child(motifs)
	music.set_settings({"music_volume":100,"announcer_volume":100,"music_enabled":true,"announcer_enabled":true,"mute":false})
	motifs.apply_settings({"effects_volume":100,"mute":false})
	music.set_scene("combat")
	music.set_seed(42)
	music.set_variation(137)
	music.start()
	music.tick(0.25)
	var cue_ok: bool = music.cue("objective")
	var motif_ok: bool = motifs.event_plan({"type":"director-phase"})
	var status: Dictionary = music.status()
	print("DIAG_STATUS ", JSON.stringify({"status":status,"cue_ok":cue_ok,"motif_ok":motif_ok}))
	for i in AudioServer.bus_count:
		print("DIAG_BUS ", i, " name=", AudioServer.get_bus_name(i),
			" volume=", AudioServer.get_bus_volume_linear(i),
			" mute=", AudioServer.is_bus_mute(i),
			" send=", AudioServer.get_bus_send(i))
	for i in music.players.size():
		var player: AudioStreamPlayer = music.players[i]
		if player.playing:
			print("DIAG_PLAYER ", i, " bus=", player.bus, " db=", player.volume_db,
				" pitch=", player.pitch_scale, " stream=", player.stream,
				" len=", (player.stream.get_length() if player.stream != null else -1.0))
	print("DIAG_ANNOUNCER playing=", music.announcer_player.playing, " stream=", music.announcer_player.stream)
	for player: AudioStreamPlayer in motifs.players:
		if player.playing:
			print("DIAG_MOTIF bus=", player.bus, " db=", player.volume_db, " stream=", player.stream)
	var peak := 0.0
	var count := 0
	for frame in 90:
		await process_frame
		var available := mini(capture.get_frames_available(), 4096)
		if available <= 0:
			continue
		var buf: PackedVector2Array = capture.get_buffer(available)
		count += buf.size()
		for sample: Vector2 in buf:
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	print("DIAG_CAPTURE frames=", count, " peak=", peak, " voices=", music.status().active_voices,
		" dropped_notes=", music.status().dropped_notes, " load_failures=", music.status().loaded_failures)
	quit(0)
