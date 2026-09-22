extends SceneTree
const Transport = preload("res://lattice/transport.gd")
class RecordingTransport extends "res://lattice/transport.gd":
	var sent: Array = []
	var open := true
	func connection_open() -> bool: return open
	func send_frame(frame: Dictionary) -> Error:
		sent.append(frame.duplicate(true))
		return OK

var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func wire(client: Node, frame: Dictionary) -> bool:
	return client.decode_text(JSON.stringify(frame))
func _initialize() -> void:
	var c := Transport.new()
	c.allowlist = {"asterion-relay": {"modes":["cocs", "cocs-coop"]}}
	c.requested_map = "asterion-relay"
	check(wire(c, {"type":"welcome", "v":3, "roomId":"test", "peerId":1}), "welcome")
	check(wire(c, {"type":"lobby", "players":[{"peerId":1,"actorId":0}]}), "roster")
	check(wire(c, {"type":"start", "mapId":"asterion-relay", "roundRevision":1, "config":{"mode":"cocs"}}), "start")
	var state := {"mapId":"asterion-relay", "actors":[{"id":0,"team":0,"health":100}], "cocs":{"roundRevision":1,"nodes":[{"id":"front-0","owner":0}],"flux":{"1":90}}}
	check(wire(c, {"type":"snapshot", "seq":1,"state":state,"acks":{"0":200}}), "snapshot")
	check(c.projection.flux == null, "missing own wallet stays unknown")
	check(not c.projection.has("actors"), "no enemy actor positions projected")
	check(c.projection.req == null, "missing REQ is unknown")
	c.actions.append({"cardId":"local-1", "actionSeq":1,"roundRev":1,"kind":"fighter","status":"queued", "reason":null})
	check(c.actions[0].status == "queued", "movement ACK cannot confirm actions")
	state.cocs.cards = [{"id":"local-1","actorId":1,"peerId":"1","state":"done","ok":true}]
	wire(c, {"type":"snapshot", "seq":2,"state":state})
	check(c.actions[0].status == "queued", "other actor card cannot confirm")
	state.cocs.cards[0].actorId = 0
	state.cocs.cards[0].peerId = "2"
	wire(c, {"type":"snapshot", "seq":3,"state":state})
	check(c.actions[0].status == "queued", "other peer card cannot confirm")
	state.cocs.cards[0].peerId = "1"
	state.cocs.cards[0].state = "running"
	state.cocs.cards[0].accepted = true
	wire(c, {"type":"snapshot", "seq":4,"state":state})
	check(c.actions[0].status == "pending (server accepted)", "accepted is not completed")
	state.cocs.cards[0].state = "done"
	wire(c, {"type":"snapshot", "seq":3,"state":state})
	check(c.actions[0].status == "pending (server accepted)", "out-of-order snapshot ignored")
	wire(c, {"type":"snapshot", "seq":5,"state":state})
	check(c.actions[0].status == "confirmed", "authoritative done confirms")
	wire(c, {"type":"cocs-reject", "cardId":"local-1","reason":"flux","roundRevision":1,"roundRev":1,"actionSeq":2})
	check(c.actions[0].status == "confirmed", "unmatched rejection ignored")
	wire(c, {"type":"cocs-reject", "cardId":"local-1","reason":"flux","roundRevision":1,"roundRev":1,"actionSeq":1})
	check(c.actions[0].status == "rejected" and c.actions[0].reason == "flux", "correlated rejection readable")
	check(not c.activate("fighter").is_empty(), "disconnect gates submission")
	check(c.sequence == 0, "blocked activation consumes no sequence")
	wire(c, {"type":"start", "mapId":"asterion-relay", "roundRevision":2,"config":{"mode":"cocs"}})
	check(c.actions.is_empty() and c.projection.is_empty() and c.revision == 2, "round resets targets and actions")
	wire(c, {"type":"snapshot", "seq":6,"state":state})
	check(c.projection.is_empty(), "old round snapshot cannot restore actions")
	check(not wire(c, {"type":"cocs-reject", "cardId":7,"reason":"bad"}), "malformed rejection fails closed")
	check(not wire(c, {"type":"cocs-reject", "cardId":"x","reason":"bad", "actionSeq":-1}), "negative sequence fails closed")
	check(not c.decode_text(" ".repeat(c.MAX_FRAME_BYTES + 1)), "size bound preserved")
	c.disconnect_server()
	check(c.revision == -1 and c.actions.is_empty() and c.projection.is_empty(), "explicit disconnect reset")
	c.free()
	var fake := RecordingTransport.new()
	fake.revision = 1
	fake.actor_id = 0
	fake.peer_id = 1
	fake.projection_actor = 0
	fake.received_at = Time.get_ticks_msec()
	fake.projection = {"health":100, "nodes":[{"id":"front-0"}], "roles":{"allow":["fighter"],"threads":{"used":0,"cap":3}}, "flux":80}
	check(fake.activate("fighter").is_empty(), "synthetic queue accepts one spend")
	check(fake.actions[0].status == "queued", "queue success remains queued")
	check(not fake.activate("fighter").is_empty() and fake.sent.size() == 1, "duplicate activation suppressed")
	fake.cooldown_until = 0
	check(not fake.activate("fighter").is_empty(), "unanswered spend blocks retries beyond cooldown")
	fake.actions[0].status = "pending (server accepted)"
	check(not fake.activate("fighter").is_empty(), "accepted spend blocks repeats until settled")
	fake.actions[0].status = "rejected"
	check(fake.activate("fighter").is_empty() and fake.sent[1].actionSeq == 2, "explicit retry gets fresh identity")
	fake.cooldown_until = 0
	fake.received_at = -1
	check(fake.gate().contains("stale"), "missing receive time disables actions")
	fake.received_at = Time.get_ticks_msec() - 1001
	check(fake.gate().contains("stale"), "stale state disables actions")
	fake.received_at = Time.get_ticks_msec()
	fake.projection.health = 0
	check(fake.gate().contains("dead"), "dead actor disables actions")
	fake.projection.health = 100
	fake.projection_actor = 2
	check(not fake.gate().is_empty(), "identity mismatch disables actions")
	fake.projection_actor = 0
	fake.actions.clear()
	fake.mode = "cocs-coop"
	fake.projection.command = {"slices":[]}
	check(not fake.action_gate("hold", "front-0").is_empty(), "unknown co-op membership disabled")
	fake.projection.command.slices = [{"id":0}]
	check(fake.action_gate("hold", "front-0").is_empty(), "known ordinary co-op membership enables HOLD")
	check(not fake.action_gate("fighter").is_empty(), "co-op economy intentionally disabled")
	fake.mode = "cocs"
	for i: int in range(32): fake.actions.append({"kind":"hold", "status":"pending (server accepted)"})
	check(not fake.activate("fighter").is_empty(), "bounded history retains unresolved actions")
	fake.reset_round()
	check(fake.actions.is_empty() and fake.sequence == 0, "synthetic round reset clears pending and counter")
	fake.free()
	print("LATTICE_SYNTHETIC %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
