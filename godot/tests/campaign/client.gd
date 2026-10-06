extends SceneTree
const Client = preload("res://campaign/client.gd")

class RecordingClient extends "res://campaign/client.gd":
	var sent: Array = []
	func send_frame(frame: Dictionary) -> Error:
		sent.append(frame.duplicate(true))
		return OK

func _initialize() -> void:
	var client := RecordingClient.new()
	client.allowlist = {"rootfall-verge":{"modes":["campaign"], "geometryHash":"one"}, "siltwake-crossing":{"modes":["campaign"], "geometryHash":"two"}}
	client.requested_map = "rootfall-verge"
	assert(client.create_room() == OK and client.sent.back().nativeArenaInput == 1)
	assert(client.campaign_action("retry") == ERR_UNAUTHORIZED)
	assert(client.decode_text(JSON.stringify({"type":"start", "mapId":"rootfall-verge", "geometryHash":"one", "inputEpoch":1})))
	assert(client.send_controls({"fire":true}) == OK)
	assert(client.sent.back().inputEpoch == 1 and client.sent.back().seq == 1)
	assert(client.send_controls({}, true) == OK and client.sent.back().cancel)
	assert(client.decode_text(JSON.stringify({"type":"snapshot", "seq":1, "inputEpoch":2, "state":{"mapId":"rootfall-verge", "campaign":{"mapId":"rootfall-verge", "phase":"dead"}}})))
	assert(client.campaign_action("retry") == OK and client.sent.back().action == "retry")
	assert(client.campaign_action("retry") == ERR_UNAUTHORIZED, "duplicate action refused")
	assert(client.campaign_action("skip") == ERR_UNAUTHORIZED)
	assert(client.decode_text(JSON.stringify({"type":"start", "mapId":"rootfall-verge", "geometryHash":"one", "inputEpoch":3})))
	assert(not client.action_pending and not client.round_finished)
	assert(client.decode_text(JSON.stringify({"type":"results", "inputEpoch":4, "state":{"mapId":"rootfall-verge", "campaign":{"mapId":"rootfall-verge", "phase":"level-complete", "nextMapId":"siltwake-crossing"}}})))
	assert(client.expected_next == "siltwake-crossing")
	assert(client.campaign_action("continue") == OK)
	assert(client.campaign_action("continue") == ERR_UNAUTHORIZED)
	assert(client.decode_text(JSON.stringify({"type":"start", "mapId":"siltwake-crossing", "geometryHash":"two", "inputEpoch":5})))
	assert(client.requested_map == "siltwake-crossing" and client.input_seq == 0 and client.input_epoch == 5 and not client.round_finished)
	assert(not client.decode_text(JSON.stringify({"type":"start", "mapId":"rootfall-verge", "geometryHash":"one", "inputEpoch":6})), "backward chapter substitution refused")
	client.free()
	for bad: Dictionary in [{"inputEpoch":1,"geometryHash":"one"}, {"inputEpoch":2,"geometryHash":"wrong"}]:
		var probe := RecordingClient.new()
		probe.allowlist = {"rootfall-verge":{"geometryHash":"one"}}
		probe.requested_map = "rootfall-verge"
		assert(probe.decode_text(JSON.stringify({"type":"start","mapId":"rootfall-verge","geometryHash":"one","inputEpoch":1})))
		var frame := {"type":"start","mapId":"rootfall-verge"}
		frame.merge(bad)
		assert(not probe.decode_text(JSON.stringify(frame)), "duplicate start epoch or geometry substitution refused")
		probe.free()
	# Final Continue remains on Crown Array but must un-latch base results before
	# the ending frame. This is not a next-map transition or campaign loop.
	var final_client := RecordingClient.new()
	final_client.allowlist = {"crown-array":{"geometryHash":"final"}}
	final_client.requested_map = "crown-array"
	var ending_phases: Array[String] = []
	final_client.results.connect(func(frame: Dictionary) -> void: ending_phases.append(frame.state.campaign.phase))
	assert(final_client.decode_text(JSON.stringify({"type":"start","mapId":"crown-array","geometryHash":"final","inputEpoch":1})))
	assert(final_client.decode_text(JSON.stringify({"type":"results","inputEpoch":2,"state":{"mapId":"crown-array","campaign":{"mapId":"crown-array","phase":"level-complete","nextMapId":null}}})))
	assert(final_client.round_finished and final_client.expected_next.is_empty())
	assert(final_client.campaign_action("continue") == OK)
	assert(final_client.decode_text(JSON.stringify({"type":"start","mapId":"crown-array","geometryHash":"final","inputEpoch":3})))
	assert(not final_client.round_finished and not final_client.action_pending and final_client.requested_map == "crown-array")
	var ending := {"type":"results","inputEpoch":4,"state":{"mapId":"crown-array","campaign":{"mapId":"crown-array","phase":"campaign-complete","nextMapId":null}}}
	assert(final_client.decode_text(JSON.stringify(ending)))
	assert(final_client.round_finished and ending_phases == ["level-complete", "campaign-complete"], "ending survives base results latch")
	assert(final_client.decode_text(JSON.stringify(ending)) and ending_phases.size() == 2, "duplicate ending cannot re-emit results")
	assert(final_client.campaign_action("continue") == ERR_UNAUTHORIZED, "ending cannot loop the final chapter")
	final_client.free()
	var batch := RecordingClient.new()
	batch.allowlist = {"rootfall-verge":{"geometryHash":"one"}}
	batch.requested_map = "rootfall-verge"
	var emitted: Array[Dictionary] = []
	batch.snapshot.connect(func(frame: Dictionary) -> void: emitted.append(frame))
	batch.results.connect(func(frame: Dictionary) -> void: emitted.append(frame))
	assert(batch.decode_text(JSON.stringify({"type":"start","mapId":"rootfall-verge","geometryHash":"one","inputEpoch":1})))
	batch.draining_snapshots = true
	for seq: int in [1,2,3]:
		assert(batch.decode_text(JSON.stringify({"type":"snapshot","seq":seq,"inputEpoch":1,"state":{"mapId":"rootfall-verge","campaign":{"mapId":"rootfall-verge","phase":"playing"}}})))
	assert(emitted.is_empty() and batch.pending_snapshot.seq == 3 and batch.last_snapshot_seq == 3 and batch.coalesced_snapshots == 2, "all packets validate while only the newest awaits presentation")
	assert(batch.decode_text(JSON.stringify({"type":"results","seq":4,"inputEpoch":2,"state":{"mapId":"rootfall-verge","campaign":{"mapId":"rootfall-verge","phase":"dead"}}})))
	assert(batch.pending_snapshot.is_empty() and emitted.size() == 1 and emitted[0].type == "results", "terminal lifecycle bypasses batching and cannot replay stale poses")
	batch.free()
	# Negative decode-once cases: distinct campaign size message, then the base
	# malformed-envelope message after the campaign size guard passes.
	var guard := RecordingClient.new()
	guard.allowlist = {"rootfall-verge":{"geometryHash":"one"}}
	guard.requested_map = "rootfall-verge"
	assert(not guard.decode_text("x".repeat(guard.MAX_FRAME_BYTES + 1)), "oversized campaign frame refused")
	assert(guard.error == "Oversized campaign frame", "oversized campaign frame keeps its exact message")
	assert(not guard.decode_text("{ not json"), "malformed JSON envelope refused")
	assert(guard.error == "Malformed JSON envelope", "malformed JSON keeps the base message")
	assert(not guard.decode_text(JSON.stringify([1, 2, 3])), "non-object JSON envelope refused")
	assert(guard.error == "Malformed JSON envelope", "non-object envelope keeps the base message")
	guard.free()
	print("CAMPAIGN_CLIENT_OK")
	quit()
