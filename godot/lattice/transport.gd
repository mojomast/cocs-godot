extends "res://net/client.gd"
## Recipient-only command adapter. Movement ACKs never settle actions.
signal changed
var mode := "cocs"
var revision := -1
var sequence := 0
var received_at := -1
var projection: Dictionary = {}
var actions: Array[Dictionary] = []
var cooldown_until := 0
var projection_actor := -1
const LIMIT := 32
const COUNTER_MAX := 2147483647
const PVP_FIGHTER_FLUX := 12.0
const COOP_REINFORCE_FLUX := 50.0

func _init() -> void:
	snapshot.connect(observe)
	started.connect(func(frame: Dictionary) -> void:
		if not frame.get("config") is Dictionary or frame.config.get("mode") != mode:
			fail("Unexpected LATTICE mode")
			return
		revision = int(frame.get("roundRevision", -1))
		changed.emit())
	lobby.connect(func(_frame: Dictionary) -> void:
		if projection_actor != actor_id: clear_projection())
	connection_error.connect(func(_message: String) -> void: clear_projection())
	results.connect(func(_frame: Dictionary) -> void: clear_projection())

func clear_projection() -> void:
	projection.clear()
	actions.clear()
	received_at = -1
	projection_actor = -1
	changed.emit()

func reset_round() -> void:
	super.reset_round()
	revision = -1
	sequence = 0
	cooldown_until = 0
	clear_projection()

func decode_text(text: String) -> bool:
	if text.to_utf8_buffer().size() > MAX_FRAME_BYTES: return fail("Oversized frame")
	var value: Variant = JSON.parse_string(text)
	if value is Dictionary and value.get("type") == "cocs-reject":
		if not value.get("cardId") is String or value.cardId.length() > 128 or not value.get("reason") is String or value.reason.length() > 256:
			return fail("Malformed LATTICE rejection")
		for key: String in ["roundRevision", "roundRev", "actionSeq"]:
			if value.has(key) and (not wire_integer(value[key]) or value[key] > COUNTER_MAX):
				return fail("Malformed LATTICE identity")
		if value.get("roundRevision", -1) != revision: return true
		for action: Dictionary in actions:
			if action.cardId != value.cardId: continue
			if value.get("roundRev", revision) != action.roundRev or value.get("actionSeq", action.actionSeq) != action.actionSeq: continue
			action.status = "rejected"
			action.reason = value.reason
		changed.emit()
		return true
	return super.decode_text(text)

func dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

func array(value: Variant) -> Array:
	return value if value is Array else []

func team_value(board: Dictionary, key: String, team: int) -> Variant:
	return dictionary(board.get(key)).get(str(team))

