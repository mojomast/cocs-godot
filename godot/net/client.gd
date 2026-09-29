class_name PortNetwork
extends Node

signal lobby(frame: Dictionary)
signal started(frame: Dictionary)
signal snapshot(frame: Dictionary)
signal events(items: Array)
signal results(frame: Dictionary)
signal connection_error(message: String)
signal transport_dropped(message: String)
signal reconnect_outcome(resumed: bool, message: String)
# ---------------------------------------------------------------------------
# Additive social surface (room browser + room-scoped text chat). These never
# participate in seating, identity, persistence or gameplay authority; they only
# expose the existing `list` / `chat` verbs of the authoritative protocol. An
# out-of-room chat refusal or a malformed social reply is a non-fatal notice.
# ---------------------------------------------------------------------------
signal rooms(items: Array)
signal chat(message: Dictionary)
signal social_error(message: String)

const PROTOCOL_VERSION := 3
# Social wire verbs (game/protocol.mjs MESSAGE.CHAT / MESSAGE.LIST). Only used to
# classify an `unknown message type: <verb>` capability notice as non-fatal.
const MESSAGE_VERB_CHAT := "chat"
const MESSAGE_VERB_LIST := "list"
const SocialModel = preload("res://social/social_model.gd")
const Loadout = preload("res://ui/loadout.gd")
const ReconnectTicket = preload("res://net/reconnect_ticket.gd")
const MAX_FRAME_BYTES := 1048576 # bounded initial cap; capture is not all-map worst case
var peer := WebSocketPeer.new()
var allowlist: Dictionary = {}
var requested_map: String = ""
var connection_endpoint: String = ""
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
var career_welcome_pending := false
var career_seated := false
var reconnect_ticket := ReconnectTicket.new()
var reconnect_pending := false
var reconnect_room := ""
var reconnect_actor := -1
var reconnect_spectator := false
var reconnect_elapsed := 0.0
var resumed_revision := -1
var resume_start_expected := false
var resumed_actor_expected := -2
const RECONNECT_TIMEOUT := 8.0

func career_wire_open() -> bool:
	return peer.get_ready_state() == WebSocketPeer.STATE_OPEN

func clear_join_context() -> void:
	career_welcome_pending = false
	career_seated = false
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
	var result := peer.connect_to_url(endpoint)
	if result == OK: connection_endpoint = endpoint
	return result

func disconnect_server() -> void:
	reconnect_ticket.clear()
	reconnect_pending = false
	resume_start_expected = false
	resumed_actor_expected = -2
	resumed_revision = -1
	career_clear()
	identity_clear()
	if peer.get_ready_state() != WebSocketPeer.STATE_CLOSED: peer.close()
	peer = WebSocketPeer.new()
	was_open = false
	connection_endpoint = ""
	room_id = ""
	peer_id = -1
	actor_id = -1
	error = ""
	clear_join_context()
	reset_round()

func reset_round() -> void:
	spectator_notice_stage = 0
	round_finished = false
	# Source resets its received sequence on a real new round, but a resumed
	# start belongs to the existing round. Its client high-water must survive.
	if not reconnect_pending: input_seq = 0
	last_ack = 0
	last_snapshot_seq = -1
	snapshots.clear()
	seen_events.clear()
	event_order.clear()

func fail(message: String) -> bool:
	reconnect_ticket.clear()
	reconnect_pending = false
	resume_start_expected = false
	resumed_actor_expected = -2
	career_clear()
	identity_clear()
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
	if not identity_storage_ready(): return ERR_FILE_CORRUPT
	var pair: Dictionary = Loadout.resolve(character, harness)
	var frame := {"type":"create", "name":"Godot port laboratory", "playerName":player_name, "character":pair.character, "harness":pair.harness, "v":3, "delta":0}
	frame.merge(identity_fields())
	var result := send_frame(frame)
	if result != OK: identity_clear()
	if result == OK:
		career_clear()
		career_seated = false
		career_welcome_pending = true
	return result

