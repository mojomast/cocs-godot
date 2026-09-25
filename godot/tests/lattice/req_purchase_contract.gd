extends SceneTree
## Native personal-REQ BUY contract. Synthetic recipient wire and GUI lifecycle,
## not live acceptance: the queue is substituted and the source rules are never
## re-implemented here. It proves the native client (a) mirrors a finite launched
## catalogue, (b) gates only on recipient-observed state, (c) sends exactly one
## ordinary `buy` frame with bounded cardId/roundRev/actionSeq, (d) never treats
## queueing as acceptance, and (e) never sends reserved FLUX/economy actions.
class RecordingTransport extends "res://lattice/world_transport.gd":
	var sent: Array = []
	func connection_open() -> bool: return true
	func send_frame(frame: Dictionary) -> Error:
		sent.append(frame.duplicate(true))
		return OK

class StubSession extends Node:
	var client: Node
	func world_command_gate() -> String: return ""

const Commands = preload("res://lattice/world_commands.gd")

var checks := 0
var failures := 0
var seq := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
	print("REQ_PURCHASE_CONTRACT ", message, " ", ok)

func wire(c: Node, frame: Dictionary) -> void:
	if not c.decode_text(JSON.stringify(frame)): check(false, "fixture wire rejected")

func snapshot(c: Node, state: Dictionary) -> void:
	seq += 1
	wire(c, {"type":"snapshot","seq":seq,"state":state,"acks":{"0":seq}})

func base_state() -> Dictionary:
	return {"mapId":"asterion-relay",
		"actors":[{"id":0,"team":0,"x":0,"y":2,"z":0,"yaw":0,"pitch":0,"health":100}],
		"cocs":{"roundRevision":1,"nodes":[{"id":"front-0","x":0,"z":0,"owner":null}],
			"flux":{"0":80},"fluxSpent":{"0":0},"req":[{"id":0,"req":120}],"traversal":{"depots":[]}}}

func option(c: Node, id: String) -> Dictionary:
	for row: Variant in c.req_options():
		if row is Dictionary and row.get("id") == id: return row
	return {}

