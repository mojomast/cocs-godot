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
	print("CAMPAIGN_CLIENT_OK")
	quit()