func join_room(id: String, player_name: String = "Godot guest", character: String = "", harness: String = "") -> Error:
	if id.is_empty(): return ERR_INVALID_PARAMETER
	if not identity_storage_ready(): return ERR_FILE_CORRUPT
	var pair: Dictionary = Loadout.resolve(character, harness)
	var frame := {"type":"join", "roomId":id, "name":player_name, "character":pair.character, "harness":pair.harness, "v":PROTOCOL_VERSION, "delta":0}
	frame.merge(identity_fields())
	var result := send_frame(frame)
	if result != OK: identity_clear()
	if result == OK:
		career_clear()
		career_seated = false
		career_welcome_pending = true
		joined_room_request = id
		spectator_notice_stage = 1
	return result

# Called only by an explicit Retry action after a transport close. No source
# credential is carried into settings, arguments, traces or diagnostics.
func retry_reconnect(url: String, maps: Dictionary, map_id: String, expected_room: String) -> Error:
	if not reconnect_ticket.available(url, map_id, expected_room): return ERR_UNAUTHORIZED
	if reconnect_pending: return ERR_BUSY
	var saved_actor: int = reconnect_ticket.actor_id
	var saved_spectator: bool = reconnect_ticket.spectator
	var saved_token: String = reconnect_ticket.token
	# Replace transport and stale cached projections, retaining only this bounded
	# in-memory ticket and the input sequence from the previous socket.
	peer = WebSocketPeer.new()
	peer.inbound_buffer_size = MAX_FRAME_BYTES * 2
	peer.outbound_buffer_size = 65536
	peer.max_queued_packets = 128
	allowlist = maps
	requested_map = map_id
	connection_endpoint = url
	was_open = false
	room_id = ""
	peer_id = -1
	actor_id = -1
	error = ""
	clear_join_context()
	last_ack = 0
	last_snapshot_seq = -1
	snapshots.clear()
	seen_events.clear()
	event_order.clear()
	round_finished = false
	reconnect_pending = true
	resume_start_expected = false
	resumed_actor_expected = -2
	reconnect_room = expected_room
	reconnect_actor = saved_actor
	reconnect_spectator = saved_spectator
	reconnect_elapsed = 0.0
	# Keep the private token solely on this instance; queue join once OPEN.
	reconnect_ticket.token = saved_token
	var result := peer.connect_to_url(url)
	if result != OK: reconnect_failed("Reconnect could not open the transport.")
	return result

func reconnect_failed(message: String) -> void:
	reconnect_pending = false
	resume_start_expected = false
	resumed_actor_expected = -2
	reconnect_ticket.clear()
	if peer.get_ready_state() != WebSocketPeer.STATE_CLOSED: peer.close()
	was_open = false
	reconnect_outcome.emit(false, message)

# A social verb the server never implemented (`unknown message type: chat` /
# `: list`) or a chat sent without a seat is a capability/seat notice, not a
# protocol violation: the connection and the seated identity stay intact.
func social_refusal(message: Variant) -> bool:
	if not message is String: return false
	if message == "not in a room": return true
	if not message.begins_with("unknown message type: "): return false
	var verb: String = message.trim_prefix("unknown message type: ").strip_edges()
	return verb == MESSAGE_VERB_CHAT or verb == MESSAGE_VERB_LIST

# Room browser. The authority answers a `list` request with a `rooms` frame on
# this same connection; it never creates, joins or changes a seat. Browsing is
# therefore honest about scope: only rooms this endpoint already advertises.
func request_rooms() -> Error:
	return send_frame({"type":"list"})

