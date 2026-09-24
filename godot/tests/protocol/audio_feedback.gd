extends SceneTree
## Audio feedback contract: the original bounded procedural cues, the invalid
## event policy, cooldowns/pool/mute lifecycle and the per-weapon weapon-oomph
## voices (layered crack/body/sub voices built from the source feel hints).
const Feedback = preload("res://world/audio_feedback.gd")
const Combat = preload("res://world/combat_feedback.gd")
var checks: int = 0
var voices: Array[Dictionary] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		quit(1)
		assert(ok, message)

func playing(feedback: Node, cue: String = "") -> int:
	var count: int = 0
	for voice: AudioStreamPlayer in feedback.get_children():
		if voice.playing and (cue.is_empty() or voice.stream == feedback._sounds.get(cue)): count += 1
	return count

func stats(sound: AudioStreamWAV) -> Dictionary:
	var peak: float = 0.0
	var square_sum: float = 0.0
	var crossings: int = 0
	var previous: float = 0.0
	var samples: int = sound.data.size() / 2
	for index: int in samples:
		var sample: float = sound.data.decode_s16(index * 2) / 32768.0
		peak = maxf(peak, absf(sample))
		square_sum += sample * sample
		if sample * previous < 0: crossings += 1
		previous = sample
	return {"peak":peak, "rms":sqrt(square_sum / maxi(1, samples)), "crossings":crossings, "samples":samples}

func _initialize() -> void:
	call_deferred("run")

func wait_for(condition: Callable, timeout_ms: int = 2000) -> bool:
	# Audio mixing uses its own clock/thread. A SceneTree timer does not prove
	# that Dummy playback has drained, especially on a contended hosted runner.
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return condition.call()

## Per-weapon distinctness: every weapon report/launch/impact band must differ
## from every other weapon in length, peak or RMS, the whole cache stays bounded
## and nothing exceeds the 0.65 peak contract.
func measure_weapons(feedback: Node) -> void:
	for weapon: int in 10:
		for cue: String in Feedback.WEAPON_CUES:
			var key: String = feedback._cue_key(cue, weapon)
			feedback._play_cue(cue, weapon)
			check(feedback._sounds.has(key), "per-weapon voice cached: " + key)
	feedback.clear_round()
	check(feedback._sounds.size() == 2 + 10 * Feedback.WEAPON_CUES.size(), "bounded per-weapon voice cache")
	var total_samples := 0
	for key: String in feedback._sounds:
		var sound: AudioStreamWAV = feedback._sounds[key]
		var data: Dictionary = stats(sound)
		total_samples += int(data.samples)
		check(sound.format == AudioStreamWAV.FORMAT_16_BITS and not sound.stereo and sound.mix_rate == 22050, "PCM format " + key)
		check(sound.data.decode_s16(0) == 0 and sound.data.decode_s16(sound.data.size() - 2) == 0, "zero-ended waveform " + key)
		check(float(data.peak) > 0.05 and float(data.peak) <= 0.65, "audible non-clipping source PCM " + key)
		check(sound.get_length() > 0.05 and sound.get_length() <= 0.52, "bounded cue length " + key)
		var weapon := -1
		if key.get_slice("/", 0) in Feedback.WEAPON_CUES:
			weapon = int(key.get_slice("/", 1))
			check(float(data.peak) >= 0.40, "weapon voice level " + key)
			if key.begins_with("shot/"):
				check(sound.get_length() > 0.10, "weapon report length " + key)
		else:
			check(sound.get_length() < 0.25, "short bounded base waveform " + key)
		voices.append({"cue":key, "weapon":weapon, "seconds":sound.get_length(), "peak":float(data.peak), "rms":float(data.rms), "zero_crossings":int(data.crossings)})
	check(total_samples < 400000, "bounded total cached PCM (%d samples)" % total_samples)
	var lengths := {}
	var peaks := {}
	var rms := {}
	for weapon: int in 10:
		var sound: AudioStreamWAV = feedback._sounds["shot/%d" % weapon]
		var data: Dictionary = stats(sound)
		lengths[snappedf(sound.get_length(), 0.001)] = true
		peaks[snappedf(float(data.peak), 0.005)] = true
		rms[snappedf(float(data.rms), 0.002)] = true
	check(lengths.size() >= 7, "ten weapon reports carry distinct lengths (%d)" % lengths.size())
	check(peaks.size() >= 7, "ten weapon reports carry distinct peaks (%d)" % peaks.size())
	check(rms.size() >= 8, "ten weapon reports carry distinct RMS bands (%d)" % rms.size())
	for a: int in 10:
		for b: int in range(a + 1, 10):
			var left: Dictionary = stats(feedback._sounds["shot/%d" % a])
			var right: Dictionary = stats(feedback._sounds["shot/%d" % b])
			var length_delta: float = absf(feedback._sounds["shot/%d" % a].get_length() - feedback._sounds["shot/%d" % b].get_length())
			var peak_delta: float = absf(float(left.peak) - float(right.peak))
			var rms_delta: float = absf(float(left.rms) - float(right.rms))
			check(length_delta > 0.004 or peak_delta > 0.004 or rms_delta > 0.004, "weapon reports differ %d vs %d" % [a, b])
	# Deterministic synthesis: the same request always produces identical PCM.
	var first: AudioStreamWAV = feedback._make_sound("shot", feedback._cue_seconds("shot", 7), 7)
	var second: AudioStreamWAV = feedback._make_sound("shot", feedback._cue_seconds("shot", 7), 7)
	check(first.data == second.data, "per-weapon synthesis is deterministic")
	check(feedback.synth_usec < 2000000, "bounded synthesis cost (%d usec)" % feedback.synth_usec)
	print("AUDIO_SYNTH ", JSON.stringify({"usec":feedback.synth_usec,"sounds":feedback._sounds.size(),"samples":total_samples,"voices":voices}))

