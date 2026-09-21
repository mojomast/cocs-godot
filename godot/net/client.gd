class_name PortNetwork
extends Node

signal lobby(frame: Dictionary)
signal started(frame: Dictionary)
signal snapshot(frame: Dictionary)
signal events(items: Array)
signal results(frame: Dictionary)
signal connection_error(message: String)

const PROTOCOL_VERSION := 3
const MAX_FRAME_BYTES := 1048576 # bounded initial cap; capture is not all-map worst case
var peer := WebSocketPeer.new()
var allowlist: Dictionary = {}
var requested_map: String = ""
var peer_id: int = -1
var actor_id: int = -1
var input_seq: int = 0
var last_ack: int = 0
var last_snapshot_seq: int = -1
var snapshots: Array[Dictionary] = []
var seen_events: Dictionary = {}
var event_order: Array = []
var error: String = ""
var was_open: bool = false

func connect_server(endpoint: String, maps: Dictionary, map_id: String) -> Error:
	disconnect_server()
	allowlist = maps
	requested_map = map_id
	if not allowlist.has(map_id):
		fail("Requested map is not allowlisted")
		return ERR_INVALID_PARAMETER
	peer.inbound_buffer_size = MAX_FRAME_BYTES * 2
	peer.outbound_buffer_size = 65536
	peer.max_queued_packets = 128
	return peer.connect_to_url(endpoint)

func disconnect_server() -> void:
	if peer.get_ready_state() != WebSocketPeer.STATE_CLOSED: peer.close()
	peer = WebSocketPeer.new()
	was_open = false
	peer_id = -1
	actor_id = -1
	error = ""
	reset_round()

func reset_round() -> void:
	input_seq = 0
	last_ack = 0
	last_snapshot_seq = -1
	snapshots.clear()
	seen_events.clear()
	event_order.clear()

func fail(message: String) -> bool:
	error = message
	connection_error.emit(message)
	if peer.get_ready_state() == WebSocketPeer.STATE_OPEN: peer.close(1008, "Port contract violation")
	return false

func send_frame(frame: Dictionary) -> Error:
	if peer.get_ready_state() != WebSocketPeer.STATE_OPEN: return ERR_CONNECTION_ERROR
	return peer.send_text(JSON.stringify(frame))

func create_room() -> Error:
	return send_frame({"type":"create", "name":"Godot port laboratory", "playerName":"Godot", "v":3, "delta":0})

func configure_match(mode: String, bots: int = 2) -> Error:
	if not allowlist.has(requested_map) or not mode in allowlist[requested_map].modes:
		fail("Mode is not explicitly supported by the requested map")
		return ERR_INVALID_PARAMETER
	return send_frame({"type":"host", "mapId":requested_map, "config":{"mode":mode,"botCount":bots}})

func send_input(controls: Dictionary) -> Error:
	input_seq += 1
	return send_frame({"type":"input", "seq":input_seq, "input":controls})

func validate_map(id: Variant) -> bool:
	return id is String and id == requested_map and allowlist.has(id)

func decode_text(text: String) -> bool:
	if text.to_utf8_buffer().size() > MAX_FRAME_BYTES: return fail("Oversized frame")
	var value: Variant = JSON.parse_string(text)
	if not value is Dictionary or not value.get("type") is String: return fail("Malformed JSON envelope")
	var frame: Dictionary = value
	match frame.type:
		"welcome":
			if frame.get("v") != PROTOCOL_VERSION: return fail("Protocol version mismatch")
			peer_id = int(frame.get("peerId", -1))
		"lobby":
			# An unconfigured newly created server room has no selected content yet.
			if frame.get("config") != null and not validate_map(frame.get("mapId")): return fail("Lobby map substitution")
			for player: Dictionary in frame.get("players", []):
				if int(player.peerId) == peer_id and player.get("actorId") != null: actor_id = int(player.actorId)
			lobby.emit(frame)
		"start":
			if not validate_map(frame.get("mapId")): return fail("Start map substitution")
			reset_round()
			started.emit(frame)
		"snapshot", "results":
			if not frame.get("state") is Dictionary or not validate_map(frame.state.get("mapId")): return fail("Snapshot map substitution")
			if frame.type == "results":
				results.emit(frame)
				return true
			var seq: int = int(frame.get("seq", -1))
			if seq <= last_snapshot_seq: return true
			last_snapshot_seq = seq
			last_ack = maxi(last_ack, int(frame.get("acks", {}).get(str(actor_id), 0)))
			snapshots.append(frame)
			if snapshots.size() > 32: snapshots.pop_front()
			snapshot.emit(frame)
		"events":
			var fresh: Array = []
			for item: Dictionary in frame.get("items", []):
				if not item.has("id"): return fail("Event has no deduplication ID")
				var id: String = str(item.id)
				if seen_events.has(id): continue
				seen_events[id] = true
				event_order.append(id)
				if event_order.size() > 4096: seen_events.erase(event_order.pop_front())
				fresh.append(item)
			events.emit(fresh)
		"snapshot-delta": return fail("Unexpected delta frame; negotiated delta=0")
		"error": return fail(str(frame.get("message", "Server error")))
	return true

func _process(_delta: float) -> void:
	peer.poll()
	var state: int = peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		was_open = true
		while peer.get_available_packet_count() > 0:
			var packet: PackedByteArray = peer.get_packet()
			if not peer.was_string_packet():
				fail("Binary frame not supported")
				return
			if not decode_text(packet.get_string_from_utf8()): return
	elif state == WebSocketPeer.STATE_CLOSED and was_open:
		was_open = false
		reset_round()
		connection_error.emit("Disconnected; reconnect requires explicit fresh join")
