extends "res://net/client.gd"
## Recipient-only command adapter. Movement ACKs never settle actions.
signal changed
## Emitted after projection/result state has been replaced, never before.
signal result_changed(result: Dictionary)
signal below_minimum(message: String)
var mode := "cocs"
var revision := -1
var sequence := 0
var received_at := -1
var projection: Dictionary = {}
## Immutable-by-convention, recipient-only final display facts. Cleared at every
## new start/identity epoch; intentionally contains no action authority.
var result_projection: Dictionary = {}
var session_config: Dictionary = {}
var roster_metadata: Dictionary = {}
var actions: Array[Dictionary] = []
var cooldown_until := 0
var projection_actor := -1
var identity_actor := -1
const LIMIT := 32
const COUNTER_MAX := 2147483647
const PVP_FIGHTER_FLUX := 12.0
const COOP_REINFORCE_FLUX := 50.0
## Source-mirrored personal REQ catalogue. Read-only mirror; the server owns the
## rules and this script only asks. See `req_catalog.gd`.
const ReqCatalog = preload("res://lattice/req_catalog.gd")

func _init() -> void:
	snapshot.connect(observe)
	started.connect(func(frame: Dictionary) -> void:
		if not frame.get("config") is Dictionary or frame.config.get("mode") != mode:
			fail("Unexpected LATTICE mode")
			return
		revision = int(frame.get("roundRevision", -1))
		result_projection.clear()
		session_config = echoed_config(frame.get("config", {}), frame.get("mapId", ""))
		changed.emit())
	lobby.connect(func(_frame: Dictionary) -> void:
		roster_metadata = roster_echo(_frame)
		if identity_actor != actor_id or projection_actor >= 0 and projection_actor != actor_id:
			identity_actor = actor_id
			result_projection.clear()
			session_config.clear()
			clear_projection())
	connection_error.connect(func(_message: String) -> void:
		result_projection.clear()
		session_config.clear()
		roster_metadata.clear()
		clear_projection())
	results.connect(_on_results)

func clear_projection() -> void:
	projection.clear()
	actions.clear()
	received_at = -1
	projection_actor = -1
	changed.emit()

func _on_results(frame: Dictionary) -> void:
	# Base decoder emits results synchronously after marking round_finished. Make
	# live authority unavailable before publishing final display to consumers.
	projection.clear()
	actions.clear()
	received_at = -1
	projection_actor = -1
	var state: Dictionary = dictionary(frame.get("state"))
	var board := dictionary(state.get("cocs"))
	var scores: Variant = board.get("scores")
	var safe_scores: Variant = null
	if scores is Dictionary:
		safe_scores = {}
		for team: String in ["0", "1"]:
			var score: Variant = scores.get(team)
			if finite_number(score): safe_scores[team] = score
	var bounded_outcome: Dictionary = {}
	var winner: Variant = state.get("winner", null)
	if winner == null or (wire_integer(winner) and (winner == 0 or winner == 1)): bounded_outcome["winner"] = winner
	var reason: Variant = state.get("overReason", null)
	if reason is String and reason.length() <= 64: bounded_outcome["reason"] = reason
	result_projection = {"map":state.get("mapId"), "mode":mode, "revision":revision,
		"sequence":frame.get("seq", null), "source_time":state.get("time", null),
		"scores":safe_scores, "outcome":bounded_outcome,
		"dominance":bounded_copy(board.get("dominance")), "mode_progress":bounded_copy(board.get("outcome"))}
	result_changed.emit(result_projection.duplicate(true))
	changed.emit()

func finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func bounded_copy(value: Variant) -> Variant:
	if value is Dictionary and value.size() <= 24: return value.duplicate(true)
	return null

