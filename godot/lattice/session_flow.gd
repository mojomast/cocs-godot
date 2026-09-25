extends RefCounted
const SessionOptions = preload("res://lattice/session_options.gd")
## Explicit host/guest lifecycle policy. One client/socket is supplied by caller.
signal state_changed(state: Dictionary)
signal configuration_echoed(config: Dictionary)
signal round_result(result: Dictionary)

enum State { DISCONNECTED, CONNECTING, HOST_CONFIGURING, HOST_WAITING, GUEST_JOINING, GUEST_WAITING, LIVE, RESULTS, FAILED }
var state := State.DISCONNECTED
var reason := ""
var requested: Dictionary = {}
var echoed: Dictionary = {}
var minimum_humans := 0
var host_peer := -1

func sourced_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= 9007199254740991.0 and floorf(float(value)) == float(value)

func publish(next_state: int, why: String = "") -> void:
	state = next_state
	reason = why
	state_changed.emit(snapshot())

func snapshot() -> Dictionary:
	return {"state":state,"reason":reason,"requested":requested.duplicate(true),
		"echoed":echoed.duplicate(true),"minimum_humans":minimum_humans,"host_peer":host_peer}

func request_configuration(options: Dictionary, client: Node) -> Dictionary:
	var problem := SessionOptions.validate(options)
	if not problem.is_empty(): return {"queued":false,"reason":problem,"queue_state":state}
	requested = options.duplicate(true)
	if options.get("join", false): return {"queued":false,"reason":"Guests cannot configure the host","queue_state":state}
	if client.spectating or client.peer_id < 0 or client.peer_id != host_peer: return {"queued":false,"reason":"Source roster does not authorize this peer as host","queue_state":state}
	var error: Error = client.send_frame(SessionOptions.host_frame(options))
	if error != OK: return {"queued":false,"reason":"Configuration could not be queued","queue_state":state}
	publish(State.HOST_CONFIGURING)
	return {"queued":true,"reason":"","queue_state":state}

func join(client: Node, endpoint: String, room: String, player: String, character: String, harness: String) -> Dictionary:
	if room.is_empty(): return {"queued":false,"reason":"Room ID required","queue_state":state}
	if not (endpoint.begins_with("ws://") or endpoint.begins_with("wss://")): return {"queued":false,"reason":"Explicit WebSocket endpoint required","queue_state":state}
	var err: Error = client.join_room(room, player, character, harness)
	if err != OK: return {"queued":false,"reason":"Join could not be queued","queue_state":state}
	publish(State.GUEST_JOINING)
	return {"queued":true,"reason":"","queue_state":state}

func observe_roster(frame: Dictionary, client: Node) -> void:
	var players: Array = frame.get("players", [])
	host_peer = int(frame.get("hostId")) if sourced_integer(frame.get("hostId")) else -1
	var lobby_cocs: Variant = frame.get("cocs")
	minimum_humans = int(lobby_cocs.get("minHumans")) if lobby_cocs is Dictionary and sourced_integer(lobby_cocs.get("minHumans")) and lobby_cocs.get("minHumans") <= 16 else 0
	if client.peer_id == host_peer: return
	if state == State.GUEST_JOINING: publish(State.GUEST_WAITING, "Joined; waiting for host start")

func observe_start(frame: Dictionary, map_id: String, mode: String) -> bool:
	var config: Variant = frame.get("config")
	if not config is Dictionary or frame.get("mapId") != map_id or config.get("mode") != mode:
		publish(State.FAILED, "Start echo does not match selected map/mode")
		return false
	if not requested.is_empty():
		if config.get("timeLimit") != requested.get("time_limit") or config.get("rung") != requested.get("rung"):
			publish(State.FAILED, "Start echo does not match requested time/rung")
			return false
		if requested.get("rung") == null and config.get("botCount") != requested.get("bots"):
			publish(State.FAILED, "Start echo does not match requested practice/Operations bot count")
			return false
	if requested.get("rung") != null:
		if host_peer < 0:
			publish(State.FAILED, "Start lacks current source roster host identity")
			return false
		if minimum_humans < 1:
			publish(State.FAILED, "Start lacks a valid sourced human-floor echo")
			return false
	echoed = config.duplicate(true)
	configuration_echoed.emit(echoed.duplicate(true))
	publish(State.LIVE)
	return true

func start(client: Node, roster: Dictionary) -> Dictionary:
	if client.peer_id < 0 or client.peer_id != roster.get("hostId", -1): return {"queued":false,"reason":"Only source roster host may start","queue_state":state}
	if state not in [State.HOST_WAITING, State.RESULTS]: return {"queued":false,"reason":"Host is not awaiting start or restart","queue_state":state}
	if requested.get("rung") != null and minimum_humans < 1:
		return {"queued":false,"reason":"Waiting for source rung floor echo","queue_state":state}
	if minimum_humans > 0 and current_humans(roster) < minimum_humans:
		var why := "Waiting for %d connected human players (%d/%d)" % [minimum_humans, current_humans(roster), minimum_humans]
		publish(State.HOST_WAITING, why)
		return {"queued":false,"reason":why,"queue_state":state}
	var err: Error = client.send_frame({"type":"start"})
	if err != OK: return {"queued":false,"reason":"Start could not be queued","queue_state":state}
	publish(State.HOST_CONFIGURING, "Start requested; waiting for authoritative start")
	return {"queued":true,"reason":"","queue_state":state}

func restart(client: Node, roster: Dictionary) -> Dictionary:
	if state != State.RESULTS: return {"queued":false,"reason":"No completed round","queue_state":state}
	return start(client, roster)

func current_humans(roster: Dictionary) -> int:
	var count := 0
	for player: Variant in roster.get("players", []):
		# Lobby roster is authoritative before actors exist; actorId is null until start.
		if player is Dictionary and player.get("connected") == true and player.get("spectate") != true: count += 1
	return count


func observe_result(result: Dictionary) -> void:
	publish(State.RESULTS)
	round_result.emit(result.duplicate(true))

func disconnect(client: Node) -> void:
	client.disconnect_server()
	echoed.clear()
	requested.clear()
	host_peer = -1
	minimum_humans = 0
	publish(State.DISCONNECTED)
