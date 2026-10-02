extends SceneTree
## Bounded connected native campaign composition, not a fabricated event fixture.
var session: Node
var output := ""
var failures: Array[String] = []
var source_events: Array = []
var recorder: AudioEffectRecord
var bus := -1

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--audio-evidence="): output = arg.trim_prefix("--audio-evidence=")
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func wait_for(predicate: Callable, seconds: float, label: String) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < end:
		if predicate.call(): return true
		await process_frame
	check(false, label)
	return false

func run() -> void:
	if output.is_empty(): quit(2); return
	check(AudioServer.get_driver_name() != "Dummy", "real mixer required")
	root.size = Vector2i(640, 400)
	root.scaling_3d_scale = 0.35
	session = load("res://campaign/demo.tscn").instantiate()
	root.add_child(session)
	session.client.events.connect(func(items: Array) -> void:
		for item: Dictionary in items:
			if item.get("type") == "enemy-telegraph": source_events.append(item.duplicate(true)))
	if not await wait_for(func() -> bool: return session.phase == -2, 8.0, "briefing"): await finish(); return
	session.campaign_hud.primary.pressed.emit()
	if not await wait_for(func() -> bool: return session.phase == 3 and session.received_pose, 20.0, "live pose"): await finish(); return
	var av: Node = session.audiovisual
	var saved: Dictionary = av.settings.duplicate()
	av.apply_settings({"effects_volume":100,"mute":false,"music_enabled":false,"announcer_enabled":false})
	bus = AudioServer.get_bus_index("Effects")
	recorder = AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus, recorder)
	recorder.set_recording_active(true)
	await wait_for(func() -> bool: return av.threats.accepted >= 2, 14.0, "two source windups reach native voices")
	check(not source_events.is_empty(), "real client wire events")
	check(av.threats.status().voices <= 4, "voice bound")
	av.apply_settings({"mute":true,"effects_volume":100})
	var muted_count: int = av.threats.accepted
	await create_timer(1.0).timeout
	check(av.threats.accepted == muted_count and av.threats.status().voices == 0, "mute release/no catchup")
	av.apply_settings({"mute":false,"effects_volume":0})
	check(av.threats.status().voices == 0, "effects zero")
	av.set_focus(false)
	check(av.threats.status().voices == 0, "focus release")
	av.set_focus(true)
	av.suspend("audio_acceptance_stale")
	check(av.threats.status().voices == 0, "stale release")
	# Production snapshots restore freshness; event identities remain consumed.
	av.apply_settings(saved)
	await create_timer(0.15).timeout
	await finish()

func finish() -> void:
	var report := {"failures":failures,"events":source_events,"driver":AudioServer.get_driver_name(),"human_listening":"OPEN"}
	if is_instance_valid(session) and session.audiovisual != null:
		report["status"] = session.audiovisual.status()
	if recorder != null:
		recorder.set_recording_active(false)
		var wav := recorder.get_recording()
		check(wav != null and wav.data.size() > 0, "recorded PCM")
		if wav != null: check(wav.save_to_wav(output.path_join("effects-wire.wav")) == OK, "save PCM")
		AudioServer.remove_bus_effect(bus, AudioServer.get_bus_effect_count(bus)-1)
	if is_instance_valid(session): session.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	var file := FileAccess.open(output.path_join("native.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report,"  "))
	print("THREAT_WIRE_OK" if failures.is_empty() else "THREAT_WIRE_FAILED", " ", failures)
	quit(0 if failures.is_empty() else 1)
