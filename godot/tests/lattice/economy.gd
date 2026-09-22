extends SceneTree
## Synthetic recipient protocol and GUI lifecycle checks, not live acceptance.
class RecordingTransport extends "res://lattice/transport.gd":
	var sent: Array = []
	func connection_open() -> bool: return true
	func send_frame(frame: Dictionary) -> Error:
		sent.append(frame.duplicate(true))
		return OK

var checks := 0
var failures := 0
var seq := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func state() -> Dictionary:
	return {"mapId":"asterion-relay", "actors":[{"id":0,"team":0,"health":100}], "cocs":{
		"roundRevision":1, "coop":true, "nodes":[{"id":"front-0", "x":10, "z":10}],
		"flux":{"0":120,"1":999}, "fluxSpent":{"0":0}, "req":[{"id":0,"req":0},{"id":99,"req":999}],
		"command":{"executor":0,"leaseUntil":1200,"threads":{"used":0,"cap":2},
			"slices":[{"id":0,"allowance":60,"remaining":0}]},
		"roles":{"spawned":0}, "director":{"phase":"intermission", "wave":1,
			"intermission":{"open":true,"sinks":[{"id":"REINFORCE","cost":50,"available":true,"affordable":true,"enabled":true}]}}}}

func wire(c: Node, value: Dictionary) -> void:
	check(c.decode_text(JSON.stringify(value)), "JSON envelope decoded")

func snapshot(c: Node, value: Dictionary) -> void:
	seq += 1
	wire(c, {"type":"snapshot","seq":seq,"state":value,"acks":{"0":999}})

