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
var room_id: String = ""
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
var round_finished: bool = false

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
	room_id = ""
	peer_id = -1
	actor_id = -1
	error = ""
	reset_round()

func reset_round() -> void:
	round_finished = false
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

func create_room(player_name: String = "Godot") -> Error:
	return send_frame({"type":"create", "name":"Godot port laboratory", "playerName":player_name, "v":3, "delta":0})

func join_room(id: String, player_name: String = "Godot guest") -> Error:
	if id.is_empty(): return ERR_INVALID_PARAMETER
	return send_frame({"type":"join", "roomId":id, "name":player_name, "v":PROTOCOL_VERSION, "delta":0})

func configure_match(mode: String, bots: int = 2) -> Error:
	if not allowlist.has(requested_map) or not mode in allowlist[requested_map].modes:
		fail("Mode is not explicitly supported by the requested map")
		return ERR_INVALID_PARAMETER
	return send_frame({"type":"host", "mapId":requested_map, "config":{"mode":mode,"botCount":bots}})

func send_input(controls: Dictionary) -> Error:
	# Failed queue attempts must not consume sequence numbers.
	var next_seq: int = input_seq + 1
	var result: Error = send_frame({"type":"input", "seq":next_seq, "input":controls})
	if result == OK: input_seq = next_seq
	return result

func validate_map(id: Variant) -> bool:
	return id is String and id == requested_map and allowlist.has(id)

# Validate container/scalar shapes before typed iteration or integer conversion.
# This is envelope hardening, not a complete gameplay-state schema.
func wire_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) <= 9007199254740991.0 and floorf(float(value)) == float(value)

func valid_envelope(frame: Dictionary) -> bool:
	match frame.type:
		"welcome":
			return frame.get("roomId") is String and wire_integer(frame.get("peerId"))
		"lobby":
			if not frame.get("players", []) is Array: return false
			var peers: Dictionary = {}
			var actors: Dictionary = {}
			for player: Variant in frame.get("players", []):
				if not player is Dictionary or not wire_integer(player.get("peerId")): return false
				var id: int = int(player.peerId)
				if peers.has(id): return false
				peers[id] = true
				if player.get("actorId") != null:
					if not wire_integer(player.actorId): return false
					var assigned: int = int(player.actorId)
					# Actor ownership must be unique; unassigned spectators may repeat.
					if actors.has(assigned): return false
					actors[assigned] = true
		"snapshot":
			if not wire_integer(frame.get("seq")) or not frame.get("acks", {}) is Dictionary: return false
			for ack: Variant in frame.get("acks", {}).values():
				if not wire_integer(ack): return false
		"events":
			if not frame.get("items", []) is Array: return false
			for item: Variant in frame.get("items", []):
				if not item is Dictionary: return false
				var id: Variant = item.get("id")
				if not ((id is String and not id.is_empty()) or wire_integer(id)): return false
	return true

func decode_text(text: String) -> bool:
	if text.to_utf8_buffer().size() > MAX_FRAME_BYTES: return fail("Oversized frame")
	var value: Variant = JSON.parse_string(text)
	if not value is Dictionary or not value.get("type") is String: return fail("Malformed JSON envelope")
	var frame: Dictionary = value
	if not valid_envelope(frame): return fail("Malformed protocol envelope")
	match frame.type:
		"welcome":
			if frame.get("v") != PROTOCOL_VERSION: return fail("Protocol version mismatch")
			room_id = str(frame.get("roomId", ""))
			peer_id = int(frame.get("peerId", -1))
		"lobby":
			# An unconfigured newly created server room has no selected content yet.
			if frame.get("config") != null and not validate_map(frame.get("mapId")): return fail("Lobby map substitution")
			# A lobby is a complete roster, not a patch. Revoked/absent
			# assignments must not retain control of a previous actor.
			var next_actor_id: int = -1
			for player: Dictionary in frame.get("players", []):
				if int(player.peerId) == peer_id and player.get("actorId") != null: next_actor_id = int(player.actorId)
			# ACKs belong to an actor; input sequences belong to this connection.
			# Do not carry an old actor's high-water mark into a new assignment.
			if next_actor_id != actor_id: last_ack = 0
			actor_id = next_actor_id
			lobby.emit(frame)
		"start":
			if not validate_map(frame.get("mapId")): return fail("Start map substitution")
			reset_round()
			started.emit(frame)
		"snapshot", "results":
			if not frame.get("state") is Dictionary or not validate_map(frame.state.get("mapId")): return fail("Snapshot map substitution")
			if round_finished: return true
			if frame.type == "results":
				round_finished = true
				results.emit(frame)
				return true
			var seq: int = int(frame.get("seq", -1))
			if seq <= last_snapshot_seq: return true
			last_snapshot_seq = seq
			# -1 is an internal unassigned sentinel, never an ACK owner.
			if actor_id >= 0:
				last_ack = maxi(last_ack, int(frame.get("acks", {}).get(str(actor_id), 0)))
			snapshots.append(frame)
			if snapshots.size() > 32: snapshots.pop_front()
			snapshot.emit(frame)
		"events":
			if round_finished: return true
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
		room_id = ""
		peer_id = -1
		actor_id = -1
		connection_error.emit("Disconnected; reconnect requires explicit fresh join")
