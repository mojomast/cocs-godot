extends SceneTree

const Feedback = preload("res://world/audio_feedback.gd")
const Combat = preload("res://world/combat_feedback.gd")
var checks: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		quit(1)
		assert(ok, message)

func playing(feedback: Node, cue: String = "") -> int:
	var count: int = 0
	for voice: AudioStreamPlayer in feedback.get_children():
		if voice.playing and (cue.is_empty() or voice.stream == feedback._sounds[cue]): count += 1
	return count

func _initialize() -> void:
	call_deferred("run")

func wait_for(condition: Callable, timeout_ms: int = 2000) -> bool:
	# Audio mixing uses its own clock/thread. A SceneTree timer does not prove
	# that Dummy playback has drained, especially on a contended hosted runner.
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return condition.call()

func run() -> void:
	var feedback := Feedback.new()
	root.add_child(feedback)
	check(feedback.get_child_count() == Feedback.MAX_VOICES, "fixed voice pool")
	check(feedback._sounds.size() == 4, "four cached original waveforms")
	for cue: String in feedback._sounds:
		var sound: AudioStreamWAV = feedback._sounds[cue]
		var peak: float = 0.0
		var square_sum: float = 0.0
		var crossings: int = 0
		var previous: float = 0.0
		for index: int in range(sound.data.size() / 2):
			var sample: float = sound.data.decode_s16(index * 2) / 32768.0
			peak = maxf(peak, absf(sample))
			square_sum += sample * sample
			if sample * previous < 0: crossings += 1
			previous = sample
		check(sound.format == AudioStreamWAV.FORMAT_16_BITS and not sound.stereo and sound.mix_rate == 22050, "PCM format")
		check(sound.get_length() > 0.05 and sound.get_length() < 0.25, "short bounded waveform")
		check(peak > 0.05 and peak <= 0.65, "audible non-clipping source PCM")
		check(sound.data.decode_s16(0) == 0 and sound.data.decode_s16(sound.data.size() - 2) == 0, "zero-ended waveform")
		print("PCM ", cue, " seconds=", sound.get_length(), " peak=", peak, " rms=", sqrt(square_sum / (sound.data.size() / 2)), " zero_crossings=", crossings)
	check(Feedback.MAX_VOICES * 0.65 * db_to_linear(Feedback.DEFAULT_VOLUME_DB) < 1.0, "conservative worst-case mix headroom")
	var invalid: Array = [null, 0, "shot", {}, {"type":"shot"}, {"type":"shot","actor":null}, {"type":"shot","actor":false}, {"type":"shot","actor":"0"}, {"type":"shot","actor":0.5}, {"type":"shot","actor":INF}, {"type":"shot","actor":1}, {"type":"pickup","actor":1}, {"type":"damage","actor":1,"source":null,"amount":10}, {"type":"damage","actor":1,"source":"0","amount":10}, {"type":"damage","source":0,"amount":10}, {"type":"damage","actor":0,"amount":0}, {"type":"damage","actor":0,"amount":-1}, {"type":"damage","actor":0,"amount":"10"}, {"type":"damage","actor":0,"amount":NAN}]
	feedback.apply_events(invalid, 0)
	check(playing(feedback) == 0, "invalid and remote events are silent; null source is not actor zero")
	feedback.apply_events([{"type":"shot","actor":0,"hit":1}], -1)
	check(playing(feedback) == 0, "unassigned local identity is silent")
	feedback.apply_events([{"type":"shot","actor":0.0,"hit":1}], 0)
	check(playing(feedback, "shot") == 1 and playing(feedback, "hit") == 0, "shot never predicts confirmed hit")
	feedback.apply_events([{"type":"damage","actor":1.0,"source":0.0,"amount":2}], 0)
	check(playing(feedback, "hit") == 1, "positive authoritative local damage confirms hit")
	feedback.apply_events([{"type":"damage","actor":0,"source":null,"amount":2}], 0)
	feedback.apply_events([{"type":"pickup","actor":0}], 0)
	check(playing(feedback, "hurt") == 1 and playing(feedback, "pickup") == 1, "environmental hurt and local pickup cues")
	for index: int in range(100):
		feedback.apply_events([{"type":"shot","actor":0},{"type":"damage","actor":1,"source":0,"amount":2},{"type":"damage","actor":0,"amount":2},{"type":"pickup","actor":0}], 0)
	check(playing(feedback) == 4 and feedback.get_child_count() == 8, "event burst rate caps preserve bounded mix")
	check(await wait_for(func() -> bool:
		return playing(feedback, "shot") == 0 and Time.get_ticks_usec() - int(feedback._last_play_usec.shot) >= int(Feedback.INTERVAL_USEC.shot)
	), "original shot naturally ends and real monotonic cooldown expires within two seconds")
	feedback.apply_events([{"type":"shot","actor":0}], 0)
	check(playing(feedback, "shot") == 1, "shot available again after original ends and monotonic cooldown")
	feedback.clear_round()
	check(playing(feedback) == 0, "clear_round stops all voices immediately")
	feedback.apply_events([{"type":"damage","actor":0,"source":0,"amount":2}], 0)
	check(playing(feedback, "hurt") == 1 and playing(feedback, "hit") == 0, "self damage hurts without confirming hit; reset clears cooldown")
	feedback.set_muted(true)
	feedback.apply_events([{"type":"shot","actor":0}], 0)
	check(playing(feedback) == 0, "mute stops active voices and blocks new events")
	feedback.clear_round()
	feedback.apply_events([{"type":"pickup","actor":0}], 0)
	check(playing(feedback) == 0, "round clear retains mute preference")
	feedback.set_muted(false)
	feedback.apply_events([{"type":"pickup","actor":0}], 0)
	check(playing(feedback, "pickup") == 1, "unmute resumes feedback")
	check(await wait_for(func() -> bool: return playing(feedback) == 0), "one-shot playback naturally finishes with Dummy driver within two seconds")
	for voice: AudioStreamPlayer in feedback.get_children():
		voice.stream = feedback._sounds.pickup
		voice.play()
	feedback.apply_events([{"type":"shot","actor":0}], 0)
	check(playing(feedback) == 8 and playing(feedback, "shot") == 0, "saturated pool drops new cue without allocation or stealing")
	var reference: WeakRef = weakref(feedback.get_child(0))
	feedback.free()
	check(reference.get_ref() == null, "free releases owned players during active playback")
	var combat := Combat.new()
	root.add_child(combat)
	combat.apply_events([{"type":"pickup","actor":0}], 0)
	check(playing(combat.audio_feedback, "pickup") == 1, "attached combat forwards authoritative pickup to audio")
	combat.clear_round()
	check(playing(combat.audio_feedback) == 0, "combat round reset stops audio")
	combat.audio_feedback.set_muted(true)
	combat.apply_events([{"type":"damage","actor":0,"source":null,"amount":5}], 0)
	check(combat.hurts == 1 and playing(combat.audio_feedback) == 0, "mute preserves non-audio feedback")
	combat.free()
	# AudioServer releases stopped playback references on its next mix iteration.
	await create_timer(0.1).timeout
	print("PORT_AUDIO_FEEDBACK_OK checks=", checks)
	quit(0)