func client() -> RecordingTransport:
	var c := RecordingTransport.new()
	c.mode = "cocs-coop"
	c.allowlist = {"asterion-relay":{"modes":["cocs","cocs-coop"]}}
	c.requested_map = "asterion-relay"
	wire(c, {"type":"welcome","v":3,"roomId":"synthetic","peerId":1})
	wire(c, {"type":"lobby","players":[{"peerId":1,"actorId":0}]})
	wire(c, {"type":"start","mapId":"asterion-relay","roundRevision":1,"config":{"mode":"cocs-coop"}})
	snapshot(c, state())
	return c

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var c := client()
	check(c.projection.command.executor is float, "actual JSON numeric identities are floats")
	check(c.action_gate("reinforce").is_empty(), "50 FLUX purchase allowed with zero REQ and zero historical remaining")
	check(c.projection.flux == 120 and c.projection.req == 0 and not c.projection.has("actors"), "only recipient wallet projected")
	check(not c.action_gate("fighter").is_empty(), "co-op cannot buy PvP Fighter")
	c.mode = "cocs"
	check(not c.action_gate("reinforce").is_empty(), "reinforce refused in PvP")
	c.mode = "cocs-coop"
	var baseline := state()
	# Source costs use pooled FLUX + allowance + thread/squad capacity, not REQ.
	for mutation: Callable in [
		func(s: Dictionary) -> void: s.cocs.director.intermission.open = false,
		func(s: Dictionary) -> void: s.cocs.director.phase = "wave",
		func(s: Dictionary) -> void: s.cocs.director.intermission.sinks[0].enabled = false,
		func(s: Dictionary) -> void: s.cocs.director.intermission.sinks[0].available = false,
		func(s: Dictionary) -> void: s.cocs.director.intermission.sinks[0].cost = 12,
		func(s: Dictionary) -> void: s.cocs.director.intermission.sinks[0].cost = "50",
		func(s: Dictionary) -> void: s.cocs.command.slices = [],
		func(s: Dictionary) -> void: s.cocs.command.slices[0].id = 99,
		func(s: Dictionary) -> void: s.cocs.command.slices[0].allowance = 49.99,
		func(s: Dictionary) -> void: s.cocs.command.slices[0].allowance = null,
		func(s: Dictionary) -> void: s.cocs.command.executor = 99,
		func(s: Dictionary) -> void: s.cocs.command.executor = "0",
		func(s: Dictionary) -> void: s.cocs.command.leaseUntil = null,
		func(s: Dictionary) -> void: s.cocs.command.threads.used = 2,
		func(s: Dictionary) -> void: s.cocs.command.threads.cap = null,
		func(s: Dictionary) -> void: s.cocs.flux["0"] = 49.99,
		func(s: Dictionary) -> void: s.cocs.flux.erase("0"),
		func(s: Dictionary) -> void: s.cocs.coop = false,
		func(s: Dictionary) -> void: s.actors[0].health = 0,
		func(s: Dictionary) -> void: s.actors[0].id = 99,
		func(s: Dictionary) -> void: s.actors[0].team = 1]:
		var modified := baseline.duplicate(true)
		mutation.call(modified)
		snapshot(c, modified)
		check(not c.activate("reinforce").is_empty() and c.sent.is_empty(), "unready permission/budget/identity sends no command")
	snapshot(c, baseline)
	c.received_at = Time.get_ticks_msec() - 1001
	check(c.activate("reinforce").contains("stale"), "stale cannot spend")
	snapshot(c, baseline)
	c.projection_actor = 99
	check(not c.activate("reinforce").is_empty(), "wrong projection identity cannot spend")
	snapshot(c, baseline)
	c.peer_id = 2
	check(not c.activate("reinforce").is_empty(), "wrong peer cannot spend from previous recipient projection")
	c.peer_id = 1
	baseline.cocs.req = [{"id":99,"req":999}]
	snapshot(c, baseline)
	check(c.projection.req == null and c.action_gate("reinforce").is_empty(), "hidden REQ stays unknown and is not a recruitment cost")
	check(c.activate("reinforce").is_empty(), "explicit valid recruitment queues")
	check(c.sent == [{"type":"economy","action":"reinforce","role":"fighter","cardId":"native-r1-p1-s1","roundRev":1,"actionSeq":1}], "exact legal source frame, no spoofed actor or funds")
	check(c.actions[0].status == "queued", "queue is not accepted")
	c.cooldown_until = 0
	check(not c.activate("reinforce").is_empty() and c.sent.size() == 1, "unresolved purchase never resends beyond cooldown")
	baseline.cocs.cards = [{"id":"native-r1-p1-s1","actorId":99,"peerId":"1","state":"done","ok":true}]
	snapshot(c, baseline)
	check(c.actions[0].status == "queued", "other actor receipt and movement ACK cannot settle")
	baseline.cocs.cards[0].actorId = 0
	baseline.cocs.cards[0].peerId = "9"
	snapshot(c, baseline)
	check(c.actions[0].status == "queued", "other peer cannot settle")
	baseline.cocs.cards[0].peerId = "1"
	baseline.cocs.cards[0].state = "running"
	baseline.cocs.cards[0].accepted = true
	snapshot(c, baseline)
	check(c.actions[0].status == "pending (server accepted)" and not c.activate("reinforce").is_empty(), "accepted remains unresolved, exactly once")
	baseline.cocs.cards[0].state = "done"
	snapshot(c, baseline)
	check(c.actions[0].status == "confirmed", "own done receipt confirms")
	check(c.activate("reinforce").is_empty() and c.sent[1].actionSeq == 2, "only explicit new activation gets fresh identity")
	wire(c, {"type":"cocs-reject","cardId":"native-r1-p1-s2","roundRevision":1,"roundRev":1,"actionSeq":1,"reason":"executor"})
	check(c.actions[1].status == "queued", "wrong sequence reject ignored")
	wire(c, {"type":"cocs-reject","cardId":"native-r1-p1-s2","roundRevision":1,"roundRev":1,"actionSeq":2,"reason":"executor"})
	check(c.actions[1].status == "rejected" and c.rejection_text(c.actions[1].reason).contains("lease"), "correlated refusal has useful explanation")
	var old_round := state()
	old_round.cocs.roundRevision = 0
	snapshot(c, old_round)
	check(c.projection.is_empty() and not c.activate("reinforce").is_empty(), "wrong round cannot restore recruitment permission")
	c.free()
	# GUI synthetic lifecycle: every authorization belongs to a live context.
	var board: Control = load("res://lattice/board.tscn").instantiate()
	root.add_child(board)
	await process_frame
	board.client.free()
	c = client()
	board.client = c
	board.add_child(c)
	c.changed.connect(board.refresh)
	board.phase = "active"
	board.refresh()
	check(board.spend_button.text == "Co-op REINFORCE" and board.confirm_spend.text.contains("50"), "separate co-op label and exact price")
	board.confirm_spend.button_pressed = true
	check(not board.spend_button.disabled, "fresh consent enables valid purchase")
	var changed := state()
	changed.cocs.command.leaseUntil = 2400
	snapshot(c, changed)
	check(not board.confirm_spend.button_pressed and board.spend_button.disabled, "new lease revokes old consent")
	board.confirm_spend.button_pressed = true
	c.received_at = Time.get_ticks_msec() - 1001
	board.refresh()
	check(not board.confirm_spend.button_pressed, "stale revokes consent")
	snapshot(c, state())
	check(board.spend_button.disabled, "fresh snapshot does not restore consent")
	board.confirm_spend.button_pressed = true
	board.buy_fighter()
	board.buy_fighter()
	check(c.sent.size() == 1 and not board.confirm_spend.button_pressed, "GUI consumes consent exactly once")
	board.disconnect_session()
	check(board.client.actions.is_empty() and board.spend_button.disabled, "disconnect clears purchase context")
	board.queue_free()
	await process_frame
	print("LATTICE_ECONOMY_SYNTHETIC %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
