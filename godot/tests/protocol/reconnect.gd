extends SceneTree
const Client = preload("res://net/client.gd")
var checks := 0

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		push_error("Reconnect check %d: %s" % [checks, description])
		quit(1)
		assert(value)

func until(test: Callable, seconds: float = 5.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		if test.call(): return true
		await process_frame
	return false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Endpoint argument required")
		quit(1)
		return
	var url: String = args[0]
	var maps := {"meridian-exchange":{"modes":["deathmatch"]}}
	var c := Client.new()
	var outcomes: Array[bool] = []
	c.reconnect_outcome.connect(func(resumed: bool, _message: String) -> void: outcomes.append(resumed))
	root.add_child(c)
	check(c.connect_server(url, maps, "meridian-exchange") == OK, "connect")
	check(await until(func() -> bool: return c.career_wire_open()), "socket opens")
	check(c.create_room("Reconnect") == OK, "create")
	check(await until(func() -> bool: return not c.room_id.is_empty()), "source welcome")
	var identity: Node = root.get_node_or_null("Identity")
	var career: Node = root.get_node_or_null("Career")
	var original_credentials: Dictionary = identity.get("_active").duplicate() if identity != null else {}
	var original_profile: String = str(career.profile.get("id", "")) if career != null else ""
	check(not original_credentials.is_empty() and not original_profile.is_empty(), "source-owned career identity admitted")
	var room := c.room_id
	check(c.configure_match("deathmatch", 0) == OK, "configure")
	check(c.send_frame({"type":"start"}) == OK, "start")
	check(await until(func() -> bool: return c.resumed_revision > 0 and c.actor_id >= 0 and c.last_snapshot_seq >= 0), "authoritative actor/start/snapshot")
	var actor := c.actor_id
	var revision := c.resumed_revision
	for i in 12:
		check(c.send_input({"x":0,"z":0}) == OK, "input queued")
		await process_frame
	check(await until(func() -> bool: return c.last_ack > 0), "source ACK")
	var previous_input := c.input_seq
	c.peer.close()
	check(await until(func() -> bool: return c.room_id.is_empty() and c.reconnect_ticket.expires_at > 0), "transport close retains bounded ticket")
	check(c.retry_reconnect(url + "/other", maps, "meridian-exchange", room) == ERR_UNAUTHORIZED, "endpoint bound")
	check(c.retry_reconnect(url, maps, "other-map", room) == ERR_UNAUTHORIZED, "map bound")
	check(c.retry_reconnect(url, maps, "meridian-exchange", "other-room") == ERR_UNAUTHORIZED, "room bound")
	check(c.retry_reconnect(url, maps, "meridian-exchange", room) == OK, "explicit retry")
	check(await until(func() -> bool: return c.room_id == room and c.actor_id == actor and c.resumed_revision == revision and c.last_snapshot_seq >= 0), "same seat and round restored")
	check(outcomes == [true], "source confirmed actual resume")
	check(c.input_seq >= previous_input, "input high-water retained")
	check(c.send_input({"x":0,"z":0}) == OK and c.input_seq > previous_input, "post-resume seq increases")
	check(await until(func() -> bool: return c.last_ack > 0), "fresh source ACK")
	check(c.reconnect_ticket.host and not c.spectating, "host authority echoed by roster")
	check(c.retry_reconnect(url, maps, "meridian-exchange", room) == ERR_UNAUTHORIZED, "open socket cannot reattach")
	# A live-room join must remain read-only, including after reattaching its
	# spectator ticket. The host's match continues on the same authority.
	var spectator := Client.new()
	root.add_child(spectator)
	check(spectator.connect_server(url, maps, "meridian-exchange") == OK, "spectator connect")
	check(await until(func() -> bool: return spectator.career_wire_open()), "spectator socket")
	check(spectator.join_room(room) == OK, "live join")
	check(await until(func() -> bool: return spectator.spectating and spectator.last_snapshot_seq >= 0), "source live spectator")
	check(spectator.actor_id == -1 and spectator.send_input({"x":1}) == ERR_UNAUTHORIZED, "spectator read-only")
	spectator.peer.close()
	check(await until(func() -> bool: return spectator.reconnect_ticket.expires_at > 0), "spectator ticket")
	check(spectator.retry_reconnect(url, maps, "meridian-exchange", room) == OK, "spectator retry")
	check(await until(func() -> bool: return spectator.spectating and spectator.last_snapshot_seq >= 0), "spectator reattached")
	check(spectator.actor_id == -1 and spectator.send_input({"fire":true}) == ERR_UNAUTHORIZED, "reattached spectator read-only")
	spectator.disconnect_server()
	spectator.free()
	# Expired token cannot resurrect a seat; the source may admit a new live
	# spectator, and native must identify that as a fresh join, not a resume.
	var expired := Client.new()
	var expired_outcomes: Array[bool] = []
	expired.reconnect_outcome.connect(func(resumed: bool, _message: String) -> void: expired_outcomes.append(resumed))
	root.add_child(expired)
	check(expired.connect_server(url, maps, "meridian-exchange") == OK, "expiry fixture connect")
	check(await until(func() -> bool: return expired.career_wire_open()), "expiry socket")
	check(expired.join_room(room) == OK, "expiry fixture join")
	check(await until(func() -> bool: return expired.spectating), "expiry fixture spectator")
	expired.peer.close()
	check(await until(func() -> bool: return expired.reconnect_ticket.expires_at > 0), "expiry fixture drop")
	var until_expiry := Time.get_ticks_msec() + 1700
	while Time.get_ticks_msec() < until_expiry: await process_frame
	check(expired.retry_reconnect(url, maps, "meridian-exchange", room) == OK, "retry within native bound")
	check(await until(func() -> bool: return expired.spectating and expired.last_snapshot_seq >= 0), "source admitted fresh spectator after grace")
	check(expired_outcomes == [false], "expired token never reports resumed")
	check(str(career.profile.get("id", "")) == original_profile and identity.get("_active") == original_credentials, "expired room seat retains persistent career identity")
	check(expired.actor_id == -1 and expired.send_input({"fire":true}) == ERR_UNAUTHORIZED, "expired seat never controls actor")
	expired.disconnect_server()
	expired.free()
	c.disconnect_server()
	check(c.reconnect_ticket.token.is_empty(), "intentional leave forgets ticket")
	check(c.reconnect_room.is_empty() and not c.career_welcome_pending, "leave clears pending context")
	c.reconnect_room = room
	c.reconnect_pending = true
	c.career_welcome_pending = true
	c.reconnect_failed("Controlled cancelled retry")
	check(c.reconnect_room.is_empty() and not c.career_welcome_pending and c.reconnect_ticket.token.is_empty(), "failed retry clears all admission context")
	check(c.connect_server(url, maps, "meridian-exchange") == OK, "new unseated transport")
	check(await until(func() -> bool: return c.career_wire_open()), "unseated socket opens")
	# Controlled late envelope: the source does not issue this frame on an
	# unseated connection. Its token must never create a native ticket.
	check(c.decode_text(JSON.stringify({"type":"welcome","v":3,"roomId":room,"peerId":500,"token":"synthetic-late-ticket","profile":{"id":"synthetic-profile"}})), "late welcome ignored")
	check(c.room_id.is_empty() and c.reconnect_ticket.token.is_empty() and not c.career_seated and identity.get("_active") == original_credentials, "late welcome cannot bind career or ticket")
	c.disconnect_server()
	c.free()
	print("PORT_NATIVE_RECONNECT_OK checks=", checks, " genuine_source_socket=true")
	quit(0)
