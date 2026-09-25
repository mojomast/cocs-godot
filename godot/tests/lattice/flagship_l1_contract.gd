extends SceneTree
const Transport = preload("res://lattice/world_transport.gd")
const Options = preload("res://lattice/session_options.gd")
const Flow = preload("res://lattice/session_flow.gd")
class FakeClient extends Node:
	var peer_id := 2
	var spectating := false
	var sent: Array[Dictionary] = []
	func send_frame(frame: Dictionary) -> Error: sent.append(frame.duplicate(true)); return OK
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func wire(c: Node, f: Dictionary) -> bool: return c.decode_text(JSON.stringify(f))

func _initialize() -> void:
	var o := Options.parse(PackedStringArray(["--endpoint=ws://127.0.0.1:9000", "--map=monsoon-foundry", "--mode=cocs", "--rung=4v4", "--time-limit=900"]))
	check(o.error.is_empty() and o.rung == "4v4", "valid competitive host options parse")
	check(Options.parse(PackedStringArray(["--endpoint=ws://x", "--mode=cocs-coop", "--rung=4v4"])).error.contains("PvP-only"), "operations cannot request rung")
	check(Options.parse(PackedStringArray(["--endpoint=ws://x", "--join-room=room", "--time-limit=900"])).error.contains("Guest join"), "direct native guest cannot silently supply host config")
	check(Options.parse(PackedStringArray(["--endpoint=ws://x", "--join-room=room", "--map=asterion-relay", "--mode=cocs"])).error.is_empty(), "guest may select expected map and mode")
	check(Options.parse(PackedStringArray(["--endpoint=ws://x", "--time-limit=59"])).error.contains("60..900"), "duration lower bound")
	check(Options.host_frame(o).config.timeLimit == 900 and Options.host_frame(o).config.rung == "4v4", "normal host frame carries requested source config")
	check(not Options.host_frame(o).config.has("botCount"), "competitive rung leaves bot fill wholly to source")
	var flow := Flow.new()
	var denied: Dictionary = flow.start(FakeClient.new(), {"hostId":1})
	check(not denied.queued and denied.reason.contains("Only source roster host"), "non-host cannot request start")
	var host := FakeClient.new()
	host.peer_id = 1
	flow.requested = {"rung":"4v4"}
	flow.publish(Flow.State.HOST_WAITING)
	check(not flow.start(host, {"hostId":1,"players":[]}).queued and host.sent.is_empty(), "rung start awaits sourced floor echo")
	flow.observe_roster({"hostId":1,"cocs":{"minHumans":2},"players":[{"peerId":1,"actorId":null,"connected":true,"spectate":false}]}, host)
	check(flow.minimum_humans == 2, "floor is read from sourced lobby cocs rung plan")
	flow.observe_roster({"hostId":1.0,"cocs":{"minHumans":2.0},"players":[]}, host)
	check(flow.host_peer == 1 and flow.minimum_humans == 2, "JSON numeric host/floor identity is recognized")
	var waiting: Dictionary = flow.start(host, {"hostId":1,"players":[{"peerId":1,"actorId":null,"connected":true,"spectate":false}]})
	check(not waiting.queued and waiting.reason.contains("Waiting for 2") and host.sent.is_empty() and flow.state == Flow.State.HOST_WAITING, "pre-start null actor counts ordinary connected peers and below-floor stays waiting")
	flow.publish(Flow.State.RESULTS)
	flow.minimum_humans = 0
	var restart: Dictionary = flow.restart(host, {"hostId":1,"players":[]})
	check(restart.queued and host.sent.size() == 1, "results restart queues directly without HOST_WAITING fiction")
	var c := Transport.new()
	c.allowlist = {"asterion-relay":{"modes":["cocs"]}}
	c.requested_map = "asterion-relay"
	check(wire(c, {"type":"welcome","v":3,"roomId":"r","peerId":1}), "welcome")
	check(wire(c, {"type":"lobby","hostId":1,"config":{"mode":"cocs"},"cocs":{"minHumans":2},"players":[{"peerId":1,"actorId":0,"connected":true,"spectate":false,"character":"chatgpt","harness":"openclaw"}]}), "roster")
	check(c.roster_metadata.minimum_humans == 2 and c.roster_metadata.players.size() == 1, "complete sourced roster/floor survives projection")
	check(wire(c, {"type":"start","mapId":"asterion-relay","roundRevision":1,"config":{"mode":"cocs","timeLimit":900,"botCount":2}}), "start")
	var state := {"mapId":"asterion-relay","time":42,"actors":[{"id":0,"team":0,"health":100,"x":0,"y":0,"z":0,"yaw":0,"pitch":0,"ammo":[]}],"pickups":[],"cocs":{"roundRevision":1,"nodes":[],"dominance":{"team":1,"progress":10,"target":45,"remaining":35,"count":3,"fastCount":4,"breakCount":2,"fast":false,"counts":{"0":2,"1":3}},"outcome":{"mode":"pvp","waves":null,"hq":null}}}
	check(wire(c, {"type":"snapshot","seq":4,"acks":{},"state":state}), "live snapshot")
	check(c.projection.dominance.breakCount == 2 and c.projection.source_sequence == 4, "public outcome projected with source context")
	check(not c.projection.has("actors") and not c.projection.has("enemy_wallet"), "projection omits private actor/raw wallet structures")
	var order: Array[String] = []
	c.changed.connect(func() -> void: order.append("changed:" + str(c.result_projection.is_empty())))
	c.result_changed.connect(func(_r: Dictionary) -> void: order.append("result"))
	state.winner = 1
	state.overReason = "dominance"
	state.cocs.scores = {"0":10,"1":12}
	check(wire(c, {"type":"results","seq":5,"state":state}), "results frame")
	check(c.projection.is_empty() and c.result_projection.outcome.winner == 1 and c.result_projection.outcome.reason == "dominance", "actual overReason and winner survive final projection after authority clears")
	check(order.size() >= 2 and order[0] == "result" and order[1] == "changed:true", "result update precedes UI changed notification")
	check(c.result_projection.scores["1"] == 12 and c.result_projection.source_time == 42, "score/time only from source result")
	check(wire(c, {"type":"start","mapId":"asterion-relay","roundRevision":2,"config":{"mode":"cocs","timeLimit":900}}), "next start")
	check(c.result_projection.is_empty() and c.actions.is_empty() and c.revision == 2 and c.roster_metadata.minimum_humans == 2 and not c.session_config.is_empty(), "new revision clears authority but preserves current roster and echoed config")
	var draw_state := state.duplicate(true)
	draw_state.erase("overReason")
	draw_state.erase("reason")
	draw_state.erase("winner")
	draw_state.cocs.roundRevision = 2
	draw_state.cocs.scores = {"0":11,"1":11}
	check(wire(c, {"type":"results","seq":6,"state":draw_state}), "draw result without optional reason")
	check(not c.result_projection.outcome.has("reason") and c.result_projection.outcome.winner == null and c.result_projection.scores["0"] == 11, "missing overReason stays absent and draw/scores remain source-faithful")
	check(wire(c, {"type":"lobby","hostId":1,"players":[{"peerId":1,"actorId":1,"connected":true}]}), "new actor roster")
	check(c.result_projection.is_empty() and c.session_config.is_empty(), "actor reassignment revokes prior result and configuration echo")
	check(wire(c, {"type":"lobby","hostId":1,"cocs":{"minHumans":2},"players":[{"peerId":1,"actorId":0,"connected":true}]}), "restored actor roster")
	check(wire(c, {"type":"start","mapId":"asterion-relay","roundRevision":3,"config":{"mode":"cocs","timeLimit":900}}), "third start")
	check(wire(c, {"type":"snapshot","seq":6,"acks":{},"state":{"mapId":"asterion-relay","time":1,"actors":[],"pickups":[]}}) and c.projection.is_empty(), "absent optional projection remains unavailable")
	var bad := state.duplicate(true)
	bad.cocs.dominance.breakCount = "3"
	check(not c.valid_envelope({"type":"snapshot","state":bad,"seq":6,"acks":{}}), "malformed optional outcome rejected")
	bad.cocs.dominance.breakCount = 1.5
	check(not c.valid_envelope({"type":"snapshot","state":bad,"seq":6,"acks":{}}), "fractional dominance break count rejected")
	c.disconnect_server()
	check(c.session_config.is_empty() and c.result_projection.is_empty() and c.roster_metadata.is_empty() and c.revision == -1, "disconnect after results clears echoes, roster, revision and results")
	c.session_config = {"mode":"cocs"}
	c.roster_metadata = {"minimum_humans":2}
	c.revision = 3
	c.result_projection = {"winner":0}
	c.disconnect_server()
	check(c.session_config.is_empty() and c.result_projection.is_empty() and c.roster_metadata.is_empty() and c.revision == -1, "disconnect during active round clears all identity epoch state")
	c.free()
	print("LATTICE_L1_SYNTHETIC %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
