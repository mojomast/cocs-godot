extends SceneTree
## SYNTHETIC wire decoder fixture, not live gameplay or geometry acceptance.
const Client = preload("res://native_arenas/client.gd")
const OrdinaryClient = preload("res://net/client.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func _initialize() -> void:
	for script: Script in [Client, OrdinaryClient]:
		var client: Node = script.new()
		client.allowlist = {"prism-foundry":{"modes":["deathmatch"]}}
		client.requested_map = "prism-foundry"
		check(client.decode_text(JSON.stringify({"type":"welcome", "v":3, "roomId":"local-native-arena", "peerId":0})), "welcome")
		check(client.decode_text(JSON.stringify({"type":"lobby", "mapId":"prism-foundry", "config":{"mode":"deathmatch"},
			"players":[{"peerId":0,"actorId":0}]})), "lobby")
		check(client.actor_id == 0, "local actor assignment")
		check(client.decode_text(JSON.stringify({"type":"start", "mapId":"prism-foundry", "inputEpoch":1})), "start")
		var status := {"receivedSeq":1,"appliedSeq":1,"cancelledThrough":0,"queueDepth":0}
		var state := {"mapId":"prism-foundry","actors":[{"id":0,"ads":true}]}
		check(client.decode_text(JSON.stringify({"type":"snapshot", "seq":1,"acks":{"0":1},"state":state,
			"inputEpoch":1,"nativeArenaInput":status})), "snapshot")
		check(client.snapshots[-1].state.actors[0].ads == true, "source ADS true retained")
		state.actors[0].ads = false
		check(client.decode_text(JSON.stringify({"type":"snapshot", "seq":2,"acks":{"0":2},"state":state,
			"inputEpoch":1,"nativeArenaInput":status})), "release snapshot")
		check(client.snapshots[-1].state.actors[0].ads == false, "source ADS false retained")
		var events := {"type":"events","items":[{"id":1,"sourceId":"pad-a","type":"traversal"},{"id":2,"sourceId":"pad-a","type":"traversal"}]}
		check(client.decode_text(JSON.stringify(events)), "events")
		check(client.decode_text(JSON.stringify(events)), "duplicate events")
		check(client.event_order.size() == 2, "wire IDs deduplicate without collapsing source payload IDs")
		check(client.decode_text(JSON.stringify({"type":"results","state":state,"inputEpoch":1,"nativeArenaInput":status})), "results")
		check(client.round_finished, "result boundary")
		check(client.decode_text(JSON.stringify({"type":"start","mapId":"prism-foundry","inputEpoch":2})), "restart")
		check(client.event_order.is_empty() and client.snapshots.is_empty() and client.last_ack == 0, "restart clears history")
		if script == Client:
			check(client.decode_text(JSON.stringify({"type":"native-arena-input-reset","inputEpoch":3,"reason":"death"})), "death boundary")
			check(client.input_epoch == 3, "epoch increments")
			check(not client.decode_text(JSON.stringify({"type":"native-arena-input-reset","inputEpoch":2})), "regressed epoch rejected")
		client.free()
	print("NATIVE_ARENA_PROTOCOL ", JSON.stringify({"synthetic":true,"ok":failures == 0,"failures":failures}))
	quit(0 if failures == 0 else 1)