func run() -> void:
	var feedback := Feedback.new()
	root.add_child(feedback)
	check(feedback.get_child_count() == Feedback.MAX_VOICES, "fixed voice pool")
	check(feedback._sounds.size() == Feedback.CUE_SECONDS.size(), "base cues cached at ready, weapon voices stay lazy")
	for cue: String in feedback._sounds:
		var sound: AudioStreamWAV = feedback._sounds[cue]
		var data := stats(sound)
		check(sound.format == AudioStreamWAV.FORMAT_16_BITS and not sound.stereo and sound.mix_rate == 22050, "PCM format")
		check(sound.get_length() > 0.05 and sound.get_length() < 0.25, "short bounded waveform")
		check(float(data.peak) > 0.05 and float(data.peak) <= 0.65, "audible non-clipping source PCM")
		check(sound.data.decode_s16(0) == 0 and sound.data.decode_s16(sound.data.size() - 2) == 0, "zero-ended waveform")
		print("PCM ", cue, " seconds=", sound.get_length(), " peak=", data.peak, " rms=", data.rms, " zero_crossings=", data.crossings)
	check(Feedback.MAX_VOICES * 0.65 * db_to_linear(Feedback.DEFAULT_VOLUME_DB) < 1.0, "conservative worst-case mix headroom")
	measure_weapons(feedback)
	# The actorless explosion stays the loud event cue and is rebuilt with the
	# weapon-oomph rumble body; it is longer than the original 0.3 s cue.
	feedback.apply_events([{"type":"explosion","pos":{"x":1,"y":0,"z":2}}], 0)
	check(playing(feedback, "explosion") == 1, "actorless authoritative explosion voices the new cue")
	var boom: AudioStreamWAV = feedback._sounds.explosion
	var boom_stats := stats(boom)
	check(boom.get_length() > 0.3 and boom.get_length() <= 0.5, "explosion cue is beefed and still bounded")
	check(float(boom_stats.peak) <= 0.65, "explosion stays under the peak contract")
	print("AUDIO_EXPLOSION ", JSON.stringify({"seconds":boom.get_length(),"peak":float(boom_stats.peak),"rms":float(boom_stats.rms)}))
	feedback.clear_round()
	var invalid: Array = [null, 0, "shot", {}, {"type":"shot"}, {"type":"shot","actor":null}, {"type":"shot","actor":false}, {"type":"shot","actor":"0"}, {"type":"shot","actor":0.5}, {"type":"shot","actor":INF}, {"type":"shot","actor":1}, {"type":"pickup","actor":1}, {"type":"damage","actor":1,"source":null,"amount":10}, {"type":"damage","actor":1,"source":"0","amount":10}, {"type":"damage","source":0,"amount":10}, {"type":"damage","actor":0,"amount":0}, {"type":"damage","actor":0,"amount":-1}, {"type":"damage","actor":0,"amount":"10"}, {"type":"damage","actor":0,"amount":NAN}]
	feedback.apply_events(invalid, 0)
	check(playing(feedback) == 0, "invalid and remote events are silent; null source is not actor zero")
	feedback.apply_events([{"type":"shot","actor":0,"hit":1}], -1)
	check(playing(feedback) == 0, "unassigned local identity is silent")
	feedback.apply_events([{"type":"shot","actor":0.0,"hit":1}], 0)
	check(playing(feedback, "shot/0") == 1 and playing(feedback, "hit/0") == 0, "shot never predicts confirmed hit")
	feedback.apply_events([{"type":"damage","actor":1.0,"source":0.0,"amount":2}], 0)
	check(playing(feedback, "hit/0") == 1, "positive authoritative local damage confirms hit with the last local weapon")
	# A weapon-carrying shot switches the confirmation timbre to that weapon.
	feedback.clear_round()
	feedback.apply_events([{"type":"shot","actor":0,"weapon":3}], 0)
	check(playing(feedback, "shot/3") == 1, "weapon-carrying shot voices the per-weapon report")
	feedback.apply_events([{"type":"damage","actor":1,"source":0,"amount":2}], 0)
	check(playing(feedback, "hit/3") == 1, "confirmation follows the last local weapon")
	feedback.clear_round()
	feedback.apply_events([{"type":"damage","actor":0,"source":null,"amount":2}], 0)
	feedback.apply_events([{"type":"pickup","actor":0}], 0)
	check(playing(feedback, "hurt") == 1 and playing(feedback, "pickup") == 1, "environmental hurt and local pickup cues")
	var burst_started := Time.get_ticks_usec()
	var cooldowns_valid := true
	var pool_bounded := true
	var accepted_retriggers := 0
	for index: int in range(100):
		var previous_starts: Dictionary = feedback._last_play_usec.duplicate()
		feedback.apply_events([{"type":"shot","actor":0},{"type":"damage","actor":1,"source":0,"amount":2},{"type":"damage","actor":0,"amount":2},{"type":"pickup","actor":0}], 0)
		for cue: String in previous_starts:
			var interval: int = feedback._last_play_usec[cue] - previous_starts[cue]
			if interval != 0:
				accepted_retriggers += 1
				cooldowns_valid = cooldowns_valid and interval >= int(Feedback.INTERVAL_USEC[cue])
		pool_bounded = pool_bounded and playing(feedback) <= Feedback.MAX_VOICES and feedback.get_child_count() == Feedback.MAX_VOICES
		# Optional scheduler-stall reproduction keeps production audio clocks real.
		if "--audio-burst-stalls" in OS.get_cmdline_user_args() and index % 20 == 0: OS.delay_msec(100)
	# Audio runs on its own thread. Cues may end or legitimately retrigger while
	# a hosted runner is descheduled; an exact surviving-voice count is not a cap.
	check(cooldowns_valid and pool_bounded, "event burst respects every monotonic cue interval and the fixed voice cap")
	print("AUDIO_BURST elapsed_usec=", Time.get_ticks_usec() - burst_started, " accepted_retriggers=", accepted_retriggers, " voices_remaining=", playing(feedback))
	check(await wait_for(func() -> bool:
		return playing(feedback, "shot/0") == 0 and Time.get_ticks_usec() - int(feedback._last_play_usec.shot) >= int(Feedback.INTERVAL_USEC.shot)
	), "original shot naturally ends and real monotonic cooldown expires within two seconds")
	feedback.apply_events([{"type":"shot","actor":0}], 0)
	check(playing(feedback, "shot/0") == 1, "shot available again after original ends and monotonic cooldown")
	feedback.clear_round()
	check(playing(feedback) == 0, "clear_round stops all voices immediately")
	feedback.apply_events([{"type":"damage","actor":0,"source":0,"amount":2}], 0)
	check(playing(feedback, "hurt") == 1 and playing(feedback, "hit/0") == 0, "self damage hurts without confirming hit; reset clears cooldown")
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
	check(playing(feedback) == 8 and playing(feedback, "shot/0") == 0, "saturated pool drops new cue without allocation or stealing")
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