# Room-scoped text chat. The authority sanitizes, rate-limits and broadcasts the
# accepted line back to the room, so this client never optimistically echoes a
# message it sent. The draft is bounded by the same source sanitizer the UI and
# the server use (control strip + JS trim + 200 UTF-16 units), so a message this
# client accepts is byte-identical to the authority's echo and the pending line
# resolves without an emoji/surrogate mismatch.
func send_chat(text: String) -> Error:
	var clean := SocialModel.sanitize(text, SocialModel.CHAT_TEXT_LIMIT)
	if clean.is_empty(): return ERR_INVALID_PARAMETER
	return send_frame({"type":"chat", "text":clean})

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
			if frame.has("token") and (not frame.token is String or frame.token.is_empty() or frame.token.length() > 128): return false
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
			if reconnect_pending:
				if frame.get("roomId") != reconnect_room: return fail("Reconnect room mismatch")
				var resumed: bool = frame.get("reconnected") == true
				if resumed and (frame.get("spectate") != reconnect_spectator or frame.get("token") != reconnect_ticket.token): return fail("Reconnect seat mismatch")
				# A false reconnected flag is an ordinary new join, potentially a
				# spectator in a live round. Never restore the old actor locally.
				reconnect_pending = false
				resume_start_expected = resumed
				resumed_actor_expected = reconnect_actor if resumed else -2
				if not resumed: input_seq = 0
				reconnect_ticket.clear()
				reconnect_outcome.emit(resumed, "Seat restored." if resumed else "Old seat expired; source admitted a fresh join. Live rounds are spectator-only.")
			var career_admitted := career_welcome_pending and career_wire_open()
			if not career_admitted and career_wire_open() and not reconnect_room.is_empty(): career_admitted = true
			if career_admitted:
				career_welcome_pending = false
				career_seated = true
			room_id = str(frame.get("roomId", ""))
			peer_id = int(frame.get("peerId", -1))
			if frame.get("token") is String:
				reconnect_ticket.remember(frame.token, connection_endpoint, requested_map, room_id, reconnect_actor if frame.get("reconnected") == true else -1, frame.get("spectate") == true, frame.get("host") == true)
			if career_admitted: career_receive(frame)
			if career_admitted:
				if joined_room_request.is_empty() or frame.get("roomId") == joined_room_request: identity_accept(frame)
				else: identity_clear()
			spectator_notice_stage = 2 if (spectator_notice_stage == 1 or (not reconnect_room.is_empty() and frame.get("reconnected") != true)) and room_id == (joined_room_request if not joined_room_request.is_empty() else reconnect_room) and frame.get("spectate") == true and frame.get("host") == false and not frame.get("reconnected", false) else 0
			if frame.get("reconnected") == true and frame.get("spectate") == true: spectating = true
			reconnect_room = ""
		"profile", "progression":
			if career_seated and career_wire_open(): career_receive(frame)
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
			if resumed_actor_expected != -2:
				# A pre-start player has no actor yet; the host may have started
				# while this transport was down. Existing actor ownership is strict.
				if resumed_actor_expected >= 0 and next_actor_id != resumed_actor_expected: return fail("Reconnect actor mismatch")
				resumed_actor_expected = -2
			if not reconnect_ticket.token.is_empty() and room_id == reconnect_ticket.room_id:
				reconnect_ticket.actor_id = next_actor_id
				reconnect_ticket.spectator = spectating
				reconnect_ticket.host = frame.get("hostId") == peer_id and not spectating
			lobby.emit(frame)
		"start":
			if not validate_map(frame.get("mapId")): return fail("Start map substitution")
			# The reattach start is an observation of the existing round. Clear
			# snapshots/events but preserve the prior input high-water.
			var previous_input: int = input_seq
			reset_round()
			if resume_start_expected and frame.get("roundRevision") == resumed_revision: input_seq = previous_input
			resume_start_expected = false
			if wire_integer(frame.get("roundRevision")): resumed_revision = int(frame.roundRevision)
			if career_seated and career_wire_open(): career_receive(frame)
			started.emit(frame)
		"snapshot", "results":
			if not frame.get("state") is Dictionary or not validate_map(frame.state.get("mapId")): return fail("Snapshot map substitution")
			if round_finished: return true
			if frame.type == "results":
				round_finished = true
				if career_seated and career_wire_open(): career_receive(frame)
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
		"history":
			if career_seated and career_wire_open(): career_receive(frame)
		"rooms":
			# Additive room-browser reply. A malformed list is a social notice,
			# never a session teardown or an invented empty room set.
			var rows: Variant = frame.get("rooms")
			if not rows is Array:
				social_error.emit("Room list reply was malformed.")
				return true
			rooms.emit(rows)
		"chat":
			# Additive room-scoped chat line. Only `text` is structurally
			# required; sender identity is display metadata and stays untrusted.
			if not frame.get("text") is String:
				social_error.emit("Chat reply was malformed.")
				return true
			chat.emit(frame)
		"snapshot-delta": return fail("Unexpected delta frame; negotiated delta=0")
		"error":
			var informational: bool = spectator_notice_stage == 3 and spectating and actor_id == -1 and frame.size() == 2 and frame.get("message") == ACTIVE_SPECTATOR_NOTICE
			spectator_notice_stage = 0
			if informational: return true
			var message := str(frame.get("message", "Server error"))
			# A chat sent without a seated room, or a social verb a server never
			# implemented, is a notice for the social surface: keep the
			# connection. Every other error frame stays fatal as before.
			if not frame.has("code") and social_refusal(frame.get("message")):
				social_error.emit(message)
				return true
			if not frame.has("code") and message == "unknown message type: history":
				if career_seated and career_wire_open(): career_receive({"type":"history-error", "message":message})
				return true
			return fail(message)
	return true

