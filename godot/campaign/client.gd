extends "res://native_arenas/client.gd"
const CampaignCatalog = preload("res://campaign/catalog.gd")
var expected_next := ""
var campaign_phase := ""
var action_pending := false
var last_start_epoch := 0
var draining_snapshots := false
var pending_snapshot: Dictionary = {}
var coalesced_snapshots := 0
const MAX_OUTSTANDING_INPUTS := 4
var outstanding_inputs: Array[int] = []
var outstanding_epoch := 0

# The authority consumes one FIFO sample per source tick. Render-time sampling
# can outrun that clock or arrive in TCP bursts; keep a small acknowledged window
# rather than filling its 16-entry queue. ERR_BUSY leaves UI pulses pending.
func send_controls(controls: Dictionary, cancel: bool = false) -> Error:
	if input_epoch < 1: return ERR_UNCONFIGURED
	if outstanding_epoch != input_epoch:
		outstanding_inputs.clear()
		outstanding_epoch = input_epoch
	var retired := maxi(int(input_status.get("appliedSeq", 0)), int(input_status.get("cancelledThrough", 0)))
	while not outstanding_inputs.is_empty() and outstanding_inputs[0] <= retired:
		outstanding_inputs.pop_front()
	if not cancel and outstanding_inputs.size() >= MAX_OUTSTANDING_INPUTS:
		return ERR_BUSY
	var result := super.send_controls(controls, cancel)
	if result == OK:
		# Cancellation clears the server FIFO in the same ordered transport.
		if cancel: outstanding_inputs.clear()
		outstanding_inputs.append(input_seq)
	return result

# Validate and acknowledge every wire packet, but pose/terrain/HUD work only
# needs the newest snapshot in a drained render-frame batch. Events retain their
# original ordered delivery; results and lifecycle boundaries are never delayed.
func deliver_snapshot(frame: Dictionary) -> void:
	if draining_snapshots and frame.get("type") == "snapshot":
		if not pending_snapshot.is_empty(): coalesced_snapshots += 1
		pending_snapshot = frame
		return
	super.deliver_snapshot(frame)

func _process(delta: float) -> void:
	draining_snapshots = true
	super._process(delta)
	draining_snapshots = false
	var frame := pending_snapshot
	pending_snapshot = {}
	if not frame.is_empty() and error.is_empty() and peer.get_ready_state() == WebSocketPeer.STATE_OPEN and not round_finished:
		super.deliver_snapshot(frame)

func create_room(player_name: String = "Operator", character: String = "chatgpt", harness: String = "openclaw") -> Error:
	if character != "chatgpt" or harness != "openclaw": return ERR_UNAUTHORIZED
	return send_frame({"type":"create", "name":"The Quiet Relay", "playerName":player_name, "v":3, "delta":0, "nativeArenaInput":1})

func disconnect_server() -> void:
	outstanding_inputs.clear()
	outstanding_epoch = 0
	pending_snapshot.clear()
	expected_next = ""
	campaign_phase = ""
	action_pending = false
	last_start_epoch = 0
	super.disconnect_server()

func campaign_action(action: String) -> Error:
	if action not in ["retry", "restart", "continue"] or input_epoch < 1 or action_pending: return ERR_UNAUTHORIZED
	if action == "retry" and campaign_phase != "dead": return ERR_UNAUTHORIZED
	if action == "continue" and campaign_phase != "level-complete": return ERR_UNAUTHORIZED
	if action == "restart" and campaign_phase not in ["playing", "dead", "level-complete"]: return ERR_UNAUTHORIZED
	var result := send_frame({"type":"campaign-action", "action":action, "inputEpoch":input_epoch})
	if result == OK: action_pending = true
	return result

func decode_text(text: String) -> bool:
	if text.to_utf8_buffer().size() > MAX_FRAME_BYTES: return fail("Oversized campaign frame")
	var frame: Variant = JSON.parse_string(text)
	if frame is Dictionary:
		if frame.get("type") == "start":
			pending_snapshot.clear()
			if not wire_integer(frame.get("inputEpoch")) or int(frame.inputEpoch) < input_epoch or int(frame.inputEpoch) <= last_start_epoch: return fail("Campaign start epoch did not advance")
			var id: String = str(frame.get("mapId", ""))
			if id not in CampaignCatalog.MAP_IDS or not allowlist.has(id): return fail("Unknown campaign map")
			if id != requested_map and id != expected_next: return fail("Unexpected campaign chapter transition")
			if frame.get("geometryHash") != allowlist[id].get("geometryHash"): return fail("Campaign geometry mismatch")
			requested_map = id
			last_start_epoch = int(frame.inputEpoch)
			expected_next = ""
			campaign_phase = ""
			action_pending = false
		if frame.get("type") in ["snapshot", "results"] and frame.get("state") is Dictionary:
			if frame.type == "results": pending_snapshot.clear()
			var campaign: Variant = frame.state.get("campaign")
			if campaign is Dictionary and campaign.get("mapId") == requested_map and not round_finished and (frame.type == "results" or int(frame.get("seq", -1)) > last_snapshot_seq):
				campaign_phase = str(campaign.get("phase", ""))
			if campaign is Dictionary and campaign.get("phase") == "level-complete" and campaign.get("mapId") == requested_map:
				var index := CampaignCatalog.MAP_IDS.find(requested_map)
				if index < 3 and campaign.get("nextMapId") == CampaignCatalog.MAP_IDS[index + 1]: expected_next = campaign.nextMapId
	return super.decode_text(text)
