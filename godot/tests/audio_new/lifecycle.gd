extends SceneTree
const Service = preload("res://audio/av_service.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var eye := Camera3D.new()
	host.add_child(eye)
	var audio := Service.new()
	host.add_child(audio)
	audio.apply_settings({"music_enabled":true,"music_volume":80,"announcer_enabled":true,"announcer_volume":75,
		"effects_volume":60,"ambience_enabled":true,"ambience_volume":40,"weather_enabled":true,"weather_quality":60,
		"lightning_flashes":true,"reduced_motion":false,"mute":false})
	audio.bind_session(host, eye, {"id":"frost-gate","biome":"snow","sky":"day"}, "ctf", "room:7", 912)
	audio.start_round("room:7")
	var actor := {"id":7,"x":0.0,"z":0.0,"health":100,"maxHealth":100,"team":0,"vehicleId":null}
	var state := {"time":5.0,"over":false,"config":{"mode":"ctf","timeLimit":300},"actors":[actor],"vehicles":[],"singleplayer":{"weather":"snow"}}
	audio.apply_events([{"id":1,"type":"cocs-depot-purchase","team":1}]) # unknown seat: consumed, not replayed
	audio.apply_snapshot(state, 7)
	audio.apply_events([{"id":2,"type":"flag-pickup","actor":7}])
	assert(audio.status().routing.remembered_events == 2)
	audio.apply_settings({"mute":true,"music_enabled":true,"announcer_enabled":true,"ambience_enabled":true})
	audio.apply_events([{"id":3,"type":"flag-return"}])
	assert(audio.status().routing.remembered_events == 3, "muted events consumed and discarded")
	audio.apply_settings({"mute":false,"music_enabled":true,"announcer_enabled":true,"ambience_enabled":true})
	audio.start_round("room:7")
	assert(audio.status().routing.remembered_events == 3, "same-round reconnect does not clear IDs")
	audio.apply_events([{"id":3,"type":"flag-return"}])
	assert(audio.status().routing.dropped_duplicate >= 1)
	audio.start_round("room:8")
	assert(audio.status().routing.remembered_events == 0)
	audio.apply_snapshot(state, 7)
	audio.finish_state({"time":301,"over":true,"winner":0,"actors":[actor],"config":{"mode":"ctf"}}, 7, "ctf")
	assert(audio.status().current_scene == "results" and audio.status().music.outcome == "victory")
	audio.apply_snapshot(state, 7)
	assert(audio.status().current_scene == "results", "combat polling cannot override final music")
	print("AUDIO_LIFECYCLE_OK")
	audio.suspend("fixture_cleanup")
	host.free()
	await create_timer(0.25).timeout
	quit()