func _process(_delta: float) -> void:
	peer.poll()
	var state: int = peer.get_ready_state()
	if reconnect_pending:
		reconnect_elapsed += _delta
		if reconnect_elapsed > RECONNECT_TIMEOUT or not reconnect_ticket.available(connection_endpoint, requested_map, reconnect_room):
			reconnect_failed("Reconnect timed out or the seat grace window expired.")
			return
		if state == WebSocketPeer.STATE_OPEN and not was_open:
			career_welcome_pending = true
			joined_room_request = reconnect_room
			spectator_notice_stage = 1
			if send_frame({"type":"join", "roomId":reconnect_room, "token":reconnect_ticket.token, "v":PROTOCOL_VERSION, "delta":0}) != OK:
				reconnect_failed("Reconnect request could not be queued.")
				return
	if state == WebSocketPeer.STATE_OPEN:
		was_open = true
		while peer.get_available_packet_count() > 0:
			var packet: PackedByteArray = peer.get_packet()
			if not peer.was_string_packet():
				fail("Binary frame not supported")
				return
			if not decode_text(packet.get_string_from_utf8()): return
	elif state == WebSocketPeer.STATE_CLOSED and was_open:
		career_clear()
		identity_clear()
		was_open = false
		var recoverable := error.is_empty() and reconnect_ticket.dropped()
		if reconnect_pending:
			reconnect_failed("Reconnect transport closed before seat confirmation.")
			return
		last_snapshot_seq = -1
		snapshots.clear()
		seen_events.clear()
		event_order.clear()
		room_id = ""
		peer_id = -1
		actor_id = -1
		clear_join_context()
		if recoverable: transport_dropped.emit("Connection lost. Retry the same room within the grace window, or Leave.")
		else: connection_error.emit("Disconnected. Join a new room explicitly.")

func career_receive(frame: Dictionary) -> void:
	var service := get_tree().root.get_node_or_null("Career") if is_inside_tree() else null
	if service != null: service.receive(self, frame)

func career_clear() -> void:
	var service := get_tree().root.get_node_or_null("Career") if is_inside_tree() else null
	if service != null: service.clear_connection(self)

func identity_fields() -> Dictionary:
	var identity := get_tree().root.get_node_or_null("Identity") if is_inside_tree() else null
	return identity.request_fields(self) if identity != null else {}

func identity_storage_ready() -> bool:
	var identity := get_tree().root.get_node_or_null("Identity") if is_inside_tree() else null
	if identity != null and not identity.status.is_empty():
		connection_error.emit(identity.status)
		return false
	return true

func identity_accept(frame: Dictionary) -> void:
	var identity := get_tree().root.get_node_or_null("Identity") if is_inside_tree() else null
	if identity != null: identity.accept_welcome(self, frame)

func identity_clear() -> void:
	var identity := get_tree().root.get_node_or_null("Identity") if is_inside_tree() else null
	if identity != null: identity.clear_connection(self)
