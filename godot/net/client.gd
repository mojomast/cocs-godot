class_name PortNetwork
extends Node

signal lobby(frame: Dictionary)
signal started(frame: Dictionary)
signal snapshot(frame: Dictionary)
signal events(items: Array)
signal results(frame: Dictionary)
signal connection_error(message: String)

const PROTOCOL_VERSION := 3
const Loadout = preload("res://ui/loadout.gd")
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
var spectating := false # Connection identity, not round state; never implies an actor.
const ACTIVE_SPECTATOR_NOTICE := "Match in progress — you joined as a spectator."
var joined_room_request := ""
# Identity the authority echoed for this connection. Empty means the frame carried
# no identity (older minimal rosters stay valid); it is never assumed from the
# local request.
var assigned_character := ""
var assigned_harness := ""
# One adjacent handshake only: queued join -> spectator welcome -> active roster -> notice.
var spectator_notice_stage := 0

func clear_join_context() -> void:
	spectating = false
	joined_room_request = ""
	spectator_notice_stage = 0
	assigned_character = ""
	assigned_harness = ""

func spectator_assignment(frame: Dictionary, player: Dictionary) -> bool:
	return frame.get("roomId") == room_id and not room_id.is_empty() and player.get("spectate") is bool and player.spectate and player.get("connected") is bool and player.connected and player.has("actorId") and player.actorId == null

func active_spectator_roster(frame: Dictionary) -> bool:
	var config: Variant = frame.get("config")
	var lifecycle: Variant = frame.get("lifecycle")
	return frame.get("started") is bool and frame.started and wire_integer(frame.get("hostId")) and frame.hostId != peer_id and wire_integer(frame.get("roundRevision")) and frame.roundRevision > 0 and lifecycle is Dictionary and lifecycle.get("phase") == "live" and validate_map(frame.get("mapId")) and config is Dictionary and config.get("mode") is String and config.mode in allowlist[requested_map].get("modes", [])

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
	clear_join_context()
	reset_round()

func reset_round() -> void:
	spectator_notice_stage = 0
	round_finished = false
	input_seq = 0
	last_ack = 0
	last_snapshot_seq = -1
	snapshots.clear()
	seen_events.clear()
	event_order.clear()

func fail(message: String) -> bool:
	spectator_notice_stage = 0
	error = message
	connection_error.emit(message)
	if peer.get_ready_state() == WebSocketPeer.STATE_OPEN: peer.close(1008, "Port contract violation")
	return false

func send_frame(frame: Dictionary) -> Error:
	if spectating and frame.get("type") in ["create", "join", "host", "start", "input"]: return ERR_UNAUTHORIZED
	if peer.get_ready_state() != WebSocketPeer.STATE_OPEN: return ERR_CONNECTION_ERROR
	return peer.send_text(JSON.stringify(frame))

func create_room(player_name: String = "Godot", character: String = "chatgpt", harness: String = "openclaw") -> Error:
	var pair: Dictionary = Loadout.resolve(character, harness)
	return send_frame({"type":"create", "name":"Godot port laboratory", "playerName":player_name, "character":pair.character, "harness":pair.harness, "v":3, "delta":0})

func join_room(id: String, player_name: String = "Godot guest", character: String = "", harness: String = "") -> Error:
	if id.is_empty(): return ERR_INVALID_PARAMETER
	var pair: Dictionary = Loadout.resolve(character, harness)
	var result := send_frame({"type":"join", "roomId":id, "name":player_name, "character":pair.character, "harness":pair.harness, "v":PROTOCOL_VERSION, "delta":0})
	if result == OK:
		joined_room_request = id
		spectator_notice_stage = 1
	return result

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
			for flag: String in ["spectate", "host", "reconnected"]:
				if frame.has(flag) and not frame[flag] is bool: return false
			return frame.get("roomId") is String and wire_integer(frame.get("peerId"))
		"lobby":
			if not frame.get("players", []) is Array: return false
			var peers: Dictionary = {}
			var actors: Dictionary = {}
			for player: Variant in frame.get("players", []):
				if not player is Dictionary or not wire_integer(player.get("peerId")): return false
				for flag: String in ["spectate", "connected"]:
					if player.has(flag) and not player[flag] is bool: return false
				# Identity is optional in the minimal roster contract; when the
				# authority sends it, it must be a string.
				for identity: String in ["character", "harness"]:
					if player.has(identity) and not player[identity] is String: return false
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
	if frame.type not in ["welcome", "lobby", "error"]: spectator_notice_stage = 0
	match frame.type:
		"welcome":
			if frame.get("v") != PROTOCOL_VERSION: return fail("Protocol version mismatch")
			if spectating: return fail("Unexpected welcome during spectator connection")
			room_id = str(frame.get("roomId", ""))
			peer_id = int(frame.get("peerId", -1))
			spectator_notice_stage = 2 if spectator_notice_stage == 1 and room_id == joined_room_request and frame.get("spectate") == true and frame.get("host") == false and not frame.get("reconnected", false) else 0
		"lobby":
			# An unconfigured newly created server room has no selected content yet.
			if frame.get("config") != null and not validate_map(frame.get("mapId")): return fail("Lobby map substitution")
			# A lobby is a complete roster, not a patch. Revoked/absent
			# assignments must not retain control of a previous actor.
			var next_actor_id: int = -1
			var self_player: Dictionary = {}
			# The roster is complete, so the echoed identity is too: an absent
			# identity clears the record instead of retaining a stale pair.
			assigned_character = ""
			assigned_harness = ""
			for player: Dictionary in frame.get("players", []):
				if int(player.peerId) == peer_id:
					self_player = player
					if player.get("character") is String: assigned_character = str(player.character)
					if player.get("harness") is String: assigned_harness = str(player.harness)
					if player.get("actorId") != null: next_actor_id = int(player.actorId)
			var readonly := spectator_assignment(frame, self_player)
			if spectating and not readonly: return fail("Spectator assignment changed; leave and join explicitly")
			if spectator_notice_stage == 2 and readonly: spectating = true
			spectator_notice_stage = 3 if spectator_notice_stage == 2 and spectating and readonly and active_spectator_roster(frame) else 0
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
		"error":
			var informational: bool = spectator_notice_stage == 3 and spectating and actor_id == -1 and frame.size() == 2 and frame.get("message") == ACTIVE_SPECTATOR_NOTICE
			spectator_notice_stage = 0
			if informational: return true
			return fail(str(frame.get("message", "Server error")))
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
		clear_join_context()
		connection_error.emit("Disconnected; reconnect requires explicit fresh join")
