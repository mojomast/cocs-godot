extends SceneTree
## Exercises the production sports/combined-arms adapter without a server.
const Lifecycle = preload("res://sports/av_lifecycle.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var camera := Camera3D.new()
	host.add_child(camera)
	var lane := Lifecycle.new()
	host.add_child(lane)
	lane.configure(host, camera, {"id":"puma-pitch","biome":"urban"}, "puma-soccer", "ws://localhost:1")
	lane.begin({"roundRevision":7}, "public-room")
	var state := {"time":2.0,"over":false,"config":{"mode":"puma-soccer","timeLimit":90},
		"actors":[{"id":5,"team":1,"health":100,"maxHealth":100,"vehicleId":null,"x":0.0,"z":0.0}],
		"vehicles":[],"race":{"phase":"kickoff","countdown":3}}
	lane.snapshot(state, 5)
	assert(lane.service.countdown_beat == 3)
	state.race = {"phase":"playing","countdown":0}
	lane.snapshot(state, 5)
	assert(lane.service.countdown_phase == "playing", "GO from observed countdown only")
	lane.events([{"id":1,"type":"goal","actor":5}])
	assert(lane.service.status().routing.remembered_events == 1)
	lane.advance(0.016, false, true, false)
	assert(lane.service.status().suspension_reason == "stale_snapshot")
	lane.events([{"id":2,"type":"goal","actor":5}])
	assert(lane.service.status().routing.remembered_events == 2, "stale event consumed, not queued")
	lane.snapshot(state, 5)
	lane.advance(0.016, true, true, false)
	lane.finish({"time":91.0,"over":true,"winner":1,"race":{"winnerTeam":1},"actors":state.actors}, 5)
	assert(lane.service.status().music.outcome == "victory")
	lane.begin({"roundRevision":7}, "public-room")
	assert(lane.service.status().routing.remembered_events == 2, "same-room/revision reconnect preserves latches")
	lane.begin({"roundRevision":8}, "public-room")
	assert(lane.service.status().routing.remembered_events == 0)
	print("AUDIO_STANDALONE_LIFECYCLE_OK")
	lane.service.suspend("fixture_cleanup")
	host.free()
	await create_timer(0.25).timeout
	quit(0)
