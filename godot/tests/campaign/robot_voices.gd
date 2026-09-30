extends SceneTree
const Voices = preload("res://campaign/robot_voices.gd")
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func actor(id: int = 1, model: String = "scrapper", health: float = 100) -> Dictionary:
	return {"id":id, "npcModel":model, "health":health, "x":0, "y":0, "z":-5}

func state(time: float, items: Array, step: int = -1) -> Dictionary:
	return {"time":time, "actors":items, "campaign":{"phase":"playing", "stepIndex":step, "enemiesRemaining":items.size()}}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var voices := Voices.new()
	root.add_child(voices)
	voices.apply_settings({"mute":false,"effects_volume":100})
	check(voices.cache.size() == 48 and voices.players.size() == 2, "bounded pre-baked cache and two spatial players")
	var signatures: Dictionary = {}
	var envelopes: Dictionary = {}
	for model: String in Voices.MODELS:
		for kind: String in Voices.KINDS:
			for variation: int in 2:
				var key := "%s_%s_%d" % [model, kind, variation]
				var sound: AudioStreamWAV = voices.cache[key]
				check(sound != null, "asset closure " + key)
				if sound == null: continue
				check(sound.mix_rate == 22050 and not sound.stereo and sound.format == AudioStreamWAV.FORMAT_16_BITS, "mono PCM format " + key)
				var pcm: PackedByteArray = sound.data
				var peak := 0
				var energy := 0.0
				var bins: Array[float] = []
				bins.resize(12)
				bins.fill(0.0)
				for index: int in int(pcm.size() / 2):
					var sample := pcm.decode_s16(index * 2)
					peak = maxi(peak, absi(sample))
					energy += float(sample) * sample
					bins[mini(11, int(index * 24.0 / pcm.size()))] += float(sample) * sample
				check(peak <= 22282 and peak > 10000 and energy > 0, "non-silent bounded peak " + key)
				var hash_value := hash(pcm)
				check(not signatures.has(hash_value), "distinct waveform " + key)
				signatures[hash_value] = true
				if kind == "encounter" and variation == 0:
					for index: int in bins.size(): bins[index] /= energy
					envelopes[model] = bins
	# Compare time-normalized energy contours: six pitch shifts of one beep
	# would have almost identical envelopes and would fail this test.
	for a: int in Voices.MODELS.size():
		for b: int in range(a + 1, Voices.MODELS.size()):
			var difference := 0.0
			for index: int in 12:
				difference += absf(envelopes[Voices.MODELS[a]][index] - envelopes[Voices.MODELS[b]][index])
			check(difference > 0.12, "distinct syllabic envelope %s/%s" % [Voices.MODELS[a], Voices.MODELS[b]])
	voices.set_active(true)
	voices.apply_state(state(1, [actor()]), Vector3.ZERO)
	check(voices.played == 0, "actor creation alone cannot claim spotting")
	voices.apply_state(state(2, [actor()], 0), Vector3.ZERO)
	check(voices.played == 1, "one received encounter activation")
	voices.apply_state(state(2, [actor(1, "scrapper", 50)], 0), Vector3.ZERO)
	voices.apply_state(state(1, [actor(1, "scrapper", 50)], 0), Vector3.ZERO)
	check(voices.played == 1, "equal/older snapshots cannot replay transitions")
	voices.apply_state(state(6, [actor(), actor(2)], 0), Vector3.ZERO)
	check(voices.played == 1, "new actors do not spam an existing encounter")
	voices.apply_state(state(7, [actor(1, "scrapper", 80)], 0), Vector3.ZERO)
	check(voices.played == 2, "confirmed health loss produces hurt")
	voices.apply_state(state(7.1, [actor(1, "scrapper", 60)], 0), Vector3.ZERO)
	check(voices.played == 2, "actor cooldown bounds repeated damage")
	voices.apply_state(state(11, [actor(1, "scrapper", 0)], 0), Vector3.ZERO)
	check(voices.played == 3, "confirmed live-to-dead transition produces death")
	voices.apply_state(state(16, [actor(1, "scrapper", 0)], 0), Vector3.ZERO)
	check(voices.played == 3, "corpse cannot vocalize repeatedly")
	voices.clear_round()
	voices.set_active(true)
	var preparing := actor(3, "mortar")
	voices.apply_state(state(1, [preparing]), Vector3.ZERO)
	preparing.artilleryWindup = 1.2
	voices.apply_state(state(2, [preparing]), Vector3.ZERO)
	check(voices.played == 4, "received windup edge produces attack preparation")
	preparing.artilleryWindup = .9
	voices.apply_state(state(3, [preparing]), Vector3.ZERO)
	check(voices.played == 4, "remaining windup countdown is not a new attack")
	voices.clear_round()
	voices.set_active(true)
	var far := actor()
	far.x = 100
	check(not voices.request(far, "hurt", 1), "out-of-range voice culled")
	check(not voices.request(actor(1, "scrapper", 0), "attack", 1), "dead actor cannot taunt")
	check(voices.request(actor(), "encounter", 1), "pool admits first voice")
	check(not voices.request(actor(2, "sentinel"), "encounter", 1.1), "global voice spacing")
	check(not voices.request(actor(2), "encounter", 1.8), "per-class voice spacing")
	check(voices.request(actor(3, "warden"), "attack", 1.1), "boss bypasses global spacing with priority")
	check(voices.players.size() == 2, "boss priority never grows pool")
	voices.apply_settings({"mute":true})
	check(not voices.players[0].playing and not voices.players[1].playing, "mute stops all active voices immediately")
	check(not voices.request(actor(), "hurt", 10), "mute rejects playback")
	voices.apply_settings({"effects_volume":0})
	check(not voices.request(actor(), "hurt", 11), "SFX slider zero rejects playback")
	voices.apply_settings({"mute":false,"effects_volume":100})
	voices.set_active(false)
	voices.apply_state(state(20, [actor()]), Vector3.ZERO)
	voices.set_active(true)
	var before := voices.played
	voices.apply_state(state(21, [actor(1, "scrapper", 20)]), Vector3.ZERO)
	check(voices.played == before, "focus/stale resume drains first transition instead of replaying")
	voices.clear_round()
	check(voices.actors.is_empty() and voices.encounters.is_empty() and voices.actor_cooldown.is_empty(), "epoch clears state and cooldowns")
	voices.set_active(true)
	voices.apply_state(state(1, [actor()], 0), Vector3.ZERO)
	check(voices.played == before + 1, "retry allows reused actor IDs and encounter index")
	voices.clear_round()
	voices.set_active(true)
	check(voices.request(actor(4, "mortar"), "encounter", 1), "long first voice admitted")
	check(voices.request(actor(5, "sentinel"), "encounter", 1.66), "second voice overlaps within bounded pool")
	check(voices.request(actor(6, "warden"), "encounter", 1.7) and 6 in voices.owners, "boss preempts lower priority when both slots are occupied")
	voices.apply_state({"time":2,"actors":[actor(6, "warden")],"campaign":{"phase":"dead"}}, Vector3.ZERO)
	check(not voices.enabled and not voices.players[0].playing and not voices.players[1].playing, "terminal campaign phase stops every voice")
	for player: AudioStreamPlayer3D in voices.players:
		check(player.bus == &"Effects" and player.max_distance == 42, "spatial effects routing and attenuation")
	var weak_player := weakref(voices.players[0])
	voices.free()
	check(weak_player.get_ref() == null, "service teardown frees owned spatial players")
	print("ROBOT_VOICES ", checks, " checks; ", failures, " failures")
	quit(1 if failures else 0)