func echoed_config(value: Variant, map_id: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	var out := {"map":map_id, "mode":value.get("mode", null),
		"rung":value.get("rung", null), "bot_count":value.get("botCount", null),
		"human_count":value.get("humanCount", null), "time_limit":value.get("timeLimit", null),
		"operator":assigned_character, "harness":assigned_harness,
		"population":bounded_copy(value.get("population"))}
	out["roster"] = roster_metadata.duplicate(true)
	return out

func roster_echo(frame: Dictionary) -> Dictionary:
	var connected := 0
	var actors := 0
	var spectators := 0
	for player: Variant in array(frame.get("players")):
		if not player is Dictionary: continue
		if player.get("connected") == true: connected += 1
		if player.get("spectate") == true: spectators += 1
		if player.get("actorId") != null: actors += 1
	var players: Array = []
	for player: Variant in array(frame.get("players")):
		if player is Dictionary: players.append({"peerId":player.get("peerId"),"actorId":player.get("actorId"),"connected":player.get("connected"),"spectate":player.get("spectate")})
	var cocs := dictionary(frame.get("cocs"))
	return {"host_peer":frame.get("hostId", null), "minimum_humans":cocs.get("minHumans", 0), "players":players,
		"connected_peers":connected,"assigned_actors":actors,"spectators":spectators,"total_roster":players.size()}

func reset_round() -> void:
	super.reset_round()
	# Base reset_round also runs immediately before `started`; retain the latest
	# authoritative lobby roster/config echo across that revision boundary.
	result_projection.clear()
	sequence = 0
	cooldown_until = 0
	clear_projection()

func disconnect_server() -> void:
	super.disconnect_server()
	# Explicit disconnect ends the identity epoch; unlike reset_round-before-start,
	# it must not retain lobby/config/result echoes.
	revision = -1
	identity_actor = -1
	result_projection.clear()
	session_config.clear()
	roster_metadata.clear()
	sequence = 0
	cooldown_until = 0
	clear_projection()

func decode_text(text: String) -> bool:
	if text.to_utf8_buffer().size() > MAX_FRAME_BYTES: return fail("Oversized frame")
	var value: Variant = JSON.parse_string(text)
	if value is Dictionary and value.get("type") == "error" and str(value.get("message", "")).begins_with("below-minimum:"):
		below_minimum.emit(str(value.message).left(256))
		return true
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
	# Team-visible supply cuts are read from this recipient's own `intel` bucket
	# and nothing else: the other team's view is never touched, and a missing or
	# unknown cut list stays empty rather than becoming an inferred cut.
	var cuts: Array = []
	for value: Variant in array(dictionary(team_value(board, "intel", team)).get("cutNodes")):
		if value is String and not cuts.has(value): cuts.append(value)
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
	# Personal buff slot: only an own-team actor carries `reqBuff` (the per-team
	# filter strips it from enemies). Missing is unknown, never an empty slot.
	var req_buff: Variant = actor.get("reqBuff")
	if not req_buff is String: req_buff = null
	# Recipient-observed traversal depots (public world truth, §11.3). Only the
	# bounded identity/ownership pair is projected, and only when the wire
	# actually carried a depot list; absence stays unknown, never "no depot".
	var depots: Array[Dictionary] = []
	var depots_known := false
	var traversal: Variant = board.get("traversal")
	if traversal is Dictionary and traversal.get("depots") is Array:
		depots_known = true
		for depot: Variant in traversal.get("depots"):
			if not depot is Dictionary or not depot.get("id") is String: continue
			var owner: Variant = depot.get("owner")
			if owner != null and not wire_integer(owner): continue
			depots.append({"id":str(depot.id), "owner":owner})
	projection = {"map":state.get("mapId"), "mode":mode, "team":team,
		"health":actor.get("health"), "req":req, "reqBuff":req_buff,
		"depots":depots, "depots_known":depots_known,
		"flux":team_value(board, "flux", team), "spent":team_value(board, "fluxSpent", team),
		"income":team_value(board, "fluxIncome", team), "upkeep":team_value(board, "fluxUpkeep", team),
		"nodes":nodes, "cuts":cuts, "roles":role_board, "command":dictionary(board.get("command")),
		"commander":dictionary(board.get("commander")), "coop":board.get("coop", false),
		"recruitment":{"peer":peer_id, "phase":director.get("phase"), "wave":director.get("wave"),
			"open":window.get("open"), "sink":reinforce,
		"spawned":dictionary(board.get("roles")).get("spawned")},
		"dominance":bounded_copy(board.get("dominance")),
		"outcome":bounded_copy(board.get("outcome")),
		"source_sequence":frame.get("seq", null), "source_time":state.get("time", null),
		"context":{"revision":revision,"peer":peer_id,"actor":actor_id,"team":team}}
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
		"ttl":"Order expired; issue HOLD again.", "round-end":"Round ended before the action completed.",
		# Personal REQ (BUY) refusals. The server owns every one of these.
		"unknown-item":"Unknown REQ item.", "wrong-mode":"Not available in this mode.",
		"not-launched":"This item has no shipped effect yet.", "depot":"No owned depot available for this purchase.",
		"vehicle":"The depot vehicle is not available.", "no-target":"No legal target for this equipment right now.",
		"insufficient-req":"Not enough REQ for this item.", "one-active-buff":"Another personal buff is already active.",
		"commander-only":"Commander seat required.", "requires-relay":"An owned relay is required.",
		"wrong-actor":"That purchase belongs to a different actor."}
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

