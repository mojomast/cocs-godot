extends SceneTree
## Bounded long-round semantic/resource probe; audible mix has its own probe.
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
	audio.apply_settings({"mute":false,"effects_volume":50,"music_enabled":true,"music_volume":70,
		"announcer_enabled":false,"ambience_enabled":true,"ambience_volume":60,"weather_quality":50})
	audio.bind_session(host, eye, {"id":"frost-gate","biome":"snow"}, "horde", "room:42", 42)
	audio.start_round("room:42")
	var state := {"time":1.0,"actors":[{"id":0,"team":0,"health":100,"maxHealth":100,"vehicleId":null,"x":0.0,"z":0.0}],
		"vehicles":[],"config":{"mode":"horde","timeLimit":900},"singleplayer":{"weather":"snow"}}
	audio.apply_snapshot(state, 0)
	for batch in 32:
		var events := []
		for i in 256:
			var id := batch * 256 + i + 1
			events.append({"id":id,"type":"horde-wave" if id % 17 == 0 else "zone-progress",
				"zone":"zone-%d" % (id % 96),"progress":id % 100,"team":0,"time":float(id) * 0.05})
		audio.apply_events(events)
		state.time = 1.0 + float(batch)
		audio.apply_snapshot(state, 0)
		audio.tick(0.1)
	var status: Dictionary = audio.status()
	assert(status.routing.remembered_events <= 4096 and status.routing.zones <= 64)
	assert(status.music.active_voices <= 19 and status.vehicle.voices <= 4 and status.motifs.active_voices <= 4)
	assert(status.weather.particles <= 48 and status.weather.particle_limit == 48)
	assert(status.music.loaded_streams == 73 and status.music.loaded_failures == 0)
	var remembered := status.routing.remembered_events
	audio.start_round("room:42")
	assert(audio.status().routing.remembered_events == remembered)
	audio.apply_settings({"mute":true,"music_enabled":true,"announcer_enabled":true,"ambience_enabled":true})
	audio.apply_events([{"id":10001,"type":"boss-phase","time":35.0}])
	assert(audio.status().routing.remembered_events <= 4096 and not audio.status().music.announcer_active)
	audio.start_round("room:43")
	assert(audio.status().routing.remembered_events == 0)
	print("AUDIO_SOAK_OK ids=",remembered," streams=",status.music.loaded_streams)
	quit(0)