func observe(frame: Dictionary) -> void:
	var state: Dictionary = frame.state
	var board := dictionary(state.get("cocs"))
	var rev: Variant = board.get("roundRevision")
	if not wire_integer(rev) or rev > COUNTER_MAX or int(rev) != revision:
		clear_projection()
		return
	if not board.get("nodes") is Array:
		clear_projection()
		return
	var actor: Dictionary = {}
	for candidate: Variant in state.get("actors", []):
		if candidate is Dictionary and candidate.get("id") == actor_id: actor = candidate
	var team_value_wire: Variant = actor.get("team")
	if not wire_integer(team_value_wire) or (team_value_wire != 0 and team_value_wire != 1):
		clear_projection()
		return
	var team := int(team_value_wire)
	var nodes: Array[Dictionary] = []
	for node: Variant in board.nodes:
		if not node is Dictionary or not node.get("id") is String: continue
		nodes.append(node.duplicate(true))
	var role_board := dictionary(team_value(board, "roleBoard", team))
	var director := dictionary(board.get("director"))
	var window := dictionary(director.get("intermission"))
	var reinforce: Dictionary = {}
	for sink: Variant in array(window.get("sinks")):
		if sink is Dictionary and sink.get("id") == "REINFORCE":
			for key: String in ["cost", "available", "enabled", "affordable"]:
				reinforce[key] = sink.get(key)
	# Only this actor's public wallet. Missing is unknown, never an inferred zero.
	var req: Variant = actor.get("req")
	for wallet: Variant in array(board.get("req")):
		if wallet is Dictionary and wallet.get("id") == actor_id: req = wallet.get("req")
	projection = {"map":state.get("mapId"), "mode":mode, "team":team,
		"health":actor.get("health"), "req":req,
		"flux":team_value(board, "flux", team), "spent":team_value(board, "fluxSpent", team),
		"income":team_value(board, "fluxIncome", team), "upkeep":team_value(board, "fluxUpkeep", team),
		"nodes":nodes, "roles":role_board, "command":dictionary(board.get("command")),
		"commander":dictionary(board.get("commander")), "coop":board.get("coop", false),
		"recruitment":{"peer":peer_id, "phase":director.get("phase"), "wave":director.get("wave"),
			"open":window.get("open"), "sink":reinforce,
			"spawned":dictionary(board.get("roles")).get("spawned")}}
	projection_actor = actor_id
	received_at = Time.get_ticks_msec()
	for card: Variant in board.get("cards", []):
		if not card is Dictionary: continue
		for action: Dictionary in actions:
			if card.get("id") != action.cardId or card.get("actorId") != actor_id or str(card.get("peerId", "")) != str(peer_id): continue
			if action.status == "rejected": continue
			var status: String = str(card.get("state", ""))
			if status == "done" and card.get("ok") == true:
				action.status = "confirmed"
			elif status in ["blocked", "expired"]:
				action.status = "rejected"
			elif status == "running" and card.get("accepted") == true:
				action.status = "pending (server accepted)"
			action.reason = card.get("reason")
	changed.emit()

func connection_open() -> bool:
	return peer.get_ready_state() == WebSocketPeer.STATE_OPEN

func purchase_kind() -> String:
	return "reinforce" if mode == "cocs-coop" else "fighter"

