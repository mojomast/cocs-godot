extends SceneTree
## Synthetic recipient fixture: checks projection/privacy/settlement copy, not a
## live BUY, natural Operations clear or human acceptance.
const Transport = preload("res://lattice/world_transport.gd")
const Model = preload("res://lattice/world_tactical_model.gd")
const HUD = preload("res://lattice/world_tactical_hud.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	print("TACTICAL_HUD ", message, " ", ok)

func wire(client: Node, frame: Dictionary) -> bool:
	return client.decode_text(JSON.stringify(frame))

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	var client := Transport.new()
	client.allowlist = {"asterion-relay":{"modes":["cocs", "cocs-coop"]}}
	client.requested_map = "asterion-relay"
	wire(client, {"type":"welcome", "v":3, "roomId":"fixture", "peerId":1})
	wire(client, {"type":"lobby", "players":[{"peerId":1,"actorId":0}]})
	wire(client, {"type":"start", "mapId":"asterion-relay", "roundRevision":1, "config":{"mode":"cocs"}})
	var state := {"mapId":"asterion-relay", "actors":[{"id":0,"team":0,"x":0,"y":2,"z":0,"yaw":0,"pitch":0,"health":100}],
		"cocs":{"roundRevision":1,"nodes":[],"req":[{"id":0,"req":120}],"flux":{"0":80},
			"contacts":{"0":[{"id":2,"team":1,"own":false,"x":22,"z":9,"spotted":true,"revealed":true},
				{"id":3,"team":1,"own":false,"x":5,"z":6,"spotted":true}]}}}
	var first_frame := {"type":"snapshot","seq":1,"state":state}
	check(wire(client, first_frame), "recipient contact snapshot accepted (" + client.error + ")")
	if client.projection.is_empty():
		client.free()
		quit(1)
		return
	check(client.projection.recon_contacts.size() == 1 and client.projection.recon_contacts[0].id == 2, "only source-revealed enemy enters HUD projection")
	var bad := state.duplicate(true)
	bad.cocs.contacts["1"] = [{"id":4,"team":0,"own":false,"x":3,"z":1}]
	check(not client.valid_envelope({"type":"snapshot","seq":2,"state":bad}), "foreign team contact bucket rejected at wire gate")
	var no_contacts := state.duplicate(true)
	no_contacts.cocs.erase("contacts")
	check(wire(client, {"type":"snapshot","seq":2,"state":no_contacts}) and client.projection.recon_contacts.is_empty(), "missing contacts clear private disclosure")
	var target := {"target_id":"front", "text":"Front · legal frontier"}
	var topology := {"by_id":{"front":{"id":"front","label":"Front", "x":10.0,"z":0.0,"capture_legal":true,"supply":"LINKED"}}}
	var model: Dictionary = Model.projection(client.projection, target, topology, state.actors[0])
	check(model.goal.contains("10 m") and model.objective.contains("CAPTURE LEGAL"), "observed objective and planar range appear")
	check(model.intel.is_empty() and model.req == "120", "no recon claim when own private contact list missing")
	check(Model.buy_receipt([{"kind":"buy","target":"sentry","status":"queued"}]).contains("NOT ACCEPTED"), "queue copy cannot imply server acceptance")
	check(Model.buy_receipt([{"kind":"buy","target":"sentry","status":"pending (server accepted)"}]).contains("AWAIT SETTLEMENT"), "accepted card remains unsettled")
	check(Model.buy_receipt([{"kind":"buy","target":"sentry","status":"confirmed"}]).contains("SETTLED BY SERVER"), "confirmed card copy is explicit")
	client.mode = "cocs-coop"
	wire(client, {"type":"start", "mapId":"asterion-relay", "roundRevision":2, "config":{"mode":"cocs-coop"}})
	state.cocs.roundRevision = 2
	state.cocs.erase("contacts")
	state.cocs.coop = true
	state.cocs.director = {"phase":"intermission", "wave":3, "waveLabel":null}
	state.cocs.waves = {"forceAlive":7,"forceTotal":13}
	state.cocs.outcome = {"mode":"operations","waves":{"cleared":2,"total":5},"hq":{"health":60,"max":100}}
	check(wire(client, {"type":"snapshot","seq":1,"state":state}), "Operations pre-wave null label accepted")
	state.cocs.director = {"phase":"peak", "wave":3, "waveLabel":"DENIAL"}
	check(wire(client, {"type":"snapshot","seq":2,"state":state}), "Operations wave snapshot accepted")
	model = Model.projection(client.projection, target, topology, state.actors[0])
	check(model.progress.contains("WAVE 3 / 5") and model.detail.contains("FORCE 7 / 13") and model.detail.contains("HQ 60 / 100"), "Operations counts are source-observed")
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var hud := HUD.new()
	layer.add_child(hud)
	hud.present(client.projection, target, topology, state.actors[0], [], "")
	await process_frame
	check(hud.visible and hud.progress.text.contains("WAVE 3") and hud.economy.text.contains("120"), "render panel consumes recipient model")
	root.size = Vector2i(760, 520)
	await process_frame
	check(hud.objective_card.get_rect().end.x < hud.status_card.position.x and hud.status_card.get_rect().end.x <= 760, "compact cards fit without overlap")
	client.clear_projection()
	hud.present(client.projection, {}, {}, {}, [], "")
	check(not hud.visible and hud.epoch.is_empty(), "identity loss clears HUD and wallet delta")
	layer.free()
	client.free()
	await process_frame
	print("TACTICAL_HUD checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