func client(mode: String) -> RecordingTransport:
	var c := RecordingTransport.new()
	c.mode = mode
	c.allowlist = {"asterion-relay":{"modes":["cocs","cocs-coop"]}}
	c.requested_map = "asterion-relay"
	wire(c, {"type":"welcome","v":3,"roomId":"synthetic","peerId":1})
	wire(c, {"type":"lobby","players":[{"peerId":1,"actorId":0}]})
	wire(c, {"type":"start","mapId":"asterion-relay","roundRevision":1,"config":{"mode":mode}})
	snapshot(c, base_state())
	return c

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var script: Script = load("res://lattice/world_commands.gd") as Script
	if script == null or not script.can_instantiate():
		push_error("REQ world commands script did not compile")
		quit(1)
		return
	_transport_contract()
	_coop_depot_contract()
	await _gui_contract()
	print("LATTICE_REQ_PURCHASE_CONTRACT checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func _transport_contract() -> void:
	var c := client("cocs")
	check(c.req_options().size() == 7, "finite launched catalogue mirrored")
	check(option(c, "spot-drone").get("enabled") == true, "equipment offered with known REQ")
	check(option(c, "puma").get("disabledReason") == "wrong-mode", "Puma is OPERATIONS-only")
	# One ordinary BUY with bounded idempotent identity.
	check(c.req_gate("field-repair").is_empty(), "recipient-observed gate ready")
	check(c.activate("buy", "field-repair").is_empty(), "explicit buy queues")
	check(c.sent.size() == 1 and c.sent[0] == {"type":"buy","itemId":"field-repair","cardId":"native-r1-p1-s1","roundRev":1,"actionSeq":1}, "exact ordinary BUY frame with bounded identity")
	check(not c.sent[0].has("action") and not c.sent[0].has("role") and not c.sent[0].has("verb") and not c.sent[0].has("depotId"), "never a reserved FLUX/economy action or a stray depot")
	check(c.actions[0].status == "queued" and c.projection.req == 120, "queue is not acceptance and never optimistically debits")
	check(not c.activate("buy", "field-repair").is_empty() and c.sent.size() == 1, "unresolved buy never resends")
	# Authoritative settlement only.
	var settled := base_state()
	settled.cocs.cards = [{"id":"native-r1-p1-s1","actorId":0,"peerId":"1","state":"running","accepted":true,"ok":true}]
	snapshot(c, settled)
	check(c.actions[0].status == "pending (server accepted)", "server acceptance is pending, not done")
	settled.cocs.cards[0].state = "done"
	settled.cocs.req = [{"id":0,"req":80}]
	snapshot(c, settled)
	check(c.actions[0].status == "confirmed" and c.projection.req == 80, "authoritative debit and completion observed")
	# Correlated refusal.
	c.cooldown_until = 0
	check(c.activate("buy", "ammo-crate").is_empty() and c.sent[1].actionSeq == 2, "explicit retry gets fresh identity")
	wire(c, {"type":"cocs-reject","cardId":"native-r1-p1-s2","roundRevision":1,"roundRev":1,"actionSeq":1,"reason":"insufficient-req"})
	check(c.actions[1].status == "queued", "unrelated sequence refusal ignored")
	wire(c, {"type":"cocs-reject","cardId":"native-r1-p1-s2","roundRevision":1,"roundRev":1,"actionSeq":2,"reason":"insufficient-req"})
	check(c.actions[1].status == "rejected", "correlated refusal settles the card")
	# Unsupported / reserved ids are refused before any frame.
	var before := c.sent.size()
	for bad: String in ["at-mine", "smoke", "barrier", "sentry", "supply-drop", "tier-upgrade", "oracle-unlock", "respawn", "reserve", "flux", ""]:
		check(not c.req_gate(bad).is_empty(), "unsupported id refused: '" + bad + "'")
	check(c.sent.size() == before, "refusals never send a frame")
	# Absent authority stays unknown/disabled, never an inferred zero.
	var blind := base_state()
	blind.actors[0].erase("req")
	blind.cocs.req = []
	snapshot(c, blind)
	check(option(c, "field-repair").get("disabledReason") == "req-unknown", "missing REQ stays unknown")
	check(not c.req_gate("field-repair").is_empty() and c.sent.size() == before, "unknown REQ cannot spend")
	# One active buff blocks a different buff, not equipment.
	var buffed := base_state()
	buffed.actors[0].reqBuff = "haste"
	snapshot(c, buffed)
	check(option(c, "field-repair").get("disabledReason") == "one-active-buff", "active buff blocks another buff")
	check(option(c, "haste").get("enabled") == true and option(c, "spot-drone").get("enabled") == true, "rebuy/equipment stay legal")
	# Life and staleness gates.
	var dead := base_state()
	dead.actors[0].health = 0
	snapshot(c, dead)
	check(not c.req_gate("field-repair").is_empty() and c.sent.size() == before, "dead actor cannot buy")
	snapshot(c, base_state())
	c.received_at = Time.get_ticks_msec() - 1001
	check(c.req_gate("field-repair").contains("stale"), "stale state cannot buy")
	c.free()

func _coop_depot_contract() -> void:
	var c := client("cocs-coop")
	var no_depot := base_state()
	no_depot.cocs.erase("traversal")
	snapshot(c, no_depot)
	check(option(c, "puma").get("disabledReason") == "depot-unknown", "missing depot list stays unknown")
	check(not c.req_gate("puma", "").is_empty() and c.sent.is_empty(), "no owned depot cannot spend")
	var enemy := base_state()
	enemy.cocs.traversal = {"depots":[{"id":"depot-x","x":0,"z":0,"owner":1}]}
	snapshot(c, enemy)
	check(option(c, "puma").get("disabledReason") == "requires-depot", "enemy depot never counts as owned")
	var owned := base_state()
	owned.cocs.req = [{"id":0,"req":200}]
	owned.cocs.traversal = {"depots":[{"id":"depot-a","x":0,"z":0,"owner":0},{"id":"depot-x","x":0,"z":0,"owner":1}]}
	snapshot(c, owned)
	check(option(c, "puma").get("enabled") == true, "owned depot enables the Puma")
	check(not c.req_gate("puma", "depot-x").is_empty() and not c.req_gate("puma", "").is_empty(), "unowned/missing depot refused")
	check(c.activate("buy", "puma", "depot-a").is_empty(), "Puma buy queues against the owned depot")
	check(c.sent.back().get("itemId") == "puma" and c.sent.back().get("depotId") == "depot-a", "Puma carries only the observed depot")
	check(not c.sent.back().has("action") and not c.sent.back().has("role"), "Puma is still an ordinary BUY")
	c.free()

func _gui_contract() -> void:
	var c := client("cocs")
	var session := StubSession.new()
	var panel: Control = Commands.new()
	root.add_child(panel)
	panel.set_process(false)
	session.client = c
	panel.world_bind(session)
	panel.show()
	panel.world_refresh()
	var index := -1
	var options: Array = c.req_options()
	for i: int in range(options.size()):
		if options[i].get("id") == "field-repair": index = i
	check(index >= 0, "GUI catalog offers the mirrored row")
	panel.world_req_select(index)
	check(panel.req_selected == "field-repair" and not panel.req_confirm.disabled, "picker enables an observed affordable item")
	check(panel.req_effect.text.contains("Heal 50"), "effect copy is shown")
	panel.req_confirm.button_pressed = true
	check(not panel.req_button.disabled, "explicit consent enables the buy")
	panel.world_req_purchase()
	panel.world_req_purchase()
	check(c.sent.size() == 1 and not panel.req_confirm.button_pressed, "GUI queues one buy and consumes consent")
	check(panel.req_notice.text.contains("not accepted"), "queued copy never implies success")
	var cards := base_state()
	cards.cocs.cards = [{"id":"native-r1-p1-s1","actorId":0,"peerId":"1","state":"running","accepted":true,"ok":true}]
	snapshot(c, cards)
	panel.world_refresh()
	check(panel.req_notice.text.contains("accepted by server") and panel.req_button.disabled, "pending copy comes from the authoritative card")
	cards.cocs.cards[0].state = "done"
	cards.cocs.req = [{"id":0,"req":80}]
	snapshot(c, cards)
	panel.world_refresh()
	check(panel.req_notice.text.contains("settled by server"), "confirmed copy comes from the authoritative card")
	check(panel.resources.text.contains("80.0"), "authoritative debit is displayed")
	# Consent belongs to one live context.
	panel.req_confirm.button_pressed = true
	cards.cocs.req = [{"id":0,"req":10}]
	snapshot(c, cards)
	panel.world_refresh()
	check(panel.req_confirm.disabled and not panel.req_confirm.button_pressed, "balance change revokes consent")
	var blind := base_state()
	blind.actors[0].erase("req")
	blind.cocs.req = []
	snapshot(c, blind)
	panel.world_refresh()
	check(panel.req_button.disabled, "missing REQ disables the GUI buy")
	panel.queue_free()
	session.free()
	c.free()
	await process_frame