func amount(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0

func recruitment_gate() -> String:
	if mode != "cocs-coop" or projection.get("mode") != mode or projection.get("coop") != true or projection.get("team") != 0:
		return "Co-op recruitment requires an authorized team-0 Operations view"
	var recruitment := dictionary(projection.get("recruitment"))
	if peer_id < 0 or recruitment.get("peer") != peer_id: return "Waiting for recipient identity"
	if recruitment.get("phase") != "intermission" or recruitment.get("open") != true:
		return "Wait for the between-wave recruitment window"
	var sink := dictionary(recruitment.get("sink"))
	if not amount(sink.get("cost")) or float(sink.cost) != COOP_REINFORCE_FLUX:
		return "REINFORCE price unknown or changed; purchase disabled"
	if sink.get("available") != true: return "No free squad slot (or availability unknown)"
	var command := dictionary(projection.get("command"))
	var member: Dictionary = {}
	for entry: Variant in array(command.get("slices")):
		if entry is Dictionary and entry.get("id") == actor_id: member = entry
	if member.is_empty(): return "Co-op command membership unknown"
	# Numeric JSON identities are floats; never stringify them as e.g. '0.0'.
	if not wire_integer(command.get("executor")) or command.executor != actor_id:
		return "Wait for your rotating executor lease"
	if not wire_integer(command.get("leaseUntil")) or command.leaseUntil <= 0: return "Executor lease not ready"
	if not amount(member.get("allowance")): return "Personal FLUX allowance unknown"
	# The authority checks allowance, NOT the historical remaining display.
	if float(member.allowance) < COOP_REINFORCE_FLUX: return "Requires a 50 FLUX slice allowance"
	var threads := dictionary(command.get("threads"))
	if not wire_integer(threads.get("used")) or not wire_integer(threads.get("cap")): return "Thread budget unknown"
	if threads.used >= threads.cap: return "No free threads"
	if not amount(projection.get("flux")): return "FLUX unknown/hidden"
	if float(projection.flux) < COOP_REINFORCE_FLUX: return "Requires 50 team FLUX"
	if sink.get("enabled") != true or sink.get("affordable") != true: return "Server recruitment permission not ready"
	return ""

func rejection_text(reason: Variant) -> String:
	var explanations := {"window-closed":"Recruitment window closed; wait for the next intermission.",
		"executor":"Executor lease changed; wait for your turn.", "slice":"Your FLUX slice is too small for this purchase.",
		"flux":"Team FLUX changed; check the live budget.", "no-thread":"All threads are busy; wait for a free thread.",
		"stale-round":"Round changed; reconnect before authorizing again.", "dead":"Your actor is unavailable.",
		"rate-limit":"Too many requests; wait before authorizing again.", "no-sink":"This action is unavailable in this mode.",
		"ttl":"Order expired; issue HOLD again.", "round-end":"Round ended before the action completed."}
	return str(explanations.get(str(reason), str(reason)))

func gate() -> String:
	if not connection_open(): return "Disconnected"
	if round_finished: return "Round ended"
	if revision < 1 or actor_id < 0 or projection_actor != actor_id: return "Waiting for round and actor identity"
	if received_at < 0 or Time.get_ticks_msec() - received_at > 1000: return "State stale; actions disabled"
	if projection.get("health") == null or float(projection.health) <= 0: return "Actor unavailable/dead"
	if Time.get_ticks_msec() < cooldown_until: return "Repeated activation suppressed"
	if sequence >= COUNTER_MAX: return "Action sequence exhausted"
	return ""

func action_gate(kind: String, target: String = "") -> String:
	var reason := gate()
	if not reason.is_empty(): return reason
	if kind == "hold":
		var found := false
		for node: Dictionary in projection.get("nodes", []):
			if node.id == target: found = true
		if not found: return "Select an authorized node"
		if mode == "cocs-coop":
			var member := false
			for entry: Variant in projection.command.get("slices", []):
				if entry is Dictionary and entry.get("id") == actor_id: member = true
			if not member: return "Co-op command membership unknown"
	elif kind == "fighter":
		if mode != "cocs": return "PvP Fighter is available only in cocs; use co-op REINFORCE"
		if not "fighter" in projection.roles.get("allow", []): return "Fighter role unavailable"
		var threads := dictionary(projection.roles.get("threads"))
		if not threads.has("used") or not threads.has("cap"): return "Thread budget unknown"
		if threads.used >= threads.cap: return "No free threads"
		if projection.flux == null: return "FLUX unknown/hidden"
		if float(projection.flux) < PVP_FIGHTER_FLUX: return "Requires 12 FLUX"
	elif kind == "reinforce":
		reason = recruitment_gate()
		if not reason.is_empty(): return reason
	elif kind != "unsupported-fortify": return "Unsupported action"
	for action: Dictionary in actions:
		if action.kind == kind and (action.status == "queued" or (kind in ["fighter", "reinforce"] and action.status == "pending (server accepted)")): return "Awaiting server response; no repeat sent"
	if actions.size() >= LIMIT:
		var has_settled := false
		for action: Dictionary in actions:
			if action.status in ["confirmed", "rejected"]: has_settled = true
		if not has_settled: return "Action history full; unresolved outcomes retained"
	return ""

func activate(kind: String, target: String = "") -> String:
	var reason := action_gate(kind, target)
	if not reason.is_empty(): return reason
	sequence += 1
	var id := "native-r%d-p%d-s%d" % [revision, peer_id, sequence]
	var frame: Dictionary = {"cardId":id, "roundRev":revision, "actionSeq":sequence}
	if kind == "hold": frame.merge({"type":"order", "verb":"HOLD", "target":target})
	elif kind == "fighter": frame.merge({"type":"economy", "action":"spawn", "role":"fighter"})
	elif kind == "reinforce": frame.merge({"type":"economy", "action":"reinforce", "role":"fighter"})
	else: frame.merge({"type":"economy", "action":"fortify", "target":target})
	if send_frame(frame) != OK: return "Queue failed; outcome unknown, reconnect explicitly"
	cooldown_until = Time.get_ticks_msec() + 600
	if actions.size() >= LIMIT:
		# Keep unacknowledged actions: never silently permit repeat spending.
		var removable := -1
		for i: int in range(actions.size()):
			if actions[i].status in ["confirmed", "rejected"]:
				removable = i
				break
		if removable >= 0: actions.remove_at(removable)
	actions.append({"cardId":id, "roundRev":revision, "actionSeq":sequence,
		"kind":kind, "target":target, "status":"queued", "reason":null})
	changed.emit()
	return ""