# ---------------------------------------------------------------------------
# Personal REQ (BUY). The catalogue is a read-only mirror; the server owns the
# mode/depot/REQ/buff rules. The native client only decides what it is allowed
# to *ask* for from recipient-observed state, and never fabricates acceptance.
# ---------------------------------------------------------------------------

## The finite, mode-aware mirror of the launched source catalogue, each row with
## `enabled`/`disabledReason` derived from this recipient's observed state.
func req_options() -> Array:
	return ReqCatalog.options(req_context())

func req_context() -> Dictionary:
	return {"mode":mode, "team":projection.get("team"), "req":projection.get("req"),
		"activeBuff":projection.get("reqBuff"), "depots":projection.get("depots", []),
		"depotsKnown":projection.get("depots_known") == true}

func req_option(item_id: String) -> Dictionary:
	for option: Variant in req_options():
		if option is Dictionary and option.get("id") == item_id: return option
	return {}

func req_reason_text(reason: String) -> String:
	return ReqCatalog.reason_text(reason)

## Recipient-observed gate for one BUY. Returns "" only when a single ordinary
## BUY request may be queued. Mirrors the source's per-row gate and adds only the
## native `unknown` reasons; an unsupported or unlaunched id is always refused.
func req_gate(item_id: String, depot_id: String = "") -> String:
	var reason := gate()
	if not reason.is_empty(): return reason
	var option := req_option(item_id)
	if option.is_empty(): return "Unsupported REQ item"
	if option.get("enabled") != true:
		return req_reason_text(str(option.get("disabledReason", "")))
	if item_id == "puma":
		if depot_id.is_empty(): return "Select an owned depot"
		var team := -1
		if projection.get("team") is int or projection.get("team") is float: team = int(projection.get("team"))
		var owned := ReqCatalog.owned_depot_ids(projection.get("depots"), team)
		if not owned.has(depot_id): return "Select an owned depot"
	for action: Dictionary in actions:
		if action.get("kind") == "buy" and action.get("target") == item_id and (action.get("status") == "queued" or str(action.get("status", "")).begins_with("pending")):
			return "Awaiting server response; no repeat sent"
	if actions.size() >= LIMIT:
		var has_settled := false
		for action: Dictionary in actions:
			if action.get("status") in ["confirmed", "rejected"]: has_settled = true
		if not has_settled: return "Action history full; unresolved outcomes retained"
	return ""

func activate(kind: String, target: String = "", depot_id: String = "") -> String:
	var reason := req_gate(target, depot_id) if kind == "buy" else action_gate(kind, target)
	if not reason.is_empty(): return reason
	sequence += 1
	var id := "native-r%d-p%d-s%d" % [revision, peer_id, sequence]
	var frame: Dictionary = {"cardId":id, "roundRev":revision, "actionSeq":sequence}
	if kind == "hold": frame.merge({"type":"order", "verb":"HOLD", "target":target})
	elif kind == "fighter": frame.merge({"type":"economy", "action":"spawn", "role":"fighter"})
	elif kind == "reinforce": frame.merge({"type":"economy", "action":"reinforce", "role":"fighter"})
	elif kind == "buy":
		frame.merge({"type":"buy", "itemId":target})
		if not depot_id.is_empty(): frame["depotId"] = depot_id
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
	var action := {"cardId":id, "roundRev":revision, "actionSeq":sequence,
		"kind":kind, "target":target, "status":"queued", "reason":null}
	if kind == "buy": action["depotId"] = depot_id
	actions.append(action)
	changed.emit()
	return ""
