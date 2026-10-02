extends SceneTree
const Bridge = preload("res://replay/bridge.gd")
func _initialize() -> void:
	var bridge := Bridge.new()
	for i in 120:
		var packet := {"op":"frame","state":{"time":i/60.0,"text":"λ東京","actors":[]},"events":[],"role":"seated"}
		assert(bridge.send(packet))
		packet.state.text = "changed by caller"
		var actual := 0
		for j in bridge.pending.size():
			var size := JSON.stringify(bridge.pending[j]).to_utf8_buffer().size()
			assert(size == bridge.pending_sizes[j], "exact UTF8 accounting")
			assert(not JSON.stringify(bridge.pending[j]).contains("changed by caller"), "detached queued snapshot")
			actual += size
		assert(actual == bridge.pending_bytes)
	assert(bridge.pending.size() == 4, "bounded batches amortize packet work")
	assert(bridge.send({"op":"seek","time":1.0}))
	assert(bridge.send({"op":"seek","time":2.0}))
	assert(bridge.pending.size() == 5 and bridge.pending.back().time == 2.0)
	bridge._abort("fixture teardown")
	assert(bridge.pending.is_empty() and bridge.pending_sizes.is_empty() and bridge.pending_bytes == 0)
	bridge.http.free()
	bridge.free()
	print("REPLAY_QUEUE_OK exact UTF8 / detached frames / bounded batches / coalescing / cleanup")
	quit()
