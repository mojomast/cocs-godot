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
		# Synthetic decoder fixture: model an already queued create request.
		client.career_welcome_pending = true
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
		var snapshot_count: int = client.snapshots.size()
		check(client.decode_text(JSON.stringify({"type":"snapshot", "seq":2,"acks":{"0":2},"state":state,
			"inputEpoch":1,"nativeArenaInput":status})), "duplicate snapshot accepted as a no-op")
		check(client.decode_text(JSON.stringify({"type":"snapshot", "seq":1,"acks":{"0":2},"state":state,
			"inputEpoch":1,"nativeArenaInput":status})), "reordered snapshot accepted as a no-op")
		check(client.snapshots.size() == snapshot_count and client.last_snapshot_seq == 2,
			"duplicate/reordered snapshots neither append nor advance the high-water mark")
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
			check(client.error == "Native arena input epoch regressed", "regressed epoch keeps its exact message")
		client.free()
		# Malformed / oversized envelope, then same-batch lifecycle + events, on
		# fresh decoders of the same class.
		var guard: Node = script.new()
		guard.allowlist = {"prism-foundry":{"modes":["deathmatch"]}}
		guard.requested_map = "prism-foundry"
		check(not guard.decode_text("{ not json"), "malformed JSON envelope refused")
		check(guard.error == "Malformed JSON envelope", "malformed JSON keeps the base message")
		check(not guard.decode_text(JSON.stringify([1, 2, 3])), "non-object envelope refused")
		check(guard.error == "Malformed JSON envelope", "non-object envelope keeps the base message")
		check(not guard.decode_text("x".repeat(guard.MAX_FRAME_BYTES + 1)), "oversized frame refused")
		check(guard.error == "Oversized frame", "oversized frame keeps its exact chain message")
		guard.free()
		var batch: Node = script.new()
		batch.allowlist = {"prism-foundry":{"modes":["deathmatch"]}}
		batch.requested_map = "prism-foundry"
		var batch_events: Array = []
		batch.events.connect(func(items: Array) -> void: batch_events.append_array(items))
		var batch_results := [0]
		batch.results.connect(func(_frame: Dictionary) -> void: batch_results[0] += 1)
		check(batch.decode_text('{"type":"start","mapId":"prism-foundry","inputEpoch":1}'), "same-batch start accepted")
		check(batch.decode_text('{"type":"events","items":[{"id":"e1","type":"traversal"}]}'), "same-batch event accepted")
		check(batch.event_order == ["e1"] and batch_events.size() == 1, "same-batch event delivered once")
		check(batch.decode_text('{"type":"results","inputEpoch":1,"state":{"mapId":"prism-foundry"}}'), "same-batch lifecycle accepted")
		check(batch.round_finished and batch_results[0] == 1, "same-batch lifecycle latches and emits once")
		check(batch.decode_text('{"type":"events","items":[{"id":"e2","type":"traversal"}]}'), "post-lifecycle event frame tolerated")
		check(batch_events.size() == 1 and not batch.event_order.has("e2"), "same-batch lifecycle suppresses later events")
		batch.free()
	print("NATIVE_ARENA_PROTOCOL ", JSON.stringify({"synthetic":true,"ok":failures == 0,"failures":failures}))
	quit(0 if failures == 0 else 1)
