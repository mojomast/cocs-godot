extends "res://native_arenas/client.gd"
const CampaignCatalog = preload("res://campaign/catalog.gd")
var expected_next := ""
var campaign_phase := ""
var action_pending := false
var last_start_epoch := 0
var draining_snapshots := false
var pending_snapshot: Dictionary = {}
var coalesced_snapshots := 0

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

# Pre-parse size guard only. The base hook owns the single JSON decode; this
# override keeps the campaign-chain step ordering and its distinct message.
func decode_text(text: String) -> bool:
	if text.to_utf8_buffer().size() > MAX_FRAME_BYTES: return fail("Oversized campaign frame")
	return super.decode_text(text)

# Campaign protocol checks run on the already-decoded frame, after the single
# parse and before the native and base layers. Hand the frame to the base state
# machine exactly once at the end.
func deliver_frame(frame: Dictionary) -> bool:
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
	return super.deliver_frame(frame)
