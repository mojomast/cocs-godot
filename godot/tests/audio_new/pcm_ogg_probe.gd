extends SceneTree
## Race probe: ALSA null runs faster than real time, so a slow read loop loses
## the note before it is drained. This drains in a tight loop right after play.
const Buses = preload("res://audio/buses.gd")

func _initialize() -> void:
	call_deferred("run")

func drain_for(capture: AudioEffectCapture, millis: int) -> Dictionary:
	var peak := 0.0
	var count := 0
	var deadline := Time.get_ticks_msec() + millis
	while Time.get_ticks_msec() < deadline:
		var available := capture.get_frames_available()
		if available <= 0:
			continue
		var buf: PackedVector2Array = capture.get_buffer(available)
		count += buf.size()
		for sample: Vector2 in buf:
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	return {"frames": count, "peak": peak}

func run() -> void:
	Buses.ensure()
	Buses.apply({"music_enabled":true,"announcer_enabled":true,"ambience_enabled":true,"mute":false})
	var master := AudioServer.get_bus_index("Master")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 5.0
	AudioServer.add_bus_effect(master, capture, 0)
	var ogg: AudioStream = load("res://audio/music/samples/strings-pad-cello-c3-p.ogg")
	print("OGG_PROBE loaded=", ogg != null, " len=", (ogg.get_length() if ogg != null else -1.0))
	var player := AudioStreamPlayer.new()
	player.stream = ogg
	player.bus = &"Score"
	player.volume_db = 0.0
	root.add_child(player)
	player.play()
	var tight: Dictionary = drain_for(capture, 2000)
	print("OGG_PROBE tight_drain=", JSON.stringify(tight))
	capture.clear_buffer()
	# Slow-loop variant for contrast.
	player.play()
	var slow_peak := 0.0
	for i in 30:
		await process_frame
		var available := mini(capture.get_frames_available(), 4096)
		if available <= 0:
			continue
		for sample: Vector2 in capture.get_buffer(available):
			slow_peak = maxf(slow_peak, maxf(absf(sample.x), absf(sample.y)))
	print("OGG_PROBE slow_loop_peak=", slow_peak)
	quit(0)
