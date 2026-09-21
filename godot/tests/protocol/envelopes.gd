extends SceneTree
const Network = preload("res://net/client.gd")
var checks := 0
func check(ok: bool) -> void:
	checks += 1
	if not ok:
		push_error("Envelope assertion " + str(checks))
		quit(1)
		assert(ok)
func _initialize() -> void:
	var net := Network.new()
	net.requested_map = "meridian-exchange"
	net.allowlist = {"meridian-exchange": {}}
	var bad: Array = [
		{"type":"welcome","v":3,"roomId":[],"peerId":1},
		{"type":"welcome","v":3,"roomId":"x","peerId":"1"},
		{"type":"lobby","players":{}},
		{"type":"lobby","players":[null]},
		{"type":"lobby","players":[{"peerId":1,"actorId":[]}]},
		{"type":"snapshot","seq":1.5},
		{"type":"snapshot","seq":1,"acks":[]},
		{"type":"snapshot","seq":1,"acks":{"1":-1}},
		{"type":"events","items":{}},
		{"type":"events","items":[null]},
		{"type":"events","items":[{"id":null}]},
		{"type":"events","items":[{"id":""}]},
		{"type":"events","items":[{"id":true}]},
		{"type":"events","items":[{"id":1},{"id":[]}]}
	]
	for frame: Dictionary in bad:
		check(not net.decode_text(JSON.stringify(frame)))
		check(net.seen_events.is_empty() and net.last_snapshot_seq == -1 and net.peer_id == -1)
	check(net.decode_text('{"type":"welcome","v":3,"roomId":"x","peerId":1}'))
	check(net.decode_text('{"type":"events","items":[{"id":1},{"id":"next"}]}'))
	check(net.seen_events.size() == 2)
	net.free()
	print("PORT_ENVELOPES_OK checks=", checks, " synthetic=true")
	quit(0)
