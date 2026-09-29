extends SceneTree
const Music = preload("res://audio/music_service.gd")
const Buses = preload("res://audio/buses.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Buses.ensure()
	var score := Music.new()
	root.add_child(score)
	assert(score.samples.size() == 37 and score.takes.size() == 12 and score.streams.size() == 73, "actual packaged Ogg/WAV resources imported")
	assert(score.load_failures == 0)
	assert(score.players.size() == 19 and score.announcer_player != null)
	score.set_settings({"music_enabled":true,"announcer_enabled":true,"music_volume":100,"announcer_volume":100,"mute":false})
	score.start()
	var profiles := ["menu","explore","combat","results"]
	for scene: String in profiles:
		score.set_scene(scene)
		var actual: Array = Music.PROGRESSIONS[scene]
		assert(actual.size() == 8 and Music.QUALITIES[scene].size() == 8)
	for mode: String in ["deathmatch","teamdeathmatch","instagib","rockets","arsenal","armsrace","team-elimination","combined-arms","ctf","koth","domination","assault","payload","holdout","uplink","vip-escort","horde","juggernaut","campaign","cocs","cocs-coop","puma-race","puma-soccer"]:
		assert(Music.PALETTES.has(mode), "source-authored mode palette missing: " + mode)
		score.set_mode_theme(mode)
		assert(score._palette().size() == 4)
	score.set_scene("combat")
	score.set_variation(42)
	var hashes_a := []
	for bar in 32:
		score.form_bar = bar
		hashes_a.append(score._hash(31) % 5)
		assert(score._section() == ("intro" if bar < 8 else "build" if bar < 16 else "climax" if bar < 24 else "transition" if bar < 28 else "outro"))
	score.set_variation(137)
	var hashes_b := []
	for bar in 32:
		score.form_bar = bar
		hashes_b.append(score._hash(31) % 5)
	assert(hashes_a != hashes_b, "seeded ornaments need an actual distinct 32-bar performance")
	for level in [0,1,2,3]:
		score.set_escalation(level)
		var seen := {}
		for bar in 32:
			score.form_bar = bar
			seen[score._section()] = true
		assert(seen.size() == 5, "each escalation retains all form sections")
	score.set_escalation(0)
	score.form_bar = 0
	score.step = 0
	score._step_music()
	assert(score.status().active_voices > 0, "first bar plays imported instruments")
	assert(score.cue("objective"), "existing recorded take plays")
	assert(score.announcer_player.playing)
	score.set_settings({"mute":true,"music_enabled":true,"announcer_enabled":true,"music_volume":100,"announcer_volume":100})
	assert(score.status().active_voices == 0 and not score.announcer_player.playing, "mute drains active audio")
	print("AUDIO_SCORE_FORM_OK samples=",score.samples.size()," bytes=",score.status().asset_bytes)
	score.free()
	await create_timer(0.25).timeout
	quit(0)
