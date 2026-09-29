extends SceneTree
const Client = preload("res://net/client.gd")

func until(test: Callable, seconds: float = 12.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		if test.call(): return true
		await process_frame
	return false

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var url: String = OS.get_cmdline_user_args()[0]
	var client := Client.new()
	root.add_child(client)
	var result_events: Array = []
	var outcomes: Array[bool] = []
	client.results.connect(func(_frame: Dictionary) -> void: result_events.append(true))
	client.reconnect_outcome.connect(func(resumed: bool, _message: String) -> void: outcomes.append(resumed))
	var maps := {"meridian-exchange":{"modes":["deathmatch"]}}
	if client.connect_server(url, maps, "meridian-exchange") != OK or not await until(func() -> bool: return client.career_wire_open()): return failed("connect")
	if client.create_room("Offline result") != OK or not await until(func() -> bool: return not client.room_id.is_empty()): return failed("create")
	if client.send_frame({"type":"host","mapId":"meridian-exchange","config":{"mode":"deathmatch","botCount":0,"timeLimit":60}}) != OK: return failed("host")
	if client.send_frame({"type":"start"}) != OK or not await until(func() -> bool: return client.resumed_revision > 0 and client.actor_id >= 0): return failed("start")
	var room := client.room_id
	var actor := client.actor_id
	var revision := client.resumed_revision
	client.peer.close()
	if not await until(func() -> bool: return client.reconnect_ticket.expires_at > 0): return failed("drop")
	# The harness advances genuine Room.tick fixed steps, with no direct state
	# mutation or injected terminal/results frame. Never expose the room token.
	print("PORT_RESULTS_SOURCE_CLOCK_READY")
	if not await until(func() -> bool: return FileAccess.file_exists(OS.get_cmdline_user_args()[1])): return failed("source clock")
	if client.retry_reconnect(url, maps, "meridian-exchange", room) != OK: return failed("retry")
	if not await until(func() -> bool: return result_events.size() == 1): return failed("source results")
	if outcomes != [true] or client.room_id != room or client.actor_id != actor or client.resumed_revision != revision or not client.round_finished:
		return failed("seat/results identity")
	print("PORT_RECONNECT_OFFLINE_RESULTS_OK source_settlement=true result_frames=", result_events.size())
	client.disconnect_server()
	client.free()
	quit(0)

func failed(reason: String) -> void:
	push_error("Reconnect offline results: " + reason)
	quit(1)
